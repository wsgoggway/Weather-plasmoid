# weatherevents -- Open-Meteo weather events plugin for the Plasma 6 calendar.
#
# Note: extra-cmake-modules (ECM) is intentionally NOT used here (it is not
# installed on this machine). Plain CMake + Qt6 core macros only:
# qt_add_plugin() instead of kcoreaddons_add_plugin().
cmake_minimum_required(VERSION 3.25)

project(weatherevents
    VERSION 0.1.0
    DESCRIPTION "Open-Meteo weather events for the Plasma calendar"
    LANGUAGES CXX
)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
set(CMAKE_AUTOMOC ON)

find_package(Qt6 REQUIRED COMPONENTS Core Gui Network)
# KF6Declarative exports the KF6::CalendarEvents library (the
# org.kde.CalendarEventsPlugin API that plasmashell loads).
find_package(KF6Declarative REQUIRED)
find_package(KF6CoreAddons REQUIRED) # KPluginMetaData in the probe

qt_add_plugin(weatherevents)
# Plasma's plasmacalendarplugins live without the "lib" prefix
# (kcoreaddons_add_plugin does the same; see holidaysevents.so etc).
set_target_properties(weatherevents PROPERTIES PREFIX "")
target_sources(weatherevents PRIVATE
    src/weathereventsplugin.cpp
)
target_include_directories(weatherevents PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/src
)
target_link_libraries(weatherevents PRIVATE
    Qt6::Core
    Qt6::Gui
    Qt6::Network
    KF6::CalendarEvents
)
target_compile_options(weatherevents PRIVATE
    -Wall -Wextra -Wpedantic
)

# Used by calendar-plugin/install.sh; never invoked by the agent.
install(TARGETS weatherevents
    LIBRARY DESTINATION /usr/lib/qt6/plugins/plasmacalendarplugins
)

add_subdirectory(test)
