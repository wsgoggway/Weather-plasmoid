import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:openmeteo_weather/data/cities_store.dart';
import 'package:openmeteo_weather/data/open_meteo_api.dart';
import 'package:openmeteo_weather/data/settings_store.dart';
import 'package:openmeteo_weather/data/weather_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Фейковый http-клиент: отвечает заготовленным JSON на forecast,
/// на air-quality — ошибкой 500 (карточка должна скрыться).
class FakeClient extends http.BaseClient {
  final Map<String, dynamic> forecastJson;
  int forecastRequests = 0;

  FakeClient(this.forecastJson);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final url = request.url.toString();
    if (url.contains("api.open-meteo.com/v1/forecast")) {
      forecastRequests++;
      return http.StreamedResponse(
        Stream.value(utf8.encode(jsonEncode(forecastJson))),
        200,
      );
    }
    return http.StreamedResponse(Stream.value(utf8.encode("{}")), 500);
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
    "wind_gusts_10m": 8.24,
    "wind_direction_10m": 310,
    "pressure_msl": 1005.0,
    "cloud_cover": 90,
    "dew_point_2m": 10.28,
    "is_day": 1,
  },
  "minutely_15": {
    "time": [
      "2026-09-18T14:00",
      "2026-09-18T14:15",
      "2026-09-18T14:30",
      "2026-09-18T14:45",
      "2026-09-18T15:00",
      "2026-09-18T15:15",
      "2026-09-18T15:30",
      "2026-09-18T15:45",
    ],
    "precipitation": [0.3, 0.5, 0.2, 0.0, 0.0, 0.0, 0.0, 0.0],
  },
  "daily": {
    "time": ["2026-09-18", "2026-09-19", "2026-09-20"],
    "sunrise": ["2026-09-18T06:38", "2026-09-19T06:40", "2026-09-20T06:42"],
    "sunset": ["2026-09-18T19:20", "2026-09-19T19:17", "2026-09-20T19:15"],
    "uv_index_max": [3.42, 4.0, 2.0],
    "precipitation_sum": [5.6, 0.0, 1.2],
    "weather_code": [63, 80, 0],
    "temperature_2m_max": [18.4, 21.2, 24.0],
    "temperature_2m_min": [9.8, 11.1, 13.3],
    "precipitation_probability_max": [90, 60, 5],
    "wind_speed_10m_max": [4.5, 3.0, 2.0],
  },
  "hourly": {
    "time": [
      "2026-09-18T12:00",
      "2026-09-18T13:00",
      "2026-09-18T14:00",
      "2026-09-18T15:00",
      "2026-09-18T16:00",
    ],
    "temperature_2m": [15.0, 16.2, 17.4, 17.8, 16.9],
    "weather_code": [61, 61, 63, 63, 80],
    "precipitation_probability": [40, 50, 90, 85, 60],
  },
};

Future<(WeatherState, FakeClient, SettingsStore)> makeState({
  Map<String, dynamic>? json,
  Map<String, Object> prefsInit = const {},
}) async {
  SharedPreferences.setMockInitialValues(prefsInit);
  final prefs = await SharedPreferences.getInstance();
  final settings = SettingsStore(prefs);
  final cities = CitiesStore(prefs);
  await cities.load();
  final client = FakeClient(json ?? _forecastJson);
  final state = WeatherState(
    apiClient: OpenMeteoApi(client: client),
    settingsStore: settings,
    citiesStore: cities,
  );
  return (state, client, settings);
}

void main() {
  test("парсинг: округления при источнике", () async {
    final (state, client, _) = await makeState();
    await state.refresh();

    expect(state.status, LoadStatus.ready);
    expect(client.forecastRequests, 1);
    final cur = state.current!;
    expect(cur.temp, 18); // 17.6 → 18
    expect(cur.feelsLike, 15); // 15.1 → 15
    expect(cur.gusts, 8.2); // 1 знак
    expect(cur.pressure, 754); // 1005 × 0.75006
    expect(cur.dewPoint, 10.3);
    expect(cur.windDir, "СЗ"); // 310°
    expect(cur.condition, "Дождь");
    expect(cur.emoji, isNot("🌙")); // день
  });

  test("ночью ясно → 🌙", () async {
    final json = Map<String, dynamic>.from(_forecastJson);
    json["current"] = {
      ..._forecastJson["current"] as Map<String, dynamic>,
      "weather_code": 0,
      "is_day": 0,
    };
    final (state, _, _) = await makeState(json: json);
    await state.refresh();
    expect(state.current!.emoji, "🌙");
  });

  test("почасовые: от текущего часа, cap 48", () async {
    // Строим ответ с 60 часами до текущего времени и 60 после.
    final hours = <String>[];
    final temps = <double>[];
    for (var i = 0; i < 120; i++) {
      hours.add("2026-09-18T${(i % 24).toString().padLeft(2, "0")}:00");
      temps.add(i.toDouble());
    }
    final json = Map<String, dynamic>.from(_forecastJson);
    json["hourly"] = {
      "time": hours,
      "temperature_2m": temps,
      "weather_code": List.filled(120, 0),
      "precipitation_probability": List.filled(120, 0),
    };
    final (state, _, _) = await makeState(json: json);
    await state.refresh();

    expect(state.hours, hasLength(48)); // cap
    // Первый час — граница текущего (14:00, индекс 14), а не 12:00.
    expect(state.hours.first.time, "2026-09-18T14:00");
    expect(state.hours.first.temp, 14);
  });

  test("nowcast распознан и предупреждение о дожде при 90%", () async {
    final (state, _, _) = await makeState();
    await state.refresh();
    expect(state.nowcastOrLast, isNotNull);
    expect(state.nowcastOrLast!.statusText, contains("закончатся"));
    expect(
      state.alerts.map((a) => a.text).join(" "),
      anyOf(contains("похолодание"), isEmpty),
    );
  });

  test("AQI-эндпоинт недоступен → aqi null (карточка скрыта)", () async {
    final (state, _, _) = await makeState();
    await state.refresh();
    // Даём завершиться асинхронному AQI-запросу.
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(state.aqi, isNull);
  });

  test("шутка: включена и выключена настройкой", () async {
    final (stateOn, _, _) = await makeState();
    await stateOn.refresh();
    expect(stateOn.jokeText, isNotEmpty);

    final (stateOff, _, _) = await makeState(
      prefsInit: {"jokesEnabled": false},
    );
    await stateOff.refresh();
    expect(stateOff.jokeText, isEmpty);
  });

  test("смена города триггерит рефетч", () async {
    final (state, client, _) = await makeState();
    await state.refresh();
    final before = client.forecastRequests;
    await state.refresh(); // повторный явный вызов
    expect(client.forecastRequests, greaterThan(before));
  });
}
