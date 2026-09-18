import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_theme.dart';
import 'data/cities_store.dart';
import 'data/open_meteo_api.dart';
import 'data/settings_store.dart';
import 'data/weather_state.dart';
import 'data/widget_sync.dart';
import 'ui/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(WeatherApp(prefs: prefs));
}

class WeatherApp extends StatefulWidget {
  final SharedPreferences prefs;

  const WeatherApp({super.key, required this.prefs});

  @override
  State<WeatherApp> createState() => _WeatherAppState();
}

class _WeatherAppState extends State<WeatherApp> {
  late final SettingsStore settings;
  late final CitiesStore cities;
  late final WeatherState weather;

  @override
  void initState() {
    super.initState();
    settings = SettingsStore(widget.prefs);
    cities = CitiesStore(widget.prefs);
    weather = WeatherState(
      apiClient: OpenMeteoApi(),
      settingsStore: settings,
      citiesStore: cities,
    );
    cities.load();
    // Мягко спрашиваем разрешение на геолокацию заранее, чтобы кнопка GPS
    // потом не тормозила (отказ — не ошибка).
    try {
      Geolocator.requestPermission();
    } catch (_) {}
    // Фоновое обновление домашнего виджета (Android; вне Android — no-op).
    registerWidgetBackgroundRefresh(settings);
  }

  @override
  void dispose() {
    weather.dispose();
    settings.dispose();
    cities.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: settings,
      builder: (context, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: settings.themeMode == AppThemeMode.system
              ? ThemeMode.system
              : ThemeMode.dark,
          home: HomeScreen(
            weather: weather,
            settings: settings,
            cities: cities,
          ),
        );
      },
    );
  }
}
