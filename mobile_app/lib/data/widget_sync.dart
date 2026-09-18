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

  /// Часов в ленте виджета (Сейчас + 4) и число колонок дней.
  static const _hourlyCount = 5;
  static const _dailyCount = 3;

  /// Чистая сборка словаря для виджета из состояния — покрыта тестами.
  /// Ключи без данных всегда пишутся пустыми, чтобы в виджете не оставалось
  /// устаревших значений от прошлого города или прошлого запуска.
  static Map<String, String> buildData(WeatherState state) {
    final cur = state.current;
    if (cur == null) return const {};
    final todayProb = state.days.isNotEmpty ? state.days.first.precProb : 0;

    final data = <String, String>{
      "emoji": cur.emoji,
      "temp": "${cur.temp}°",
      "city": state.cityName,
      "condition": cur.condition,
      "details":
          "Ощущается ${cur.feelsLike}${state.tempUnitLabel}"
          " · 💧$todayProb%",
      "updated": state.lastUpdate != null
          ? "Обновлено в ${_hhmm(state.lastUpdate!)} · Open-Meteo"
          : "",
    };

    // Почасовая лента (Apple Weather / Pixel style): время, эмодзи, t°.
    final hours = state.hours.take(_hourlyCount).toList();
    for (var i = 0; i < _hourlyCount; i++) {
      if (i < hours.length) {
        data["h${i}_time"] = i == 0 ? "Сейчас" : _hour(hours[i].time);
        data["h${i}_emoji"] = hours[i].emoji;
        data["h${i}_temp"] = "${hours[i].temp}°";
      } else {
        data["h${i}_time"] = "";
        data["h${i}_emoji"] = "";
        data["h${i}_temp"] = "";
      }
    }

    // Метрики в одну строку (Gismeteo/Overdrop style).
    data["m_humidity"] = "💧${cur.humidity}%";
    data["m_wind"] = "💨${_num(cur.windSpeed)} ${state.windUnitLabel}";
    data["m_pressure"] = "🧭${cur.pressure} ${state.pressureUnitLabel}";
    data["m_uv"] = "☀️УФ ${state.uvIndex.round()}";

    // Прогноз на 3 дня.
    for (var i = 0; i < _dailyCount; i++) {
      if (i < state.days.length) {
        final d = state.days[i];
        data["d${i}_label"] = switch (i) {
          0 => "Сегодня",
          1 => "Завтра",
          _ => dayLabel(d.date, i),
        };
        data["d$i"] = "${d.emoji} ${d.tempMax}°/${d.tempMin}°";
      } else {
        data["d${i}_label"] = "";
        data["d$i"] = "";
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
