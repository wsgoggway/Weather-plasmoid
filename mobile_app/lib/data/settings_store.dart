/// Пользовательские настройки приложения (shared_preferences).
/// Дефолты унаследованы от настроек виджета, где это применимо.
library;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum TemperatureUnit { celsius, fahrenheit }

enum WindSpeedUnit { ms, kmh, mph, kn }

enum PressureUnit { mmhg, hpa }

enum ForecastMode { daily, hourly, both }

enum AppThemeMode { dark, system }

extension TemperatureUnitX on TemperatureUnit {
  String get apiValue => name;
  String get label => this == TemperatureUnit.fahrenheit ? "°F" : "°C";
  String get title =>
      this == TemperatureUnit.fahrenheit ? "Фаренгейт (°F)" : "Цельсий (°C)";
}

extension WindSpeedUnitX on WindSpeedUnit {
  String get apiValue => name;
  String get label => switch (this) {
    WindSpeedUnit.ms => "м/с",
    WindSpeedUnit.kmh => "км/ч",
    WindSpeedUnit.mph => "миль/ч",
    WindSpeedUnit.kn => "уз",
  };
  String get title => switch (this) {
    WindSpeedUnit.ms => "Метры в секунду (м/с)",
    WindSpeedUnit.kmh => "Километры в час (км/ч)",
    WindSpeedUnit.mph => "Мили в час (миль/ч)",
    WindSpeedUnit.kn => "Узлы",
  };
}

extension PressureUnitX on PressureUnit {
  String get label => this == PressureUnit.mmhg ? "мм рт." : "гПа";
  String get title =>
      this == PressureUnit.mmhg ? "Миллиметры ртутного столба" : "Гектопаскали";
}

extension ForecastModeX on ForecastMode {
  String get title => switch (this) {
    ForecastMode.daily => "По дням",
    ForecastMode.hourly => "По часам",
    ForecastMode.both => "Дни + Часы",
  };
}

extension AppThemeModeX on AppThemeMode {
  String get title => switch (this) {
    AppThemeMode.dark => "Тёмная",
    AppThemeMode.system => "Как в системе",
  };
}

class SettingsStore extends ChangeNotifier {
  SettingsStore(this._prefs);

  final SharedPreferences _prefs;

  static const _kTempUnit = "temperatureUnit";
  static const _kWindUnit = "windSpeedUnit";
  static const _kPressureUnit = "pressureUnit";
  static const _kUpdateInterval = "updateInterval";
  static const _kThemeMode = "themeMode";
  static const _kAnimations = "animationsEnabled";
  static const _kJokes = "jokesEnabled";
  static const _kShowForecast = "showForecast";
  static const _kForecastMode = "forecastMode";
  static const _kForecastDays = "forecastDays";

  TemperatureUnit get temperatureUnit {
    final v = _prefs.getString(_kTempUnit);
    return v == "fahrenheit"
        ? TemperatureUnit.fahrenheit
        : TemperatureUnit.celsius;
  }

  WindSpeedUnit get windSpeedUnit {
    switch (_prefs.getString(_kWindUnit)) {
      case "kmh":
        return WindSpeedUnit.kmh;
      case "mph":
        return WindSpeedUnit.mph;
      case "kn":
        return WindSpeedUnit.kn;
      default:
        return WindSpeedUnit.ms;
    }
  }

  PressureUnit get pressureUnit => _prefs.getString(_kPressureUnit) == "hpa"
      ? PressureUnit.hpa
      : PressureUnit.mmhg;

  int get updateInterval {
    final v = _prefs.getInt(_kUpdateInterval) ?? 30;
    return v.clamp(5, 180);
  }

  AppThemeMode get themeMode => _prefs.getString(_kThemeMode) == "system"
      ? AppThemeMode.system
      : AppThemeMode.dark;

  bool get animationsEnabled => _prefs.getBool(_kAnimations) ?? true;
  bool get jokesEnabled => _prefs.getBool(_kJokes) ?? true;
  bool get showForecast => _prefs.getBool(_kShowForecast) ?? true;

  ForecastMode get forecastMode {
    switch (_prefs.getString(_kForecastMode)) {
      case "daily":
        return ForecastMode.daily;
      case "hourly":
        return ForecastMode.hourly;
      default:
        return ForecastMode.both;
    }
  }

  int get forecastDays => (_prefs.getInt(_kForecastDays) ?? 10).clamp(1, 16);

  Future<void> setTemperatureUnit(TemperatureUnit v) async {
    await _prefs.setString(_kTempUnit, v.apiValue);
    notifyListeners();
  }

  Future<void> setWindSpeedUnit(WindSpeedUnit v) async {
    await _prefs.setString(_kWindUnit, v.apiValue);
    notifyListeners();
  }

  Future<void> setPressureUnit(PressureUnit v) async {
    await _prefs.setString(_kPressureUnit, v.name);
    notifyListeners();
  }

  Future<void> setUpdateInterval(int minutes) async {
    await _prefs.setInt(_kUpdateInterval, minutes.clamp(5, 180));
    notifyListeners();
  }

  Future<void> setThemeMode(AppThemeMode v) async {
    await _prefs.setString(_kThemeMode, v.name);
    notifyListeners();
  }

  Future<void> setAnimationsEnabled(bool v) async {
    await _prefs.setBool(_kAnimations, v);
    notifyListeners();
  }

  Future<void> setJokesEnabled(bool v) async {
    await _prefs.setBool(_kJokes, v);
    notifyListeners();
  }

  Future<void> setShowForecast(bool v) async {
    await _prefs.setBool(_kShowForecast, v);
    notifyListeners();
  }

  Future<void> setForecastMode(ForecastMode v) async {
    await _prefs.setString(_kForecastMode, v.name);
    notifyListeners();
  }

  Future<void> setForecastDays(int days) async {
    await _prefs.setInt(_kForecastDays, days.clamp(1, 16));
    notifyListeners();
  }
}
