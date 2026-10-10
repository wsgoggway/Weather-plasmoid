// SPDX-FileCopyrightText: 2026 Vladimir Manichev
// SPDX-License-Identifier: MIT
#include "weatherdatastore.h"

#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonParseError>
#include <QJsonValue>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QSaveFile>
#include <QStandardPaths>
#include <QTimer>

#include <QtGlobal>

#include <algorithm>
#include <array>
#include <chrono>
#include <limits>
#include <tuple>
#include <utility>

namespace {

constexpr int cacheVersion = 1;
constexpr auto cacheRelativePath = "/weatherevents/daily.json";

constexpr std::chrono::seconds fetchTimeout{15};
constexpr std::chrono::hours refreshInterval{3};
constexpr qint64 fetchFreshnessMs = 3LL * 60 * 60 * 1000;

// The fetchable Open-Meteo window around today (past_days / forecast_days).
constexpr int pastDaysWindow = 7;
constexpr int forecastDaysWindow = 16;

bool fail(QString *error, const QString &message)
{
    if (error != nullptr) {
        *error = message;
    }
    return false;
}

// Hostile JSON numbers (1e300) must not be UB on the double->int conversion.
int clampToInt(double value)
{
    if (!(value > static_cast<double>(std::numeric_limits<int>::min()))) {
        return std::numeric_limits<int>::min();
    }
    if (!(value < static_cast<double>(std::numeric_limits<int>::max()))) {
        return std::numeric_limits<int>::max();
    }
    return static_cast<int>(value);
}

// JSON nulls (Open-Meteo reports them for some past-day columns) count as 0.
int intOrZero(const QJsonValue &value)
{
    return value.isDouble() ? clampToInt(value.toDouble()) : 0;
}

// Numeric day fields are rounded at parse time (repo rule).
int roundedOrZero(const QJsonValue &value)
{
    if (!value.isDouble()) {
        return 0;
    }
    const double v = value.toDouble();
    if (!(v > static_cast<double>(std::numeric_limits<int>::min()) + 1.0)) {
        return std::numeric_limits<int>::min();
    }
    if (!(v < static_cast<double>(std::numeric_limits<int>::max()) - 1.0)) {
        return std::numeric_limits<int>::max();
    }
    return qRound(v);
}

double doubleOrZero(const QJsonValue &value)
{
    return value.isDouble() ? value.toDouble() : 0.0;
}

QJsonObject dayToJson(const WeatherDataStore::DayWeather &day)
{
    return QJsonObject{
        {QLatin1String("wmoCode"), day.wmoCode},
        {QLatin1String("tMax"), day.tMax},
        {QLatin1String("tMin"), day.tMin},
        {QLatin1String("precipProb"), day.precipProb},
        {QLatin1String("precipSumMm"), day.precipSumMm},
        {QLatin1String("windMaxKmh"), day.windMaxKmh},
        {QLatin1String("windDirDeg"), day.windDirDeg},
        {QLatin1String("uvMax"), day.uvMax},
        {QLatin1String("sunrise"), day.sunrise},
        {QLatin1String("sunset"), day.sunset},
    };
}

WeatherDataStore::DayWeather dayFromJson(const QJsonObject &obj, const QDate &date)
{
    WeatherDataStore::DayWeather day;
    day.date = date;
    day.wmoCode = obj.value(QLatin1String("wmoCode")).toInt();
    day.tMax = obj.value(QLatin1String("tMax")).toInt();
    day.tMin = obj.value(QLatin1String("tMin")).toInt();
    day.precipProb = obj.value(QLatin1String("precipProb")).toInt();
    day.precipSumMm = obj.value(QLatin1String("precipSumMm")).toInt();
    day.windMaxKmh = obj.value(QLatin1String("windMaxKmh")).toInt();
    day.windDirDeg = obj.value(QLatin1String("windDirDeg")).toInt();
    day.uvMax = obj.value(QLatin1String("uvMax")).toDouble();
    day.sunrise = obj.value(QLatin1String("sunrise")).toString();
    day.sunset = obj.value(QLatin1String("sunset")).toString();
    return day;
}

bool sameCoordinate(double a, double b)
{
    return std::abs(a - b) < 1e-6;
}

} // namespace

