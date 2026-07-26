import QtQuick 2.15
import QtQuick.Layouts 1.15
import org.kde.plasma.components 3.0 as PlasmaComponents
import org.kde.kirigami 2.20 as Kirigami

/*
 * Hourly forecast item — plain vertical (time / emoji / temp).
 * Styled for the dark-glass template: no card background, subtle time label,
 * first item shows "Сейчас".
 */
Item {
    id: forecastItem
    property var forecastData: ({})
    property var appletRef: null
    property bool isFirst: false

    // dark-glass palette (kept local so this component is self-contained)
    readonly property color textColor: "#ffffff"
    readonly property color subtleColor: Qt.rgba(1, 1, 1, 0.6)

    implicitWidth: Kirigami.Units.gridUnit * 3.4
    implicitHeight: Kirigami.Units.gridUnit * 5.4

    function formatHour(isoTime) {
        if (!isoTime) return ""
        var t = isoTime.split("T")[1]
        return t ? t.substring(0, 5) : ""
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Kirigami.Units.smallSpacing

        PlasmaComponents.Label {
            Layout.alignment: Qt.AlignHCenter
            text: isFirst ? "Сейчас" : formatHour(forecastData.time)
            font.pixelSize: Kirigami.Units.gridUnit * 0.75
            color: forecastItem.subtleColor
        }
        PlasmaComponents.Label {
            Layout.alignment: Qt.AlignHCenter
            text: forecastData ? (forecastData.emoji || "🌈") : "🌈"
            font.pixelSize: Kirigami.Units.gridUnit * 1.4
        }
        PlasmaComponents.Label {
            Layout.alignment: Qt.AlignHCenter
            text: {
                if (!forecastData) return ""
                var unit = appletRef ? appletRef._tempUnitLabel : "°"
                return (forecastData.temp || 0) + unit
            }
            font.pixelSize: Kirigami.Units.gridUnit * 0.95
            font.weight: Font.Medium
            color: forecastItem.textColor
        }
    }
}
