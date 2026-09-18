import 'package:flutter_test/flutter_test.dart';
import 'package:openmeteo_weather/data/open_meteo_api.dart';
import 'package:openmeteo_weather/data/settings_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<SettingsStore> settings(Map<String, Object> init) async {
  SharedPreferences.setMockInitialValues(init);
  return SettingsStore(await SharedPreferences.getInstance());
}

void main() {
  test("URL по умолчанию: оба режима, 10 дней, nowcast запрошен", () async {
    final s = await settings({});
    final url = OpenMeteoApi.buildForecastUrl(
      lat: 55.7558,
      lon: 37.6173,
      settings: s,
    );
    expect(url, startsWith("https://api.open-meteo.com/v1/forecast?"));
    expect(url, contains("latitude=55.7558"));
    expect(url, contains("longitude=37.6173"));
    expect(url, contains("&minutely_15=precipitation"));
    expect(url, contains("&forecast_days=10"));
    expect(url, contains("&temperature_unit=celsius"));
    expect(url, contains("&wind_speed_unit=ms"));
    expect(url, contains("&timezone=auto"));
    // Оба режима: есть и daily-поля прогноза, и hourly.
    expect(url, contains("weather_code,temperature_2m_max"));
    expect(url, contains("&hourly=temperature_2m,weather_code"));
    // Сводные поля запрашиваются всегда.
    expect(url, contains("sunrise,sunset,uv_index_max,precipitation_sum"));
  });

  test("режим «по дням»: hourly нет, daily есть", () async {
    final s = await settings({"showForecast": true, "forecastMode": "daily"});
    final url = OpenMeteoApi.buildForecastUrl(lat: 1, lon: 2, settings: s);
    expect(url, contains("&daily="));
    expect(url.contains("&hourly="), isFalse);
  });

  test("режим «по часам»: daily-поля прогноза нет, hourly есть", () async {
    final s = await settings({"forecastMode": "hourly"});
    final url = OpenMeteoApi.buildForecastUrl(lat: 1, lon: 2, settings: s);
    expect(url, contains("&hourly="));
    expect(url.contains("weather_code,temperature_2m_max"), isFalse);
    // Но сводка дня всегда запрошена.
    expect(url, contains("sunrise,sunset"));
  });

  test("прогноз выключен: days=1, без hourly, без daily-прогноза", () async {
    final s = await settings({"showForecast": false, "forecastDays": 12});
    final url = OpenMeteoApi.buildForecastUrl(lat: 1, lon: 2, settings: s);
    expect(url, contains("&forecast_days=1"));
    expect(url.contains("&hourly="), isFalse);
    expect(url.contains("weather_code,temperature_2m_max"), isFalse);
  });

  test("дни и единицы передаются", () async {
    final s = await settings({
      "forecastDays": 16,
      "temperatureUnit": "fahrenheit",
      "windSpeedUnit": "kn",
    });
    final url = OpenMeteoApi.buildForecastUrl(lat: 1, lon: 2, settings: s);
    expect(url, contains("&forecast_days=16"));
    expect(url, contains("&temperature_unit=fahrenheit"));
    expect(url, contains("&wind_speed_unit=kn"));
  });
}
