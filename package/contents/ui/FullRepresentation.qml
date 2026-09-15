import QtQuick 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15
import org.kde.plasma.components 3.0 as PlasmaComponents
import org.kde.plasma.plasmoid 2.0
import org.kde.plasma.core 2.0 as PlasmaCore
import org.kde.plasma.extras 2.0 as PlasmaExtras
import org.kde.kirigami 2.20 as Kirigami

/*
 * Full representation — dark-glass, full-bleed. Root is PlasmaExtras.Representation
 * with collapseMarginsHint so the glass fills the whole popup platter (no
 * external Plasma margins). Kirigami.Theme is set on the root so all Plasma
 * controls render light-on-dark.
 * Sections: location header (big thin temp + feels-like right + italic quip),
 * 3×2 metrics grid, hourly forecast (horizontal), divider, daily forecast
 * (vertical rows with gradient temp-bars).
 */
PlasmaExtras.Representation {
    id: fullRoot

    required property PlasmoidItem plasmoidItem

    // ── form-factor / size adaptivity ────────────────────────────────────────
    // Desktop widgets (Planar) embed this view inline and are freely resizable;
    // panel popups get a fixed tall size. The `narrow` breakpoint reflows the
    // layout: 2 instead of 3 metric columns, smaller header type, tighter pad.
    readonly property bool planar: Plasmoid.formFactor === PlasmaCore.Types.Planar
    readonly property bool narrow: width < Kirigami.Units.gridUnit * 23

    // Full-bleed: collapse the popup's content margins/borders; no Page padding,
    // so the glass background fills the entire platter edge to edge.
    collapseMarginsHint: true
    padding: 0

    Layout.minimumWidth: Kirigami.Units.gridUnit * (planar ? 12 : 20)
    Layout.minimumHeight: Kirigami.Units.gridUnit * (planar ? 8 : 16)
    Layout.preferredWidth: Kirigami.Units.gridUnit * (planar ? 24 : 25)
    // Plasma 6 caches the popup size after first open and does not reliably
    // re-size to dynamic content, so request a tall popup — Plasma clamps it
    // to the available screen height. Typical content (7-day forecast) then
    // fits with little/no scroll; the Flickable handles overflow and reaches
    // the last day. (User can also resize manually; Plasma persists it.)
    // On the desktop the 60gu popup height would be absurd — start compact;
    // the user resizes from there and Plasma persists the choice.
    Layout.preferredHeight: Kirigami.Units.gridUnit * (planar ? 16 : 60)

    property bool showLoading: !plasmoidItem || plasmoidItem._loading
    property bool showError: plasmoidItem ? plasmoidItem._errorMessage.length > 0 : false
    property bool showContent: plasmoidItem && !plasmoidItem._loading && !showError

    // ── theme-aware palette (follows the system light/dark theme) ───────────
    readonly property color textColor: Kirigami.Theme.textColor
    readonly property color subtleColor: Kirigami.Theme.disabledTextColor
    readonly property color glassColor: Kirigami.Theme.backgroundColor
    readonly property color cardColor: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.07)
    readonly property color dividerColor: Qt.rgba(Kirigami.Theme.textColor.r, Kirigami.Theme.textColor.g, Kirigami.Theme.textColor.b, 0.12)
    readonly property color accentColor: Kirigami.Theme.highlightColor
    readonly property color barCold: "#4fc3f7"
    readonly property color barWarm: "#ffb74d"
    property color negColor: Kirigami.Theme.negativeTextColor
    readonly property int pad: Kirigami.Units.gridUnit * (narrow ? 0.9 : 1.4)

    // AQI dot: theme colors only — green/amber/red by pollution level
    readonly property color aqiDotColor: {
        if (!plasmoidItem || plasmoidItem._aqiLevel < 0) return fullRoot.subtleColor
        if (plasmoidItem._aqiLevel === 0) return Kirigami.Theme.positiveTextColor
        if (plasmoidItem._aqiLevel === 1) return Kirigami.Theme.neutralTextColor
        return Kirigami.Theme.negativeTextColor
    }

    function forecastMode() { return plasmoid.configuration.forecastMode || "daily" }
    function showDaily()  { return forecastMode() === "daily"  || forecastMode() === "both" }
    function showHourly() { return forecastMode() === "hourly" || forecastMode() === "both" }

    function sunText() {
        if (!plasmoidItem) return "--:–"
        return (plasmoidItem._sunrise || "--:--") + " – " + (plasmoidItem._sunset || "--:--")
    }

    // weekday from ISO date (timezone-safe, Sakamoto); index 0 → "Сегодня"
    function dayLabel(dateStr, idx) {
        if (idx === 0) return "Сегодня"
        if (!dateStr) return ""
        var p = dateStr.substring(0, 10).split("-")
        if (p.length < 3) return ""
        var y = +p[0], m = +p[1], d = +p[2]
        var tm = [0, 3, 2, 5, 0, 3, 5, 1, 4, 6, 2, 4]
        var yy = m < 3 ? y - 1 : y
        var wd = (yy + Math.floor(yy/4) - Math.floor(yy/100) + Math.floor(yy/400) + tm[m-1] + d) % 7
        return ["Вс","Пн","Вт","Ср","Чт","Пт","Сб"][wd]
    }

    // week-wide min/max → positions the daily temp-bars
    readonly property var _fc: plasmoidItem ? plasmoidItem._forecasts : []
    readonly property real weekMin: {
        if (!_fc.length) return 0
        var m = _fc[0].temp_min
        for (var i = 1; i < _fc.length; i++) if (_fc[i].temp_min < m) m = _fc[i].temp_min
        return m
    }
    readonly property real weekMax: {
        if (!_fc.length) return 1
        var m = _fc[0].temp_max
        for (var i = 1; i < _fc.length; i++) if (_fc[i].temp_max > m) m = _fc[i].temp_max
        return m
    }

    // ── glass background fills the entire popup (no gap below content) ───────
    Rectangle {
        id: glassBg
        anchors.fill: parent
        color: fullRoot.glassColor
        radius: 0
    }

    Flickable {
        anchors.fill: parent
        contentWidth: width
        contentHeight: contentCol.implicitHeight + fullRoot.pad * 2
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: contentCol
            x: fullRoot.pad
            y: fullRoot.pad
            width: parent.width - fullRoot.pad * 2
            spacing: Kirigami.Units.gridUnit * 1.2

            // ── Location + actions ──────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing
                PlasmaComponents.Label {
                    text: (plasmoid.configuration.cityName || "Погода")
                    font.pixelSize: Kirigami.Units.gridUnit * 1.15
                    font.weight: Font.Medium
                    color: fullRoot.textColor
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
                PlasmaComponents.ToolButton {
                    icon.name: "search"
                    onClicked: {
                        var city = plasmoid.configuration.cityName
                        if (city && plasmoidItem)
                            plasmoidItem.geocodeCity(city, function(lat, lon, name, tz) {
                                if (lat != null && lon != null)
                                    plasmoidItem.writeLocation(lat, lon, name, tz)
                                else if (plasmoidItem)
                                    plasmoidItem.showNotice("✗ Город не найден")
                            })
                    }
                    PlasmaComponents.ToolTip { text: "Найти координаты по городу" }
                }
                PlasmaComponents.ToolButton {
                    icon.name: "find-location"
                    onClicked: { if (plasmoidItem) plasmoidItem.detectLocation() }
                    PlasmaComponents.ToolTip { text: "Определить по IP" }
                }
                PlasmaComponents.ToolButton {
                    icon.name: "view-refresh"
                    onClicked: { if (plasmoidItem) plasmoidItem.fetchWeather() }
                    PlasmaComponents.ToolTip { text: "Обновить" }
                }
            }

            // ── Transient notice (geocode / IP-detect feedback) ─────────
            PlasmaComponents.Label {
                Layout.fillWidth: true
                visible: plasmoidItem && plasmoidItem._noticeText.length > 0
                text: plasmoidItem ? plasmoidItem._noticeText : ""
                color: fullRoot.negColor
                font.pixelSize: Kirigami.Units.gridUnit * 0.78
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
            }

            // ── Loading ─────────────────────────────────────────────────
            PlasmaComponents.BusyIndicator {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: Kirigami.Units.gridUnit * 3
                running: fullRoot.showLoading
                visible: fullRoot.showLoading
            }
            PlasmaComponents.Label {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: Kirigami.Units.gridUnit
                visible: fullRoot.showLoading
                text: "Загрузка погоды…"
                color: fullRoot.subtleColor
            }

            // ── Error — standard Plasma empty-state message ─────────────
            PlasmaExtras.PlaceholderMessage {
                Layout.fillWidth: true
                Layout.topMargin: Kirigami.Units.gridUnit * 3
                visible: fullRoot.showError
                iconName: "weather-storm"
                text: "Не удалось загрузить погоду"
                explanation: plasmoidItem ? (plasmoidItem._errorMessage || "") : ""
                helpfulAction: Action {
                    icon.name: "view-refresh"
                    text: "Повторить"
                    onTriggered: { if (plasmoidItem) plasmoidItem.fetchWeather() }
                }
            }

            // ── Current weather (header) ────────────────────────────────
            ColumnLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.gridUnit * 0.6
                visible: fullRoot.showContent

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.gridUnit

                    PlasmaComponents.Label {
                        text: plasmoidItem ? (plasmoidItem._currentEmoji || "🌈") : "🌈"
                        font.pixelSize: Kirigami.Units.gridUnit * (fullRoot.narrow ? 3.4 : 4.2)
                        Layout.alignment: Qt.AlignVCenter
                    }
                    ColumnLayout {
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 0
                        PlasmaComponents.Label {
                            text: plasmoidItem
                                ? (plasmoidItem._currentTemp + plasmoidItem._tempUnitLabel)
                                : "--°"
                            font.pixelSize: Kirigami.Units.gridUnit * (fullRoot.narrow ? 2.6 : 3.3)
                            font.weight: Font.Light
                            color: fullRoot.textColor
                        }
                        PlasmaComponents.Label {
                            text: plasmoidItem ? (plasmoidItem._currentConditionRu || "") : ""
                            font.pixelSize: Kirigami.Units.gridUnit * 0.9
                            color: fullRoot.subtleColor
                            visible: text.length > 0
                        }
                    }
                    Item { Layout.fillWidth: true }
                    ColumnLayout {
                        id: feelsCol
                        // very narrow widget — "feels like" already sits in the tooltip
                        visible: fullRoot.width >= Kirigami.Units.gridUnit * 17
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 0
                        PlasmaComponents.Label {
                            Layout.fillWidth: true
                            text: "Ощущается как"
                            font.pixelSize: Kirigami.Units.gridUnit * 0.8
                            color: fullRoot.subtleColor
                            horizontalAlignment: Text.AlignRight
                        }
                        PlasmaComponents.Label {
                            Layout.fillWidth: true
                            text: plasmoidItem
                                ? (plasmoidItem._currentFeelsLike + plasmoidItem._tempUnitLabel)
                                : "--°"
                            font.pixelSize: Kirigami.Units.gridUnit * 0.8
                            color: fullRoot.subtleColor
                            horizontalAlignment: Text.AlignRight
                        }
                    }
                }

                PlasmaComponents.Label {
                    Layout.fillWidth: true
                    text: plasmoidItem ? (plasmoidItem._feelsJokeText || "") : ""
                    font.pixelSize: Kirigami.Units.gridUnit * 0.88
                    font.italic: true
                    color: fullRoot.subtleColor
                    wrapMode: Text.WordWrap
                    visible: text.length > 0
                }
            }

            // ── Metrics grid (3×3) ──────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                visible: fullRoot.showContent
                color: fullRoot.cardColor
                radius: Kirigami.Units.gridUnit * 0.75
                implicitHeight: metricsGrid.implicitHeight + Kirigami.Units.gridUnit * 1.8

                GridLayout {
                    id: metricsGrid
                    anchors.fill: parent
                    anchors.margins: Kirigami.Units.gridUnit * 0.9
                    // reflow: 2 columns when the widget is narrow (desktop resize)
                    columns: fullRoot.narrow ? 2 : 3
                    rowSpacing: Kirigami.Units.gridUnit * 0.7
                    columnSpacing: Kirigami.Units.gridUnit * 0.7

                    Repeater {
                        model: [
                            { l: "💨 Ветер",      v: plasmoidItem ? (plasmoidItem._currentWindSpeed + plasmoidItem._windUnitLabel + " " + (plasmoidItem._currentWindDir||"")) : "--" },
                            { l: "🌬 Порывы",     v: plasmoidItem ? (plasmoidItem._currentGusts + plasmoidItem._windUnitLabel) : "--" },
                            { l: "💦 Точка росы", v: plasmoidItem ? (plasmoidItem._currentDewPoint + plasmoidItem._tempUnitLabel) : "--" },
                            { l: "💧 Влажность",  v: plasmoidItem ? (plasmoidItem._currentHumidity + "%") : "--" },
                            { l: "🧭 Давление",   v: plasmoidItem ? (plasmoidItem._currentPressure + " мм") : "--" },
                            { l: "☁️ Облачность", v: plasmoidItem ? (plasmoidItem._currentCloudCover + "%") : "--" },
                            { l: "🌧 Осадки",     v: plasmoidItem ? (plasmoidItem._precipSum + " мм") : "--" },
                            { l: "☀️ УФ-индекс",  v: plasmoidItem ? plasmoidItem.uvText(plasmoidItem._uvIndex) : "--" },
                            { l: "🌅 Солнце",     v: fullRoot.sunText() }
                        ]
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            PlasmaComponents.Label {
                                text: modelData.l
                                font.pixelSize: Kirigami.Units.gridUnit * 0.72
                                color: fullRoot.subtleColor
                            }
                            PlasmaComponents.Label {
                                text: modelData.v
                                font.pixelSize: Kirigami.Units.gridUnit * 0.92
                                font.weight: Font.Medium
                                color: fullRoot.textColor
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }
                    }
                }
            }

            // ── Air quality card (hidden until Air Quality API answers) ─
            Rectangle {
                Layout.fillWidth: true
                visible: fullRoot.showContent && plasmoidItem && plasmoidItem._aqiText.length > 0
                color: fullRoot.cardColor
                radius: Kirigami.Units.gridUnit * 0.75
                implicitHeight: aqiRow.implicitHeight + Kirigami.Units.gridUnit * 1.2

                RowLayout {
                    id: aqiRow
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.margins: Kirigami.Units.gridUnit * 0.9
                    spacing: Kirigami.Units.smallSpacing

                    Rectangle {
                        Layout.alignment: Qt.AlignVCenter
                        implicitWidth: Kirigami.Units.gridUnit * 0.55
                        implicitHeight: implicitWidth
                        radius: implicitWidth / 2
                        color: fullRoot.aqiDotColor
                    }
                    PlasmaComponents.Label {
                        text: "🌫 Качество воздуха"
                        font.pixelSize: Kirigami.Units.gridUnit * 0.72
                        color: fullRoot.subtleColor
                    }
                    Item { Layout.fillWidth: true }
                    PlasmaComponents.Label {
                        text: plasmoidItem ? plasmoidItem._aqiText : ""
                        font.pixelSize: Kirigami.Units.gridUnit * 0.92
                        font.weight: Font.Medium
                        color: fullRoot.textColor
                    }
                }
            }

            // ── Hourly forecast ─────────────────────────────────────────
            ColumnLayout {
                Layout.fillWidth: true
                visible: fullRoot.showContent && fullRoot.showHourly()
                         && plasmoidItem && plasmoidItem._hourlyForecasts.length > 0
                spacing: Kirigami.Units.gridUnit * 0.6

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.smallSpacing
                    PlasmaComponents.Label {
                        text: "Почасовой прогноз"
                        font.pixelSize: Kirigami.Units.gridUnit * 0.85
                        color: fullRoot.subtleColor
                    }
                    Item { Layout.fillWidth: true }
                    PlasmaComponents.Label {
                        // hint: the hourly row scrolls sideways (only when it overflows)
                        visible: hourlyList.contentWidth > hourlyList.width
                        text: "листай →"
                        font.pixelSize: Kirigami.Units.gridUnit * 0.72
                        font.italic: true
                        color: fullRoot.subtleColor
                    }
                }
                ListView {
                    id: hourlyList
                    Layout.fillWidth: true
                    orientation: ListView.Horizontal
                    spacing: Kirigami.Units.gridUnit
                    implicitHeight: Kirigami.Units.gridUnit * 6.8
                    clip: true
                    interactive: contentWidth > width
                    boundsBehavior: Flickable.StopAtBounds

                    model: plasmoidItem ? plasmoidItem._hourlyForecasts : []
                    delegate: ForecastItem {
                        width: Kirigami.Units.gridUnit * 3.4
                        height: hourlyList.height
                        forecastData: modelData
                        appletRef: plasmoidItem
                        isFirst: index === 0
                    }
                }
            }

            // ── Divider ─────────────────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                visible: fullRoot.showContent && fullRoot.showDaily()
                         && plasmoidItem && plasmoidItem._forecasts.length > 1
                height: 1
                color: fullRoot.dividerColor
            }

            // ── Daily forecast (vertical rows + temp bars) ──────────────
            ColumnLayout {
                Layout.fillWidth: true
                visible: fullRoot.showContent && fullRoot.showDaily()
                         && plasmoidItem && plasmoidItem._forecasts.length > 0
                spacing: Kirigami.Units.gridUnit * 0.55

                PlasmaComponents.Label {
                    text: "Прогноз по дням"
                    font.pixelSize: Kirigami.Units.gridUnit * 0.85
                    color: fullRoot.subtleColor
                }

                Repeater {
                    model: plasmoidItem ? plasmoidItem._forecasts : []
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Kirigami.Units.gridUnit * 0.8

                        PlasmaComponents.Label {
                            Layout.preferredWidth: Kirigami.Units.gridUnit * 4
                            text: fullRoot.dayLabel(modelData.date, index)
                            color: fullRoot.textColor
                            font.pixelSize: Kirigami.Units.gridUnit * 0.92
                        }
                        PlasmaComponents.Label {
                            Layout.preferredWidth: Kirigami.Units.gridUnit * 1.8
                            text: modelData.emoji
                            font.pixelSize: Kirigami.Units.gridUnit * 1.35
                            horizontalAlignment: Text.AlignHCenter
                        }
                        PlasmaComponents.Label {
                            Layout.preferredWidth: Kirigami.Units.gridUnit * 2.4
                            // too narrow to afford the column — emoji + bar remain
                            visible: fullRoot.width >= Kirigami.Units.gridUnit * 19
                            text: "💧" + (modelData.prec_prob || 0) + "%"
                            color: modelData.prec_prob >= 40 ? fullRoot.textColor : fullRoot.subtleColor
                            font.pixelSize: Kirigami.Units.gridUnit * 0.72
                        }
                        // temp bar
                        Item {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            implicitHeight: 6
                            Rectangle {
                                anchors.fill: parent
                                color: fullRoot.dividerColor
                                radius: 3
                            }
                            Rectangle {
                                property real rng: Math.max(1, fullRoot.weekMax - fullRoot.weekMin)
                                x: parent.width * Math.max(0, (modelData.temp_min - fullRoot.weekMin) / rng)
                                width: parent.width * Math.max(0.03, (modelData.temp_max - modelData.temp_min) / rng)
                                height: parent.height
                                radius: 3
                                gradient: Gradient {
                                    orientation: Gradient.Horizontal
                                    GradientStop { position: 0.0; color: fullRoot.barCold }
                                    GradientStop { position: 1.0; color: fullRoot.barWarm }
                                }
                            }
                        }
                        PlasmaComponents.Label {
                            Layout.preferredWidth: Kirigami.Units.gridUnit * 2.3
                            text: (modelData.temp_min || 0) + "°"
                            color: fullRoot.subtleColor
                            font.pixelSize: Kirigami.Units.gridUnit * 0.92
                            horizontalAlignment: Text.AlignRight
                        }
                        PlasmaComponents.Label {
                            Layout.preferredWidth: Kirigami.Units.gridUnit * 2.3
                            text: (modelData.temp_max || 0) + "°"
                            color: fullRoot.textColor
                            font.pixelSize: Kirigami.Units.gridUnit * 0.92
                            font.weight: Font.DemiBold
                            horizontalAlignment: Text.AlignRight
                        }
                    }
                }
            }

            // ── Last successful update ───────────────────────────────────
            PlasmaComponents.Label {
                Layout.alignment: Qt.AlignHCenter
                visible: fullRoot.showContent && plasmoidItem && plasmoidItem._lastUpdate.length > 0
                text: "Обновлено в " + plasmoidItem._lastUpdate
                color: fullRoot.subtleColor
                font.pixelSize: Kirigami.Units.gridUnit * 0.72
            }

            // bottom breathing room
            Item { Layout.fillWidth: true; height: 1 }
        }
    }
}
