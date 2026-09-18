/// Клиент Open-Meteo: прогноз + nowcast (minutely_15), качество воздуха,
/// геокодинг. Без ключей, те же эндпоинты, что у виджета (main.qml:428-514).
library;

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'settings_store.dart';

class GeocodeResult {
  final String name;
  final String country;
  final String admin1;
  final double lat;
  final double lon;

  const GeocodeResult({
    required this.name,
    required this.country,
    required this.admin1,
    required this.lat,
    required this.lon,
  });

  String get subtitle =>
      [admin1, country].where((s) => s.isNotEmpty).join(", ");
}

class OpenMeteoApi {
  OpenMeteoApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  int _seq = 0;

  static const _forecastBase = "https://api.open-meteo.com/v1/forecast";
  static const _airBase =
      "https://air-quality-api.open-meteo.com/v1/air-quality";
  static const _geocodeBase = "https://geocoding-api.open-meteo.com/v1/search";

  /// Чистая сборка URL прогноза — вынесена для юнит-тестов.
  /// Параметры зеркалят main.qml:428-451; nowcast (minutely_15) запрашивается
  /// всегда — карточка «Осадки сейчас» сама скроется без данных.
  static String buildForecastUrl({
    required double lat,
    required double lon,
    required SettingsStore settings,
  }) {
    final wantHourly =
        settings.showForecast && settings.forecastMode != ForecastMode.daily;
    final wantDaily =
        settings.showForecast && settings.forecastMode != ForecastMode.hourly;
    final days = settings.showForecast ? settings.forecastDays : 1;

    var url =
        "$_forecastBase"
        "?latitude=$lat&longitude=$lon"
        "&current=temperature_2m,relative_humidity_2m,apparent_temperature,"
        "weather_code,wind_speed_10m,wind_gusts_10m,wind_direction_10m,"
        "pressure_msl,cloud_cover,dew_point_2m,is_day"
        "&minutely_15=precipitation";

    var dailyFields = "sunrise,sunset,uv_index_max,precipitation_sum";
    if (wantDaily) {
      dailyFields +=
          ",weather_code,temperature_2m_max,temperature_2m_min,"
          "apparent_temperature_max,apparent_temperature_min,"
          "precipitation_probability_max,wind_speed_10m_max,"
          "wind_direction_10m_dominant";
    }
    url += "&daily=$dailyFields";
    if (wantHourly) {
      url +=
          "&hourly=temperature_2m,weather_code,precipitation_probability,"
          "wind_speed_10m,wind_direction_10m";
    }
    url +=
        "&timezone=auto"
        "&forecast_days=$days"
        "&temperature_unit=${settings.temperatureUnit.apiValue}"
        "&wind_speed_unit=${settings.windSpeedUnit.apiValue}";
    return url;
  }

  Map<String, dynamic> _decode(http.Response response) {
    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes))
          as Map<String, dynamic>;
    }
    if (response.statusCode == 429) {
      throw ApiException("Слишком много запросов. Попробуйте позже.");
    }
    throw ApiException("Ошибка HTTP ${response.statusCode}");
  }

  /// Прогноз + nowcast. Возвращает разобранный JSON ответа.
  Future<Map<String, dynamic>> fetchForecast({
    required double lat,
    required double lon,
    required SettingsStore settings,
  }) async {
    final url = buildForecastUrl(lat: lat, lon: lon, settings: settings);
    try {
      final response = await _client
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 15));
      return _decode(response);
    } on TimeoutException {
      throw ApiException("Таймаут запроса");
    } on http.ClientException {
      throw ApiException("Ошибка сети");
    }
  }

  /// Европейский AQI или null при любой ошибке — карточка просто скрывается.
  Future<double?> fetchAqi({required double lat, required double lon}) async {
    final seq = ++_seq;
    try {
      final response = await _client
          .get(
            Uri.parse(
              "$_airBase?latitude=$lat&longitude=$lon"
              "&current=european_aqi&timezone=auto",
            ),
          )
          .timeout(const Duration(seconds: 8));
      if (seq != _seq) return null;
      if (response.statusCode != 200) return null;
      final data =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final current = data["current"] as Map<String, dynamic>?;
      return (current?["european_aqi"] as num?)?.toDouble();
    } catch (_) {
      return null;
    }
  }

  /// Поиск города (язык ru). Пустой список — ничего не найдено.
  Future<List<GeocodeResult>> geocode(String query) async {
    if (query.trim().isEmpty) return const [];
    try {
      final response = await _client
          .get(
            Uri.parse(
              "$_geocodeBase?name=${Uri.encodeQueryComponent(query.trim())}"
              "&count=8&language=ru&format=json",
            ),
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return const [];
      final data =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final results = (data["results"] as List?) ?? const [];
      return results
          .map((e) {
            final m = e as Map<String, dynamic>;
            return GeocodeResult(
              name: m["name"] as String? ?? "",
              country: m["country"] as String? ?? "",
              admin1: m["admin1"] as String? ?? "",
              lat: (m["latitude"] as num).toDouble(),
              lon: (m["longitude"] as num).toDouble(),
            );
          })
          .where((r) => r.name.isNotEmpty)
          .toList();
    } catch (_) {
      return const [];
    }
  }
}

class ApiException implements Exception {
  final String message;
  const ApiException(this.message);
  @override
  String toString() => message;
}
