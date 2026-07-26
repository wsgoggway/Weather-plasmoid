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

    // ── Day summary & extras ──────────────────────────────────────────────
    property string _sunrise: "--:--"
    property string _sunset: "--:--"
    property double _uvIndex: 0
    property double _precipSum: 0
    property string _feelsJokeText: ""
    property var _historyEvents: []
    property string _holidaysText: ""
    property string _historyDate: ""
    property string _holidaysDate: ""

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
        // Re-render on any weather-affecting setting change (debounced).
        function onLatitudeChanged()      { _configReloadTimer.restart() }
        function onLongitudeChanged()     { _configReloadTimer.restart() }
        function onTimezoneChanged()      { _configReloadTimer.restart() }
        function onTemperatureUnitChanged(){ _configReloadTimer.restart() }
        function onWindSpeedUnitChanged() { _configReloadTimer.restart() }
        function onForecastDaysChanged()  { _configReloadTimer.restart() }
        function onForecastModeChanged()  { _configReloadTimer.restart() }
        function onShowForecastChanged()  { _configReloadTimer.restart() }
        function onShowTodayChanged()     { _configReloadTimer.restart() }
    }

    // Coalesces a burst of config changes (one Apply) into a single reload.
    Timer {
        id: _configReloadTimer
        interval: 400
        repeat: false
        onTriggered: {
            fetchWeather()
            if (plasmoid.configuration.showToday !== false) fetchThisDay()
        }
    }

    Component.onCompleted: {
        // Fetch today's holidays + "this day in history" once at startup
        // (only if the "Сегодня" block is enabled).
        if (plasmoid.configuration.showToday !== false) fetchThisDay()
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

    // ── Sarcastic "feels like" quip (varied; random pick per refresh) ───────
    // feelsLike is given in the displayed unit (°C / °F); we normalize to °C.
    function feelsLikeJoke(feelsLike, unitLabel) {
        if (feelsLike === null || feelsLike === undefined) return ""
        var c = feelsLike
        if (unitLabel === "°F") c = (feelsLike - 32) * 5 / 9
        // [threshold, [variants...]] — first threshold that c is below wins
        var buckets = [
            [-30, [
                "На улице холоднее, чем в морге. И ветер злее.",
                "План на день: дойти до холодильника и обратно. И то спорно.",
                "Если вернулся живым — уже повод для гордости.",
                "Собака просится гулять? Собака врёт. Она хочет жить."
            ]],
            [-20, [
                "Куртка толщиной с матрас — мастхэв.",
                "Холоднее, чем твой утренний энтузиазм.",
                "Врачи советуют дышать через шарф. Или вообще не дышать.",
                "Идеальная погода, чтобы передумать выходить."
            ]],
            [-10, [
                "Пуховик, шапка, гордость — и вперёд страдать.",
                "Нос стал декоративным элементом. Крепись.",
                "Свежо так, что брови подозрительно хрустят.",
                "Погода намекает: ну куда ты опять собрался?"
            ]],
            [-5, [
                "Шапку надень. Мама ведь негласно следит.",
                "Не холодно, не жарко — страдай эстетично.",
                "Ветер лично проверяет твой капюшон на прочность.",
                "Середина термометра — самое мучительное место."
            ]],
            [0, [
                "Слякоть, ветер, серость — классика жанра.",
                "Чай остынет быстрее, чем ты его допьёшь. Как и мотивация.",
                "Погода для тех, кто любит страдать красиво.",
                "Куртка промокает, настроение — следом."
            ]],
            [5, [
                "Весна? Зима? Кому какое дело, всё равно мерзко.",
                "Надевать куртку — жарко, снимать — самоубийство.",
                "Обманчивая температура: выглядит ок, на деле — промозгло.",
                "Градусник явно издевается."
            ]],
            [10, [
                "Ветровка и капля надежды на весну.",
                "Прохладно ровно настолько, чтобы ныть, но не замёрзнуть.",
                "Погода, ради которой не хочется вставать с кровати.",
                "Вроде весна, а вроде опять обман."
            ]],
            [15, [
                "Норм. Можно даже снять шапку. Если не трус.",
                "Идеально для прогулки, на которую ты не пойдёшь.",
                "Природа намекает: вылезай уже.",
                "Терпимо. Для нас — почти курорт."
            ]],
            [18, [
                "Почти хорошо. Почти весна. Почти счастье.",
                "Можно без куртки — и почти не дрожать.",
                "Температура, при которой никто не жалуется. Редкость!",
                "Грех сидеть дома. Но ты же всё равно будешь."
            ]],
            [23, [
                "Идеально. Не испорть это нытьём.",
                "Беги гулять, пока погода не передумала.",
                "Так хорошо, что даже подозрительно.",
                "Погода старается. А ты?"
            ]],
            [27, [
                "Тепло, уютно, можно выкинуть носки.",
                "Погода намекает на шашлыки. Намёк понял?",
                "Лучше, чем твой вчерашний день. Наверняка.",
                "Идеальный день, чтобы никуда не спешить."
            ]],
            [30, [
                "Жара подкралась незаметно. Как и дедлайн.",
                "Шорты и философский вопрос: а не холодно ли в теньке?",
                "Вентилятор ещё не нужен, но уже греет душу.",
                "Наконец-то можно потеть легально."
            ]],
            [33, [
                "Горячо. Мороженое обязательно, тень — святое.",
                "Пот градом, зато не снег.",
                "Пора вспомнить, где лежит вентилятор.",
                "Асфальт плавится, и ты рядом."
            ]]
        ]
        for (var i = 0; i < buckets.length; i++) {
            if (c < buckets[i][0]) {
                var arr = buckets[i][1]
                return arr[Math.floor(Math.random() * arr.length)]
            }
        }
        var hot = buckets[buckets.length - 1][1]
        return hot[Math.floor(Math.random() * hot.length)]
    }

    // ── Small format helpers ────────────────────────────────────────────────
    function isoToHM(iso) {
        if (!iso) return "--:--"
        var t = iso.split("T")[1]
        return t ? t.substring(0, 5) : "--:--"
    }
    function uvText(uv) {
        if (uv === null || uv === undefined) return "--"
        var n = Math.round(uv)
        var d = n < 3 ? "низкий" : n < 6 ? "умер." : n < 8 ? "высокий" : n < 11 ? "оч. высок." : "экстрим"
        return n + " · " + d
    }

    // ── Today's holidays (offline dataset) ──────────────────────────────────
    function holidaysForMonthDay(mm, dd) {
        var h = {
            "1-1":  "🎉 Новый год",
            "1-2":  "🎊 Новогодние каникулы",
            "1-3":  "🎊 Новогодние каникулы",
            "1-4":  "🎊 Новогодние каникулы",
            "1-5":  "🎊 Новогодние каникулы",
            "1-6":  "🎊 Новогодние каникулы",
            "1-7":  "🎄 Рождество Христово",
            "1-8":  "🎊 Новогодние каникулы",
            "1-14": "📅 Старый Новый год",
            "1-25": "🎓 День студента (Татьянин день)",
            "2-8":  "🔬 День российской науки",
            "2-10": "💼 День дипломатического работника",
            "2-14": "💝 День святого Валентина",
            "2-23": "🇷🇺 День защитника Отечества",
            "3-8":  "🌷 Международный женский день",
            "3-25": "🎭 День работника культуры",
            "3-27": "🎫 День театра",
            "4-1":  "🤡 День смеха",
            "4-12": "🚀 День космонавтики",
            "5-1":  "🛠️ Праздник Весны и Труда",
            "5-7":  "📻 День радио",
            "5-9":  "🎖️ День Победы",
            "5-24": "📜 День славянской письменности и культуры",
            "5-28": "🛡️ День пограничника",
            "6-1":  "🧸 День защиты детей",
            "6-6":  "📖 День русского языка",
            "6-12": "🇷🇺 День России",
            "6-27": "🌟 День молодёжи",
            "7-8":  "💑 День семьи, любви и верности",
            "8-22": "🚩 День Государственного флага РФ",
            "8-27": "🎬 День российского кино",
            "9-1":  "📚 День знаний",
            "10-1": "👴 День пожилого человека",
            "10-5": "👨‍🏫 Всемирный день учителя",
            "11-4": "🇷🇺 День народного единства",
            "11-7": "🎖️ День воинской славы (1941)",
            "12-9": "🏅 День Героев Отечества",
            "12-12":"⚖️ День Конституции РФ",
            "12-31":"🎄 Канун Нового года"
        }
        return h[mm + "-" + dd] || ""
    }

    // ── Today: holidays (htmlweb.ru, daily) + history (Wikipedia, daily) ───
    // Both are fetched at most once per day (cached by date). On any failure
    // (network, rate-limit) we keep the offline holiday dictionary fallback.
    function fetchThisDay() {
        var now = new Date()
        var mm = now.getMonth() + 1
        var dd = now.getDate()
        var key = now.getFullYear() + "-" + mm + "-" + dd

        // Holidays: once per day. Offline dict is the immediate fallback;
        // htmlweb.ru (richer) overwrites _holidaysText on success only.
        if (_holidaysDate !== key) {
            _holidaysDate = key
            _holidaysText = holidaysForMonthDay(mm, dd)
            fetchHolidaysHtmlweb(mm, dd, now.getFullYear())
        }

        // History: once per day.
        if (_historyDate === key && _historyEvents.length > 0) return
        _historyDate = key
        fetchHistoryWikipedia(mm, dd)
    }

    // Rich holidays from htmlweb.ru (keyless, ~20 req/day/IP → called once/day).
    // On any error/limit we keep the offline fallback already in _holidaysText.
    function fetchHolidaysHtmlweb(mm, dd, year) {
        var pad2 = function(n) { return (n < 10 ? "0" : "") + n }
        var ds = pad2(dd) + "." + pad2(mm) + "." + year
        var xhr = new XMLHttpRequest()
        xhr.open("GET", "https://htmlweb.ru/json/calendar/list?d_from=" + ds + "&d_to=" + ds + "&country=RU")
        xhr.timeout = 10000
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE && xhr.status === 200) {
                try {
                    var data = JSON.parse(xhr.responseText)
                    if (data && data.status === 200 && data.holidays) {
                        var skip = /^(Выходной день|Выходной|Дополнительный выходной|Рабочий день)$/i
                        var names = []
                        for (var i = 0; i < data.holidays.length; i++) {
                            var n = (data.holidays[i].name || "").trim()
                            if (n && !skip.test(n) && names.indexOf(n) === -1) names.push(n)
                        }
                        if (names.length) _holidaysText = "🎉 " + names.join(", ")
                    }
                } catch (err) {}
            }
        }
        xhr.ontimeout = function() {}
        xhr.onerror   = function() {}
        xhr.send()
    }

    // "This day in history" via Wikipedia REST API (ru) — pick 3 random events
    // with their article URL.
    function fetchHistoryWikipedia(mm, dd) {
        var mms = (mm < 10 ? "0" : "") + mm
        var dds = (dd < 10 ? "0" : "") + dd
        var xhr = new XMLHttpRequest()
        xhr.open("GET", "https://ru.wikipedia.org/api/rest_v1/feed/onthisday/events/" + mms + "/" + dds)
        xhr.timeout = 10000
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE && xhr.status === 200) {
                try {
                    var data = JSON.parse(xhr.responseText)
                    var evs = data.events || []
                    var pool = evs.slice()
                    var picks = []
                    var count = Math.min(3, pool.length)
                    for (var k = 0; k < count; k++) {
                        var idx = Math.floor(Math.random() * pool.length)
                        var ev = pool[idx]
                        if (ev && ev.text) {
                            var url = ""
                            var pg = ev.pages && ev.pages.length ? ev.pages[0] : null
                            if (pg && pg.content_urls && pg.content_urls.desktop)
                                url = pg.content_urls.desktop.page || ""
                            picks.push({ year: ev.year || "?", text: ev.text, url: url })
                        }
                        pool.splice(idx, 1)
                    }
                    _historyEvents = picks
                } catch (err) {}
            }
        }
        xhr.ontimeout = function() {}
        xhr.onerror   = function() {}
        xhr.send()
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

        // Day-summary metrics (sunrise/sunset/uv/precip) are always requested —
        // they feed the "Day" card regardless of forecast mode.
        var dailyFields = "sunrise,sunset,uv_index_max,precipitation_sum"
        if (wantDaily) {
            dailyFields += ",weather_code,temperature_2m_max,temperature_2m_min," +
                "apparent_temperature_max,apparent_temperature_min," +
                "precipitation_probability_max,wind_speed_10m_max," +
                "wind_direction_10m_dominant"
        }
        url += "&daily=" + dailyFields
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
        _currentTemp       = Math.round(cur.temperature_2m != null ? cur.temperature_2m : 0)
        _currentFeelsLike  = Math.round(cur.apparent_temperature != null ? cur.apparent_temperature : _currentTemp)
        _currentHumidity   = cur.relative_humidity_2m != null ? cur.relative_humidity_2m : 0
        _currentCloudCover = cur.cloud_cover != null ? cur.cloud_cover : 0
        _currentWindSpeed  = cur.wind_speed_10m != null ? cur.wind_speed_10m : 0
        _currentWindDir    = windDegToCompass(cur.wind_direction_10m != null ? cur.wind_direction_10m : 0)
        _currentPressure   = cur.pressure_msl ? Math.round(cur.pressure_msl * 0.75006) : 0

        var wmo = cur.weather_code != null ? cur.weather_code : 0
        var info = wmoInfo(wmo)
        _currentEmoji = info[0]
        _currentConditionRu = info[1]

        // Today's day-summary metrics (always available)
        var daily = data.daily || {}
        var sunriseArr = daily.sunrise || []
        var sunsetArr  = daily.sunset  || []
        var uvArr      = daily.uv_index_max || []
        var precipArr  = daily.precipitation_sum || []
        _sunrise = isoToHM(sunriseArr.length ? sunriseArr[0] : "")
        _sunset  = isoToHM(sunsetArr.length ? sunsetArr[0] : "")
        _uvIndex = (uvArr.length && uvArr[0] != null) ? Math.round(uvArr[0] * 10) / 10 : 0
        _precipSum = (precipArr.length && precipArr[0] != null) ? Math.round(precipArr[0] * 10) / 10 : 0

        // Sarcastic quip for the current feels-like temperature (varied)
        _feelsJokeText = feelsLikeJoke(_currentFeelsLike, _tempUnitLabel)

        // Daily forecast (only when daily forecast fields were requested)
        var arr = []
        var wcArr = daily.weather_code || []
        var n = (daily.time || []).length
        if (wcArr.length > 0) {
            for (var i = 0; i < n; i++) {
                var dw = wcArr[i] || 0
                var di = wmoInfo(dw)
                arr.push({
                    date:           (daily.time || [])[i] || "",
                    temp_max:       Math.round((daily.temperature_2m_max || [])[i] || 0),
                    temp_min:       Math.round((daily.temperature_2m_min || [])[i] || 0),
                    emoji:          di[0],
                    condition:      di[1],
                    prec_prob:      (daily.precipitation_probability_max || [])[i] || 0,
                    wind_speed_max: (daily.wind_speed_10m_max || [])[i] || 0,
                    wind_dir_dom:   windDegToCompass((daily.wind_direction_10m_dominant || [])[i] || 0)
                })
            }
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
                temp:           Math.round((hourly.temperature_2m || [])[j] || 0),
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
