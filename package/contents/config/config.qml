import QtQuick 2.15
import QtQuick.Controls 2.15
import org.kde.kirigami 2.20 as Kirigami
import org.kde.plasma.configuration 2.0

ConfigModel {
    ConfigCategory {
        name: "Основные"
        icon: "configure"
        source: "configGeneral.qml"
    }
}
