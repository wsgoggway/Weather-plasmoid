# AGENT.md — Rules for the Agent (Open-Meteo Weather Plasmoid)

Weather widget for **KDE Plasma 6** in pure QML/JS. Free APIs, no API keys required.
All identifiers/code are in English; descriptions are now in English as well.

---

## 0. What Is This

- A **Plasma 6 plasmoid (applet)** using `KPackageStructure: Plasma/Applet`.
- Id: `com.github.vladimirm.openmeteo-weather`.
- **No C++/Python/compilation.** Only QML + JavaScript + JSON metadata.
- Weather source: **Open-Meteo** (no key). City geocoding — Open-Meteo Geocoding, IP geolocation — ipwhois.app (HTTPS), fallback ip-api.com (HTTP).

---

## 1. Structure

```
package/
├── metadata.json                 # Plasma 6 metadata (Id, Version, KPlugin)
└── contents/
    ├── ui/
    │   ├── main.qml              # root (PlasmoidItem): state, network, parsing
    │   ├── CompactRepresentation.qml   # panel view (emoji + temp)
    │   ├── FullRepresentation.qml      # expanded popup (card layout)
    │   ├── ForecastItem.qml       # forecast card (daily/hourly)
    │   ├── DetailRow.qml          # detail row (icon + label + value)
    │   └── configGeneral.qml      # settings page (KCM.SimpleKCM)
    ├── config/
    │   ├── config.qml            # ConfigModel → one category "General"
    │   └── main.xml              # KConfig XT schema (types + defaults)
install.sh                        # copies package/ into plasma/plasmoids/<Id>
```

- `main.qml` (`PlasmoidItem { id: root }`) — **the single source of truth** for state and logic.
- `FullRepresentation` / `CompactRepresentation` receive `plasmoidItem: root` automatically; they read `plasmoidItem._*` properties. They must not contain network or parsing logic.

---

## 2. ⚠️ Golden Rule: Settings (Plasma 6 KCM)

A bug that has happened before and must not recur: **`onValueChanged`/`onCheckedChanged` overwrite loaded values during initialization.**

In `configGeneral.qml`:

| Control | Reading config value | Writing back |
|---|---|---|
| `SpinBox` | `value: cfg_x` | `onValueModified: cfg_x = value` |
| `ComboBox` | `currentIndex: {…search model…}` | `onActivated: cfg_x = model[currentIndex].value` |
| `CheckBox` | `checked: cfg_x !== false` | `onToggled: cfg_x = checked` |
| `TextField` (text) | `onTextEdited` + sync in `Component.onCompleted` | `onTextEdited: cfg_x = text` |
| `TextField` (number, lat/lon) | **DO NOT** bind `text:` directly (interferes with typing "55.") | `onTextEdited: cfg_x = parseFloat(text)` |

- Write back **only** through user-initiated signals: `onValueModified`, `onActivated`, `onToggled`, `onTextEdited`. Never use `onValueChanged`/`onCheckedChanged`.
- 1:1 mapping: every `cfg_<name>` in QML has a corresponding `<entry name="<name>">` in `main.xml`.
- In QML, declare both `property var cfg_<name>` and `property var cfg_<name>Default` (KCM auto-binds both).

---

## 3. State Model in `main.qml`

- All state is stored as `property` on the root with a `_` prefix (e.g., `_currentTemp`, `_forecasts`, `_sunrise`).
- Network → `parseOpenMeteo(data)` sets **all** properties at once. The UI only reads them.
- **Conversions and rounding happen at the source** (`parseOpenMeteo`), not in display bindings. Temperatures use `Math.round()` immediately during parsing.
- Pressure: hPa → mmHg via `* 0.75006`.
- The "feels-like" joke is computed in `parseOpenMeteo` → `_feelsJokeText` (once per update, to avoid re-triggering on re-renders).

---

## 4. Network

