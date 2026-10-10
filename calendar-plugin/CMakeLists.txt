# weatherevents -- Open-Meteo weather events plugin for the Plasma 6 calendar.
#
# Note: extra-cmake-modules (ECM) is intentionally NOT used here (it is not
# installed on this machine). Plain CMake + Qt6 core macros only:
# qt_add_plugin() instead of kcoreaddons_add_plugin(), qt_add_qml_module()
# for the config-page helper module.
cmake_minimum_required(VERSION 3.25)

project(weatherevents
    VERSION 0.2.0
    DESCRIPTION "Open-Meteo weather events for the Plasma calendar"
    LANGUAGES CXX
)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
set(CMAKE_AUTOMOC ON)

find_package(Qt6 REQUIRED COMPONENTS Core Gui Network Qml)
# KF6Declarative exports the KF6::CalendarEvents library (the
# org.kde.CalendarEventsPlugin API that plasmashell loads).
find_package(KF6Declarative REQUIRED)
find_package(KF6CoreAddons REQUIRED) # KPluginMetaData in the probe
find_package(KF6Config REQUIRED) # KSharedConfig/KConfigWatcher in the plugin

# Install destinations (this project installs system-wide via install.sh,
# which runs `sudo cmake --install`; the agent never invokes sudo).
set(WEATHER_PLUGIN_DIR /usr/lib/qt6/plugins/plasmacalendarplugins)
set(WEATHER_CONFIG_PAGE_DIR ${WEATHER_PLUGIN_DIR}/weatherevents)
set(WEATHER_QML_MODULE_DIR /usr/lib/qt6/qml/org/kde/plasma/private/weathereventsconfig)

qt_add_plugin(weatherevents)
# Plasma's plasmacalendarplugins live without the "lib" prefix
# (kcoreaddons_add_plugin does the same; see holidaysevents.so etc).
set_target_properties(weatherevents PROPERTIES PREFIX "")
target_sources(weatherevents PRIVATE
    src/weathereventsplugin.cpp
    src/weatherdatastore.cpp
    src/wmoconditions.cpp
)
target_include_directories(weatherevents PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/src
)
target_link_libraries(weatherevents PRIVATE
    Qt6::Core
    Qt6::Gui
    Qt6::Network
    KF6::CalendarEvents
    KF6::ConfigCore
)
target_compile_options(weatherevents PRIVATE
    -Wall -Wextra -Wpedantic
)

# QML module with the config-page helper (WeatherEventsConfig), following the
# ConfigStorage pattern of KDE's alternatecalendar plugin: a calendar plugin
# config page cannot write its own KConfig through the applet cfg_* machinery.
# PLUGIN_TARGET pointing at itself keeps module + registration in ONE shared
# library, so the module dir is self-contained (no cross-directory rpath).
qt_add_qml_module(weathereventsconfigplugin
    URI org.kde.plasma.private.weathereventsconfig
    VERSION 1.0
    PLUGIN_TARGET weathereventsconfigplugin
    NO_PLUGIN_OPTIONAL
    SOURCES
        src/confighelper.h
        src/confighelper.cpp
)
target_link_libraries(weathereventsconfigplugin PRIVATE
    Qt6::Core
    KF6::ConfigCore
)
target_compile_options(weathereventsconfigplugin PRIVATE
    -Wall -Wextra -Wpedantic
)
# The generated *_qmltyperegistrations.cpp compiles inside this target and
# includes our headers by bare name.
target_include_directories(weathereventsconfigplugin PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/src
)

install(TARGETS weatherevents
    LIBRARY DESTINATION ${WEATHER_PLUGIN_DIR}
)
# The config page must sit next to the .so in a subdirectory named after the
# plugin id; EventPluginsManager resolves "weatherevents/configui.qml"
# (X-KDE-PlasmaCalendar-ConfigUi) against the plugin directory.
install(FILES src/configui.qml
    DESTINATION ${WEATHER_CONFIG_PAGE_DIR}
)
install(TARGETS weathereventsconfigplugin
    LIBRARY DESTINATION ${WEATHER_QML_MODULE_DIR}
)
qt_query_qml_module(weathereventsconfigplugin
    QMLDIR weather_qmldir
    TYPEINFO weather_typeinfo
)
install(FILES "${weather_qmldir}" "${weather_typeinfo}"
    DESTINATION ${WEATHER_QML_MODULE_DIR}
)

enable_testing()
add_subdirectory(test)
