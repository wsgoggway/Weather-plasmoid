/// Синхронизация с домашним виджетом Android: нативный AppWidget
/// (WeatherWidgetProvider) читает данные из prefs "HomeWidgetPreferences",
/// которые мы сюда пишем через плагин home_widget. Плюс периодическая
/// фоновая задача (workmanager), обновляющая виджет без открытого приложения.
library;

import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import 'cities_store.dart';
import 'open_meteo_api.dart';
import 'settings_store.dart';
import 'weather_state.dart';
import '../domain/wmo.dart';

class WidgetSync {
  WidgetSync._();

  static const _qualifiedProvider =
      "com.github.vladimirm.openmeteo_weather.WeatherWidgetProvider";

  /// Часов в ленте виджета (Сейчас + 4), дней в прогнозе и плиток метрик.
  static const _hourlyCount = 5;
  static const _dailyCount = 3;
  static const _metricCount = 4;

  /// Ключ иконки виджета по коду погоды и времени суток.
  /// Векторы лежат в android res/drawable/wi_*.xml.
  static String widgetIconKey(int wmo, bool isDay) {
    if (wmo == 45 || wmo == 48) return "fog";
    if (wmo >= 95) return "storm";
    if (const [71, 73, 75, 77, 85, 86].contains(wmo)) return "snow";
    if (const [
      51, 53, 55, 56, 57, 61, 63, 65, 66, 67, 80, 81, 82, 96, 99,
    ].contains(wmo)) {
      return "rain";
    }
    switch (wmo) {
      case 0:
        return isDay ? "sun" : "moon";
      case 1:
      case 2:
        return isDay ? "partly" : "partly_night";
      default:
        return "cloud";
    }
  }

  /// Ключ градиента фона по погоде и времени суток (Pixel style).
  static String widgetThemeKey(int wmo, bool isDay) {
    if (wmo == 45 || wmo == 48) return "fog";
    if (wmo >= 95) return "storm";
    if (const [71, 73, 75, 77, 85, 86].contains(wmo)) return "snow";
    if (const [
      51, 53, 55, 56, 57, 61, 63, 65, 66, 67, 80, 81, 82, 95, 96, 99,
    ].contains(wmo)) {
      return "rain";
    }
    if (wmo == 3) return "cloud";
    if (wmo == 1 || wmo == 2) return isDay ? "partly" : "clear_night";
    return isDay ? "clear_day" : "clear_night";
  }

  /// Чистая сборка словаря для виджета из состояния — покрыта тестами.
  /// Ключи без данных всегда пишутся пустыми, чтобы в виджете не оставалось
  /// устаревших значений от прошлого города или прошлого запуска.
  static Map<String, String> buildData(WeatherState state) {
    final cur = state.current;
    if (cur == null) return const {};

    final icon = widgetIconKey(state.lastWmoCode, cur.isDay);
    final theme = widgetThemeKey(state.lastWmoCode, cur.isDay);
    final today = state.days.isNotEmpty ? state.days.first : null;

    final data = <String, String>{
      "theme": theme,
      "icon": icon,
      "temp": "${cur.temp}°",
      "city": state.cityName,
      "condition": cur.condition,
      "feels": "Ощущается ${cur.feelsLike}${state.tempUnitLabel}",
      "hi": today != null ? "↑${today.tempMax}°" : "",
      "lo": today != null ? "↓${today.tempMin}°" : "",
      "updated": state.lastUpdate != null
          ? "Обновлено в ${_hhmm(state.lastUpdate!)} · Open-Meteo"
          : "",
    };

    // Почасовая лента (Apple Weather / Pixel style): время, иконка, t°.
    final hours = state.hours.take(_hourlyCount).toList();
    for (var i = 0; i < _hourlyCount; i++) {
      if (i < hours.length) {
        final h = hours[i];
        final hourOfDay = int.tryParse(_hour(h.time));
        final isDayHour = hourOfDay != null && hourOfDay >= 7 && hourOfDay < 20;
        data["h${i}_time"] = i == 0 ? "Сейчас" : _hour(h.time);
        data["h${i}_icon"] = widgetIconKey(h.wmo, isDayHour);
        data["h${i}_temp"] = "${h.temp}°";
      } else {
        data["h${i}_time"] = "";
        data["h${i}_icon"] = "cloud";
        data["h${i}_temp"] = "";
      }
    }

    // Метрики: 4 плитки «значение + подпись» (Apple style).
    final tiles = <(String, String)>[
      ("${_num(cur.windSpeed)} ${state.windUnitLabel}", "Ветер"),
      ("${cur.humidity}%", "Влажность"),
      ("${cur.pressure} ${_shortPressure(state.pressureUnitLabel)}", "Давление"),
      ("${state.uvIndex.round()}", "УФ-индекс"),
    ];
    for (var i = 0; i < _metricCount; i++) {
      if (i < tiles.length) {
        data["mv$i"] = tiles[i].$1;
        data["ml$i"] = tiles[i].$2;
      } else {
        data["mv$i"] = "";
        data["ml$i"] = "";
      }
    }

    // Прогноз на 3 дня: подпись / иконка / ↑max / ↓min.
    for (var i = 0; i < _dailyCount; i++) {
      if (i < state.days.length) {
        final d = state.days[i];
        data["d${i}_label"] = switch (i) {
          0 => "Сегодня",
          1 => "Завтра",
          _ => dayLabel(d.date, i),
        };
        data["d${i}_icon"] = widgetIconKey(d.wmo, true);
        data["d${i}_max"] = "${d.tempMax}°";
        data["d${i}_min"] = "${d.tempMin}°";
      } else {
        data["d${i}_label"] = "";
        data["d${i}_icon"] = "cloud";
        data["d${i}_max"] = "";
        data["d${i}_min"] = "";
      }
    }
    return data;
  }

