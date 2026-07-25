import QtQuick 2.15
import QtQuick.Layouts 1.15
import org.kde.plasma.components 3.0 as PlasmaComponents
import org.kde.plasma.plasmoid 2.0
import org.kde.kirigami 2.20 as Kirigami

/*
 * Compact representation — panel / system tray.
 * plasmoidItem is set by PlasmoidItem automatically (official Plasma 6 API).
 */
MouseArea {
    id: compactRoot

    required property PlasmoidItem plasmoidItem

    Layout.minimumWidth: Kirigami.Units.iconSizes.small * 3
    Layout.minimumHeight: Kirigami.Units.iconSizes.smallMedium
    Layout.preferredWidth: emojiLabel.implicitWidth + tempLabel.implicitWidth + Kirigami.Units.smallSpacing * 4
    Layout.preferredHeight: Layout.minimumHeight

    RowLayout {
        anchors.centerIn: parent
        spacing: Kirigami.Units.smallSpacing

        PlasmaComponents.Label {
            id: emojiLabel
            text: plasmoidItem ? (plasmoidItem._currentEmoji || "🌤️") : "🌤️"
            font.pointSize: Kirigami.Theme.smallFont ? Kirigami.Theme.smallFont.pointSize : 8
            visible: compactRoot.width > Kirigami.Units.iconSizes.small * 2.5
        }

        PlasmaComponents.Label {
            id: tempLabel
            text: {
                if (!plasmoidItem) return "--°"
                var t = plasmoidItem._currentTemp
                if (t === undefined || t === null) return "--°"
                return t + plasmoidItem._tempUnitLabel
            }
            font.pointSize: Kirigami.Theme.smallFont ? Kirigami.Theme.smallFont.pointSize : 8
            font.bold: true
        }
    }

    // Toggle popup — works in both panel and system tray
    onClicked: plasmoidItem.expanded = !plasmoidItem.expanded

    PlasmaComponents.ToolTip {
        visible: compactRoot.containsMouse
        text: {
            if (!plasmoidItem) return ""
            if (plasmoidItem._currentConditionRu) {
                return plasmoidItem._currentConditionRu + " — " +
                       (plasmoidItem._currentTemp || "?") + plasmoidItem._tempUnitLabel +
                       ", ощущается " + (plasmoidItem._currentFeelsLike || "?") + plasmoidItem._tempUnitLabel
            }
            return plasmoid.configuration.cityName || "Погода"
        }
        delay: 500
        timeout: 3000
    }
}
