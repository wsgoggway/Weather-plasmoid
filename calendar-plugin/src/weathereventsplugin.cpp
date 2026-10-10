// SPDX-FileCopyrightText: 2026 Vladimir Manichev
// SPDX-License-Identifier: MIT
#include "weathereventsplugin.h"

#include <KConfigGroup>

#include <QDateTime>
#include <QTime>

#include <algorithm>
#include <cmath>

#include "wmoconditions.h"

namespace {

constexpr auto configFileName = "weathereventsrc";
constexpr auto generalGroupName = "General";

constexpr auto latitudeKey = "latitude";
constexpr auto longitudeKey = "longitude";
constexpr auto temperatureUnitKey = "temperatureUnit";

constexpr auto eventUidPrefix = "weatherevents-";

// The event title joins the min/max temperatures with an ellipsis.
constexpr auto titleEllipsis = u8"…";
constexpr auto midDot = u8" · ";

constexpr int precipitationProbabilityThreshold = 30;

bool sameCoordinate(double a, double b)
{
    return std::abs(a - b) < 1e-6;
}

// Fahrenheit -> Celsius, for scales that need physical degrees (the color
// ramp). The store reports temperatures in the configured unit.
[[nodiscard]] double fahrenheitToCelsius(double fahrenheit)
{
    return (fahrenheit - 32.0) * 5.0 / 9.0;
}

// "6,6" style is avoided on purpose: plain dot decimal, ".0" stripped.
[[nodiscard]] QString formatUv(double uv)
{
    const double rounded = std::round(uv * 10.0) / 10.0;
    if (std::fabs(rounded - std::round(rounded)) < 0.05) {
        return QString::number(static_cast<int>(std::round(rounded)));
    }
    return QString::number(rounded, 'f', 1);
}

// sunrise/sunset come as local ISO strings ("2026-10-14T06:58"); only the
// "HH:MM" part is shown.
[[nodiscard]] QString isoTimePart(const QString &iso)
{
    return iso.size() >= 16 ? iso.mid(11, 5) : QString();
}

} // namespace

WeatherEventsPlugin::WeatherEventsPlugin(QObject *parent)
    : CalendarEvents::CalendarEventsPlugin(parent)
    , m_config(KSharedConfig::openConfig(QLatin1String(configFileName)))
    , m_store(new WeatherDataStore(WeatherDataStore::defaultCacheFilePath(), this))
{
    loadConfig();
    applyConfiguredLocation();

    connect(m_store, &WeatherDataStore::updated, this, [this] {
        rebuildAndEmit(false);
    });
    connect(m_store, &WeatherDataStore::fetchFailed, this, [this](const QString &reason) {
        qWarning("weatherevents: weather fetch failed, keeping previous data: %s",
                 qUtf8Printable(reason));
    });

    // The config page writes weathereventsrc in this very process; re-apply
    // the location when latitude/longitude/temperatureUnit change.
    m_configWatcher = KConfigWatcher::create(m_config);
    connect(m_configWatcher.data(), &KConfigWatcher::configChanged, this, [this](const KConfigGroup &group) {
        if (group.name() != QLatin1String(generalGroupName)) {
            return;
        }
        const bool locationChanged = loadConfig();
        if (locationChanged) {
            applyConfiguredLocation();
            rebuildAndEmit(true);
        }
    });
}

WeatherEventsPlugin::~WeatherEventsPlugin() = default;

bool WeatherEventsPlugin::loadConfig()
{
    const KConfigGroup general(m_config, QLatin1String(generalGroupName));
    const double latitude = general.readEntry(QLatin1String(latitudeKey), 0.0);
    const double longitude = general.readEntry(QLatin1String(longitudeKey), 0.0);
    const auto unit = general.readEntry(QLatin1String(temperatureUnitKey), QString())
                          == QLatin1String("fahrenheit")
        ? WeatherDataStore::TemperatureUnit::Fahrenheit
        : WeatherDataStore::TemperatureUnit::Celsius;

    // Unset or out-of-range coordinates count as "no location".
    const bool valid = !(latitude == 0.0 && longitude == 0.0)
        && latitude >= -90.0 && latitude <= 90.0 && longitude >= -180.0 && longitude <= 180.0;

    const bool changed = valid != (m_latitude != 0.0 || m_longitude != 0.0)
        || !sameCoordinate(m_latitude, latitude) || !sameCoordinate(m_longitude, longitude)
        || m_unit != unit;

    m_latitude = valid ? latitude : 0.0;
    m_longitude = valid ? longitude : 0.0;
    m_unit = unit;
    return changed;
}

void WeatherEventsPlugin::applyConfiguredLocation()
{
    if (m_latitude == 0.0 && m_longitude == 0.0) {
        return; // nothing configured: the store stays location-less, no fetches
    }
    m_store->setLocation(m_latitude, m_longitude, m_unit);
    if (m_rangeStart.isValid() && m_rangeEnd.isValid()) {
        m_store->ensureRange(m_rangeStart, m_rangeEnd);
    }
}

