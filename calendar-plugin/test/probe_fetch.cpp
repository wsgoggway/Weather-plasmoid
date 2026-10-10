// SPDX-FileCopyrightText: 2026 Vladimir Manichev
// SPDX-License-Identifier: MIT

// Real-network e2e probe for the weather data layer (the path the calendar
// plugin drives in plasmashell).
//
// Usage: probe_fetch [lat] [lon] [unit] [cacheFilePath]
//   lat/lon default to Moscow; unit is "celsius"|"fahrenheit".
//   cacheFilePath defaults to a throwaway file under /tmp -- the real cache
//   in the user's XDG cache dir is never touched.
//
// Builds a WeatherDataStore, requests today-7..today+16 and waits up to 20 s
// for updated()/fetchFailed(). Prints the fetch outcome, the number of
// available days and three sample days formatted like calendar event titles.
// Exits 0 only when the fetch succeeded and data is available.

#include <QCoreApplication>
#include <QDate>
#include <QEventLoop>
#include <QSet>
#include <QTimer>

#include <algorithm>
#include <cstdio>
#include <vector>

#include "weatherdatastore.h"
#include "wmoconditions.h"

namespace {

constexpr int waitMs = 20000;

QString sampleTitle(const WeatherDataStore::DayWeather &day)
{
    QString title = formatTemperature(day.tMin) + QStringLiteral("…")
        + formatTemperature(day.tMax) + QStringLiteral(" · ") + wmoCondition(day.wmoCode).label;
    if (day.precipProb >= 30) {
        title += QStringLiteral(" · осадки %1%").arg(day.precipProb);
    }
    return title;
}

} // namespace

int main(int argc, char *argv[])
{
    QCoreApplication app(argc, argv);

    const QStringList args = app.arguments().mid(1);
    bool argsOk = true;
    // Defaults: Moscow, celsius, throwaway cache under /tmp.
    double latitude = 55.7522;
    double longitude = 37.6156;
    const QString unit = args.value(2, QStringLiteral("celsius"));
    const QString cachePath = args.value(3, QStringLiteral("/tmp/weatherevents-probe-cache.json"));
    if (!args.value(0).isEmpty()) {
        latitude = args.value(0).toDouble(&argsOk);
    }
    if (argsOk && !args.value(1).isEmpty()) {
        longitude = args.value(1).toDouble(&argsOk);
    }
    if (!argsOk || (unit != QLatin1String("celsius") && unit != QLatin1String("fahrenheit"))) {
        std::fprintf(stderr, "Usage: probe_fetch [lat] [lon] [celsius|fahrenheit] [cacheFilePath]\n");
        return 1;
    }

    WeatherDataStore store(cachePath);
    store.setLocation(latitude,
                       longitude,
                       unit == QLatin1String("fahrenheit") ? WeatherDataStore::TemperatureUnit::Fahrenheit
                                                           : WeatherDataStore::TemperatureUnit::Celsius);

    bool fetchOk = false;
    QString failureReason;
    QEventLoop loop;

    QObject::connect(&store, &WeatherDataStore::updated, &loop, [&] {
        fetchOk = true;
        loop.quit();
    });
    QObject::connect(&store, &WeatherDataStore::fetchFailed, &loop, [&](const QString &reason) {
        failureReason = reason;
        loop.quit();
    });
    QTimer::singleShot(waitMs, &loop, &QEventLoop::quit);

    const QDate today = QDate::currentDate();
    store.ensureRange(today.addDays(-7), today.addDays(16));
    if (!store.availableDays().isEmpty()) {
        // setLocation starts a fresh cache, so this only happens if the
        // throwaway file already held data from an earlier run -- still fine,
        // but a real fetch check needs a range that is not covered.
        std::printf("note: cache pre-covered the range (rerun with a fresh path for a real fetch)\n");
    }
    loop.exec();

    if (!fetchOk) {
        std::fprintf(stderr,
                     "PROBE FETCH FAILED: %s\n",
                     qUtf8Printable(failureReason.isEmpty()
                                        ? QStringLiteral("no answer within %1 ms").arg(waitMs)
                                        : failureReason));
        return 1;
    }

    std::vector<QDate> days;
    const QSet<QDate> available = store.availableDays();
    days.reserve(available.size());
    for (const QDate &day : available) {
        days.push_back(day);
    }
    std::sort(days.begin(), days.end());

    std::printf("PROBE FETCH OK days=%zu\n", days.size());
    const int sampleCount = std::min<size_t>(3, days.size());
    for (int i = 0; i < sampleCount; ++i) {
        const auto dayWeather = store.dayFor(days[static_cast<size_t>(i)]);
        if (!dayWeather.has_value()) {
            continue;
        }
        std::printf("sample %s: %s\n",
                    qUtf8Printable(days[static_cast<size_t>(i)].toString(Qt::ISODate)),
                    qUtf8Printable(sampleTitle(*dayWeather)));
    }
    return 0;
}