  /// "2026-09-18T15:00" → "15".
  static String _hour(String isoTime) {
    final parts = isoTime.split("T");
    if (parts.length < 2) return isoTime;
    final hh = parts[1].split(":").first;
    return hh;
  }

  /// Красивое число: 3 → "3", 3.7 → "3.7".
  static String _num(num v) => v % 1 == 0 ? v.toInt().toString() : v.toString();

  /// Короткая подпись давления для плитки: "мм рт." → "мм".
  static String _shortPressure(String label) =>
      label == "мм рт." ? "мм" : label;

  /// Пишет данные и перерисовывает виджет. Любая ошибка (не Android,
  /// тесты, нет виджета) тихо игнорируется — виджет опционален.
  static Future<void> update(WeatherState state) async {
    try {
      final data = buildData(state);
      if (data.isEmpty) return;
      for (final entry in data.entries) {
        await HomeWidget.saveWidgetData<String>(entry.key, entry.value);
      }
      await HomeWidget.updateWidget(qualifiedAndroidName: _qualifiedProvider);
    } catch (_) {
      // Платформа не поддерживает home_widget — не падаем.
    }
  }

  static String _hhmm(DateTime t) {
    final h = t.hour.toString().padLeft(2, "0");
    final m = t.minute.toString().padLeft(2, "0");
    return "$h:$m";
  }
}

/// Точка входа фонового изолята workmanager: подтягивает настройки/города
/// из prefs, делает запрос Open-Meteo и обновляет виджет. Логика та же,
/// что в приложении, — отдельного парсинга нет.
@pragma('vm:entry-point')
void widgetBackgroundDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    final prefs = await SharedPreferences.getInstance();
    final settings = SettingsStore(prefs);
    final cities = CitiesStore(prefs);
    await cities.load();
    final state = WeatherState(
      apiClient: OpenMeteoApi(),
      settingsStore: settings,
      citiesStore: cities,
    );
    await state.refresh();
    await WidgetSync.update(state);
    state.dispose();
    // false → Workmanager перезапустит задачу с backoff (например, не было сети).
    return state.current != null;
  });
}

/// Регистрирует периодическое фоновое обновление виджета
/// (минимум Android — 15 минут). Вызывать один раз из main.
Future<void> registerWidgetBackgroundRefresh(SettingsStore settings) async {
  try {
    await Workmanager().initialize(widgetBackgroundDispatcher);
    await Workmanager().registerPeriodicTask(
      "weather-widget-sync",
      "weatherWidgetSync",
      frequency: Duration(
        minutes: settings.updateInterval < 15 ? 15 : settings.updateInterval,
      ),
      constraints: Constraints(networkType: NetworkType.connected),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
    );
  } catch (_) {
    // Не Android или плагин недоступен — фон не критичен.
  }
}
