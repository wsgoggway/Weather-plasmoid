// SPDX-FileCopyrightText: 2026 Vladimir Manichev
// SPDX-License-Identifier: MIT
#pragma once

#include <KConfigGroup>
#include <KSharedConfig>

#include <QObject>
#include <qqmlintegration.h>

// QML-facing helper for the plugin's config page (the ConfigStorage pattern
// used by KDE's own calendar plugins): the digital clock config dialog gives
// a calendar plugin page only the applet's own cfg_* properties, so a
// calendar plugin cannot write its settings through that machinery. This
// element reads/writes the plugin's own KConfig file ("weathereventsrc")
// instead; the plugin side picks the change up through KConfigWatcher.
//
// Shipped as the QML module org.kde.plasma.private.weathereventsconfig and
// installed under the Qt QML import path next to the other KDE calendar
// config modules.
class WeatherEventsConfig : public QObject
{
    Q_OBJECT
    QML_ELEMENT

    // Latitude in degrees, [-90, 90]. 0 together with a 0 longitude means
    // "no location chosen" (the plugin treats that as unset).
    Q_PROPERTY(double latitude READ latitude WRITE setLatitude NOTIFY latitudeChanged)

    // Longitude in degrees, [-180, 180].
    Q_PROPERTY(double longitude READ longitude WRITE setLongitude NOTIFY longitudeChanged)

    // "celsius" or "fahrenheit"; anything else reads back as "celsius".
    Q_PROPERTY(QString temperatureUnit READ temperatureUnit WRITE setTemperatureUnit NOTIFY
                   temperatureUnitChanged)

    // Informational only (shown in the page); the plugin uses coordinates.
    Q_PROPERTY(QString cityName READ cityName WRITE setCityName NOTIFY cityNameChanged)

public:
    explicit WeatherEventsConfig(QObject *parent = nullptr);

    [[nodiscard]] double latitude() const;
    void setLatitude(double latitude);

    [[nodiscard]] double longitude() const;
    void setLongitude(double longitude);

    [[nodiscard]] QString temperatureUnit() const;
    void setTemperatureUnit(const QString &unit);

    [[nodiscard]] QString cityName() const;
    void setCityName(const QString &cityName);

    // Writes the current property values to weathereventsrc [General] and
    // syncs so the running plugin (KConfigWatcher) sees them immediately.
    Q_INVOKABLE void save();

Q_SIGNALS:
    void latitudeChanged();
    void longitudeChanged();
    void temperatureUnitChanged();
    void cityNameChanged();

private:
    [[nodiscard]] static KSharedConfig::Ptr openConfig();

    KSharedConfig::Ptr m_config;
    KConfigGroup m_general;
    double m_latitude = 0.0;
    double m_longitude = 0.0;
    QString m_temperatureUnit = QStringLiteral("celsius");
    QString m_cityName;
};