- Only `XMLHttpRequest` (QML does not enforce CORS — cross-domain requests are fine).
- Mandatory: `xhr.timeout`, `xhr.ontimeout`, `xhr.onerror`, check `readyState === DONE` and `status === 200`.
- **Only free APIs without keys.** It is forbidden to add endpoints that require keys/tokens.
- Allowed sources:
  - `api.open-meteo.com/v1/forecast` — weather
  - `geocoding-api.open-meteo.com/v1/search` — city → coordinates
  - `ipwhois.app/json/` (https, primary) + `ip-api.com/json/` (http, last-resort fallback — free tier has no HTTPS) — IP geolocation
- Before using a new API field, **verify the exact name and format with `curl`** (e.g., `uv_index_max`, `precipitation_sum`).

---

## 5. Building the Open-Meteo Request

- `current` is always included; daily metrics (`sunrise,sunset,uv_index_max,precipitation_sum`) are **always** included, regardless of forecast mode.
- Daily forecast fields (`weather_code,temperature_2m_max,...`) are included only if `wantDaily`.
- Assemble the daily forecast array **only if `daily.weather_code` exists** (guard clause), otherwise `forecastMode=hourly` will produce garbage.
- Hourly forecast is filtered from the current hour onward (`currentTime.substring(0,13)`), with a limit of 48 data points.

---

## 6. UI / Layout

Design: theme-aware (adapts to the system light/dark theme). The full layout lives in `FullRepresentation.qml`.

- **Root** — `PlasmaExtras.Representation` with `collapseMarginsHint: true` + `padding: 0` → full-bleed (the background fills the whole popup platter, no Plasma margins). A `Rectangle` (`glassBg`) fills it with the theme background.
- **Palette** (constants on `fullRoot`, all theme-derived): `textColor = Kirigami.Theme.textColor`, `subtleColor = Kirigami.Theme.disabledTextColor`, `glassColor = Kirigami.Theme.backgroundColor`, `cardColor = Kirigami.Theme.alternateBackgroundColor`, `dividerColor = textColor @ 12% alpha`, `accentColor = Kirigami.Theme.highlightColor`, `negColor = Kirigami.Theme.negativeTextColor`. Only `barCold #4fc3f7` / `barWarm #ffb74d` are hardcoded (decorative temp gradient, visible on both themes). Do **not** override `Kirigami.Theme.*` — use the real system theme.
- **Header**: location → row [emoji + large thin temperature (`Font.Light`) | "Feels like" on the right] → the joke in italics (`subtleColor`).
- **Metrics grid 3×2**: Wind, Humidity, Pressure, Precipitation, UV index, Sun (sunrise – sunset). Each cell: an **icon-prefixed label** (`subtleColor`) + value (`textColor`, `Font.Medium`). Implemented with a `Repeater` inside a `GridLayout`.
- **Hourly forecast** — horizontal `ListView`; items are `ForecastItem` (plain, no background); the first item shows "Now".
- **Daily forecast** — vertical list (`Repeater` inside a `ColumnLayout`, **not** a nested ListView); each row: day / emoji / temp-bar / min / max.
- **temp-bar**: a `dividerColor` track 6px tall + a `Gradient.Horizontal #4fc3f7→#ffb74d` fill; its position/width are fractions of `(t_min−weekMin)/(weekMax−weekMin)`, where `weekMin`/`weekMax` are computed across all forecast days.
- `ForecastItem` is hourly-only (plain, no card background; theme-aware colors).
- Sizing via `Kirigami.Units.gridUnit`; spacing via `largeSpacing`/`smallSpacing`.
- All user-visible label/value strings are hardcoded Russian (see §8).
- Imports (canonical set):
  ```
  import QtQuick 2.15
  import QtQuick.Layouts 1.15
  import QtQuick.Controls 2.15
  import org.kde.plasma.components 3.0 as PlasmaComponents
  import org.kde.plasma.plasmoid 2.0
  import org.kde.plasma.extras 2.0 as PlasmaExtras
  import org.kde.kirigami 2.20 as Kirigami
  ```
