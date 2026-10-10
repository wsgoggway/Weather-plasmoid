// SPDX-FileCopyrightText: 2026 Vladimir Manichev
// SPDX-License-Identifier: MIT

// Offline unit tests for the weather data layer: fixture parsing, cache
// merge/persistence, WMO mapping and temperature formatting. No network
// access happens here (ensureRange is only exercised without a location).

#include "weatherdatastore.h"
#include "wmoconditions.h"

#include <QDate>
#include <QFile>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QLatin1String>
#include <QRegularExpression>
#include <QSet>
#include <QSignalSpy>
#include <QTemporaryDir>
#include <QtGlobal>
#include <QtTest/QtTest>

#include <algorithm>
#include <array>
#include <optional>

namespace {

constexpr char16_t typographicMinus = u'\u2212';

// Reference stop colors from the contract, as RGB.
constexpr int coldRed = 0x15, coldGreen = 0x65, coldBlue = 0xc0; // #1565c0
constexpr int hotRed = 0xe5, hotGreen = 0x39, hotBlue = 0x35;   // #e53935

struct Rgb
{
    int red = 0;
    int green = 0;
    int blue = 0;
};

Rgb parseRgb(const QString &hex)
{
    Rgb rgb;
    rgb.red = hex.mid(1, 2).toInt(nullptr, 16);
    rgb.green = hex.mid(3, 2).toInt(nullptr, 16);
    rgb.blue = hex.mid(5, 2).toInt(nullptr, 16);
    return rgb;
}

qint64 squaredDistance(const Rgb &a, int r, int g, int b)
{
    const qint64 dr = a.red - r;
    const qint64 dg = a.green - g;
    const qint64 db = a.blue - b;
    return dr * dr + dg * dg + db * db;
}

QByteArray readFile(const QString &path)
{
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly)) {
        return {};
    }
    return file.readAll();
}

// Synthetic single-day Open-Meteo payload (full column set, like the API).
QByteArray singleDayPayload(const QString &date, int wmoCode, double tMax)
{
    QJsonArray times;
    times.append(date);
    QJsonArray codes;
    codes.append(wmoCode);
    QJsonArray tMaxArr;
    tMaxArr.append(tMax);
    QJsonArray tMinArr;
    tMinArr.append(tMax - 5.5);
    QJsonArray probArr;
    probArr.append(42);
    QJsonArray sumArr;
    sumArr.append(1.25);
    QJsonArray windArr;
    windArr.append(7.4);
    QJsonArray dirArr;
    dirArr.append(180);
    QJsonArray uvArr;
    uvArr.append(2.5);
    QJsonArray sunriseArr;
    sunriseArr.append(date + QStringLiteral("T06:36"));
    QJsonArray sunsetArr;
    sunsetArr.append(date + QStringLiteral("T18:00"));

    QJsonObject daily;
    daily.insert(QLatin1String("time"), times);
    daily.insert(QLatin1String("weather_code"), codes);
    daily.insert(QLatin1String("temperature_2m_max"), tMaxArr);
    daily.insert(QLatin1String("temperature_2m_min"), tMinArr);
    daily.insert(QLatin1String("precipitation_probability_max"), probArr);
    daily.insert(QLatin1String("precipitation_sum"), sumArr);
    daily.insert(QLatin1String("wind_speed_10m_max"), windArr);
    daily.insert(QLatin1String("wind_direction_10m_dominant"), dirArr);
    daily.insert(QLatin1String("uv_index_max"), uvArr);
    daily.insert(QLatin1String("sunrise"), sunriseArr);
    daily.insert(QLatin1String("sunset"), sunsetArr);
    QJsonObject root;
    root.insert(QLatin1String("daily"), daily);
    return QJsonDocument(root).toJson(QJsonDocument::Compact);
}

} // namespace