WeatherDataStore::WeatherDataStore(QString cacheFilePath, QObject *parent)
    : QObject(parent)
    , m_cacheFilePath(std::move(cacheFilePath))
    , m_network(new QNetworkAccessManager(this))
    , m_refreshTimer(new QTimer(this))
{
    m_refreshTimer->setInterval(std::chrono::milliseconds(refreshInterval));
    connect(m_refreshTimer, &QTimer::timeout, this, &WeatherDataStore::refreshRequestedRange);
    loadCache();
}

WeatherDataStore::~WeatherDataStore() = default;

QString WeatherDataStore::defaultCacheFilePath()
{
    return QStandardPaths::writableLocation(QStandardPaths::GenericCacheLocation)
        + QLatin1String(cacheRelativePath);
}

void WeatherDataStore::setLocation(double latitude, double longitude, TemperatureUnit unit)
{
    if (m_hasLocation && sameCoordinate(m_latitude, latitude)
            && sameCoordinate(m_longitude, longitude) && m_unit == unit) {
        return;
    }
    m_latitude = latitude;
    m_longitude = longitude;
    m_unit = unit;
    m_hasLocation = true;

    // The cached days belong to the old location: start a fresh cache.
    m_days.clear();
    m_lastFetch = QDateTime();
    m_requestedStart = QDate();
    m_requestedEnd = QDate();
    std::ignore = saveCache(); // best effort: persist the fresh (empty) cache
}

std::optional<WeatherDataStore::DayWeather> WeatherDataStore::dayFor(QDate date) const
{
    const auto it = m_days.constFind(date);
    if (it == m_days.constEnd()) {
        return std::nullopt;
    }
    return it.value();
}

QSet<QDate> WeatherDataStore::availableDays() const
{
    return QSet<QDate>(m_days.keyBegin(), m_days.keyEnd());
}

void WeatherDataStore::ensureRange(QDate startDate, QDate endDate)
{
    if (!m_hasLocation || m_activeReply != nullptr) {
        return;
    }
    m_requestedStart = startDate;
    m_requestedEnd = endDate;

    const QDate today = QDate::currentDate();
    const QDate fetchStart = std::max(startDate, today.addDays(-pastDaysWindow));
    const QDate fetchEnd = std::min(endDate, today.addDays(forecastDaysWindow));
    if (fetchStart > fetchEnd) {
        return; // entirely outside the API window: the cache serves what it has
    }
    if (rangeCovered(fetchStart, fetchEnd) && fetchIsFresh()) {
        return;
    }
    startFetch();
}

