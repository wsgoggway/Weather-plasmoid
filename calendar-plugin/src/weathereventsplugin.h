// SPDX-FileCopyrightText: 2026 Vladimir Manichev
// SPDX-License-Identifier: MIT
#pragma once

#include <QDate>
#include <QMultiHash>

#include <KConfigWatcher>
#include <KSharedConfig>

#include <CalendarEvents/CalendarEventsPlugin>

#include "weatherdatastore.h"

// Plasma calendar plugin that feeds Open-Meteo weather into the digital
// clock widget's calendar. The plugin owns a WeatherDataStore configured
// from weathereventsrc [General] (written by the plugin's config page), asks
// it to cover every requested date range and turns each available day into
// one all-day EventData (colored by the day's mean temperature) plus a
// subLabel with the day's max temperature.
//
// The base class CalendarEvents::CalendarEventsPlugin already derives from
// QObject, so this class inherits only the interface (adding another QObject
// base would create a QObject diamond and break qt_metacast/qobject_cast).
class WeatherEventsPlugin : public CalendarEvents::CalendarEventsPlugin
{
    Q_OBJECT
    Q_PLUGIN_METADATA(IID "org.kde.CalendarEventsPlugin" FILE "metadata.json")
    Q_INTERFACES(CalendarEvents::CalendarEventsPlugin)

public:
    explicit WeatherEventsPlugin(QObject *parent = nullptr);
    ~WeatherEventsPlugin() override;

    void loadEventsForDateRange(const QDate &startDate, const QDate &endDate) override;

private:
    // Reads [General] from weathereventsrc and returns whether a usable
    // location is configured (0/0 counts as unset).
    bool loadConfig();
    void applyConfiguredLocation();
    // fullEmission=true re-sends the whole set (the UI just cleared its model
    // and re-requested the range); otherwise only the diff against the last
    // emission goes out (see rebuildAndEmit).
    void rebuildAndEmit(bool fullEmission);
    [[nodiscard]] static bool sameEvent(const CalendarEvents::EventData &a,
                                        const CalendarEvents::EventData &b);
    void rememberRange(const QDate &startDate, const QDate &endDate);

    [[nodiscard]] CalendarEvents::EventData makeDayEvent(const WeatherDataStore::DayWeather &day) const;
    [[nodiscard]] QString dayEventTitle(const WeatherDataStore::DayWeather &day) const;
    [[nodiscard]] QString dayEventDescription(const WeatherDataStore::DayWeather &day) const;

    KSharedConfig::Ptr m_config;
    KConfigWatcher::Ptr m_configWatcher;
    WeatherDataStore *m_store = nullptr;

    // Location currently applied to the store (used to detect config changes).
    double m_latitude = 0.0;
    double m_longitude = 0.0;
    WeatherDataStore::TemperatureUnit m_unit = WeatherDataStore::TemperatureUnit::Celsius;

    // Union of all ranges requested this session; invalid = nothing asked yet.
    QDate m_rangeStart;
    QDate m_rangeEnd;

    // The data set from the last dataReady emission, so a config change can
    // retire the stale uids via eventRemoved (the holidays plugin does the same).
    QMultiHash<QDate, CalendarEvents::EventData> m_lastData;
};