class WeatherDataStoreTest : public QObject
{
    Q_OBJECT

private slots:
    void initTestCase();
    void wmoConditionKnownCodes();
    void wmoConditionUnknownCodes();
    void temperatureColorFormat();
    void temperatureColorStopsAndClamping();
    void temperatureColorColdVsHot();
    void formatTemperatureFormats();
    void dayForOnEmptyStore();
    void parsesFixtureIntoDays();
    void cacheMergeKeepsOldDays();
    void malformedJsonRejectedWithoutStateChange();
    void ensureRangeWithoutLocationIsNoOp();

private:
    QByteArray m_fixtureJson;
    QJsonObject m_fixtureDaily;
};

void WeatherDataStoreTest::initTestCase()
{
    const QString fixturePath =
        QStringLiteral(FIXTURES_DIR "/openmeteo-daily.json");
    m_fixtureJson = readFile(fixturePath);
    QVERIFY2(!m_fixtureJson.isEmpty(), qUtf8Printable(QStringLiteral("cannot read %1").arg(fixturePath)));

    const QJsonDocument doc = QJsonDocument::fromJson(m_fixtureJson);
    QVERIFY(doc.isObject());
    m_fixtureDaily = doc.object().value(QLatin1String("daily")).toObject();
    QVERIFY(!m_fixtureDaily.isEmpty());
    QVERIFY(!m_fixtureDaily.value(QLatin1String("time")).toArray().isEmpty());
}

void WeatherDataStoreTest::wmoConditionKnownCodes()
{
    struct Expected
    {
        int code;
        const char *label;
        bool precipitation;
    };
    const std::array<Expected, 24> table{{
        {0, "Ясно", false},
        {1, "Преимущественно ясно", false},
        {2, "Переменная облачность", false},
        {3, "Пасмурно", false},
        {45, "Туман", false},
        {48, "Туман", false},
        {51, "Морось", true},
        {55, "Морось", true},
        {56, "Ледяная морось", true},
        {57, "Ледяная морось", true},
        {61, "Дождь", true},
        {63, "Дождь", true},
        {65, "Дождь", true},
        {66, "Ледяной дождь", true},
        {67, "Ледяной дождь", true},
        {71, "Снег", true},
        {75, "Снег", true},
        {77, "Снежные зёрна", true},
        {80, "Ливень", true},
        {82, "Ливень", true},
        {85, "Снегопад", true},
        {86, "Снегопад", true},
        {95, "Гроза", true},
        {99, "Гроза с градом", true},
    }};
    for (const Expected &row : table) {
        const WmoCondition condition = wmoCondition(row.code);
        QCOMPARE(condition.label, QString::fromUtf8(row.label));
        QCOMPARE(condition.isPrecipitation, row.precipitation);
    }
}

void WeatherDataStoreTest::wmoConditionUnknownCodes()
{
    for (const int code : {7, 42, 49, 50, 100, -1}) {
        const WmoCondition condition = wmoCondition(code);
        QCOMPARE(condition.label, QStringLiteral("Погода"));
        QVERIFY(!condition.isPrecipitation);
    }
}

void WeatherDataStoreTest::temperatureColorFormat()
{
    const QRegularExpression hexColor(QStringLiteral("^#[0-9a-f]{6}$"));
    const std::array<double, 10> samples{{-40.0, -30.0, -17.3, 0.0, 7.5,
                                          10.0, 18.2, 25.0, 35.0, 40.0}};
    for (const double celsius : samples) {
        const QString color = temperatureColor(celsius);
        QVERIFY2(hexColor.match(color).hasMatch(),
                 qUtf8Printable(QStringLiteral("celsius=%1 color=%2").arg(celsius).arg(color)));
    }
}

