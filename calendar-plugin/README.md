# weatherevents — weather events for the Plasma calendar

KDE Plasma 6 calendar plugin (`plasmacalendarplugins`) that feeds Open-Meteo
weather into the stock digital-clock widget's calendar: every day of the
visible month(s) gets a colored all-day entry with the temperature range and
condition, plus a day sub-label showing the day's max temperature. Data comes
from the free Open-Meteo daily forecast API (no key), is cached on disk and
refreshed at most every 3 hours.

## Layout

```
calendar-plugin/
├── CMakeLists.txt            # plugin module + config QML module + install rules
├── install.sh                # build + system install (manual, needs sudo)
├── src/
│   ├── metadata.json         # KPlugin metadata (Id "weatherevents") + ConfigUi path
│   ├── weathereventsplugin.h/.cpp  # calendar glue: store -> EventData/subLabels
│   ├── weatherdatastore.h/.cpp     # Open-Meteo daily fetch + on-disk cache
│   ├── wmoconditions.h/.cpp        # WMO code -> label/color/temperature strings
│   ├── confighelper.h/.cpp         # QML helper reading/writing weathereventsrc
│   └── configui.qml          # settings page (city search, coordinates, units)
└── test/
    ├── CMakeLists.txt
    ├── test_weatherdatastore.cpp   # offline unit tests (ctest)
    ├── probe_load.cpp              # out-of-process load verification
    └── probe_fetch.cpp             # real-network e2e probe of the data layer
```

## Enable in the clock calendar

1. Install (below) and let `plasmashell --replace` restart the shell.
2. Right-click the digital clock → «Настроить цифровые часы…» → «Календарь» →
   check «Погода» in «Доступные дополнения» → Apply.
3. Open the clock settings again: a new «Погода» page appears in the sidebar
   (it shows up only while the plugin is enabled). Choose a city (search via
   Open-Meteo geocoding) or enter coordinates manually, pick the temperature
   unit, Apply.
4. Open the calendar: days in the past-7..next-16 window are marked with a
   colored dot and show «−4°…+2° · Облачно» style entries; hovering a day
   shows details (wind, precipitation, UV, sunrise/sunset).

Coordinates are stored in `~/.config/weathereventsrc` (group `[General]`):

```ini
[General]
latitude=55.7522
longitude=37.6156
temperatureUnit=celsius   # или fahrenheit
cityName=Москва           # informational
```

Manual editing works too — the running plasmashell picks the file change up
without a restart. `0/0` (both zeros) counts as "no location".

## Build

```bash
cmake -S calendar-plugin -B calendar-plugin/build -DCMAKE_BUILD_TYPE=Release
cmake --build calendar-plugin/build
```

Note: extra-cmake-modules (ECM) is not used — plain CMake + Qt6 core macros
only. Requires: Qt 6 (Core/Gui/Network/Qml), KF6Declarative (CalendarEvents
API), KF6CoreAddons, KF6Config.

## Tests and probes

```bash
ctest --test-dir calendar-plugin/build --output-on-failure   # offline unit tests
./calendar-plugin/build/test/probe_load  ./calendar-plugin/build/weatherevents.so
# expect: PROBE OK events=0   (no location configured -> empty set, no fetch)

# real-network check of the data layer (throwaway cache under /tmp):
./calendar-plugin/build/test/probe_fetch 55.7522 37.6156 celsius
# expect: PROBE FETCH OK days=23 + three sample "−4°…+2° · Облачно" lines
```

## Install (manual, user-run)

Installs system-wide (`weatherevents.so` into
`/usr/lib/qt6/plugins/plasmacalendarplugins`, `configui.qml` next to it, the
config QML module into `/usr/lib/qt6/qml/org/kde/plasma/private/weathereventsconfig`)
and restarts plasmashell. Requires sudo. Agents never run this script.

```bash
./calendar-plugin/install.sh            # build + install + plasmashell --replace
./calendar-plugin/install.sh uninstall  # remove installed files + plasmashell --replace
```

## Data details

- One all-day `EventData` per available day: uid `weatherevents-YYYY-MM-DD`,
  title «tMin…tMax · условие» (· осадки N% at ≥30% probability), description
  «Ветер до N км/ч · Осадки M мм · УФ-индекс U · Восход HH:MM · Закат HH:MM»,
  color from the day mean temperature (blue → red ramp).
- `subLabelReady` carries `dayLabel = tMax` per day (shown by the calendar's
  day grid).
- Cache: `<GenericCacheLocation>/weatherevents/daily.json`; a location/unit
  change starts a fresh cache; fetch failures keep the previous data.
