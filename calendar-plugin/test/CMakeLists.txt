add_executable(probe_load probe_load.cpp)
target_link_libraries(probe_load PRIVATE
    Qt6::Core
    KF6::CalendarEvents
    KF6::CoreAddons
)
target_compile_options(probe_load PRIVATE
    -Wall -Wextra -Wpedantic
)
