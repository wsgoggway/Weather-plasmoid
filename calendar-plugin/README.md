# weatherevents — weather events for the Plasma calendar (WIP)

KDE Plasma 6 calendar plugin (`plasmacalendarplugins`) that feeds Open-Meteo
weather into the stock digital-clock widget's calendar. **Work in progress**:
this scaffold emits one stub all-day event («Погода (заглушка): +21°, ясно»)
for today so the build/load path is proven; the real Open-Meteo integration
arrives in later slices.

## Layout

```
calendar-plugin/
├── CMakeLists.txt        # plugin module + probe_load target
├── install.sh            # build + system install (manual, needs sudo)
├── src/
│   ├── metadata.json     # KPlugin metadata (Id "weatherevents")
│   ├── weathereventsplugin.h/.cpp
│   └── configui.qml      # settings placeholder (not installed yet)
└── test/
    ├── CMakeLists.txt
    └── probe_load.cpp    # out-of-process load verification
```

## Build

```bash
cmake -S calendar-plugin -B calendar-plugin/build -DCMAKE_BUILD_TYPE=Release
cmake --build calendar-plugin/build
```

Note: extra-cmake-modules (ECM) is not used — plain CMake + Qt6 core macros
only. Requires: Qt 6 (Core/Gui/Network), KF6Declarative (CalendarEvents API),
KF6CoreAddons.

## Probe

Loads the built plugin out-of-process and checks metadata, interface cast and
the stub `dataReady` emission:

```bash
./calendar-plugin/build/test/probe_load ./calendar-plugin/build/weatherevents.so
# expect: PROBE OK events=1
```

## Install (manual, user-run)

Installs system-wide into `/usr/lib/qt6/plugins/plasmacalendarplugins` and
restarts plasmashell. Requires sudo. Agents never run this script.

```bash
./calendar-plugin/install.sh            # build + install + plasmashell --replace
./calendar-plugin/install.sh uninstall  # remove the .so + plasmashell --replace
```

## What works (this slice)

- Builds as a plasmashell calendar plugin module (`weatherevents.so`);
- KPlugin metadata: Id `weatherevents`, Name «Погода», Icon `weather-clouds`;
- `loadEventsForDateRange()` emits one stub all-day event for today
  (only when the requested range covers today);
- `probe_load` verifies metadata, load, interface cast and `events=1`.

## Not yet (later slices)

- Real Open-Meteo fetch (`Qt6::Network`) and per-day weather entries;
- Settings UI (`configui.qml` is a placeholder and is not installed yet — the
  `X-KDE-PlasmaCalendar-ConfigUi` reference is resolved later);
- Calendar sub-labels, event colors per condition, etc.
