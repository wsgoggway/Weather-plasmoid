# AGENT.md — правила для агента (Open-Meteo Weather Plasmoid)

Виджет погоды для **KDE Plasma 6** на чистом QML/JS. Бесплатные API без ключей.
Все пояснения ниже — на русском (язык проекта), идентификаторы/код — на английском.

---

## 0. Что это

- **Плазмоид (applet) Plasma 6**, структура пакета `KPackageStructure: Plasma/Applet`.
- Id: `com.github.vladimirm.openmeteo-weather`.
- **Без C++/Python/компиляции.** Только QML + JavaScript + JSON-метаданные.
- Источник погоды — **Open-Meteo** (без ключа). Геолокация по городу — Open-Meteo Geocoding, по IP — ip-api/ipwhois, «этот день в истории» — Wikipedia REST (ru).

---

## 1. Структура

```
package/
├── metadata.json                 # метаданные Plasma 6 (Id, Version, KPlugin)
└── contents/
    ├── ui/
    │   ├── main.qml              # корень (PlasmoidItem): состояние, сеть, парсинг
    │   ├── CompactRepresentation.qml   # вид в панели (emoji + temp)
    │   ├── FullRepresentation.qml      # развёрнутый popup (карточная вёрстка)
    │   ├── ForecastItem.qml       # карточка прогноза (daily/hourly)
    │   ├── DetailRow.qml          # строка детализации (icon + label + value)
    │   └── configGeneral.qml      # страница настроек (KCM.SimpleKCM)
    └── config/
        ├── config.qml            # ConfigModel → одна категория «Основные»
        └── main.xml              # схема KConfig XT (типы + дефолты)
install.sh                        # копирует package/ в plasma/plasmoids/<Id>
```

- `main.qml` (`PlasmoidItem { id: root }`) — **единственный источник истины** для состояния и логики.
- `FullRepresentation` / `CompactRepresentation` получают `plasmoidItem: root` автоматически; читают `plasmoidItem._*` свойства. Логики сети/парсинга в них быть не должно.

---

## 2. ⚠️ Главное правило: настройки (Plasma 6 KCM)

Баг, который уже был и не должен вернуться: **`onValueChanged`/`onCheckedChanged` перетирают загруженные значения при инициализации.**

В `configGeneral.qml`:

| Контрол | Значение из конфига | Запись обратно |
|---|---|---|
| `SpinBox` | `value: cfg_x` | `onValueModified: cfg_x = value` |
| `ComboBox` | `currentIndex: {…поиск по model…}` | `onActivated: cfg_x = model[currentIndex].value` |
| `CheckBox` | `checked: cfg_x !== false` | `onToggled: cfg_x = checked` |
| `TextField` (текст) | `onTextEdited` + синхрон в `Component.onCompleted` | `onTextEdited: cfg_x = text` |
| `TextField` (число, lat/lon) | **НЕ** биндить `text:` напрямую (будет мешать вводу «55.») | `onTextEdited: cfg_x = parseFloat(text)` |

- Писать обратно **только** через пользовательские сигналы: `onValueModified`, `onActivated`, `onToggled`, `onTextEdited`. Никогда — `onValueChanged`/`onCheckedChanged`.
- Связка 1:1: каждому `cfg_<name>` в QML соответствует `<entry name="<name>">` в `main.xml`.
- В QML объявлять и `property var cfg_<name>`, и `property var cfg_<name>Default` (KCM авто-связывает оба).

---

## 3. Модель состояния в `main.qml`

- Всё состояние — `property` на корне с префиксом `_` (напр. `_currentTemp`, `_forecasts`, `_sunrise`).
- Сеть → `parseOpenMeteo(data)` единожды проставляет **все** свойства. UI их только читает.
- **Преобразования и округление — в источнике** (`parseOpenMeteo`), не в биндингах отображения. Температуры — `Math.round()` сразу при парсинге.
- Давление: гПа → мм рт. ст. через `* 0.75006`.
- Шутку «ощущается» пересчитываем в `parseOpenMeteo` → `_feelsJokeText` (один раз за обновление, чтобы не дёргалась при ререндерах).

---

## 4. Сеть