bool WeatherDataStore::applyFetchJson(const QByteArray &json, QString *error)
{
    QJsonParseError parseError{};
    const QJsonDocument doc = QJsonDocument::fromJson(json, &parseError);
    if (parseError.error != QJsonParseError::NoError) {
        return fail(error, QStringLiteral("JSON parse error at offset %1: %2")
                              .arg(parseError.offset)
                              .arg(parseError.errorString()));
    }
    if (!doc.isObject()) {
        return fail(error, QStringLiteral("Response root is not a JSON object"));
    }
    const QJsonObject daily = doc.object().value(QLatin1String("daily")).toObject();
    if (daily.isEmpty()) {
        return fail(error, QStringLiteral("Response has no daily object"));
    }

    // Open-Meteo daily shape: parallel arrays, one value per day.
    const QJsonArray times = daily.value(QLatin1String("time")).toArray();
    if (times.isEmpty()) {
        return fail(error, QStringLiteral("daily.time is missing or empty"));
    }
    const QJsonArray weatherCodes = daily.value(QLatin1String("weather_code")).toArray();
    const QJsonArray tMax = daily.value(QLatin1String("temperature_2m_max")).toArray();
    const QJsonArray tMin = daily.value(QLatin1String("temperature_2m_min")).toArray();
    const QJsonArray precipProb = daily.value(QLatin1String("precipitation_probability_max")).toArray();
    const QJsonArray precipSum = daily.value(QLatin1String("precipitation_sum")).toArray();
    const QJsonArray windMax = daily.value(QLatin1String("wind_speed_10m_max")).toArray();
    const QJsonArray windDir = daily.value(QLatin1String("wind_direction_10m_dominant")).toArray();
    const QJsonArray uvMax = daily.value(QLatin1String("uv_index_max")).toArray();
    const QJsonArray sunrise = daily.value(QLatin1String("sunrise")).toArray();
    const QJsonArray sunset = daily.value(QLatin1String("sunset")).toArray();

    const std::array<std::pair<const char *, const QJsonArray *>, 10> columns{{
        {"weather_code", &weatherCodes},
        {"temperature_2m_max", &tMax},
        {"temperature_2m_min", &tMin},
        {"precipitation_probability_max", &precipProb},
        {"precipitation_sum", &precipSum},
        {"wind_speed_10m_max", &windMax},
        {"wind_direction_10m_dominant", &windDir},
        {"uv_index_max", &uvMax},
        {"sunrise", &sunrise},
        {"sunset", &sunset},
    }};
    for (const auto &[key, column] : columns) {
        if (column->size() != times.size()) {
            return fail(error, QStringLiteral("daily.%1 length %2 does not match daily.time length %3")
                                   .arg(QLatin1String(key))
                                   .arg(column->size())
                                   .arg(times.size()));
        }
    }

    // Parse into a staging map first: malformed input must leave the store
    // untouched, so only a fully valid payload is committed.
    QHash<QDate, DayWeather> fetched;
    fetched.reserve(times.size());
    for (int i = 0; i < times.size(); ++i) {
        const QDate date = QDate::fromString(times.at(i).toString(), Qt::ISODate);
        if (!date.isValid()) {
            return fail(error, QStringLiteral("daily.time[%1] '%2' is not an ISO date")
                                   .arg(i)
                                   .arg(times.at(i).toString()));
        }
        DayWeather day;
        day.date = date;
        day.wmoCode = intOrZero(weatherCodes.at(i));
        day.tMax = roundedOrZero(tMax.at(i));
        day.tMin = roundedOrZero(tMin.at(i));
        day.precipProb = intOrZero(precipProb.at(i));
        day.precipSumMm = roundedOrZero(precipSum.at(i));
        day.windMaxKmh = roundedOrZero(windMax.at(i));
        day.windDirDeg = intOrZero(windDir.at(i));
        day.uvMax = doubleOrZero(uvMax.at(i));
        day.sunrise = sunrise.at(i).toString();
        day.sunset = sunset.at(i).toString();
        fetched.insert(date, day);
    }

    // Commit: per-date, newly fetched wins; older cached days are kept.
    for (auto it = fetched.constBegin(); it != fetched.constEnd(); ++it) {
        m_days.insert(it.key(), it.value());
    }
    m_lastFetch = QDateTime::currentDateTime();
    std::ignore = saveCache(); // best effort: a failed write must not fail the parse
    return true;
}

bool WeatherDataStore::rangeCovered(QDate startDate, QDate endDate) const
{
    for (QDate day = startDate; day <= endDate; day = day.addDays(1)) {
        if (!m_days.contains(day)) {
            return false;
        }
    }
    return true;
}

bool WeatherDataStore::fetchIsFresh() const
{
    if (!m_lastFetch.isValid()) {
        return false;
    }
    return m_lastFetch.msecsTo(QDateTime::currentDateTime()) < fetchFreshnessMs;
}

void WeatherDataStore::refreshRequestedRange()
{
    if (m_requestedStart.isValid() && m_requestedEnd.isValid()) {
        ensureRange(m_requestedStart, m_requestedEnd);
    }
}

QUrl WeatherDataStore::buildFetchUrl() const
{
    const auto unitParam = m_unit == TemperatureUnit::Celsius
        ? QStringLiteral("celsius")
        : QStringLiteral("fahrenheit");
    return QUrl(QStringLiteral(
        "https://api.open-meteo.com/v1/forecast"
        "?latitude=%1&longitude=%2"
        "&daily=weather_code,temperature_2m_max,temperature_2m_min,"
        "precipitation_probability_max,precipitation_sum,"
        "wind_speed_10m_max,wind_direction_10m_dominant,uv_index_max,sunrise,sunset"
        "&timezone=auto&past_days=7&forecast_days=16&temperature_unit=%3")
                    .arg(QString::number(m_latitude),
                         QString::number(m_longitude),
                         unitParam));
}