- Do **not** set `display:` on a textless `ToolButton`.

---

## 7. Dates and Time (Timezone-Safe)

- **Do not use `new Date(isoString)` for forecast timestamps** — it breaks across timezones.
- Parse ISO strings with substring: `"2026-07-25T14:00"` → `split("T")[1].substring(0,5)` → `"14:00"` (see `isoToHM`, `formatHour` in ForecastItem).
- Day-of-week uses the Tomohiko Sakamoto algorithm (`formatDay` in ForecastItem), no `Date`.
- Current local time (for timer / "last updated") — `new Date().toLocaleTimeString(Qt.locale(), "hh:mm")` is fine.

---

## 8. Language of UI Strings

- The widget is **single-language**: all user-visible strings are **hardcoded Russian** by design. This is intentional, not an oversight.
- `i18n()` / `i18nc()` / `i18nd()` calls are **NOT used** anywhere in the code.
- There is **no locale pipeline**: no `contents/locale/` directory, no `.po`/`.pot`/`.mo` files, and `install.sh` does not run `msgfmt`.
- Do not add `i18n()` calls or a `locale/` directory piecemeal. Migrating to KDE i18n is **future work** and must be a dedicated task: extract all strings, set up the `.po` files and the build/install step, then rewrite this section.
- Until then, keep new user-visible strings hardcoded Russian, consistent with the rest of the UI.

---

## 9. Git Workflow (Mandatory)

- **Every change is committed.** Do not leave uncommitted changes hanging.
- **All work is done in a dedicated branch** off `master`. Branch names are short and descriptive (`feat/sunrise-metrics`, `fix/forecast-days-spinbox`, `docs/agent-rules`).
- Procedure:
  ```bash
  git checkout master && git pull               # get current master (if remote exists)
  git checkout -b <type>/<short-name>           # new branch
  # … edits, qmllint, tests per §10 …
  git add -A && git commit -m "<message>"       # may be multiple coherent commits
  git checkout master && git merge --no-ff <branch>   # merge into master
  git branch -d <branch>                        # delete merged branch
  ```
- Commit messages are meaningful; optional type prefix: `feat:`, `fix:`, `docs:`, `refactor:`.
- Merge into `master` **only after** passing lint and tests (see §10).
- If a remote exists, `git push` after merging.

## 10. Localization (Future Work)

There is currently **no translation pipeline**: no `contents/locale/` directory, no `.po`/`.pot` files, and `install.sh` does **not** compile anything with `msgfmt` — it only copies `package/` into the plasma plasmoids directory. UI strings are hardcoded Russian (see §8).

If localization is ever added, it must include:
1. Replacing all hardcoded strings with `i18n()`/`i18nc()` calls.
2. A `package/contents/locale/<lang>/LC_MESSAGES/plasmoid_<applet-id>.po` layout.
3. String extraction (`xgettext`) and `.po` → `.mo` compilation (`msgfmt`) wired into `install.sh`.
4. An update of this document.

Until then, do not expect — or "restore" — the locale pipeline in audits: it does not exist.

## 11. Documentation (Keep in Sync)

- Any behavior/feature change → **update documentation in the same commit**:
  - `README.md` — user-facing features, settings, list of metrics;
  - `AGENT.md` — if conventions, API, structure, or workflow change.
- New settings — mention in README (section "Settings") and in §12.
- New or changed user-visible strings stay hardcoded Russian (see §8) — there is no `.po` pipeline to update yet.
- Do not let code and docs drift out of sync: both describe the same state.

## 12. Definition of Done — Before Saying "It's Ready"

Say "done" is ready **only after**:

