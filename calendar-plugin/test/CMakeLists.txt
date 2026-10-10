find_package(Qt6 REQUIRED COMPONENTS Test)

add_executable(probe_load probe_load.cpp)
target_link_libraries(probe_load PRIVATE
    Qt6::Core
    KF6::CalendarEvents
    KF6::CoreAddons
)
target_compile_options(probe_load PRIVATE
    -Wall -Wextra -Wpedantic
)

# Offline unit tests for the data layer (store + WMO conditions), compiled
# directly from the plugin sources.
add_executable(test_weatherdatastore
    test_weatherdatastore.cpp
    ../src/weatherdatastore.cpp
    ../src/wmoconditions.cpp
)
target_include_directories(test_weatherdatastore PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/../src
)
target_link_libraries(test_weatherdatastore PRIVATE
    Qt6::Test
    Qt6::Core
    Qt6::Network
)
target_compile_options(test_weatherdatastore PRIVATE
    -Wall -Wextra -Wpedantic
)
# Fixture directory is baked in so the test behaves identically under ctest
# and under a manual run, regardless of the current working directory.
target_compile_definitions(test_weatherdatastore PRIVATE
    FIXTURES_DIR="${CMAKE_CURRENT_SOURCE_DIR}/fixtures"
)
add_test(NAME test_weatherdatastore COMMAND test_weatherdatastore)

# Real-network e2e probe (data layer only). NOT registered with ctest: it
# needs internet and is run manually during verification.
add_executable(probe_fetch probe_fetch.cpp
    ../src/weatherdatastore.cpp
    ../src/wmoconditions.cpp
)
target_include_directories(probe_fetch PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/../src
)
target_link_libraries(probe_fetch PRIVATE
    Qt6::Core
    Qt6::Network
)
target_compile_options(probe_fetch PRIVATE
    -Wall -Wextra -Wpedantic
)

# Instantiates the settings page through a real QQmlEngine: the local qmllint
# build silently mis-checks files, so this is the authoritative check that the
# page the clock dialog will load is actually loadable.
find_package(Qt6 REQUIRED COMPONENTS Quick)
add_executable(probe_configui probe_configui.cpp)
target_link_libraries(probe_configui PRIVATE
    Qt6::Core
    Qt6::Quick
)
target_compile_options(probe_configui PRIVATE
    -Wall -Wextra -Wpedantic
)
target_compile_definitions(probe_configui PRIVATE
    CONFIGUI_PATH="${CMAKE_CURRENT_SOURCE_DIR}/../src/configui.qml"
)
add_test(NAME probe_configui COMMAND probe_configui)
