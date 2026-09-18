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

  /// Чистая сборка словаря для виджета из состояния — покрыта тестами.
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

    for (var i = 0; i < 3; i++) {
      if (i >= state.days.length) break;
      final d = state.days[i];
      data["d${i}_label"] = switch (i) {
        0 => "Сегодня",
        1 => "Завтра",
        _ => dayLabel(d.date, i),
      };
      data["d$i"] = "${d.emoji} ${d.tempMax}°/${d.tempMin}°";
    }
    return data;
  }

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