void WeatherDataStore::startFetch()
{
    QNetworkRequest request(buildFetchUrl());
    request.setTransferTimeout(std::chrono::milliseconds(fetchTimeout));
    m_activeReply = m_network->get(request);
    connect(m_activeReply, &QNetworkReply::finished, this, [this] {
        QNetworkReply *reply = m_activeReply;
        m_activeReply = nullptr;
        reply->deleteLater();

        if (reply->error() != QNetworkReply::NoError) {
            Q_EMIT fetchFailed(reply->errorString());
            return;
        }
        QString error;
        if (!applyFetchJson(reply->readAll(), &error)) {
            Q_EMIT fetchFailed(error);
            return;
        }
        m_refreshTimer->start(); // (re)arm the 3h refresh cycle
        Q_EMIT updated();
    });
}

void WeatherDataStore::loadCache()
{
    if (m_cacheFilePath.isEmpty()) {
        return; // in-memory store
    }
    QFile file(m_cacheFilePath);
    if (!file.open(QIODevice::ReadOnly)) {
        return; // no cache yet -> start empty
    }
    const QJsonDocument doc = QJsonDocument::fromJson(file.readAll());
    const QJsonObject root = doc.object();
    if (!doc.isObject() || root.value(QLatin1String("version")).toInt() != cacheVersion) {
        qWarning("weatherevents: unreadable or outdated cache %s, starting empty",
                 qUtf8Printable(m_cacheFilePath));
        m_days.clear();
        m_lastFetch = QDateTime();
        return;
    }

    if (root.contains(QLatin1String("latitude")) && root.contains(QLatin1String("longitude"))) {
        m_latitude = root.value(QLatin1String("latitude")).toDouble();
        m_longitude = root.value(QLatin1String("longitude")).toDouble();
        m_hasLocation = true;
    }
    m_unit = root.value(QLatin1String("unit")).toString() == QLatin1String("fahrenheit")
        ? TemperatureUnit::Fahrenheit
        : TemperatureUnit::Celsius;
    m_lastFetch = QDateTime::fromString(root.value(QLatin1String("fetchedAt")).toString(),
                                        Qt::ISODateWithMs);

    const QJsonObject days = root.value(QLatin1String("days")).toObject();
    for (auto it = days.constBegin(); it != days.constEnd(); ++it) {
        const QDate date = QDate::fromString(it.key(), Qt::ISODate);
        if (!date.isValid()) {
            qWarning("weatherevents: skipping cache day with bad date '%s'",
                     qUtf8Printable(it.key()));
            continue;
        }
        m_days.insert(date, dayFromJson(it.value().toObject(), date));
    }
}

bool WeatherDataStore::saveCache() const
{
    if (m_cacheFilePath.isEmpty()) {
        return true; // in-memory store
    }

    QJsonObject days;
    for (auto it = m_days.constBegin(); it != m_days.constEnd(); ++it) {
        days.insert(it.key().toString(Qt::ISODate), dayToJson(it.value()));
    }
    QJsonObject root;
    root.insert(QLatin1String("version"), cacheVersion);
    root.insert(QLatin1String("latitude"), m_latitude);
    root.insert(QLatin1String("longitude"), m_longitude);
    root.insert(QLatin1String("unit"),
                m_unit == TemperatureUnit::Celsius ? QLatin1String("celsius")
                                                   : QLatin1String("fahrenheit"));
    root.insert(QLatin1String("fetchedAt"),
                m_lastFetch.isValid() ? m_lastFetch.toString(Qt::ISODateWithMs) : QString());
    root.insert(QLatin1String("days"), days);

    if (!QDir().mkpath(QFileInfo(m_cacheFilePath).absolutePath())) {
        qWarning("weatherevents: cannot create cache directory for %s",
                 qUtf8Printable(m_cacheFilePath));
        return false;
    }
    QSaveFile file(m_cacheFilePath);
    // The cache holds the approximate home location - keep it owner-only.
    // QSaveFile applies the permissions to the final file at commit().
    file.setPermissions(QFile::ReadOwner | QFile::WriteOwner);
    if (!file.open(QIODevice::WriteOnly)
            || !file.write(QJsonDocument(root).toJson(QJsonDocument::Compact)) || !file.commit()) {
        qWarning("weatherevents: cannot write cache %s: %s",
                 qUtf8Printable(m_cacheFilePath),
                 qUtf8Printable(file.errorString()));
        return false;
    }
    return true;
}
