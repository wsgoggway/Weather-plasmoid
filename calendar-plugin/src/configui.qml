// SPDX-FileCopyrightText: 2026 Vladimir Manichev
// SPDX-License-Identifier: MIT

// Settings page of the weatherevents calendar plugin. Loaded by the digital
// clock settings dialog as an absolute file path (metadata key
// "X-KDE-PlasmaCalendar-ConfigUi", resolved relative to the plugin .so), so
// the page gets no plugin context object: it reads and writes
// ~/.config/weathereventsrc through the C++ helper from
// org.kde.plasma.private.weathereventsconfig (installed with the plugin).
//
// Expected page API (same contract as KDE's own calendar plugin pages):
// signal configurationChanged() and function saveConfig(), called by the
// config dialog on Apply/OK.
//
// Note: no "pragma ComponentBehavior: Bound" — the repo's QML does not use
// it, and the local qmllint build crashes silently on any file that has it.
import QtQuick
import QtQuick.Controls as QQC2

import org.kde.kcmutils as KCMUtils
import org.kde.kirigami as Kirigami

import org.kde.plasma.private.weathereventsconfig as Private

KCMUtils.SimpleKCM {
    id: root

    // expected API
    signal configurationChanged()

    property bool unsavedChanges: false

    function checkUnsavedChanges() {
        root.unsavedChanges = weatherConfig.latitude !== currentConfig.latitude
            || weatherConfig.longitude !== currentConfig.longitude
            || weatherConfig.temperatureUnit !== currentConfig.temperatureUnit
            || weatherConfig.cityName !== currentConfig.cityName;
        root.configurationChanged();
    }

    // expected API: called by the config dialog on Apply/OK
    function saveConfig() {
        weatherConfig.save();
        root.unsavedChanges = false;
    }

    Private.WeatherEventsConfig {
        id: weatherConfig
    }

    // Snapshot of the loaded values for the unsaved-changes check.
    QtObject {
        id: currentConfig

        readonly property double latitude: weatherConfig.latitude
        readonly property double longitude: weatherConfig.longitude
        readonly property string temperatureUnit: weatherConfig.temperatureUnit
        readonly property string cityName: weatherConfig.cityName
    }

    Kirigami.FormLayout {
        QQC2.TextField {
            id: citySearchField

            Kirigami.FormData.label: "Поиск города:"
            placeholderText: "Введите название города"
            selectByMouse: true

            onTextEdited: searchTimer.restart()
        }

        Timer {
            id: searchTimer

            interval: 500
            onTriggered: citySearch.search(citySearchField.text)
        }

        QQC2.ComboBox {
            id: cityResults

            Kirigami.FormData.label: "Результаты:"
            model: citySearch.results
            textRole: "label"
            enabled: count > 0

            onActivated: index => {
                const entry = citySearch.results[index];
                weatherConfig.cityName = entry.label;
                weatherConfig.latitude = entry.latitude;
                weatherConfig.longitude = entry.longitude;
                // Sync the manual fields so the chosen city stays visible.
                latitudeField.text = entry.latitude.toString();
                longitudeField.text = entry.longitude.toString();
                cityStatus.text = "";
                root.checkUnsavedChanges();
            }
        }

        Kirigami.InlineMessage {
            id: cityStatus

            type: Kirigami.MessageType.Error
            showCloseButton: false
            visible: text.length > 0
        }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
        }

        QQC2.TextField {
            id: latitudeField

            Kirigami.FormData.label: "Широта:"
            inputMethodHints: Qt.ImhFormattedNumbersOnly
            selectByMouse: true

            onTextEdited: {
                const value = parseFloat(text);
                if (!Number.isNaN(value) && value >= -90 && value <= 90) {
                    weatherConfig.latitude = value;
                    root.checkUnsavedChanges();
                }
            }
        }

        QQC2.TextField {
            id: longitudeField

            Kirigami.FormData.label: "Долгота:"
            inputMethodHints: Qt.ImhFormattedNumbersOnly
            selectByMouse: true

            onTextEdited: {
                const value = parseFloat(text);
                if (!Number.isNaN(value) && value >= -180 && value <= 180) {
                    weatherConfig.longitude = value;
                    root.checkUnsavedChanges();
                }
            }
        }

        QQC2.ComboBox {
            id: unitComboBox

            Kirigami.FormData.label: "Единицы температуры:"
            textRole: "text"
            model: [
                { value: "celsius", text: "Градусы Цельсия (°C)" },
                { value: "fahrenheit", text: "Градусы Фаренгейта (°F)" }
            ]

            Component.onCompleted: {
                currentIndex = model.findIndex(entry => entry.value === weatherConfig.temperatureUnit);
            }
            onActivated: index => {
                weatherConfig.temperatureUnit = model[index].value;
                root.checkUnsavedChanges();
            }
        }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
        }

        QQC2.Label {
            text: {
                if (weatherConfig.latitude === 0 && weatherConfig.longitude === 0) {
                    return "Место не выбрано";
                }
                const city = weatherConfig.cityName.length > 0 ? weatherConfig.cityName + " · " : "";
                return city + "Координаты: " + weatherConfig.latitude.toFixed(4) + ", "
                    + weatherConfig.longitude.toFixed(4);
            }
            color: Kirigami.Theme.disabledTextColor
        }
    }

    // Open-Meteo geocoding: city name -> up to 5 candidates.
    QtObject {
        id: citySearch

        property var results: []

        function search(query) {
            const trimmed = query.trim();
            if (trimmed.length < 2) {
                citySearch.results = [];
                cityStatus.text = "";
                return;
            }
            const request = new XMLHttpRequest();
            const url = "https://geocoding-api.open-meteo.com/v1/search?name="
                + encodeURIComponent(trimmed) + "&language=ru&count=5";
            request.timeout = 10000;
            request.onreadystatechange = () => {
                if (request.readyState !== XMLHttpRequest.DONE) {
                    return;
                }
                if (request.status !== 200) {
                    cityStatus.text = "Ошибка сети при поиске города";
                    return;
                }
                try {
                    const payload = JSON.parse(request.responseText);
                    const entries = Array.isArray(payload.results) ? payload.results : [];
                    citySearch.results = entries.map(entry => ({
                        label: entry.name + (entry.admin1 ? ", " + entry.admin1 : "")
                            + (entry.country ? ", " + entry.country : ""),
                        latitude: entry.latitude,
                        longitude: entry.longitude,
                    }));
                    cityStatus.text = citySearch.results.length === 0 ? "Город не найден" : "";
                } catch (error) {
                    cityStatus.text = "Некорректный ответ сервиса геокодирования";
                }
            };
            request.open("GET", url);
            request.send();
        }
    }

    Component.onCompleted: {
        if (weatherConfig.latitude !== 0 || weatherConfig.longitude !== 0) {
            latitudeField.text = weatherConfig.latitude.toString();
            longitudeField.text = weatherConfig.longitude.toString();
        }
    }
}
