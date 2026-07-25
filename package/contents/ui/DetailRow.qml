import QtQuick 2.15
import QtQuick.Layouts 1.15
import org.kde.plasma.components 3.0 as PlasmaComponents
import org.kde.kirigami 2.20 as Kirigami

/*
 * A single detail row: emoji icon + label + value.
 */
RowLayout {
    spacing: Kirigami.Units.smallSpacing

    property string icon: ""
    property string label: ""
    property string value: ""

    PlasmaComponents.Label {
        text: icon
        font.pixelSize: Kirigami.Units.gridUnit * 1.0
    }
    PlasmaComponents.Label {
        text: label
        font.pixelSize: Kirigami.Units.gridUnit * 0.85
        color: Kirigami.Theme.disabledTextColor
    }
    PlasmaComponents.Label {
        text: value
        font.pixelSize: Kirigami.Units.gridUnit * 0.85
        font.bold: true
        Layout.leftMargin: Kirigami.Units.smallSpacing * 2
    }
}
