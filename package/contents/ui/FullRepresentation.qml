import QtQuick 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15
import org.kde.plasma.components 3.0 as PlasmaComponents
import org.kde.plasma.extras 2.0 as PlasmaExtras
import org.kde.kirigami 2.20 as Kirigami
import org.kde.plasma.plasmoid 2.0

/*
 * Full representation — popup / desktop.
 * plasmoidItem is set by PlasmoidItem automatically (official Plasma 6 API).
 */
Item {
    id: fullRoot

    required property PlasmoidItem plasmoidItem

    Layout.minimumWidth: Kirigami.Units.gridUnit * 16
    Layout.minimumHeight: Kirigami.Units.gridUnit * 18
    Layout.preferredWidth: Kirigami.Units.gridUnit * 20
    Layout.preferredHeight: Kirigami.Units.gridUnit * 28

    property bool showLoading: !plasmoidItem || plasmoidItem._loading
    property bool showError: plasmoidItem ? plasmoidItem._errorMessage.length > 0 : false
    property bool showContent: plasmoidItem && !plasmoidItem._loading && !showError

    property int forecastTab: 0

    function forecastMode() { return plasmoid.configuration.forecastMode || "daily" }
    function showDaily()  { return forecastMode() === "daily"  || forecastMode() === "both" }
    function showHourly() { return forecastMode() === "hourly" || forecastMode() === "both" }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Kirigami.Units.largeSpacing
        spacing: Kirigami.Units.largeSpacing * 0.4

        // ── Header ────────────────────────────────────────────────────────
        RowLayout {
            Layout.fillWidth: true
            PlasmaComponents.Label {
                text: plasmoid.configuration.cityName || "Погода"
                font.pixelSize: Kirigami.Units.gridUnit * 1.3
                font.bold: true
                elide: Text.ElideRight
                Layout.fillWidth: true
            }
            PlasmaComponents.Label {
                text: plasmoidItem ? (plasmoidItem._lastUpdate || "") : ""
                font.pixelSize: Kirigami.Units.gridUnit * 0.7
                color: Kirigami.Theme.disabledTextColor
                visible: text.length > 0
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

        // ── Loading ───────────────────────────────────────────────────────
        PlasmaComponents.BusyIndicator {
            Layout.alignment: Qt.AlignCenter
            running: fullRoot.showLoading
            visible: fullRoot.showLoading
        }

        // ── Error ─────────────────────────────────────────────────────────
        PlasmaComponents.Label {
            visible: fullRoot.showError
            text: plasmoidItem ? (plasmoidItem._errorMessage || "") : ""
            color: Kirigami.Theme.negativeTextColor
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
        }

        // ── Current weather ───────────────────────────────────────────────
        ColumnLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: Kirigami.Units.smallSpacing
            visible: fullRoot.showContent

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: Kirigami.Units.gridUnit

                PlasmaComponents.Label {
                    text: plasmoidItem ? (plasmoidItem._currentEmoji || "🌈") : "🌈"
                    font.pixelSize: Kirigami.Units.gridUnit * 3.5
                }
                ColumnLayout {
                    spacing: 0
                    PlasmaComponents.Label {
                        text: plasmoidItem
                            ? (plasmoidItem._currentTemp || 0) + plasmoidItem._tempUnitLabel
                            : "--°"
                        font.pixelSize: Kirigami.Units.gridUnit * 3
                        font.bold: true
                    }
                    PlasmaComponents.Label {
                        text: plasmoidItem
                            ? "Ощущается " + (plasmoidItem._currentFeelsLike || "--") +
                              plasmoidItem._tempUnitLabel
                            : ""
                        font.pixelSize: Kirigami.Units.gridUnit * 0.9
                        color: Kirigami.Theme.disabledTextColor
                    }
                }
            }

            PlasmaComponents.Label {
                Layout.alignment: Qt.AlignHCenter
                text: plasmoidItem ? (plasmoidItem._currentConditionRu || "") : ""
                font.pixelSize: Kirigami.Units.gridUnit * 1.1
            }

            GridLayout {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: Kirigami.Units.smallSpacing
                columns: 2
                rowSpacing: Kirigami.Units.smallSpacing
                columnSpacing: Kirigami.Units.gridUnit * 3

                DetailRow { icon: "💨"; label: "Ветер";
                    value: plasmoidItem
                        ? (plasmoidItem._currentWindSpeed || 0) +
                          plasmoidItem._windUnitLabel + " " +
                          (plasmoidItem._currentWindDir || "")
                        : "" }
                DetailRow { icon: "💧"; label: "Влажность";
                    value: plasmoidItem
                        ? (plasmoidItem._currentHumidity || 0) + "%"
                        : "" }
                DetailRow { icon: "🔵"; label: "Давление";
                    value: plasmoidItem
                        ? (plasmoidItem._currentPressure || 0) + " мм рт.ст."
                        : "" }
                DetailRow { icon: "☁️"; label: "Облачность";
                    value: plasmoidItem
                        ? ((plasmoidItem._currentCloudCover != null ? plasmoidItem._currentCloudCover : 0) + "%")
                        : "" }
            }
        }

        // ── Forecast ──────────────────────────────────────────────────────
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: Kirigami.Units.gridUnit * 10
            visible: fullRoot.showContent && plasmoid.configuration.showForecast

            ColumnLayout {
                anchors.fill: parent
                spacing: Kirigami.Units.smallSpacing

                RowLayout {
                    visible: fullRoot.forecastMode() === "both"
                    spacing: Kirigami.Units.smallSpacing
                    PlasmaComponents.ToolButton {
                        text: "По дням"
                        checked: fullRoot.forecastTab === 0
                        checkable: true
                        onClicked: fullRoot.forecastTab = 0
                    }
                    PlasmaComponents.ToolButton {
                        text: "По часам"
                        checked: fullRoot.forecastTab === 1
                        checkable: true
                        onClicked: fullRoot.forecastTab = 1
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
                        width: Kirigami.Units.gridUnit * 6
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
                        width: Kirigami.Units.gridUnit * 5
                        height: hourlyList.height
                        mode: "hourly"
                        forecastData: modelData
                        appletRef: plasmoidItem
                    }
                }
            }
        }
    }
}
