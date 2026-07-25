import QtQuick 2.15
import QtQuick.Layouts 1.15
import org.kde.plasma.components 3.0 as PlasmaComponents
import org.kde.kirigami 2.20 as Kirigami

/*
 * A single forecast item — supports "daily" and "hourly" modes.
 * Parses ISO date/time strings directly (timezone-safe, no new Date()).
 */
Item {
    id: forecastItem
    property var forecastData: ({})
    property var appletRef: null
    property string mode: "daily"

    // Parse ISO "2026-07-25" → "Пн", "25.7"
    function formatDay(isoDate) {
        if (!isoDate) return ["", ""]
        var p = isoDate.substring(0, 10).split("-")
        if (p.length < 3) return ["", ""]
        var y = parseInt(p[0]), m = parseInt(p[1]), d = parseInt(p[2])
        // Tomohiko Sakamoto's day-of-week (0=Sun..6=Sat)
        var tm = [0, 3, 2, 5, 0, 3, 5, 1, 4, 6, 2, 4]
        var yy = m < 3 ? y - 1 : y
        var wd = (yy + Math.floor(yy/4) - Math.floor(yy/100) + Math.floor(yy/400) + tm[m-1] + d) % 7
        var days = ["Вс","Пн","Вт","Ср","Чт","Пт","Сб"]
        return [days[wd], d + "." + m]
    }

    // Parse ISO "2026-07-25T14:00" → "14:00"
    function formatHour(isoTime) {
        if (!isoTime) return ""
        var t = isoTime.split("T")[1]
        if (!t) return ""
        return t.substring(0, 5)
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Kirigami.Units.smallSpacing
        spacing: 2

        // ── Header: day-of-week (daily) or hour (hourly) ──────────────────
        PlasmaComponents.Label {
            Layout.alignment: Qt.AlignHCenter
            text: {
                if (!forecastData) return ""
                if (mode === "hourly") return formatHour(forecastData.time)
                return formatDay(forecastData.date)[0]
            }
            font.bold: true
            font.pixelSize: Kirigami.Units.gridUnit * 0.9
        }

        // ── Sub-header: date (daily only) ─────────────────────────────────
        PlasmaComponents.Label {
            Layout.alignment: Qt.AlignHCenter
            visible: mode === "daily"
            text: forecastData ? formatDay(forecastData.date)[1] : ""
            font.pixelSize: Kirigami.Units.gridUnit * 0.75
            color: Kirigami.Theme.disabledTextColor
        }

        // ── Emoji ─────────────────────────────────────────────────────────
        PlasmaComponents.Label {
            Layout.alignment: Qt.AlignHCenter
            text: forecastData ? (forecastData.emoji || "🌈") : "🌈"
            font.pixelSize: mode === "daily"
                ? Kirigami.Units.gridUnit * 1.6
                : Kirigami.Units.gridUnit * 1.4
        }

        // ── Temperature ───────────────────────────────────────────────────
        PlasmaComponents.Label {
            Layout.alignment: Qt.AlignHCenter
            text: {
                if (!forecastData) return ""
                var unit = appletRef ? appletRef._tempUnitLabel : "°"
                if (mode === "hourly") return (forecastData.temp || 0) + unit
                return (forecastData.temp_max || 0) + unit
            }
            font.pixelSize: Kirigami.Units.gridUnit * 1.1
            font.bold: true
        }

        // ── Min temp (daily only) ─────────────────────────────────────────
        PlasmaComponents.Label {
            Layout.alignment: Qt.AlignHCenter
            visible: mode === "daily"
            text: forecastData && mode === "daily"
                ? (forecastData.temp_min || 0) + (appletRef ? appletRef._tempUnitLabel : "°")
                : ""
            font.pixelSize: Kirigami.Units.gridUnit * 0.85
            color: Kirigami.Theme.disabledTextColor
        }

        // ── Wind (hourly only) ────────────────────────────────────────────
        PlasmaComponents.Label {
            Layout.alignment: Qt.AlignHCenter
            visible: mode === "hourly"
            text: forecastData && mode === "hourly"
                ? (forecastData.wind_speed || 0) + (appletRef ? appletRef._windUnitLabel : " м/с")
                : ""
            font.pixelSize: Kirigami.Units.gridUnit * 0.65
            color: Kirigami.Theme.disabledTextColor
        }

        // ── Precipitation ─────────────────────────────────────────────────
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 1
            visible: forecastData && (forecastData.prec_prob || 0) > 0
            PlasmaComponents.Label { text: "💧"; font.pixelSize: Kirigami.Units.gridUnit * 0.7 }
            PlasmaComponents.Label {
                text: forecastData ? (forecastData.prec_prob || 0) + "%" : ""
                font.pixelSize: Kirigami.Units.gridUnit * 0.7
                color: "#5b9bd5"
            }
        }
    }
}
