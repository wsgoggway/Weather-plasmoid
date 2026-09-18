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
    "sunrise": [
      "2026-09-18T06:38",
      "2026-09-19T06:40",
      "2026-09-20T06:42",
      "2026-09-21T06:44",
    ],
    "sunset": [
      "2026-09-18T19:20",
      "2026-09-19T19:17",
      "2026-09-20T19:15",
      "2026-09-21T19:13",
    ],
    "uv_index_max": [3.4, 4.0, 2.0, 2.0],
    "precipitation_sum": [5.6, 0.0, 1.2, 0.0],
    "weather_code": [63, 80, 0, 1],
    "temperature_2m_max": [18.4, 21.2, 24.0, 22.0],
    "temperature_2m_min": [9.8, 11.1, 13.3, 12.0],
    "precipitation_probability_max": [90, 60, 5, 10],
    "wind_speed_10m_max": [4.5, 3.0, 2.0, 2.0],
  },
  "hourly": {
    "time": ["2026-09-18T14:00", "2026-09-18T15:00"],
    "temperature_2m": [17.4, 17.8],
    "weather_code": [63, 63],
    "precipitation_probability": [90, 85],
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
  test("buildData: основные поля виджета", () async {
    final state = await makeState();
    final data = WidgetSync.buildData(state);

    expect(data["emoji"], "🌧️"); // код 63
    expect(data["temp"], "18°");
    expect(data["city"], "Москва");
    expect(data["condition"], "Дождь");
    expect(data["details"], "Ощущается 15°C · 💧90%");
    expect(data["updated"], contains("Обновлено в "));
  });

  test("buildData: три колонки прогноза с подписями дней", () async {
    final state = await makeState();
    final data = WidgetSync.buildData(state);

    expect(data["d0_label"], "Сегодня");
    expect(data["d0"], "🌧️ 18°/10°"); // 9.8 → 10
    expect(data["d1_label"], "Завтра");
    expect(data["d1"], "🌦️ 21°/11°"); // VS16 из маппинга
    // 2026-09-20 — воскресенье.
    expect(data["d2_label"], "Вс");
    expect(data["d2"], "☀️ 24°/13°");
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
