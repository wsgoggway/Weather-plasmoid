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
    "weather_code": 0,
    "wind_speed_10m": 3.7,
    "wind_gusts_10m": 8.2,
    "wind_direction_10m": 310,
    "pressure_msl": 1005.0,
    "cloud_cover": 10,
    "dew_point_2m": 10.3,
    "is_day": 1,
  },
  "daily": {
    "time": ["2026-09-18", "2026-09-19", "2026-09-20", "2026-09-21"],
    "sunrise": ["2026-09-18T06:38", "2026-09-19T06:40", "2026-09-20T06:42", "2026-09-21T06:44"],
    "sunset": ["2026-09-18T19:20", "2026-09-19T19:17", "2026-09-20T19:15", "2026-09-21T19:13"],
    "uv_index_max": [3.4, 4.0, 2.0, 2.0],
    "precipitation_sum": [5.6, 0.0, 1.2, 0.0],
    "weather_code": [0, 80, 0, 1],
    "temperature_2m_max": [18.4, 21.2, 24.0, 22.0],
    "temperature_2m_min": [9.8, 11.1, 13.3, 12.0],
    "precipitation_probability_max": [90, 60, 5, 10],
    "wind_speed_10m_max": [4.5, 3.0, 2.0, 2.0],
  },
  "hourly": {
    "time": [
      "2026-09-18T14:00", "2026-09-18T15:00", "2026-09-18T16:00",
      "2026-09-18T17:00", "2026-09-18T18:00", "2026-09-18T19:00",
      "2026-09-18T20:00", "2026-09-18T21:00",
    ],
    "temperature_2m": [17.4, 17.8, 17.1, 16.0, -0.4, -3.0, -5.0, -7.0],
    "weather_code": [0, 0, 0, 0, 1, 2, 3, 3],
    "precipitation_probability": [10, 10, 10, 10, 10, 10, 20, 20],
  },
};

Future<WeatherState> makeState({
  Map<String, dynamic>? json,
  Map<String, Object> prefsInit = const {},
}) async {
  SharedPreferences.setMockInitialValues(prefsInit);
  final prefs = await SharedPreferences.getInstance();
  final settings = SettingsStore(prefs);
  final cities = CitiesStore(prefs);
  await cities.load();
  final state = WeatherState(
    apiClient: OpenMeteoApi(client: FakeClient(json ?? _forecastJson)),
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

    test("дневные темы светлые, ночь тёмная", () {
      expect(WidgetSync.widgetThemeKey(0, true), "clear_day");
      expect(WidgetSync.widgetThemeKey(0, false), "clear_night");
      expect(WidgetSync.widgetThemeKey(1, true), "partly");
      expect(WidgetSync.widgetThemeKey(2, false), "clear_day");
      expect(WidgetSync.widgetThemeKey(3, true), "cloud");
      expect(WidgetSync.widgetThemeKey(63, true), "rain");
    });
  });

  test("buildData: герой по референсу — плюс перед температурой", () async {
    final state = await makeState();
    final data = WidgetSync.buildData(state);

    // Ясный день: 17.6 → 18, 15.1 → 15, код 0 → sun/clear_day, светлая палитра.
    expect(data["palette"], "light");
    expect(data["theme"], "clear_day");
    expect(data["icon"], "sun");
    expect(data["temp"], "+18°");
    expect(data["city"], "Москва");
    expect(data["condition"], "Ясно");
    expect(data["feels"], "Ощущается как +15°");
  });

  test("buildData: ночь — тёмная палитра, луна", () async {
    final json = Map<String, dynamic>.from(_forecastJson);
    json["current"] = {
      ..._forecastJson["current"] as Map<String, dynamic>,
      "is_day": 0,
    };
    final state = await makeState(json: json);
    final data = WidgetSync.buildData(state);

    expect(data["palette"], "dark");
    expect(data["icon"], "moon");
    expect(data["theme"], "clear_night");
  });

  test("buildData: 7 колонок почасовой полосы", () async {
    final state = await makeState();
    final data = WidgetSync.buildData(state);

    expect(data["h0_time"], "14:00"); // первый час — полностью
    expect(data["h0_icon"], "sun");
    expect(data["h0_temp"], "+17°");
    expect(data["h1_time"], "15");
    expect(data["h4_temp"], "0°"); // -0.4 → 0, без плюса
    expect(data["h5_temp"], "-3°");
    expect(data["h6_temp"], "-5°");
  });

  test("buildData: часы кончились — ключи пустые, не устаревшие", () async {
    final state = await makeState();
    state.hours = const [
      HourItem(time: "2026-09-18T14:00", wmo: 0, temp: 17, emoji: "☀️", condition: "Ясно", precProb: 10),
    ];
    final data = WidgetSync.buildData(state);

    expect(data["h0_temp"], "+17°");
    expect(data["h1_time"], "");
    expect(data["h1_temp"], "");
    expect(data["h6_temp"], "");
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