void WeatherDataStoreTest::temperatureColorStopsAndClamping()
{
    QCOMPARE(temperatureColor(-30.0), QStringLiteral("#1565c0"));
    QCOMPARE(temperatureColor(-10.0), QStringLiteral("#42a5f5"));
    QCOMPARE(temperatureColor(0.0), QStringLiteral("#4fc3f7"));
    QCOMPARE(temperatureColor(10.0), QStringLiteral("#ffb74d"));
    QCOMPARE(temperatureColor(25.0), QStringLiteral("#ef6c00"));
    QCOMPARE(temperatureColor(35.0), QStringLiteral("#e53935"));
    // Outside the range the ramp is clamped to the end stops.
    QCOMPARE(temperatureColor(-100.0), temperatureColor(-30.0));
    QCOMPARE(temperatureColor(100.0), temperatureColor(35.0));
    QCOMPARE(temperatureColor(-30.1), temperatureColor(-30.0));
    // A mid-segment temperature interpolates away from both stops.
    QVERIFY(temperatureColor(-20.0) != temperatureColor(-30.0));
    QVERIFY(temperatureColor(-20.0) != temperatureColor(-10.0));
}

void WeatherDataStoreTest::temperatureColorColdVsHot()
{
    const Rgb cold = parseRgb(temperatureColor(-10.0));
    const Rgb hot = parseRgb(temperatureColor(10.0));
    QVERIFY(temperatureColor(-10.0) != temperatureColor(10.0));
    // -10 sits closer to the deep-cold blue; +10 sits closer to the hot red.
    QVERIFY2(squaredDistance(cold, coldRed, coldGreen, coldBlue)
                 < squaredDistance(hot, coldRed, coldGreen, coldBlue),
             "color(-10) must be closer to #1565c0 than color(+10)");
    QVERIFY2(squaredDistance(hot, hotRed, hotGreen, hotBlue)
                 < squaredDistance(cold, hotRed, hotGreen, hotBlue),
             "color(+10) must be closer to #e53935 than color(-10)");
}

void WeatherDataStoreTest::formatTemperatureFormats()
{
    QCOMPARE(formatTemperature(4.4), QStringLiteral("+4°"));
    QCOMPARE(formatTemperature(-4.6), QStringLiteral("%1%2°").arg(QChar(typographicMinus)).arg(5));
    QCOMPARE(formatTemperature(0.0), QStringLiteral("0°"));
    QCOMPARE(formatTemperature(-0.4), QStringLiteral("0°")); // rounds to zero, no sign
    QCOMPARE(formatTemperature(21.0), QStringLiteral("+21°"));
    QCOMPARE(formatTemperature(-21.0),
             QStringLiteral("%1%2°").arg(QChar(typographicMinus)).arg(21));
}

void WeatherDataStoreTest::dayForOnEmptyStore()
{
    WeatherDataStore store{QString()}; // in-memory
    QVERIFY(!store.dayFor(QDate::currentDate()).has_value());
    QVERIFY(!store.dayFor(QDate(2026, 1, 1)).has_value());
    QVERIFY(store.availableDays().isEmpty());
}

