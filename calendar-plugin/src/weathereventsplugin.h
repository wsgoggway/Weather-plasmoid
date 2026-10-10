// SPDX-FileCopyrightText: 2026 Vladimir Manichev
// SPDX-License-Identifier: MIT
#pragma once

#include <QDate>

#include <CalendarEvents/CalendarEventsPlugin>

// Plasma calendar plugin that feeds Open-Meteo weather into the digital
// clock widget's calendar. This slice emits one stub all-day event for
// today's date; the real Open-Meteo integration arrives in later slices.
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
    [[nodiscard]] CalendarEvents::EventData makeStubEvent() const;
};
