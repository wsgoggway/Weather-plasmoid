import QtQuick 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15
import org.kde.plasma.plasmoid 2.0
import org.kde.plasma.components 3.0 as PlasmaComponents
import org.kde.plasma.extras 2.0 as PlasmaExtras
import org.kde.kirigami 2.20 as Kirigami

PlasmoidItem {
    id: root

    // ── Weather state ───────────────────────────────────────────────────────
    property double _currentTemp: 0
    property double _currentFeelsLike: 0
    property string _currentConditionRu: ""
    property string _currentEmoji: "🌈"
    property double _currentWindSpeed: 0
    property string _currentWindDir: ""
    property double _currentHumidity: 0
    property double _currentPressure: 0
    property double _currentCloudCover: 0
    property var _forecasts: []
    property var _hourlyForecasts: []
    property string _lastUpdate: ""
    property string _errorMessage: ""
    property bool _loading: false
    property string _tempUnitLabel: "°C"
    property string _windUnitLabel: " м/с"

    // ── Layout ──────────────────────────────────────────────────────────────
    switchWidth: Kirigami.Units.gridUnit * 12
    switchHeight: Kirigami.Units.gridUnit * 14

    compactRepresentation: CompactRepresentation { plasmoidItem: root }
    fullRepresentation: FullRepresentation { plasmoidItem: root }

    // ── Tooltip ─────────────────────────────────────────────────────────────
    toolTipMainText: {
        if (_currentConditionRu && _currentTemp !== undefined) {
            return _currentConditionRu + " — " +
                   _currentTemp + _tempUnitLabel +
                   ", ощущается " + _currentFeelsLike + _tempUnitLabel +
                   ", ветер " + _currentWindSpeed + _windUnitLabel + " " + _currentWindDir
        }
        return plasmoid.configuration.cityName || "Open-Meteo Weather"
    }

    // ── Timer ────────────────────────────────────────────────────────────────
    Timer {
        id: _updateTimer
        interval: Math.max((plasmoid.configuration.updateInterval || 30) * 60 * 1000, 60000)
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: fetchWeather()
    }

    Connections {
        target: plasmoid.configuration
        function onUpdateIntervalChanged() {
            _updateTimer.interval = Math.max((plasmoid.configuration.updateInterval || 30) * 60 * 1000, 60000)
            _updateTimer.restart()
        }
    }

    // ── Geocode city name → coordinates ─────────────────────────────────────
    function geocodeCity(city, callback) {
        var xhr = new XMLHttpRequest()
        xhr.open("GET", "https://geocoding-api.open-meteo.com/v1/search?name=" +
            encodeURIComponent(city) + "&count=1&language=ru")
        xhr.timeout = 8000
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (xhr.status === 200) {
                    try {
                        var data = JSON.parse(xhr.responseText)
                        if (data.results && data.results.length > 0) {
                            var r = data.results[0]
                            if (callback) callback(r.latitude, r.longitude,
                                r.name || city, r.timezone || "Europe/Moscow")
                            return
                        }
                    } catch (e) {}
                }
                if (callback) callback(null, null, null, null)
            }
        }
        xhr.ontimeout = function() { if (callback) callback(null, null, null, null) }
        xhr.onerror   = function() { if (callback) callback(null, null, null, null) }
        xhr.send()
    }

    // ── Location auto-detect via IP ─────────────────────────────────────────
    function detectLocation() {
        var xhr = new XMLHttpRequest()
        xhr.open("GET", "http://ip-api.com/json/?fields=status,message,country,city,lat,lon,timezone")
        xhr.timeout = 8000
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (xhr.status === 200) {
                    try {
                        var d = JSON.parse(xhr.responseText)
                        if (d.status === "success" && d.lat && d.lon) {
                            writeLocation(d.lat, d.lon, d.city || "", d.timezone || "Europe/Moscow")
                            return
                        }
                    } catch (e) {}
                }
                tryFallbackIpwhois()
            }
        }
        xhr.ontimeout = function() { tryFallbackIpwhois() }
        xhr.onerror   = function() { tryFallbackIpwhois() }
        xhr.send()
    }

    function tryFallbackIpwhois() {
        var xhr = new XMLHttpRequest()
        xhr.open("GET", "https://ipwhois.app/json/")
        xhr.timeout = 8000
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE && xhr.status === 200) {
                try {
                    var d = JSON.parse(xhr.responseText)
                    if (d.success !== false && d.latitude && d.longitude) {
                        writeLocation(d.latitude, d.longitude,
                            d.city || d.region || "", d.timezone || "Europe/Moscow")
                        return
                    }
                } catch (e) {}
            }
        }
        xhr.ontimeout = function() {}
        xhr.onerror   = function() {}
        xhr.send()
    }

    function writeLocation(lat, lon, city, tz) {
        plasmoid.configuration.latitude  = lat
        plasmoid.configuration.longitude = lon
        plasmoid.configuration.cityName  = city || ""
        plasmoid.configuration.timezone  = tz || "Europe/Moscow"
        fetchWeather()
    }

    // ── Wind: degrees → Russian compass ─────────────────────────────────────
    function windDegToCompass(deg) {
        var dirs = ["С", "ССВ", "СВ", "ВСВ", "В", "ВЮВ", "ЮВ", "ЮЮВ",
                    "Ю", "ЮЮЗ", "ЮЗ", "ЗЮЗ", "З", "ЗСЗ", "СЗ", "ССЗ"]
        return dirs[Math.round(deg / 22.5) % 16]
    }

    // ── WMO code → emoji + Russian description ──────────────────────────────
    function wmoInfo(code) {
        var m = {
            0:  ["☀️","Ясно"],                  1:["🌤️","Преим. ясно"],
            2:  ["⛅","Перем. облачность"],      3:["☁️","Пасмурно"],
            45: ["🌫️","Туман"],                 48:["🌫️","Изморозь"],
            51: ["🌦️","Лёгкая морось"],         53:["🌦️","Морось"],
            55: ["🌧️","Сильная морось"],        56:["🌨️","Лёгкий лед. дождь"],
            57: ["🌨️","Сильный лед. дождь"],    61:["🌦️","Небольшой дождь"],
            63: ["🌧️","Дождь"],                 65:["🌧️","Сильный дождь"],
            66: ["🌨️","Лёгкий лед. дождь"],     67:["🌨️","Сильный лед. дождь"],
            71: ["🌨️","Небольшой снег"],        73:["❄️","Снег"],
            75: ["❄️","Сильный снегопад"],      77:["❄️","Снежные зёрна"],
            80: ["🌦️","Небольшой ливень"],      81:["🌧️","Ливень"],
            82: ["⛈️","Сильный ливень"],         85:["🌨️","Небольшой снегопад"],
            86: ["🌨️","Сильный снегопад"],      95:["⛈️","Гроза"],
            96: ["⛈️","Гроза с градом"],         99:["⛈️","Сильная гроза"]
        }
        return m[code] || ["🌈","Неизвестно"]
    }

    // ── Fetch from Open-Meteo ───────────────────────────────────────────────
    function fetchWeather() {
        _loading = true
        _errorMessage = ""

        var lat = plasmoid.configuration.latitude || 55.7558
        var lon = plasmoid.configuration.longitude || 37.6173
        var tz  = plasmoid.configuration.timezone || "Europe/Moscow"
        var days = plasmoid.configuration.showForecast ? (plasmoid.configuration.forecastDays || 7) : 1
        var tempUnit = plasmoid.configuration.temperatureUnit || "celsius"
        var windUnit = plasmoid.configuration.windSpeedUnit || "ms"
        var fm = plasmoid.configuration.forecastMode || "daily"
        var wantHourly = (fm === "hourly" || fm === "both")
        var wantDaily  = (fm === "daily"  || fm === "both")

        _tempUnitLabel = tempUnit === "fahrenheit" ? "°F" : "°C"
        _windUnitLabel = windUnit === "ms" ? " м/с" :
                         windUnit === "kmh" ? " км/ч" :
                         windUnit === "mph" ? " миль/ч" :
                         windUnit === "kn" ? " уз" : " м/с"

        var url = "https://api.open-meteo.com/v1/forecast" +
            "?latitude=" + lat + "&longitude=" + lon +
            "&current=temperature_2m,relative_humidity_2m,apparent_temperature," +
            "weather_code,wind_speed_10m,wind_direction_10m,pressure_msl,cloud_cover"

        if (wantDaily) {
            url += "&daily=weather_code,temperature_2m_max,temperature_2m_min," +
                "apparent_temperature_max,apparent_temperature_min," +
                "precipitation_probability_max,wind_speed_10m_max," +
                "wind_direction_10m_dominant"
        }
        if (wantHourly) {
            url += "&hourly=temperature_2m,weather_code,precipitation_probability," +
                "wind_speed_10m,wind_direction_10m"
        }
        url += "&timezone=" + encodeURIComponent(tz) +
            "&forecast_days=" + days +
            "&temperature_unit=" + tempUnit +
            "&wind_speed_unit=" + windUnit

        var xhr = new XMLHttpRequest()
        xhr.open("GET", url)
        xhr.timeout = 15000
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                _loading = false
                if (xhr.status === 200) {
                    try {
                        parseOpenMeteo(JSON.parse(xhr.responseText))
                        _errorMessage = ""
                        _lastUpdate = new Date().toLocaleTimeString(Qt.locale(), "hh:mm")
                    } catch (e) {
                        _errorMessage = "Ошибка обработки данных"
                    }
                } else if (xhr.status === 429) {
                    _errorMessage = "Слишком много запросов. Попробуйте позже."
                } else {
                    _errorMessage = "Ошибка HTTP " + xhr.status
                }
            }
        }
        xhr.ontimeout = function() { _loading = false; _errorMessage = "Таймаут запроса" }
        xhr.onerror   = function() { _loading = false; _errorMessage = "Ошибка сети" }
        xhr.send()
    }

    // ── Parse response ──────────────────────────────────────────────────────
    function parseOpenMeteo(data) {
        var cur = data.current || {}
        _currentTemp       = cur.temperature_2m != null ? cur.temperature_2m : 0
        _currentFeelsLike  = cur.apparent_temperature != null ? cur.apparent_temperature : _currentTemp
        _currentHumidity   = cur.relative_humidity_2m != null ? cur.relative_humidity_2m : 0
        _currentCloudCover = cur.cloud_cover != null ? cur.cloud_cover : 0
        _currentWindSpeed  = cur.wind_speed_10m != null ? cur.wind_speed_10m : 0
        _currentWindDir    = windDegToCompass(cur.wind_direction_10m != null ? cur.wind_direction_10m : 0)
        _currentPressure   = cur.pressure_msl ? Math.round(cur.pressure_msl * 0.75006) : 0

        var wmo = cur.weather_code != null ? cur.weather_code : 0
        var info = wmoInfo(wmo)
        _currentEmoji = info[0]
        _currentConditionRu = info[1]

        // Daily forecast
        var arr = []
        var daily = data.daily || {}
        var n = (daily.time || []).length
        for (var i = 0; i < n; i++) {
            var dw = (daily.weather_code || [])[i] || 0
            var di = wmoInfo(dw)
            arr.push({
                date:           (daily.time || [])[i] || "",
                temp_max:       (daily.temperature_2m_max || [])[i] || 0,
                temp_min:       (daily.temperature_2m_min || [])[i] || 0,
                emoji:          di[0],
                condition:      di[1],
                prec_prob:      (daily.precipitation_probability_max || [])[i] || 0,
                wind_speed_max: (daily.wind_speed_10m_max || [])[i] || 0,
                wind_dir_dom:   windDegToCompass((daily.wind_direction_10m_dominant || [])[i] || 0)
            })
        }
        _forecasts = arr

        // Hourly forecast — start from current hour (ISO string comparison)
        var harr = []
        var hourly = data.hourly || {}
        var htimes = hourly.time || []
        var currentTime = data.current ? (data.current.time || "") : ""
        // Current hour boundary: "2026-07-25T08:30" → "2026-07-25T08"
        var currentHourBoundary = currentTime ? currentTime.substring(0, 13) : ""
        for (var j = 0; j < htimes.length; j++) {
            // Only include hours >= current hour boundary
            if (currentHourBoundary && htimes[j] < currentHourBoundary) continue
            if (harr.length >= 48) break
            var hw = (hourly.weather_code || [])[j] || 0
            var hi = wmoInfo(hw)
            harr.push({
                time:           htimes[j] || "",
                temp:           (hourly.temperature_2m || [])[j] || 0,
                emoji:          hi[0],
                condition:      hi[1],
                prec_prob:      (hourly.precipitation_probability || [])[j] || 0,
                wind_speed:     (hourly.wind_speed_10m || [])[j] || 0,
                wind_dir:       windDegToCompass((hourly.wind_direction_10m || [])[j] || 0)
            })
        }
        _hourlyForecasts = harr
    }
}