- Только `XMLHttpRequest` (QML не применяет CORS — кросс-доменные запросы ок).
- Обязательно: `xhr.timeout`, `xhr.ontimeout`, `xhr.onerror`, проверка `readyState === DONE` и `status === 200`.
- **Только бесплатные API без ключей.** Запрещено добавлять эндпоинты, требующие ключи/токены.
- Разрешённые источники:
  - `api.open-meteo.com/v1/forecast` — погода
  - `geocoding-api.open-meteo.com/v1/search` — город → координаты
  - `ip-api.com/json/` (http) + `ipwhois.app/json/` (фолбэк) — геолокация по IP
  - `ru.wikipedia.org/api/rest_v1/feed/onthisday/events/MM/DD` — события дня (ru)
- Перед использованием нового поля API — **проверить `curl`-ом** точное имя и формат (напр. `uv_index_max`, `precipitation_sum`).

---

## 5. Формирование запроса Open-Meteo

- `current` всегда; метрики дня (`sunrise,sunset,uv_index_max,precipitation_sum`) — **всегда**, независимо от режима прогноза.
- Поля прогноза по дням (`weather_code,temperature_2m_max,...`) — только если `wantDaily`.
- Массив дневного прогноза собирать **только если есть `daily.weather_code`** (guard), иначе при `forecastMode=hourly` получим мусор.
- Почасовой прогноз фильтруем от текущего часа (`currentTime.substring(0,13)`), лимит 48 точек.

---

## 6. UI / вёрстка

- **Карточный стиль**: `Rectangle { color: Kirigami.Theme.alternateBackgroundColor; radius: Math.round(Kirigami.Units.largeSpacing*0.8) }`. `ForecastItem` тоже имеет карточный фон.
- Цвета — **только из темы**: `alternateBackgroundColor` (карточки), `disabledTextColor` (приглушённый), `highlightColor` (акцент), `negativeTextColor` (ошибки). Хардкод цветов — только мелкие эмодзи-акценты.
- `FullRepresentation` обёрнут в `Flickable` (`boundsBehavior: StopAtBounds`) — контент скроллится.
- Hero-блок — **центрированная колонка** (`Layout.alignment: Qt.AlignHCenter`), не прижат влево.
- Размеры — через `Kirigami.Units.gridUnit`, отступы — `largeSpacing`/`smallSpacing`.
- Импорты (эталонный набор):
  ```
  import QtQuick 2.15
  import QtQuick.Layouts 1.15
  import QtQuick.Controls 2.15
  import org.kde.plasma.components 3.0 as PlasmaComponents
  import org.kde.plasma.plasmoid 2.0
  import org.kde.kirigami 2.20 as Kirigami
  ```
- У `ToolButton` без текста **не** ставить `display:` — лишнее и рискованно с enum Plasma-типов.

---

## 7. Даты и время (timezone-safe)

- **Не использовать `new Date(isoString)` для прогнозных меток** — ломается на часовых поясах.
- Парсить ISO подстрокой: `"2026-07-25T14:00"` → `split("T")[1].substring(0,5)` → `"14:00"` (см. `isoToHM`, `formatHour` в ForecastItem).
- День недели — алгоритм Томохико Сакамото (`formatDay` в ForecastItem), без `Date`.
- Текущее локальное время (для таймера/«обновлено в») — `new Date().toLocaleTimeString(Qt.locale(), "hh:mm")` — ок.

---

## 8. Контент и язык

- Весь интерфейс — **на русском**.
- WMO-коды (0–99) → emoji + русское описание через карту `wmoInfo()` в `main.qml`.
- Направление ветра (градусы) → русские румбы (`windDegToCompass()`): С, СВ, ЮЗ…
- Праздники — оффлайн-словарь `holidaysForMonthDay()` (без сети).
- Шутки «ощущается как» — **язвительные**, массивы вариантов по диапазонам в `feelsLikeJoke()`, случайный выбор. Температуру нормализуем в °C для сравнения (учёт °F).

---

## 9. Git workflow (обязательно)

- **Каждое изменение фиксируется коммитом.** Не оставлять незафиксированных правок «в воздухе».
- **Вся работа — в отдельной ветке** от `master`. Имя ветки — краткое и описательное (`feat/sunrise-metrics`, `fix/forecast-days-spinbox`, `docs/agent-rules`).
- Порядок:
  ```bash
  git checkout master && git pull               # актуальный master (если есть remote)
  git checkout -b <тип>/<кратко>                # новая ветка
  # … правки, qmllint, тесты по §11 …
  git add -A && git commit -m "<сообщение>"     # можно несколько логичных коммитов
  git checkout master && git merge --no-ff <ветка>   # влить в master
  git branch -d <ветка>                         # удалить слитую ветку
  ```
- Сообщения коммитов — осмысленные; префикс типа по желанию: `feat:`, `fix:`, `docs:`, `refactor:`.
- Сливать в `master` **только после** прохождения линта и тестов (см. §11).
- При наличии remote — `git push` после слияния.