void WeatherEventsPlugin::loadEventsForDateRange(const QDate &startDate, const QDate &endDate)
{
    if (!startDate.isValid() || !endDate.isValid()) {
        return;
    }
    // The settings page writes the config from this same process, and the file
    // watcher may have been created before the config file existed (its watch
    // then silently never attaches) - so re-read on every UI request: opening
    // the calendar always picks up the latest location.
    const bool locationChanged = loadConfig();
    if (locationChanged) {
        applyConfiguredLocation();
    }
    rememberRange(startDate, endDate);
    m_store->ensureRange(startDate, endDate);
    rebuildAndEmit(locationChanged);
}

void WeatherEventsPlugin::rememberRange(const QDate &startDate, const QDate &endDate)
{
    if (!m_rangeStart.isValid() || startDate < m_rangeStart) {
        m_rangeStart = startDate;
    }
    if (!m_rangeEnd.isValid() || endDate > m_rangeEnd) {
        m_rangeEnd = endDate;
    }
}

void WeatherEventsPlugin::rebuildAndEmit(bool locationChanged)
{
    QMultiHash<QDate, CalendarEvents::EventData> data;
    QHash<QDate, CalendarEvents::CalendarEventsPlugin::SubLabel> subLabels;

    const QDate today = QDate::currentDate();
    const QDate windowStart = std::max(m_rangeStart, today.addDays(-7));
    const QDate windowEnd = std::min(m_rangeEnd, today.addDays(16));

    const QSet<QDate> available = m_store->availableDays();
    QList<QDate> days;
    days.reserve(available.size());
    for (const QDate &day : available) {
        if (m_rangeStart.isValid() && m_rangeEnd.isValid() && day >= windowStart && day <= windowEnd) {
            days.append(day);
        }
    }
    std::sort(days.begin(), days.end());

    for (const QDate &day : days) {
        const auto dayWeather = m_store->dayFor(day);
        if (!dayWeather.has_value()) {
            continue; // cannot happen for availableDays(), kept as a guard
        }
        CalendarEvents::CalendarEventsPlugin::SubLabel subLabel;
        subLabel.dayLabel = formatTemperature(dayWeather->tMax);
        subLabel.priority = CalendarEvents::CalendarEventsPlugin::SubLabelPriority::Default;
        subLabels.insert(day, subLabel);
        data.insert(day, makeDayEvent(*dayWeather));
    }

    if (locationChanged) {
        // The old events belong to the old location: retire them explicitly.
        for (auto it = m_lastData.constBegin(); it != m_lastData.constEnd(); ++it) {
            Q_EMIT eventRemoved(it->uid());
        }
    }

    m_lastData = data;
    Q_EMIT dataReady(data);
    Q_EMIT subLabelReady(subLabels);
}

QString WeatherEventsPlugin::dayEventTitle(const WeatherDataStore::DayWeather &day) const
{
    // The store reports temperatures in the configured unit; formatTemperature
    // prints "+4°" for either scale, while the color ramp needs Celsius.
    const QString midDotStr = QString::fromUtf8(midDot);
    QString title = formatTemperature(day.tMin) + QString::fromUtf8(titleEllipsis)
        + formatTemperature(day.tMax) + midDotStr + wmoCondition(day.wmoCode).label;
    if (day.precipProb >= precipitationProbabilityThreshold) {
        title += midDotStr + QStringLiteral("осадки %1%").arg(day.precipProb);
    }
    return title;
}

QString WeatherEventsPlugin::dayEventDescription(const WeatherDataStore::DayWeather &day) const
{
    QStringList parts;
    parts.append(QStringLiteral("Ветер до %1 км/ч").arg(day.windMaxKmh));
    parts.append(QStringLiteral("Осадки %1 мм").arg(day.precipSumMm));
    parts.append(QStringLiteral("УФ-индекс %1").arg(formatUv(day.uvMax)));

    const QString sunrise = isoTimePart(day.sunrise);
    if (!sunrise.isEmpty()) {
        parts.append(QStringLiteral("Восход %1").arg(sunrise));
    }
    const QString sunset = isoTimePart(day.sunset);
    if (!sunset.isEmpty()) {
        parts.append(QStringLiteral("Закат %1").arg(sunset));
    }
    return parts.join(QString::fromUtf8(midDot));
}

CalendarEvents::EventData WeatherEventsPlugin::makeDayEvent(const WeatherDataStore::DayWeather &day) const
{
    CalendarEvents::EventData event;
    event.setUid(QLatin1String(eventUidPrefix) + day.date.toString(Qt::ISODate));
    event.setTitle(dayEventTitle(day));
    event.setDescription(dayEventDescription(day));
    event.setEventType(CalendarEvents::EventData::EventType::Event);
    event.setIsAllDay(true);
    event.setStartDateTime(day.date.startOfDay());
    event.setEndDateTime(day.date.endOfDay());

    const double meanCelsius = m_unit == WeatherDataStore::TemperatureUnit::Fahrenheit
        ? fahrenheitToCelsius((day.tMax + day.tMin) / 2.0)
        : (day.tMax + day.tMin) / 2.0;
    event.setEventColor(temperatureColor(meanCelsius));
    return event;
}
