import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import org.kde.kirigami 2.20 as Kirigami
import org.kde.plasma.components 3.0 as PlasmaComponents
import org.kde.plasma.configuration 2.0
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    // KCM auto-wires cfg_* properties from main.xml
    property var cfg_latitude
    property var cfg_longitude
    property var cfg_cityName
    property var cfg_timezone
    property var cfg_updateInterval
    property var cfg_showForecast
    property var cfg_forecastDays
    property var cfg_temperatureUnit
    property var cfg_windSpeedUnit
    property var cfg_forecastMode

    // KCM also sets cfg_*Default from main.xml — accept silently
    property var cfg_latitudeDefault
    property var cfg_longitudeDefault
    property var cfg_cityNameDefault
    property var cfg_timezoneDefault
    property var cfg_updateIntervalDefault
    property var cfg_showForecastDefault
    property var cfg_forecastDaysDefault
    property var cfg_temperatureUnitDefault
    property var cfg_windSpeedUnitDefault
    property var cfg_forecastModeDefault

    // ── Sync UI fields from cfg_* on load ──────────────────────────────────
    // Note: only TextFields need manual sync (to avoid fighting the user while
    // typing into a bound numeric field). SpinBox/ComboBox/CheckBox use direct
    // bindings + user-only signals (onValueModified/onActivated/onToggled) so
    // they never clobber the loaded config value during initialization.
    Component.onCompleted: {
        latitudeField.text  = String(cfg_latitude  || 55.7558)
        longitudeField.text = String(cfg_longitude || 37.6173)
        cityNameField.text  = cfg_cityName || ""
        timezoneField.text  = cfg_timezone || "Europe/Moscow"
    }

    // ── Geocode city name → coordinates (Open-Meteo Geocoding API) ─────────
    function geocodeCity(cityName) {
        geocodeBtn.enabled = false
        geocodeBtn.text = "Ищу..."
        var xhr = new XMLHttpRequest()
        xhr.open("GET", "https://geocoding-api.open-meteo.com/v1/search?name=" +
            encodeURIComponent(cityName) + "&count=1&language=ru")
        xhr.timeout = 8000
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE && xhr.status === 200) {
                try {
                    var data = JSON.parse(xhr.responseText)
                    if (data.results && data.results.length > 0) {
                        var r = data.results[0]
                        cfg_latitude  = Math.round(r.latitude  * 10000) / 10000
                        cfg_longitude = Math.round(r.longitude * 10000) / 10000
                        cfg_cityName  = r.name || cityName
                        cfg_timezone  = r.timezone || "Europe/Moscow"
                        latitudeField.text  = String(cfg_latitude)
                        longitudeField.text = String(cfg_longitude)
                        cityNameField.text  = cfg_cityName
                        timezoneField.text  = cfg_timezone
                        geocodeBtn.enabled = true
                        geocodeBtn.text = "✓ Найдено: " + cfg_cityName
                        return
                    }
                } catch (e) {}
            }
            geocodeBtn.enabled = true
            geocodeBtn.text = "✗ Город не найден"
        }
        xhr.ontimeout = function() { geocodeBtn.enabled = true; geocodeBtn.text = "✗ Таймаут" }
        xhr.onerror   = function() { geocodeBtn.enabled = true; geocodeBtn.text = "✗ Нет интернета" }
        xhr.send()
    }

    // ── Detect location via IP (same reliable APIs as the widget) ──────────
    function detectLocation() {
        detectBtn.enabled = false
        detectBtn.text = "Определяю..."
        var xhr = new XMLHttpRequest()
        xhr.open("GET", "http://ip-api.com/json/?fields=status,message,country,city,lat,lon,timezone")
        xhr.timeout = 8000
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (xhr.status === 200) {
                    try {
                        var d = JSON.parse(xhr.responseText)
                        if (d.status === "success" && d.lat && d.lon) {
                            writeDetectedLocation(d.lat, d.lon, d.city || "", d.timezone || "Europe/Moscow")
                            return
                        }
                    } catch (e) {}
                }
                tryFallbackDetect()
            }
        }
        xhr.ontimeout = function() { tryFallbackDetect() }
        xhr.onerror   = function() { tryFallbackDetect() }
        xhr.send()
    }

    function tryFallbackDetect() {
        var xhr = new XMLHttpRequest()
        xhr.open("GET", "https://ipwhois.app/json/")
        xhr.timeout = 8000
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE && xhr.status === 200) {
                try {
                    var d = JSON.parse(xhr.responseText)
                    if (d.success !== false && d.latitude && d.longitude) {
                        writeDetectedLocation(d.latitude, d.longitude,
                            d.city || d.region || "", d.timezone || "Europe/Moscow")
                        return
                    }
                } catch (e) {}
            }
            detectBtn.enabled = true
            detectBtn.text = "✗ Не удалось определить"
        }
        xhr.ontimeout = function() { detectBtn.enabled = true; detectBtn.text = "✗ Таймаут" }
        xhr.onerror   = function() { detectBtn.enabled = true; detectBtn.text = "✗ Нет интернета" }
        xhr.send()
    }

    function writeDetectedLocation(lat, lon, city, tz) {
        cfg_latitude  = Math.round(lat * 10000) / 10000; latitudeField.text  = String(cfg_latitude)
        cfg_longitude = Math.round(lon * 10000) / 10000; longitudeField.text = String(cfg_longitude)
        cfg_cityName  = city || "";                      cityNameField.text  = cfg_cityName
        cfg_timezone  = tz || "Europe/Moscow";           timezoneField.text  = cfg_timezone
        detectBtn.enabled = true
        detectBtn.text = "✓ Определено: " + (cfg_cityName || "город")
    }

    // ── UI ─────────────────────────────────────────────────────────────────
    Item {
        anchors.fill: parent
        implicitWidth: childrenRect.width
        implicitHeight: childrenRect.height
    Kirigami.FormLayout {
        anchors { left: parent.left; right: parent.right }
        wideMode: true

        Kirigami.InlineMessage {
            Layout.fillWidth: true
            type: Kirigami.MessageType.Information
            text: "Бесплатный API Open-Meteo, ключ не нужен."
            visible: true
        }

        // ── Location section ──────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            Kirigami.FormData.label: "Город:"
            TextField {
                id: cityNameField
                placeholderText: "Москва"
                Layout.fillWidth: true
                onTextEdited: cfg_cityName = text
            }
            Button {
                id: geocodeBtn
                text: "Найти"
                icon.name: "search"
                onClicked: {
                    if (cityNameField.text.length > 1)
                        geocodeCity(cityNameField.text)
                }
            }
        }

        Button {
            id: detectBtn
            text: "Определить по IP"
            icon.name: "find-location"
            Layout.fillWidth: true
            onClicked: detectLocation()
        }

        TextField {
            id: latitudeField
            Kirigami.FormData.label: "Широта:"
            placeholderText: "55.7558"
            Layout.fillWidth: true
            inputMethodHints: Qt.ImhFormattedNumbersOnly
            validator: DoubleValidator { bottom: -90.0; top: 90.0; decimals: 6 }
            onTextEdited: cfg_latitude = parseFloat(text) || 0
        }

        TextField {
            id: longitudeField
            Kirigami.FormData.label: "Долгота:"
            placeholderText: "37.6173"
            Layout.fillWidth: true
            inputMethodHints: Qt.ImhFormattedNumbersOnly
            validator: DoubleValidator { bottom: -180.0; top: 180.0; decimals: 6 }
            onTextEdited: cfg_longitude = parseFloat(text) || 0
        }

        TextField {
            id: timezoneField
            Kirigami.FormData.label: "Часовой пояс:"
            placeholderText: "Europe/Moscow"
            Layout.fillWidth: true
            onTextEdited: cfg_timezone = text
        }

        // ── Update settings ───────────────────────────────────────────────
        SpinBox {
            id: updateIntervalSpin
            Kirigami.FormData.label: "Интервал обновления (мин):"
            from: 5; to: 180; stepSize: 5
            value: cfg_updateInterval
            onValueModified: cfg_updateInterval = value
        }

        ComboBox {
            id: tempUnitCombo
            Kirigami.FormData.label: "Температура:"
            textRole: "text"
            model: [{ text: "Цельсий (°C)", value: "celsius" },
                    { text: "Фаренгейт (°F)", value: "fahrenheit" }]
            currentIndex: {
                var v = cfg_temperatureUnit || "celsius"
                for (var i = 0; i < model.length; i++)
                    if (model[i].value === v) return i
                return 0
            }
            onActivated: cfg_temperatureUnit = model[currentIndex].value
        }

        ComboBox {
            id: windUnitCombo
            Kirigami.FormData.label: "Единицы ветра:"
            textRole: "text"
            model: [{ text: "м/с", value: "ms" },
                    { text: "км/ч", value: "kmh" },
                    { text: "миль/ч", value: "mph" },
                    { text: "узлы", value: "kn" }]
            currentIndex: {
                var v = cfg_windSpeedUnit || "ms"
                for (var i = 0; i < model.length; i++)
                    if (model[i].value === v) return i
                return 0
            }
            onActivated: cfg_windSpeedUnit = model[currentIndex].value
        }

        // ── Forecast section ──────────────────────────────────────────────
        CheckBox {
            id: showForecastCheck
            Kirigami.FormData.label: "Прогноз:"
            text: "Показывать прогноз"
            checked: cfg_showForecast !== false
            onToggled: cfg_showForecast = checked
        }

        ComboBox {
            id: forecastModeCombo
            Kirigami.FormData.label: "Режим прогноза:"
            textRole: "text"
            enabled: showForecastCheck.checked
            model: [{ text: "По дням", value: "daily" },
                    { text: "По часам", value: "hourly" },
                    { text: "Дни + Часы", value: "both" }]
            currentIndex: {
                var v = cfg_forecastMode || "daily"
                for (var i = 0; i < model.length; i++)
                    if (model[i].value === v) return i
                return 0
            }
            onActivated: cfg_forecastMode = model[currentIndex].value
        }

        SpinBox {
            id: forecastDaysSpin
            Kirigami.FormData.label: "Дней прогноза:"
            from: 1; to: 16; stepSize: 1
            enabled: showForecastCheck.checked
            value: cfg_forecastDays
            onValueModified: cfg_forecastDays = value
        }
    } // FormLayout
    } // Item
}