## 10. Документация (держим в синхроне)

- Любое изменение поведения/функционала → **обновить документацию в том же коммите**:
  - `README.md` — пользовательские возможности, настройки, список метрик;
  - `AGENT.md` — если меняются соглашения, API, структура или workflow.
- Новую настройку — упомянуть в README (раздел «Настройка») и в §13.
- Не оставлять рассинхрон: код и текст описывают одно и то же состояние.

## 11. Definition of Done — перед словами «всё готово»

Говорить, что готово, **только после**:

1. `qmllint package/contents/ui/*.qml` — без ошибок.
2. Новые/изменённые поля API проверены `curl`-ом (имена + формат).
3. Установлено: `./install.sh --user` + `plasmashell --replace &`.
4. Виджет реально открыт и проверен визуально/функционально:
   - текущая погода, шутка, метрики дня, карточка «Сегодня», прогноз;
   - все режимы прогноза: `daily`, `hourly`, `both`;
   - настройки открываются, **значения восстанавливаются корректно** (особенно SpinBox/ComboBox), сохраняются;
   - переключение единиц (°C/°F, единицы ветра) — без артефактов;
   - при ошибке сети — карточка ошибки с «Повторить».
5. Документация обновлена.
6. Изменения закоммичены и слиты в `master` (§9).

Пока пункт не пройден — задача не завершена, «готово» не говорить.

## 12. Чеклист перед коммитом/PR

- [ ] `qmllint` чист по всем `.qml`.
- [ ] Нет хардкод-цветов вне темы; нет `onValueChanged`/`onCheckedChanged` для `cfg_*`.
- [ ] Новые свойства состояния объявлены на корне `main.qml` с префиксом `_` и проставляются в `parseOpenMeteo`.
- [ ] Округление/формат — в источнике, не в UI.
- [ ] Сеть: `timeout`/`ontimeout`/`onerror` есть; бесплатный API без ключа.
- [ ] Новые настройки связаны 1:1 `main.xml` ↔ `cfg_*`.
- [ ] README/AGENT обновлены.
- [ ] Тест по §11 пройден.

## 13. Как добавить новую настройку end-to-end

1. **`contents/config/main.xml`** — добавить `<entry name="<name>" type="Int|Double|String|Bool"><default>…</default></entry>` в группу `General`.
2. **`contents/ui/configGeneral.qml`**:
   - объявить `property var cfg_<name>` и `property var cfg_<name>Default`;
   - добавить контрол по правилам §2 (прямой биндинг + пользовательский сигнал).
3. **`contents/ui/main.qml`** — читать `plasmoid.configuration.<name>` (с фолбэком `|| default`), использовать в логике.
4. При необходимости — UI-элемент в `FullRepresentation.qml`.
5. **Тест**: переустановить пакет и **пересоздать виджет** (иначе новая схема `main.xml` может не подхватиться), проверить сохранение/восстановление значения.
6. Обновить README (раздел «Настройка»).
7. Коммит + merge по §9.

## 14. Антипаттерны

- ❌ API-ключи, платные/требующие токены эндпоинты.
- ❌ `onValueChanged`/`onCheckedChanged` для записи `cfg_*` в настройках.
- ❌ Округление/форматирование в слое отображения (делать в `parseOpenMeteo`).
- ❌ `new Date(isoForecastString)` для разбора прогноза.
- ❌ Хардкод цветов там, где есть аналог в `Kirigami.Theme`.
- ❌ Логика сети/парсинга вне `main.qml`.
- ❌ Коммитить без `qmllint` и без теста (§11).
- ❌ Дубликат `visible:`/свойства в одном объекте (даже если `qmllint` промолчал — движок упадёт).
- ❌ Работать напрямую в `master` или оставлять незафиксированные правки.
- ❌ Говорить «готово» до прохождения §11.

## 15. Полезные команды

```bash
qmllint package/contents/ui/*.qml                      # проверка синтаксиса
./install.sh --user                                    # установка пользователю
plasmashell --replace &                                # перезапуск оболочки
git checkout -b feat/<name>                            # ветка для задачи
git add -A && git commit -m "feat: …"                  # зафиксировать
git checkout master && git merge --no-ff feat/<name>   # влить в master
curl -s "https://api.open-meteo.com/v1/forecast?latitude=55.75&longitude=37.62&daily=sunrise,sunset&timezone=Europe/Moscow&forecast_days=1"
```