void WeatherDataStoreTest::parsesFixtureIntoDays()
{
    WeatherDataStore store{QString()}; // in-memory
    QString error;
    QVERIFY2(store.applyFetchJson(m_fixtureJson, &error), qUtf8Printable(error));

    const QJsonArray times = m_fixtureDaily.value(QLatin1String("time")).toArray();
    QCOMPARE(store.availableDays().size(), times.size());

    // Dates are exactly the fixture dates and are continuous.
    QList<QDate> dates = store.availableDays().values();
    std::sort(dates.begin(), dates.end());
    for (int i = 0; i < dates.size(); ++i) {
        QCOMPARE(dates.at(i), QDate::fromString(times.at(i).toString(), Qt::ISODate));
    }
    for (int i = 1; i < dates.size(); ++i) {
        QCOMPARE(dates.at(i), dates.at(i - 1).addDays(1));
    }

    // Spot-check a mid-range day against the fixture values.
    const int mid = times.size() / 2;
    const std::optional<WeatherDataStore::DayWeather> day =
        store.dayFor(QDate::fromString(times.at(mid).toString(), Qt::ISODate));
    QVERIFY(day.has_value());
    QCOMPARE(day->wmoCode,
             m_fixtureDaily.value(QLatin1String("weather_code")).toArray().at(mid).toInt());
    QCOMPARE(day->tMax, qRound(m_fixtureDaily.value(QLatin1String("temperature_2m_max"))
                                   .toArray()
                                   .at(mid)
                                   .toDouble()));
    QCOMPARE(day->tMin, qRound(m_fixtureDaily.value(QLatin1String("temperature_2m_min"))
                                   .toArray()
                                   .at(mid)
                                   .toDouble()));
    QCOMPARE(day->precipProb,
             m_fixtureDaily.value(QLatin1String("precipitation_probability_max"))
                 .toArray()
                 .at(mid)
                 .toInt());
    QCOMPARE(day->precipSumMm,
             qRound(m_fixtureDaily.value(QLatin1String("precipitation_sum"))
                        .toArray()
                        .at(mid)
                        .toDouble()));
    QCOMPARE(day->windMaxKmh,
             qRound(m_fixtureDaily.value(QLatin1String("wind_speed_10m_max"))
                        .toArray()
                        .at(mid)
                        .toDouble()));
    QCOMPARE(day->windDirDeg,
             m_fixtureDaily.value(QLatin1String("wind_direction_10m_dominant"))
                 .toArray()
                 .at(mid)
                 .toInt());
    QCOMPARE(day->uvMax,
             m_fixtureDaily.value(QLatin1String("uv_index_max")).toArray().at(mid).toDouble());
    QCOMPARE(day->sunrise, m_fixtureDaily.value(QLatin1String("sunrise")).toArray().at(mid).toString());
    QCOMPARE(day->sunset, m_fixtureDaily.value(QLatin1String("sunset")).toArray().at(mid).toString());

    // An unknown date yields nothing.
    QVERIFY(!store.dayFor(QDate(1999, 12, 31)).has_value());

    // Every WMO code present in the fixture maps to a concrete label whose
    // precipitation flag matches its group.
    QSet<int> codes;
    const QJsonArray codeArray = m_fixtureDaily.value(QLatin1String("weather_code")).toArray();
    for (const QJsonValue &value : codeArray) {
        codes.insert(value.toInt());
    }
    QVERIFY(!codes.isEmpty());
    for (const int code : std::as_const(codes)) {
        const WmoCondition condition = wmoCondition(code);
        QVERIFY2(condition.label != QStringLiteral("Погода"),
                 qUtf8Printable(QStringLiteral("code %1 unmapped").arg(code)));
        const bool precipGroup = (code >= 51 && code <= 67) || (code >= 71 && code <= 77)
            || (code >= 80 && code <= 86) || (code >= 95 && code <= 99);
        QCOMPARE(condition.isPrecipitation, precipGroup);
    }
}