1. `qmllint package/contents/ui/*.qml` — no errors AND no warnings. **`qmllint` exits 0 even when it prints warnings**, so read its stdout — don't trust the exit code alone.
2. New/changed API fields verified with `curl` (names + format).
3. Installed: `./install.sh --user` + `plasmashell --replace &`.
4. Widget actually opened and tested visually/functionally:
   - current weather, joke, daily metrics, "Today" card, forecast;
   - all forecast modes: `daily`, `hourly`, `both`;
   - settings open, **values restore correctly** (especially SpinBox/ComboBox), save works;
   - unit switching (°C/°F, wind units) — no artifacts;
   - on network error — error card with "Retry" button.
5. Documentation updated (§11).
6. Changes committed and merged into `master` (§9).

If a step is not complete, the task is not done — do not say "ready".

## 13. Pre-Commit / PR Checklist

- [ ] `qmllint` clean on all `.qml` files.
- [ ] No hardcoded colors outside the theme; no `onValueChanged`/`onCheckedChanged` for `cfg_*`.
- [ ] New state properties declared on the `main.qml` root with `_` prefix and populated in `parseOpenMeteo`.
- [ ] Rounding/formatting done at source, not in UI.
- [ ] User-visible strings are hardcoded Russian (single-language widget; see §8 — no i18n yet).
- [ ] Network: `timeout`/`ontimeout`/`onerror` present; free API without key.
- [ ] New settings have 1:1 mapping `main.xml` ↔ `cfg_*`.
- [ ] README/AGENT updated.
- [ ] Tests per §12 passed.

## 14. How to Add a New Setting End-to-End

1. **`contents/config/main.xml`** — add `<entry name="<name>" type="Int|Double|String|Bool"><default>…</default></entry>` in the `General` group.
2. **`contents/ui/configGeneral.qml`**:
   - declare `property var cfg_<name>` and `property var cfg_<name>Default`;
   - add a control following §2 rules (direct binding + user-initiated signal);
   - use hardcoded Russian for all user-visible strings (labels, button text, tooltips) — see §8.
3. **`contents/ui/main.qml`** — read `plasmoid.configuration.<name>` (with `|| default` fallback), use in logic.
4. If needed, add a UI element in `FullRepresentation.qml` (hardcoded Russian strings, see §8).
5. **Test**: reinstall the package and **re-create the widget** (otherwise the new `main.xml` schema may not be picked up), check save/restore.
6. Update README (section "Settings").
7. Commit + merge per §9.

## 15. Anti-Patterns

- ❌ API keys, paid or token-requiring endpoints.
- ❌ `onValueChanged`/`onCheckedChanged` for writing `cfg_*` in settings.
- ❌ Rounding/formatting in the display layer (do it in `parseOpenMeteo`).
- ❌ `new Date(isoForecastString)` for forecast parsing.
- ❌ Hardcoded colors where a `Kirigami.Theme` equivalent exists.
- ❌ Network/parsing logic outside `main.qml`.
- ❌ Committing without `qmllint` and without testing (§12).
- ❌ Duplicate `visible:`/property in the same object (even if `qmllint` is silent — the engine will crash).
- ❌ **Property names beginning with an uppercase letter** (e.g. `RAIN_JOKES`) — the QML engine rejects them with "Property names cannot begin with an upper case letter". Always lowercase (`rainJokes`).
- ❌ Working directly in `master` or leaving uncommitted changes.
- ❌ Saying "ready" before passing §12.
- ❌ Mixing `i18n()` calls into the hardcoded-Russian UI — i18n is not used at all yet (see §8).

## 16. Useful Commands

```bash
qmllint package/contents/ui/*.qml                      # syntax check
./install.sh --user                                    # user-local install (copies package/)
plasmashell --replace &                                # restart shell
git checkout -b feat/<name>                            # branch for a task
git add -A && git commit -m "feat: …"                  # commit
git checkout master && git merge --no-ff feat/<name>   # merge into master
curl -s "https://api.open-meteo.com/v1/forecast?latitude=55.75&longitude=37.62&daily=sunrise,sunset&timezone=Europe/Moscow&forecast_days=1"
```
