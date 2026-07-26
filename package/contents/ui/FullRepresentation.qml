import QtQuick 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15
import org.kde.plasma.components 3.0 as PlasmaComponents
import org.kde.plasma.extras 2.0 as PlasmaExtras
import org.kde.kirigami 2.20 as Kirigami
import org.kde.plasma.plasmoid 2.0

/*
 * Full representation — popup / desktop.
 * Card-based layout: centered hero (temp + feels-like quip), conditions grid,
 * day-metrics strip (sunrise/sunset/UV/precip), "today" card (holidays +
 * this day in history), and forecast.
 * plasmoidItem is set by PlasmoidItem automatically (official Plasma 6 API).
 */
Item {
    id: fullRoot

    required property PlasmoidItem plasmoidItem

    Layout.minimumWidth: Kirigami.Units.gridUnit * 19
    Layout.minimumHeight: Kirigami.Units.gridUnit * 22
    Layout.preferredWidth: Kirigami.Units.gridUnit * 25
    Layout.preferredHeight: Kirigami.Units.gridUnit * 34

    property bool showLoading: !plasmoidItem || plasmoidItem._loading
    property bool showError: plasmoidItem ? plasmoidItem._errorMessage.length > 0 : false
    property bool showContent: plasmoidItem && !plasmoidItem._loading && !showError
    property int forecastTab: 0

    // theme-aware styling
    readonly property color cardColor: Kirigami.Theme.alternateBackgroundColor
    readonly property color mutedColor: Kirigami.Theme.disabledTextColor
    readonly property color accentColor: Kirigami.Theme.highlightColor
    readonly property color negColor: Kirigami.Theme.negativeTextColor
    readonly property int cardRadius: Math.round(Kirigami.Units.largeSpacing * 0.8)
    readonly property int hPad: Kirigami.Units.gridUnit
    readonly property int cardPad: Math.round(Kirigami.Units.largeSpacing * 0.8)

    function forecastMode() { return plasmoid.configuration.forecastMode || "daily" }
    function showDaily()  { return forecastMode() === "daily"  || forecastMode() === "both" }
    function showHourly() { return forecastMode() === "hourly" || forecastMode() === "both" }

    // ── Reusable centered hero / detail helpers via components ──────────────
    function precipText() {
        if (!plasmoidItem) return "--"
        return plasmoidItem._precipSum + " мм"
    }

    Flickable {
        anchors.fill: parent
        contentWidth: width
        contentHeight: mainColumn.implicitHeight + Kirigami.Units.largeSpacing
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: mainColumn
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: Kirigami.Units.largeSpacing
            spacing: Kirigami.Units.largeSpacing

            // ── Header ────────────────────────────────────────────────────
            RowLayout {
                Layout.fillWidth: true
                spacing: Kirigami.Units.smallSpacing

                PlasmaComponents.Label {
                    text: "📍 " + (plasmoid.configuration.cityName || "Погода")
                    font.pixelSize: Kirigami.Units.gridUnit * 1.25
                    font.bold: true
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }
                PlasmaComponents.Label {
                    text: plasmoidItem && plasmoidItem._lastUpdate
                          ? "обновлено " + plasmoidItem._lastUpdate : ""
                    font.pixelSize: Kirigami.Units.gridUnit * 0.72
                    color: fullRoot.mutedColor
                    visible: text.length > 0
                    Layout.rightMargin: Kirigami.Units.smallSpacing
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
                    PlasmaComponents.ToolTip { text: "Найти координаты по названию города" }
                }
                PlasmaComponents.ToolButton {
                    icon.name: "find-location"
                    onClicked: { if (plasmoidItem) plasmoidItem.detectLocation() }
                    PlasmaComponents.ToolTip { text: "Определить местоположение по IP" }
                }
                PlasmaComponents.ToolButton {
                    icon.name: "view-refresh"
                    onClicked: { if (plasmoidItem) plasmoidItem.fetchWeather() }
                    PlasmaComponents.ToolTip { text: "Обновить" }
                }
            }

            // ── Loading ───────────────────────────────────────────────────
            PlasmaComponents.BusyIndicator {
                Layout.alignment: Qt.AlignCenter
                Layout.topMargin: Kirigami.Units.gridUnit * 3
                running: fullRoot.showLoading
                visible: fullRoot.showLoading
            }
            PlasmaComponents.Label {
                visible: fullRoot.showLoading
                Layout.alignment: Qt.AlignHCenter
                text: "Загрузка погоды…"
                color: fullRoot.mutedColor
            }

            // ── Error card ────────────────────────────────────────────────
            Rectangle {
                Layout.fillWidth: true
                visible: fullRoot.showError
                color: fullRoot.cardColor
                radius: fullRoot.cardRadius
                implicitHeight: errCol.implicitHeight + Kirigami.Units.gridUnit * 1.6
                ColumnLayout {
                    id: errCol
                    anchors.fill: parent
                    anchors.margins: fullRoot.hPad * 0.8
                    spacing: Kirigami.Units.smallSpacing
                    PlasmaComponents.Label {
                        text: "⚠️"; font.pixelSize: Kirigami.Units.gridUnit * 2
                        Layout.alignment: Qt.AlignHCenter
                    }
                    PlasmaComponents.Label {
                        text: plasmoidItem ? (plasmoidItem._errorMessage || "") : ""
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
            }

            // ── Hero card (CENTERED): emoji + temp + condition + quip ──────
            Rectangle {
                id: heroCard
                Layout.fillWidth: true
                visible: fullRoot.showContent
                color: fullRoot.cardColor
                radius: fullRoot.cardRadius
                implicitHeight: heroCol.implicitHeight + Kirigami.Units.gridUnit * 2.5

                ColumnLayout {
                    id: heroCol
                    anchors.fill: parent
                    anchors.margins: fullRoot.hPad
                    spacing: Kirigami.Units.smallSpacing * 0.6

                    PlasmaComponents.Label {
                        Layout.alignment: Qt.AlignHCenter
                        text: plasmoidItem ? (plasmoidItem._currentEmoji || "🌈") : "🌈"
                        font.pixelSize: Kirigami.Units.gridUnit * 4.5
                    }
                    PlasmaComponents.Label {
                        Layout.alignment: Qt.AlignHCenter
                        text: plasmoidItem
                            ? (plasmoidItem._currentTemp + plasmoidItem._tempUnitLabel)
                            : "--°"
                        font.pixelSize: Kirigami.Units.gridUnit * 3.4
                        font.bold: true
                    }
                    PlasmaComponents.Label {
                        Layout.alignment: Qt.AlignHCenter
                        text: plasmoidItem ? (plasmoidItem._currentConditionRu || "") : ""
                        font.pixelSize: Kirigami.Units.gridUnit * 1.1
                        color: fullRoot.mutedColor
                    }
                    PlasmaComponents.Label {
                        Layout.alignment: Qt.AlignHCenter
                        text: plasmoidItem
                            ? "ощущается " + plasmoidItem._currentFeelsLike + plasmoidItem._tempUnitLabel
                            : ""
                        font.pixelSize: Kirigami.Units.gridUnit * 0.85
                        color: fullRoot.mutedColor
                    }
                    PlasmaComponents.Label {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.fillWidth: true
                        Layout.topMargin: Kirigami.Units.smallSpacing
                        text: plasmoidItem ? (plasmoidItem._feelsJokeText || "") : ""
                        font.pixelSize: Kirigami.Units.gridUnit * 0.82
                        font.italic: true
                        color: fullRoot.accentColor
                        horizontalAlignment: Text.AlignHCenter
                        wrapMode: Text.WordWrap
                        visible: text.length > 0
                    }
                }
            }

            // ── Current conditions grid (2×2) ─────────────────────────────
            GridLayout {
                Layout.fillWidth: true
                visible: fullRoot.showContent
                columns: 2
                rowSpacing: Kirigami.Units.smallSpacing
                columnSpacing: Kirigami.Units.smallSpacing

                Rectangle { // Wind
                    Layout.fillWidth: true
                    color: fullRoot.cardColor; radius: fullRoot.cardRadius
                    implicitHeight: windRow.implicitHeight + Kirigami.Units.largeSpacing
                    RowLayout {
                        id: windRow
                        anchors.fill: parent; anchors.margins: fullRoot.cardPad
                        PlasmaComponents.Label { text: "💨"; font.pixelSize: Kirigami.Units.gridUnit * 1.5 }
                        ColumnLayout {
                            spacing: 0
                            PlasmaComponents.Label { text: "Ветер"; font.pixelSize: Kirigami.Units.gridUnit * 0.72; color: fullRoot.mutedColor }
                            PlasmaComponents.Label {
                                text: plasmoidItem
                                    ? (plasmoidItem._currentWindSpeed + plasmoidItem._windUnitLabel +
                                       " " + (plasmoidItem._currentWindDir || ""))
                                    : "--"
                                font.bold: true
                            }
                        }
                        Item { Layout.fillWidth: true }
                    }
                }

                Rectangle { // Humidity
                    Layout.fillWidth: true
                    color: fullRoot.cardColor; radius: fullRoot.cardRadius
                    implicitHeight: humRow.implicitHeight + Kirigami.Units.largeSpacing
                    RowLayout {
                        id: humRow
                        anchors.fill: parent; anchors.margins: fullRoot.cardPad
                        PlasmaComponents.Label { text: "💧"; font.pixelSize: Kirigami.Units.gridUnit * 1.5 }
                        ColumnLayout {
                            spacing: 0
                            PlasmaComponents.Label { text: "Влажность"; font.pixelSize: Kirigami.Units.gridUnit * 0.72; color: fullRoot.mutedColor }
                            PlasmaComponents.Label {
                                text: plasmoidItem ? (plasmoidItem._currentHumidity + "%") : "--"
                                font.bold: true
                            }
                        }
                        Item { Layout.fillWidth: true }
                    }
                }

                Rectangle { // Pressure
                    Layout.fillWidth: true
                    color: fullRoot.cardColor; radius: fullRoot.cardRadius
                    implicitHeight: presRow.implicitHeight + Kirigami.Units.largeSpacing
                    RowLayout {
                        id: presRow
                        anchors.fill: parent; anchors.margins: fullRoot.cardPad
                        PlasmaComponents.Label { text: "🧭"; font.pixelSize: Kirigami.Units.gridUnit * 1.5 }
                        ColumnLayout {
                            spacing: 0
                            PlasmaComponents.Label { text: "Давление"; font.pixelSize: Kirigami.Units.gridUnit * 0.72; color: fullRoot.mutedColor }
                            PlasmaComponents.Label {
                                text: plasmoidItem ? (plasmoidItem._currentPressure + " мм рт.ст.") : "--"
                                font.bold: true
                            }
                        }
                        Item { Layout.fillWidth: true }
                    }
                }

                Rectangle { // Cloud cover
                    Layout.fillWidth: true
                    color: fullRoot.cardColor; radius: fullRoot.cardRadius
                    implicitHeight: cloudRow.implicitHeight + Kirigami.Units.largeSpacing
                    RowLayout {
                        id: cloudRow
                        anchors.fill: parent; anchors.margins: fullRoot.cardPad
                        PlasmaComponents.Label { text: "☁️"; font.pixelSize: Kirigami.Units.gridUnit * 1.5 }
                        ColumnLayout {
                            spacing: 0
                            PlasmaComponents.Label { text: "Облачность"; font.pixelSize: Kirigami.Units.gridUnit * 0.72; color: fullRoot.mutedColor }
                            PlasmaComponents.Label {
                                text: plasmoidItem
                                    ? ((plasmoidItem._currentCloudCover != null ? plasmoidItem._currentCloudCover : 0) + "%")
                                    : "--"
                                font.bold: true
                            }
                        }
                        Item { Layout.fillWidth: true }
                    }
                }
            }

            // ── Day metrics strip: sunrise / sunset / UV / precip ─────────
            RowLayout {
                id: dayStrip
                Layout.fillWidth: true
                visible: fullRoot.showContent
                spacing: Kirigami.Units.smallSpacing

                Rectangle { // Sunrise
                    Layout.fillWidth: true
                    color: fullRoot.cardColor; radius: fullRoot.cardRadius
                    implicitHeight: sunCol.implicitHeight + Kirigami.Units.largeSpacing
                    ColumnLayout {
                        id: sunCol
                        anchors.fill: parent; anchors.margins: fullRoot.cardPad
                        spacing: 0
                        PlasmaComponents.Label { Layout.alignment: Qt.AlignHCenter; text: "🌅"; font.pixelSize: Kirigami.Units.gridUnit * 1.4 }
                        PlasmaComponents.Label { Layout.alignment: Qt.AlignHCenter; text: "Восход"; font.pixelSize: Kirigami.Units.gridUnit * 0.65; color: fullRoot.mutedColor }
                        PlasmaComponents.Label { Layout.alignment: Qt.AlignHCenter; text: plasmoidItem ? plasmoidItem._sunrise : "--:--"; font.bold: true; font.pixelSize: Kirigami.Units.gridUnit * 0.85 }
                    }
                }
                Rectangle { // Sunset
                    Layout.fillWidth: true
                    color: fullRoot.cardColor; radius: fullRoot.cardRadius
                    implicitHeight: setCol.implicitHeight + Kirigami.Units.largeSpacing
                    ColumnLayout {
                        id: setCol
                        anchors.fill: parent; anchors.margins: fullRoot.cardPad
                        spacing: 0
                        PlasmaComponents.Label { Layout.alignment: Qt.AlignHCenter; text: "🌇"; font.pixelSize: Kirigami.Units.gridUnit * 1.4 }
                        PlasmaComponents.Label { Layout.alignment: Qt.AlignHCenter; text: "Закат"; font.pixelSize: Kirigami.Units.gridUnit * 0.65; color: fullRoot.mutedColor }
                        PlasmaComponents.Label { Layout.alignment: Qt.AlignHCenter; text: plasmoidItem ? plasmoidItem._sunset : "--:--"; font.bold: true; font.pixelSize: Kirigami.Units.gridUnit * 0.85 }
                    }
                }
                Rectangle { // UV index
                    Layout.fillWidth: true
                    color: fullRoot.cardColor; radius: fullRoot.cardRadius
                    implicitHeight: uvCol.implicitHeight + Kirigami.Units.largeSpacing
                    ColumnLayout {
                        id: uvCol
                        anchors.fill: parent; anchors.margins: fullRoot.cardPad
                        spacing: 0
                        PlasmaComponents.Label { Layout.alignment: Qt.AlignHCenter; text: "☀️"; font.pixelSize: Kirigami.Units.gridUnit * 1.4 }
                        PlasmaComponents.Label { Layout.alignment: Qt.AlignHCenter; text: "УФ-индекс"; font.pixelSize: Kirigami.Units.gridUnit * 0.65; color: fullRoot.mutedColor }
                        PlasmaComponents.Label { Layout.alignment: Qt.AlignHCenter; text: plasmoidItem ? plasmoidItem.uvText(plasmoidItem._uvIndex) : "--"; font.bold: true; font.pixelSize: Kirigami.Units.gridUnit * 0.85 }
                    }
                }
                Rectangle { // Precipitation
                    Layout.fillWidth: true
                    color: fullRoot.cardColor; radius: fullRoot.cardRadius
                    implicitHeight: precCol.implicitHeight + Kirigami.Units.largeSpacing
                    ColumnLayout {
                        id: precCol
                        anchors.fill: parent; anchors.margins: fullRoot.cardPad
                        spacing: 0
                        PlasmaComponents.Label { Layout.alignment: Qt.AlignHCenter; text: "🌧️"; font.pixelSize: Kirigami.Units.gridUnit * 1.4 }
                        PlasmaComponents.Label { Layout.alignment: Qt.AlignHCenter; text: "Осадки"; font.pixelSize: Kirigami.Units.gridUnit * 0.65; color: fullRoot.mutedColor }
                        PlasmaComponents.Label { Layout.alignment: Qt.AlignHCenter; text: fullRoot.precipText(); font.bold: true; font.pixelSize: Kirigami.Units.gridUnit * 0.85 }
                    }
                }
            }

            // ── "Today" card: holidays + this day in history ──────────────
            Rectangle {
                Layout.fillWidth: true
                color: fullRoot.cardColor
                radius: fullRoot.cardRadius
                implicitHeight: todayCol.implicitHeight + Kirigami.Units.largeSpacing * 1.4
                // hide entirely if nothing to show
                visible: fullRoot.showContent &&
                         (((plasmoidItem && plasmoidItem._holidaysText.length > 0)) ||
                          ((plasmoidItem && plasmoidItem._historyEvents.length > 0)))

                ColumnLayout {
                    id: todayCol
                    anchors.fill: parent
                    anchors.margins: fullRoot.hPad * 0.8
                    spacing: Kirigami.Units.smallSpacing

                    PlasmaComponents.Label {
                        text: "📅 Сегодня"
                        font.bold: true
                        font.pixelSize: Kirigami.Units.gridUnit * 0.95
                    }

                    PlasmaComponents.Label {
                        Layout.fillWidth: true
                        visible: plasmoidItem && plasmoidItem._holidaysText.length > 0
                        text: plasmoidItem ? plasmoidItem._holidaysText : ""
                        font.pixelSize: Kirigami.Units.gridUnit * 0.9
                        font.bold: true
                        color: fullRoot.accentColor
                        wrapMode: Text.WordWrap
                    }

                    Repeater {
                        model: plasmoidItem ? plasmoidItem._historyEvents : []
                        PlasmaComponents.Label {
                            Layout.fillWidth: true
                            text: "📜 " + (modelData.year || "?") + ": " + (modelData.text || "")
                            font.pixelSize: Kirigami.Units.gridUnit * 0.78
                            color: fullRoot.mutedColor
                            wrapMode: Text.WordWrap
                            elide: Text.ElideRight
                            maximumLineCount: 3
                        }
                    }

                    PlasmaComponents.Label {
                        visible: plasmoidItem && plasmoidItem._historyEvents.length === 0
                                 && plasmoidItem._holidaysText.length === 0
                        text: "Загружаем события дня…"
                        font.pixelSize: Kirigami.Units.gridUnit * 0.75
                        color: fullRoot.mutedColor
                        font.italic: true
                    }
                }
            }

            // ── Forecast ──────────────────────────────────────────────────
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.minimumHeight: Kirigami.Units.gridUnit * 10
                visible: fullRoot.showContent && plasmoid.configuration.showForecast
                spacing: Kirigami.Units.smallSpacing

                RowLayout {
                    Layout.fillWidth: true
                    PlasmaComponents.Label {
                        text: fullRoot.forecastMode() === "hourly" ? "⏱️ Почасовой прогноз"
                              : fullRoot.forecastMode() === "both" ? "🔮 Прогноз"
                              : "📅 Прогноз по дням"
                        font.bold: true
                        font.pixelSize: Kirigami.Units.gridUnit
                    }
                    Item { Layout.fillWidth: true }
                    RowLayout {
                        visible: fullRoot.forecastMode() === "both"
                        spacing: 0
                        PlasmaComponents.ToolButton {
                            text: "Дни"; checkable: true; checked: fullRoot.forecastTab === 0
                            onClicked: fullRoot.forecastTab = 0
                        }
                        PlasmaComponents.ToolButton {
                            text: "Часы"; checkable: true; checked: fullRoot.forecastTab === 1
                            onClicked: fullRoot.forecastTab = 1
                        }
                    }
                }

                ListView {
                    id: dailyList
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    orientation: ListView.Horizontal
                    spacing: Kirigami.Units.smallSpacing
                    clip: true
                    visible: fullRoot.showDaily() &&
                             (fullRoot.forecastMode() !== "both" || fullRoot.forecastTab === 0)
                    model: plasmoidItem ? plasmoidItem._forecasts : []
                    delegate: ForecastItem {
                        width: Kirigami.Units.gridUnit * 6.2
                        height: dailyList.height
                        mode: "daily"
                        forecastData: modelData
                        appletRef: plasmoidItem
                    }
                }

                ListView {
                    id: hourlyList
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    orientation: ListView.Horizontal
                    spacing: Kirigami.Units.smallSpacing
                    clip: true
                    visible: fullRoot.showHourly() &&
                             plasmoidItem && plasmoidItem._hourlyForecasts.length > 0 &&
                             (fullRoot.forecastMode() !== "both" || fullRoot.forecastTab === 1)
                    model: plasmoidItem ? plasmoidItem._hourlyForecasts : []
                    delegate: ForecastItem {
                        width: Kirigami.Units.gridUnit * 5.2
                        height: hourlyList.height
                        mode: "hourly"
                        forecastData: modelData
                        appletRef: plasmoidItem
                    }
                }
            }
        } // mainColumn
    } // Flickable
}