void WeatherDataStoreTest::cacheMergeKeepsOldDays()
{
    QTemporaryDir dir;
    QVERIFY(dir.isValid());
    const QString cachePath = dir.filePath(QStringLiteral("daily.json"));

    // Seed a cache with one old day (a previous fetch, different location).
    {
        WeatherDataStore seed(cachePath);
        seed.setLocation(55.7522, 37.6156, WeatherDataStore::TemperatureUnit::Celsius);
        QString error;
        QVERIFY2(seed.applyFetchJson(singleDayPayload(QStringLiteral("2026-01-01"), 3, -5.5),
                                     &error),
                 qUtf8Printable(error));
    }

    WeatherDataStore store(cachePath);
    QVERIFY(store.dayFor(QDate(2026, 1, 1)).has_value()); // restored from disk

    QString error;
    QVERIFY2(store.applyFetchJson(m_fixtureJson, &error), qUtf8Printable(error));

    const QJsonArray times = m_fixtureDaily.value(QLatin1String("time")).toArray();
    const QDate firstFixtureDate =
        QDate::fromString(times.at(0).toString(), Qt::ISODate);
    QVERIFY(store.dayFor(QDate(2026, 1, 1)).has_value());       // old day preserved
    QVERIFY(store.dayFor(firstFixtureDate).has_value());        // fixture days present
    QCOMPARE(store.availableDays().size(), times.size() + 1);   // fixture + old day

    // The cache file was rewritten with the merged content and the location.
    const QJsonObject savedRoot = QJsonDocument::fromJson(readFile(cachePath)).object();
    const QJsonObject savedDays = savedRoot.value(QLatin1String("days")).toObject();
    QCOMPARE(savedDays.size(), times.size() + 1);
    QVERIFY(savedDays.contains(QStringLiteral("2026-01-01")));
    QVERIFY(savedDays.contains(times.at(0).toString()));
    QCOMPARE(savedRoot.value(QLatin1String("latitude")).toDouble(), 55.7522);
    QCOMPARE(savedRoot.value(QLatin1String("longitude")).toDouble(), 37.6156);
    QCOMPARE(savedRoot.value(QLatin1String("unit")).toString(), QStringLiteral("celsius"));

    // Newly fetched wins: re-applying the same fixture must not grow the set.
    QVERIFY2(store.applyFetchJson(m_fixtureJson, &error), qUtf8Printable(error));
    QCOMPARE(store.availableDays().size(), times.size() + 1);
}

void WeatherDataStoreTest::malformedJsonRejectedWithoutStateChange()
{
    QTemporaryDir dir;
    QVERIFY(dir.isValid());
    const QString cachePath = dir.filePath(QStringLiteral("daily.json"));

    WeatherDataStore store(cachePath);
    store.setLocation(55.7522, 37.6156, WeatherDataStore::TemperatureUnit::Celsius);
    QString error;
    QVERIFY2(store.applyFetchJson(singleDayPayload(QStringLiteral("2026-01-01"), 3, -5.5),
                                  &error),
             qUtf8Printable(error));
    const QSet<QDate> before = store.availableDays();
    const QByteArray cacheBefore = readFile(cachePath);

    const std::array<QByteArray, 4> badPayloads{{
        QByteArrayLiteral("not json at all"),
        QByteArrayLiteral("{}"),
        QByteArrayLiteral("{\"daily\":{\"time\":[]}}"),
        singleDayPayload(QStringLiteral("2026-13-99"), 3, 0.0), // invalid date, full columns
    }};
    for (const QByteArray &payload : badPayloads) {
        error.clear();
        QVERIFY2(!store.applyFetchJson(payload, &error), payload.constData());
        QVERIFY2(!error.isEmpty(), payload.constData());
        QVERIFY(store.availableDays() == before);
        QCOMPARE(readFile(cachePath), cacheBefore); // file untouched
    }

    // A truncated real response is rejected too, state still untouched.
    error.clear();
    QVERIFY(!store.applyFetchJson(m_fixtureJson.left(m_fixtureJson.size() / 2), &error));
    QVERIFY(!error.isEmpty());
    QVERIFY(store.availableDays() == before);
    QCOMPARE(readFile(cachePath), cacheBefore);
}

void WeatherDataStoreTest::ensureRangeWithoutLocationIsNoOp()
{
    WeatherDataStore store{QString()}; // no location ever set
    QSignalSpy updatedSpy(&store, &WeatherDataStore::updated);
    QSignalSpy failedSpy(&store, &WeatherDataStore::fetchFailed);

    const QDate today = QDate::currentDate();
    store.ensureRange(today.addDays(-1), today.addDays(1));
    store.ensureRange(today.addDays(-30), today.addDays(30));

    QCOMPARE(updatedSpy.size(), 0);
    QCOMPARE(failedSpy.size(), 0);
    QVERIFY(store.availableDays().isEmpty());
}

QTEST_GUILESS_MAIN(WeatherDataStoreTest)

#include "test_weatherdatastore.moc"
