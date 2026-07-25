# Open-Meteo Weather — KDE Plasma 6 Plasmoid

Виджет погоды для KDE Plasma 6, использующий **бесплатный** API [Open-Meteo](https://open-meteo.com).

> **Не требует API-ключа.** Просто установите и пользуйтесь.

## Возможности

- 🌡 Текущая температура, «ощущается как», влажность, давление, облачность
- 💨 Скорость и направление ветра
- 📅 Прогноз до 16 дней: макс./мин. температура, вероятность осадков
- 📌 Компактный вид для панели (эмодзи + температура)
- 🖥 Развёрнутый вид с деталями и прогнозом
- 🔄 Автообновление (настраиваемый интервал)
- 🇷🇺 Русские названия погодных условий и направлений ветра
- 🌍 Настраиваемые единицы измерения (°C/°F, m/s/kmh/mph/kn)
- 🕐 Поддержка часовых поясов
- 🎨 Вписывается в тему Plasma (Kirigami)

## Требования

- **KDE Plasma 6** (или Plasma 5 с `metadata.desktop`)
- Подключение к интернету
- **Бесплатно** — API-ключ не требуется!

## Установка

```bash
# Для текущего пользователя
./install.sh --user

# Системная установка (требует sudo)
./install.sh --system
```

Перезапустите plasmashell:

```bash
plasmashell --replace &
```

## Настройка

1. Добавьте виджет: ПКМ по панели → **Add Widgets** → **Environment & Weather** → **Open-Meteo Weather**
2. ПКМ по виджету → **Configure...**:
   - **City name** — название города (для отображения)
   - **Latitude / Longitude** — координаты (Москва: 55.75, 37.62)
   - **Timezone** — часовой пояс (Europe/Moscow, Asia/Yekaterinburg, ...)
   - **Update interval** — интервал обновления (5–180 минут)
   - **Temperature unit** — °C или °F
   - **Wind speed unit** — m/s, km/h, mph, knots
   - **Forecast days** — до 16 дней

## Структура проекта

```
package/
├── metadata.json                     # Метаданные (Plasma 6 JSON)
├── contents/
│   ├── ui/
│   │   ├── main.qml                  # Точка входа + Open-Meteo API логика
│   │   ├── CompactRepresentation.qml  # Компактный вид (панель)
│   │   ├── FullRepresentation.qml    # Развёрнутый вид
│   │   ├── ForecastItem.qml          # День прогноза
│   │   ├── DetailItem.qml            # Строка с иконкой
│   │   └── configGeneral.qml         # Страница настроек
│   └── config/
│       ├── config.qml                # Вкладки конфигурации
│       └── main.xml                  # Схема KConfig XT
└── install.sh                        # Установочный скрипт
```

## Как это работает

Чистый **QML + JavaScript** — без Python, C++ или внешних зависимостей:

1. `main.qml` содержит таймер, HTTP-запросы к `api.open-meteo.com/v1/forecast` через `XMLHttpRequest`, парсинг JSON
2. Запрашиваются `current` (текущая погода) и `daily` (прогноз) переменные
3. WMO-коды погоды (0–99) преобразуются в текст и эмодзи
4. Давление конвертируется из гПа в мм рт. ст.
5. Направление ветра из градусов — в русские обозначения (С, СВ, ЮЗ, ...)
6. UI-компоненты автоматически обновляются через QML data binding

## Open-Meteo API

- **Эндпоинт:** `https://api.open-meteo.com/v1/forecast`
- **Бесплатно** для некоммерческого использования
- До **10 000 запросов/день** бесплатно
- Модели: GFS, ECMWF, MeteoFrance, JMA, ...
- [Документация](https://open-meteo.com/en/docs)

## Лицензия

MIT. Данные погоды: [open-meteo.com](https://open-meteo.com) (CC BY 4.0)
