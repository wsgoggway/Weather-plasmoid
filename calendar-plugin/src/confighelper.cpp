// SPDX-FileCopyrightText: 2026 Vladimir Manichev
// SPDX-License-Identifier: MIT
#include "confighelper.h"

#include <algorithm>

namespace {

constexpr auto configFileName = "weathereventsrc";
constexpr auto generalGroupName = "General";

constexpr auto latitudeKey = "latitude";
constexpr auto longitudeKey = "longitude";
constexpr auto temperatureUnitKey = "temperatureUnit";
constexpr auto cityNameKey = "cityName";

bool isCelsius(const QString &unit)
{
    return unit != QLatin1String("fahrenheit");
}

} // namespace

WeatherEventsConfig::WeatherEventsConfig(QObject *parent)
    : QObject(parent)
    , m_config(openConfig())
    , m_general(m_config, QLatin1String(generalGroupName))
{
    m_latitude = m_general.readEntry(QLatin1String(latitudeKey), 0.0);
    m_longitude = m_general.readEntry(QLatin1String(longitudeKey), 0.0);
    m_temperatureUnit = isCelsius(m_general.readEntry(QLatin1String(temperatureUnitKey), QString()))
        ? QStringLiteral("celsius")
        : QStringLiteral("fahrenheit");
    m_cityName = m_general.readEntry(QLatin1String(cityNameKey), QString());
}

KSharedConfig::Ptr WeatherEventsConfig::openConfig()
{
    return KSharedConfig::openConfig(QLatin1String(configFileName));
}

double WeatherEventsConfig::latitude() const
{
    return m_latitude;
}

void WeatherEventsConfig::setLatitude(double latitude)
{
    latitude = std::clamp(latitude, -90.0, 90.0);
    if (qFuzzyCompare(m_latitude, latitude)) {
        return;
    }
    m_latitude = latitude;
    Q_EMIT latitudeChanged();
}

double WeatherEventsConfig::longitude() const
{
    return m_longitude;
}

void WeatherEventsConfig::setLongitude(double longitude)
{
    longitude = std::clamp(longitude, -180.0, 180.0);
    if (qFuzzyCompare(m_longitude, longitude)) {
        return;
    }
    m_longitude = longitude;
    Q_EMIT longitudeChanged();
}

QString WeatherEventsConfig::temperatureUnit() const
{
    return m_temperatureUnit;
}

void WeatherEventsConfig::setTemperatureUnit(const QString &unit)
{
    const QString normalized = isCelsius(unit) ? QStringLiteral("celsius")
                                               : QStringLiteral("fahrenheit");
    if (m_temperatureUnit == normalized) {
        return;
    }
    m_temperatureUnit = normalized;
    Q_EMIT temperatureUnitChanged();
}

QString WeatherEventsConfig::cityName() const
{
    return m_cityName;
}

void WeatherEventsConfig::setCityName(const QString &cityName)
{
    if (m_cityName == cityName) {
        return;
    }
    m_cityName = cityName;
    Q_EMIT cityNameChanged();
}

void WeatherEventsConfig::save()
{
    m_general.writeEntry(QLatin1String(latitudeKey), m_latitude);
    m_general.writeEntry(QLatin1String(longitudeKey), m_longitude);
    m_general.writeEntry(QLatin1String(temperatureUnitKey), m_temperatureUnit);
    m_general.writeEntry(QLatin1String(cityNameKey), m_cityName);
    m_config->sync();
}
