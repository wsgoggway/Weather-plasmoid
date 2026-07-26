import QtQuick 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15
import org.kde.plasma.components 3.0 as PlasmaComponents
import org.kde.plasma.plasmoid 2.0
import org.kde.kirigami 2.20 as Kirigami

/*
 * Full representation — dark-glass card matching new_template.html.
 * Layout: glass background fills the whole popup (sibling of the Flickable,
 * so there is no gap when content is shorter than the popup); Kirigami.Theme
 * is set on the root so all Plasma controls render light-on-dark.
 * Sections: location header (big thin temp + feels-like right + italic quip),
 * 3×2 metrics grid, hourly forecast (horizontal), divider, daily forecast
 * (vertical rows with gradient temp-bars), and an optional "Сегодня" block.
 */
Item {
    id: fullRoot

    required property PlasmoidItem plasmoidItem

    Layout.minimumWidth: Kirigami.Units.gridUnit * 20
    Layout.minimumHeight: Kirigami.Units.gridUnit * 22
    Layout.preferredWidth: Kirigami.Units.gridUnit * 25
    Layout.preferredHeight: Kirigami.Units.gridUnit * 34

    property bool showLoading: !plasmoidItem || plasmoidItem._loading
    property bool showError: plasmoidItem ? plasmoidItem._errorMessage.length > 0 : false
    property bool showContent: plasmoidItem && !plasmoidItem._loading && !showError

    // ── dark-glass palette (from new_template.html) ─────────────────────────
    readonly property color textColor: "#ffffff"
    readonly property color subtleColor: Qt.rgba(1, 1, 1, 0.6)
    readonly property color glassColor: Qt.rgba(30/255, 30/255, 40/255, 0.85)
    readonly property color cardColor: Qt.rgba(1, 1, 1, 0.05)
    readonly property color dividerColor: Qt.rgba(1, 1, 1, 0.1)
    readonly property color accentColor: "#3daee9"
    readonly property color barCold: "#4fc3f7"
    readonly property color barWarm: "#ffb74d"
    readonly property color negColor: "#ef4f4f"
    readonly property int pad: Kirigami.Units.gridUnit * 1.4

    // Plasma/Kirigami controls inside render light-on-dark (inherited by all descendants)
    Kirigami.Theme.textColor: fullRoot.textColor
    Kirigami.Theme.disabledTextColor: fullRoot.subtleColor
    Kirigami.Theme.backgroundColor: "#1e1e28"
    Kirigami.Theme.highlightColor: fullRoot.accentColor

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
        radius: Kirigami.Units.gridUnit * 0.9
        border.color: fullRoot.dividerColor
        border.width: 1
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
                                if (lat) plasmoidItem.writeLocation(lat, lon, name, tz)
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

            // ── Error ───────────────────────────────────────────────────
            ColumnLayout {
                Layout.fillWidth: true
                Layout.topMargin: Kirigami.Units.gridUnit * 3
                visible: fullRoot.showError
                spacing: Kirigami.Units.smallSpacing
                PlasmaComponents.Label {
                    Layout.alignment: Qt.AlignHCenter
                    text: "⚠️ " + (plasmoidItem ? (plasmoidItem._errorMessage || "") : "")
                    color: fullRoot.negColor
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                    Layout.fillWidth: true
                }
                PlasmaComponents.Button {
                    text: "Повторить"; icon.name: "view-refresh"
                    Layout.alignment: Qt.AlignHCenter
                    onClicked: { if (plasmoidItem) plasmoidItem.fetchWeather() }
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
                        font.pixelSize: Kirigami.Units.gridUnit * 4.2
                        Layout.alignment: Qt.AlignVCenter
                    }
                    PlasmaComponents.Label {
                        text: plasmoidItem
                            ? (plasmoidItem._currentTemp + plasmoidItem._tempUnitLabel)
                            : "--°"
                        font.pixelSize: Kirigami.Units.gridUnit * 3.3
                        font.weight: Font.Light
                        color: fullRoot.textColor
                        Layout.alignment: Qt.AlignVCenter
                    }
                    Item { Layout.fillWidth: true }
                    ColumnLayout {
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

            // ── Metrics grid (3×2) ──────────────────────────────────────
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
                    columns: 3
                    rowSpacing: Kirigami.Units.gridUnit * 0.7
                    columnSpacing: Kirigami.Units.gridUnit * 0.7

                    Repeater {
                        model: [
                            { l: "Ветер",     v: plasmoidItem ? (plasmoidItem._currentWindSpeed + plasmoidItem._windUnitLabel + " " + (plasmoidItem._currentWindDir||"")) : "--" },
                            { l: "Влажность", v: plasmoidItem ? (plasmoidItem._currentHumidity + "%") : "--" },
                            { l: "Давление",  v: plasmoidItem ? (plasmoidItem._currentPressure + " мм") : "--" },
                            { l: "Осадки",    v: plasmoidItem ? (plasmoidItem._precipSum + " мм") : "--" },
                            { l: "УФ-индекс", v: plasmoidItem ? plasmoidItem.uvText(plasmoidItem._uvIndex) : "--" },
                            { l: "Солнце",    v: fullRoot.sunText() }
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

            // ── Hourly forecast ─────────────────────────────────────────
            ColumnLayout {
                Layout.fillWidth: true
                visible: fullRoot.showContent && fullRoot.showHourly()
                         && plasmoidItem && plasmoidItem._hourlyForecasts.length > 0
                spacing: Kirigami.Units.gridUnit * 0.6

                PlasmaComponents.Label {
                    text: "Почасовой прогноз"
                    font.pixelSize: Kirigami.Units.gridUnit * 0.85
                    color: fullRoot.subtleColor
                }
                ListView {
                    id: hourlyList
                    Layout.fillWidth: true
                    orientation: ListView.Horizontal
                    spacing: Kirigami.Units.gridUnit
                    implicitHeight: Kirigami.Units.gridUnit * 5.6
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
                        // temp bar
                        Item {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            implicitHeight: 6
                            Rectangle {
                                anchors.fill: parent
                                color: Qt.rgba(1, 1, 1, 0.1)
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

            // ── Optional "Сегодня" (holidays + this day in history) ─────
            ColumnLayout {
                Layout.fillWidth: true
                visible: fullRoot.showContent && plasmoidItem &&
                         (plasmoidItem._holidaysText.length > 0 || plasmoidItem._historyEvents.length > 0)
                spacing: Kirigami.Units.smallSpacing

                Rectangle { Layout.fillWidth: true; height: 1; color: fullRoot.dividerColor }

                PlasmaComponents.Label {
                    text: "Сегодня"
                    font.pixelSize: Kirigami.Units.gridUnit * 0.85
                    color: fullRoot.subtleColor
                }
                PlasmaComponents.Label {
                    text: plasmoidItem ? plasmoidItem._holidaysText : ""
                    visible: plasmoidItem && plasmoidItem._holidaysText.length > 0
                    font.pixelSize: Kirigami.Units.gridUnit * 0.9
                    font.weight: Font.Medium
                    color: fullRoot.accentColor
                    wrapMode: Text.WordWrap
                    Layout.fillWidth: true
                }
                Repeater {
                    model: plasmoidItem ? plasmoidItem._historyEvents : []
                    PlasmaComponents.Label {
                        Layout.fillWidth: true
                        property string _url: modelData.url || ""
                        text: "📜 " + (modelData.year || "?") + ": " + (modelData.text || "")
                              + (_url.length ? "  ↗" : "")
                        font.pixelSize: Kirigami.Units.gridUnit * 0.78
                        color: histMa.containsMouse ? fullRoot.accentColor : fullRoot.subtleColor
                        wrapMode: Text.WordWrap
                        elide: Text.ElideRight
                        maximumLineCount: 2
                        MouseArea {
                            id: histMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: parent._url.length ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: if (parent._url.length) Qt.openUrlExternally(parent._url)
                        }
                    }
                }
            }

            // bottom breathing room
            Item { Layout.fillWidth: true; height: 1 }
        }
    }
}
