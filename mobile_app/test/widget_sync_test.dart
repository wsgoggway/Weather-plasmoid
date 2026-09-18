import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:openmeteo_weather/data/cities_store.dart';
import 'package:openmeteo_weather/data/open_meteo_api.dart';
import 'package:openmeteo_weather/data/settings_store.dart';
import 'package:openmeteo_weather/data/weather_state.dart';
import 'package:openmeteo_weather/data/widget_sync.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeClient extends http.BaseClient {
  final Map<String, dynamic> forecastJson;
  FakeClient(this.forecastJson);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    return http.StreamedResponse(
      Stream.value(utf8.encode(jsonEncode(forecastJson))),
      200,
    );
  }
}

const _forecastJson = {
  "current": {
    "time": "2026-09-18T14:23",
    "temperature_2m": 17.6,
    "apparent_temperature": 15.1,
    "relative_humidity_2m": 62,
    "weather_code": 63,
    "wind_speed_10m": 3.7,
    "wind_gusts_10m": 8.2,
    "wind_direction_10m": 310,
    "pressure_msl": 1005.0,
    "cloud_cover": 90,
    "dew_point_2m": 10.3,
    "is_day": 1,
  },
  "daily": {
    "time": ["2026-09-18", "2026-09-19", "2026-09-20", "2026-09-21"],
    "sunrise": ["2026-09-18T06:38", "2026-09-19T06:40", "2026-09-20T06:42", "2026-09-21T06:44"],
    "sunset": ["2026-09-18T19:20", "2026-09-19T19:17", "2026-09-20T19:15", "2026-09-21T19:13"],
    "uv_index_max": [3.4, 4.0, 2.0, 2.0],
    "precipitation_sum": [5.6, 0.0, 1.2, 0.0],
    "weather_code": [63, 80, 0, 1],
    "temperature_2m_max": [18.4, 21.2, 24.0, 22.0],
    "temperature_2m_min": [9.8, 11.1, 13.3, 12.0],
    "precipitation_probability_max": [90, 60, 5, 10],
    "wind_speed_10m_max": [4.5, 3.0, 2.0, 2.0],
  },
  "hourly": {
    "time": ["2026-09-18T14:00", "2026-09-18T15:00", "2026-09-18T16:00"],
    "temperature_2m": [17.4, 17.8, 17.1],
    "weather_code": [63, 61, 3],
    "precipitation_probability": [90, 85, 40],
  },
};

Future<WeatherState> makeState() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final settings = SettingsStore(prefs);
  final cities = CitiesStore(prefs);
  await cities.load();
  final state = WeatherState(
    apiClient: OpenMeteoApi(client: FakeClient(_forecastJson)),
    settingsStore: settings,
    citiesStore: cities,
  );
  await state.refresh();
  return state;
}

void main() {
  group("ключи иконки/темы виджета", () {
    test("погода и время суток", () {
      expect(WidgetSync.widgetIconKey(0, true), "sun");
      expect(WidgetSync.widgetIconKey(0, false), "moon");
      expect(WidgetSync.widgetIconKey(1, true), "partly");
      expect(WidgetSync.widgetIconKey(2, false), "partly_night");
      expect(WidgetSync.widgetIconKey(3, true), "cloud");
      expect(WidgetSync.widgetIconKey(63, true), "rain");
      expect(WidgetSync.widgetIconKey(71, true), "snow");
      expect(WidgetSync.widgetIconKey(95, true), "storm");
      expect(WidgetSync.widgetIconKey(45, true), "fog");
    });

    test("фоновые градиенты", () {
      expect(WidgetSync.widgetThemeKey(0, true), "clear_day");
      expect(WidgetSync.widgetThemeKey(0, false), "clear_night");
      expect(WidgetSync.widgetThemeKey(1, true), "partly");
      expect(WidgetSync.widgetThemeKey(2, false), "clear_night");
      expect(WidgetSync.widgetThemeKey(3, true), "cloud");
      expect(WidgetSync.widgetThemeKey(63, true), "rain");
      expect(WidgetSync.widgetThemeKey(95, true), "storm");
      expect(WidgetSync.widgetThemeKey(45, true), "fog");
    });
  });

  test("buildData: герой + hi/lo + тема", () async {
    final state = await makeState();
    final data = WidgetSync.buildData(state);

    expect(data["theme"], "rain"); // код 63
    expect(data["icon"], "rain");
    expect(data["temp"], "18°");
    expect(data["city"], "Москва");
    expect(data["condition"], "Дождь");
    expect(data["feels"], "Ощущается 15°C");
    expect(data["hi"], "↑18°"); // 18.4 → 18
    expect(data["lo"], "↓10°"); // 9.8 → 10
    expect(data["updated"], contains("Обновлено в "));
  });

  test("buildData: три дня — иконка + цветные max/min", () async {
    final state = await makeState();
    final data = WidgetSync.buildData(state);

    expect(data["d0_label"], "Сегодня");
    expect(data["d0_icon"], "rain");
    expect(data["d0_max"], "18°");
    expect(data["d0_min"], "10°");
    expect(data["d1_label"], "Завтра");
    expect(data["d1_icon"], "rain"); // код 80 — ливень
    expect(data["d2_label"], "Вс"); // 2026-09-20 — воскресенье
    expect(data["d2_icon"], "sun"); // код 0
  });

  test("buildData: почасовая лента — Сейчас + 4 часа, ночная иконка", () async {
    final state = await makeState();
    final data = WidgetSync.buildData(state);

    expect(data["h0_time"], "Сейчас");
    expect(data["h0_icon"], "rain"); // код 63
    expect(data["h0_temp"], "17°");
    expect(data["h1_time"], "15"); // "2026-09-18T15:00"
    expect(data["h2_icon"], "cloud"); // код 3
    // Дополнительные колонки без данных — пустые.
    expect(data["h3_time"], "");
    expect(data["h3_temp"], "");
  });

  test("buildData: метрики плитками «значение + подпись»", () async {
    final state = await makeState();
    final data = WidgetSync.buildData(state);

    expect(data["mv0"], "3.7 м/с");
    expect(data["ml0"], "Ветер");
    expect(data["mv1"], "62%");
    expect(data["ml1"], "Влажность");
    expect(data["mv2"], "754 мм");
    expect(data["ml2"], "Давление");
    expect(data["mv3"], "3"); // 3.4 → 3
    expect(data["ml3"], "УФ-индекс");
  });

  test("buildData: часы кончились — ключи пустые, не устаревшие", () async {
    final state = await makeState();
    // Единственный час в ответе — остальные 4 колонки должны очиститься.
    state.hours = const [
      HourItem(time: "2026-09-18T14:00", wmo: 63, temp: 17, emoji: "🌧️", condition: "Дождь", precProb: 90),
    ];
    final data = WidgetSync.buildData(state);

    expect(data["h0_temp"], "17°");
    expect(data["h1_time"], "");
    expect(data["h1_temp"], "");
    expect(data["h4_temp"], "");
  });

  test("buildData: без данных — пустой словарь (виджет не трогаем)", () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final state = WeatherState(
      apiClient: OpenMeteoApi(client: FakeClient(_forecastJson)),
      settingsStore: SettingsStore(prefs),
      citiesStore: CitiesStore(prefs),
    );
    expect(WidgetSync.buildData(state), isEmpty);
  });
}
