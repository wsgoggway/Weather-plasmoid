// SPDX-FileCopyrightText: 2026 Vladimir Manichev
// SPDX-License-Identifier: MIT
#pragma once

#include <QDate>
#include <QDateTime>
#include <QHash>
#include <QObject>
#include <QSet>
#include <QString>
#include <QUrl>

#include <optional>

class QNetworkAccessManager;
class QNetworkReply;
class QTimer;

// Daily Open-Meteo forecast data layer: fetch, parse, on-disk cache merge.
// Pure logic — the calendar plugin glue (a later slice) drives it through
// ensureRange()/dayFor()/availableDays() and listens to updated()/fetchFailed().
//
// Cache file format (JSON):
//   {"version":1,"latitude":..,"longitude":..,"unit":"celsius",
//    "fetchedAt":"ISO8601","days":{"2026-10-10":{DayWeather fields},...}}
// A corrupt or unreadable cache starts the store empty (never crashes).
class WeatherDataStore : public QObject
{
    Q_OBJECT

public:
    enum class TemperatureUnit { Celsius, Fahrenheit };

    // Numeric fields are rounded at parse time (repo rule); uvMax stays
    // fractional. sunrise/sunset keep the API's local ISO form
    // ("2026-10-14T06:58") because the calendar only slices it.
    struct DayWeather
    {
        QDate date;
        int wmoCode = 0;
        int tMax = 0;
        int tMin = 0;
        int precipProb = 0; // percent 0..100; past days (null) -> 0
        int precipSumMm = 0;
        int windMaxKmh = 0;
        int windDirDeg = 0; // dominant direction, degrees 0..359
        double uvMax = 0.0;
        QString sunrise;
        QString sunset;
    };

    // Empty cacheFilePath -> in-memory only (tests).
    explicit WeatherDataStore(QString cacheFilePath, QObject *parent = nullptr);
    ~WeatherDataStore() override;

    // Production cache location:
    // <GenericCacheLocation>/weatherevents/daily.json
    [[nodiscard]] static QString defaultCacheFilePath();

    // Changing location or unit starts a fresh cache: in-memory days are
    // dropped and the cache file is rewritten empty for the new location.
    // Calling it again with identical values is a no-op.
    void setLocation(double latitude, double longitude, TemperatureUnit unit);

    [[nodiscard]] std::optional<DayWeather> dayFor(QDate date) const;
    [[nodiscard]] QSet<QDate> availableDays() const;

    // No location set -> no-op. If the requested range is already covered by
    // cached days AND the last successful fetch is less than 3h old -> no-op.
    // Otherwise fetches Open-Meteo daily data (request clamped to the API
    // window: past 7 days .. next 16 days; a range entirely outside the
    // window triggers no fetch — the cache serves what it has). Emits
    // updated() after new data is merged; emits fetchFailed(reason) on
    // network/HTTP/parse errors, keeping the old cache intact. A 3h
    // repeating timer re-runs the last request; it is armed only after the
    // first successful fetch and restarts on every new one.
    void ensureRange(QDate startDate, QDate endDate);

    // Test hook: parse an Open-Meteo daily JSON response, merge it into the
    // cache (per-date, newly fetched wins) and persist the cache. Emits
    // nothing. Returns false and fills *error on malformed input, leaving
    // the store state untouched.
    bool applyFetchJson(const QByteArray &json, QString *error = nullptr);

signals:
    void updated();
    void fetchFailed(const QString &reason);

private:
    void loadCache();
    [[nodiscard]] bool saveCache() const;
    void startFetch();
    [[nodiscard]] QUrl buildFetchUrl() const;
    [[nodiscard]] bool rangeCovered(QDate startDate, QDate endDate) const;
    [[nodiscard]] bool fetchIsFresh() const;
    void refreshRequestedRange();

    QString m_cacheFilePath;
    QHash<QDate, DayWeather> m_days;
    QDateTime m_lastFetch; // last successful fetch, persisted as "fetchedAt"
    double m_latitude = 0.0;
    double m_longitude = 0.0;
    TemperatureUnit m_unit = TemperatureUnit::Celsius;
    bool m_hasLocation = false;
    QDate m_requestedStart; // range of the latest ensureRange() call
    QDate m_requestedEnd;
    QNetworkAccessManager *m_network = nullptr;
    QTimer *m_refreshTimer = nullptr;
    QNetworkReply *m_activeReply = nullptr;
};
