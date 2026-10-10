// SPDX-FileCopyrightText: 2026 Vladimir Manichev
// SPDX-License-Identifier: MIT
#include "weathereventsplugin.h"

#include <QDateTime>
#include <QMultiHash>
#include <QTime>

namespace {

constexpr auto stubEventUid = "weatherevents-stub";
constexpr auto stubEventColor = "#ff9800";

} // namespace

WeatherEventsPlugin::WeatherEventsPlugin(QObject *parent)
    : CalendarEvents::CalendarEventsPlugin(parent)
{
}

WeatherEventsPlugin::~WeatherEventsPlugin() = default;

void WeatherEventsPlugin::loadEventsForDateRange(const QDate &startDate, const QDate &endDate)
{
    const QDate today = QDate::currentDate();

    QMultiHash<QDate, CalendarEvents::EventData> data;
    if (startDate <= today && today <= endDate) {
        data.insert(today, makeStubEvent());
    }

    Q_EMIT dataReady(data);
}

CalendarEvents::EventData WeatherEventsPlugin::makeStubEvent() const
{
    const QDateTime dayStart(QDate::currentDate(), QTime(0, 0));
    const QDateTime dayEnd(QDate::currentDate(), QTime(23, 59, 59));

    CalendarEvents::EventData event;
    event.setUid(QLatin1String(stubEventUid));
    event.setTitle(QStringLiteral("Погода (заглушка): +21°, ясно"));
    event.setEventType(CalendarEvents::EventData::EventType::Event);
    event.setEventColor(QLatin1String(stubEventColor));
    event.setIsAllDay(true);
    event.setStartDateTime(dayStart);
    event.setEndDateTime(dayEnd);
    return event;
}
