/// Единый источник состояния погоды (аналог main.qml по духу AGENT.md):
/// сеть и парсинг живут здесь, UI только читает готовые поля.
/// Округления — при парсинге, не в биндингах.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import 'cities_store.dart';
import 'open_meteo_api.dart';
import 'settings_store.dart';
import 'widget_sync.dart';
import '../domain/alerts.dart';
import '../domain/jokes.dart';
import '../domain/nowcast.dart';
import '../domain/wmo.dart';

enum LoadStatus { loading, ready, error }

/// Текущая погода (значения уже округлены при парсинге).
class CurrentData {
  final int temp;
  final int feelsLike;
  final int humidity;
  final int cloudCover;
  final double windSpeed;
  final String windDir;
  final double gusts;
  final int pressure;
  final double dewPoint;
  final String emoji;
  final String condition;
  final bool isDay;

  const CurrentData({
    required this.temp,
    required this.feelsLike,
    required this.humidity,
    required this.cloudCover,
    required this.windSpeed,
    required this.windDir,
    required this.gusts,
    required this.pressure,
    required this.dewPoint,
    required this.emoji,
    required this.condition,
    required this.isDay,
  });
}

class DayItem {
  final String date;
  final int tempMax;
  final int tempMin;
  final String emoji;
  final String condition;
  final int precProb;
  final double windSpeedMax;

  const DayItem({
    required this.date,
    required this.tempMax,
    required this.tempMin,
    required this.emoji,
    required this.condition,
    required this.precProb,
    required this.windSpeedMax,
  });
}

class HourItem {
  final String time;
  final int temp;
  final String emoji;
  final String condition;
  final int precProb;

  const HourItem({
    required this.time,
    required this.temp,
    required this.emoji,
    required this.condition,
    required this.precProb,
  });
}

class WeatherState extends ChangeNotifier {
  WeatherState({
    required OpenMeteoApi apiClient,
    required SettingsStore settingsStore,
    required CitiesStore citiesStore,
  }) : _api = apiClient,
       _settings = settingsStore,
       _cities = citiesStore {
    _settings.addListener(_onDepChanged);
    _cities.addListener(_onDepChanged);
  }

  final OpenMeteoApi _api;
  final SettingsStore _settings;
  final CitiesStore _cities;

  LoadStatus status = LoadStatus.loading;
  String errorMessage = "";

  CurrentData? current;
  List<DayItem> days = const [];
  List<HourItem> hours = const [];
  Nowcast? nowcast;
  Nowcast? _prevNowcast;
  double? aqi;
  List<WeatherAlert> alerts = const [];
  DateTime? lastUpdate;
  String jokeText = "";

  /// Сырой код WMO текущей погоды — для подбора динамического фона.
  int lastWmoCode = 0;

  // Сводные показатели дня (солнце, УФ, осадки).
  String sunrise = "--:--";
  String sunset = "--:--";
  double uvIndex = 0;
  double precipSum = 0;

  int _seq = 0;
  Timer? _debounce;

  String get tempUnitLabel => _settings.temperatureUnit.label;
  String get windUnitLabel => _settings.windSpeedUnit.label;
  String get pressureUnitLabel => _settings.pressureUnit.label;
  String get cityName => _cities.active.name;

  void _onDepChanged() {
    // Дебаунс 400 мс, как у виджета: пачка изменений — один рефетч.
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      refresh();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _settings.removeListener(_onDepChanged);
    _cities.removeListener(_onDepChanged);
    super.dispose();
  }

  Future<void> refresh() async {
    final seq = ++_seq;
    final place = _cities.active;
    status = LoadStatus.loading;
    errorMessage = "";
    notifyListeners();

    try {
      final data = await _api.fetchForecast(
        lat: place.lat,
        lon: place.lon,
        settings: _settings,
      );
      if (seq != _seq) return;
      _parse(data);
      status = LoadStatus.ready;
      errorMessage = "";
      lastUpdate = DateTime.now();
      notifyListeners();
      // Домашний виджет — необязательный подписчик: ошибки глотаются внутри.
      await WidgetSync.update(this);
    } on ApiException catch (e) {
      if (seq != _seq) return;
      status = LoadStatus.error;
      errorMessage = e.message;
      notifyListeners();
    } catch (_) {
      if (seq != _seq) return;
      status = LoadStatus.error;
      errorMessage = "Ошибка обработки данных";
      notifyListeners();
    }

    // AQI независим: ошибка любого рода просто скрывает карточку.
    _api.fetchAqi(lat: place.lat, lon: place.lon).then((value) {
      if (seq != _seq) return;
      aqi = value;
      notifyListeners();
    });
  }

  void _parse(Map<String, dynamic> data) {
    final cur = (data["current"] as Map<String, dynamic>?) ?? const {};
    final settings = _settings;

    final temp = _num(cur["temperature_2m"]) ?? 0;
    final feelsLike = _num(cur["apparent_temperature"]) ?? temp;
    final windSpeed = _num(cur["wind_speed_10m"]) ?? 0;
    final gusts = _num(cur["wind_gusts_10m"]) ?? 0;
    final dewPoint = _num(cur["dew_point_2m"]) ?? 0;

    var pressureHpa = _num(cur["pressure_msl"]);
    final pressure = settings.pressureUnit == PressureUnit.mmhg
        ? (pressureHpa != null ? (pressureHpa * 0.75006).round() : 0)
        : (pressureHpa != null ? pressureHpa.round() : 0);

    final wmo = (cur["weather_code"] as num?)?.toInt() ?? 0;
    final isDay = (cur["is_day"] as num?)?.toInt() ?? 1;
    var info = wmoInfo(wmo);
    var emoji = isClearNight(wmo, isDay) ? nightEmoji : info.emoji;
    lastWmoCode = wmo;

    current = CurrentData(
      temp: temp.round(),
      feelsLike: feelsLike.round(),
      humidity: (_num(cur["relative_humidity_2m"]) ?? 0).round(),
      cloudCover: (_num(cur["cloud_cover"]) ?? 0).round(),
      windSpeed: windSpeed,
      windDir: windDegToCompass(_num(cur["wind_direction_10m"]) ?? 0),
      gusts: _round1(gusts),
      pressure: pressure,
      dewPoint: _round1(dewPoint),
      emoji: emoji,
      condition: info.text,
      isDay: isDay == 1,
    );

    final daily = (data["daily"] as Map<String, dynamic>?) ?? const {};
    final sunriseArr = (daily["sunrise"] as List?)?.cast<String>() ?? const [];
    final sunsetArr = (daily["sunset"] as List?)?.cast<String>() ?? const [];
    final uvArr = (daily["uv_index_max"] as List?) ?? const [];
    final precipArr = (daily["precipitation_sum"] as List?) ?? const [];
    sunrise = isoToHM(sunriseArr.isNotEmpty ? sunriseArr.first : "");
    sunset = isoToHM(sunsetArr.isNotEmpty ? sunsetArr.first : "");
    uvIndex = uvArr.isNotEmpty ? _round1(_num(uvArr.first) ?? 0) : 0;
    precipSum = precipArr.isNotEmpty ? _round1(_num(precipArr.first) ?? 0) : 0;

    // Сарказм «ощущается как» — температура + контекст.
    final windMs = windToMs(windSpeed, settings.windSpeedUnit.apiValue);
    jokeText = settings.jokesEnabled
        ? feelsLikeJoke(
            feelsLike: feelsLike,
            unitLabel: settings.temperatureUnit.label,
            wmo: wmo,
            windMs: windMs,
            uv: uvIndex,
          )
        : "";

    // Прогноз по дням (только если поля запрашивались).
    final dayList = <DayItem>[];
    final times = (daily["time"] as List?)?.cast<String>() ?? const [];
    final wcArr = (daily["weather_code"] as List?) ?? const [];
    if (wcArr.isNotEmpty) {
      final maxArr = (daily["temperature_2m_max"] as List?) ?? const [];
      final minArr = (daily["temperature_2m_min"] as List?) ?? const [];
      final probArr =
          (daily["precipitation_probability_max"] as List?) ?? const [];
      final windArr = (daily["wind_speed_10m_max"] as List?) ?? const [];
      for (var i = 0; i < times.length; i++) {
        final dw = _num(_at(wcArr, i))?.toInt() ?? 0;
        final di = wmoInfo(dw);
        dayList.add(
          DayItem(
            date: times[i],
            tempMax: (_num(_at(maxArr, i)) ?? 0).round(),
            tempMin: (_num(_at(minArr, i)) ?? 0).round(),
            emoji: di.emoji,
            condition: di.text,
            precProb: (_num(_at(probArr, i)) ?? 0).round(),
            windSpeedMax: _num(_at(windArr, i)) ?? 0,
          ),
        );
      }
    }
    days = dayList;

    // Почасовой прогноз — от текущего часа, максимум 48 записей.
    final hourList = <HourItem>[];
    final hourly = (data["hourly"] as Map<String, dynamic>?) ?? const {};
    final hTimes = (hourly["time"] as List?)?.cast<String>() ?? const [];
    final currentTime = cur["time"] as String? ?? "";
    final currentHourBoundary = currentTime.length >= 13
        ? currentTime.substring(0, 13)
        : "";
    final hTemps = (hourly["temperature_2m"] as List?) ?? const [];
    final hCodes = (hourly["weather_code"] as List?) ?? const [];
    final hProbs = (hourly["precipitation_probability"] as List?) ?? const [];
    for (var j = 0; j < hTimes.length; j++) {
      if (currentHourBoundary.isNotEmpty &&
          hTimes[j].compareTo(currentHourBoundary) < 0) {
        continue;
      }
      if (hourList.length >= 48) break;
      final hw = _num(_at(hCodes, j))?.toInt() ?? 0;
      final hi = wmoInfo(hw);
      hourList.add(
        HourItem(
          time: hTimes[j],
          temp: (_num(_at(hTemps, j)) ?? 0).round(),
          emoji: hi.emoji,
          condition: hi.text,
          precProb: (_num(_at(hProbs, j)) ?? 0).round(),
        ),
      );
    }
    hours = hourList;

    // Nowcast: сохраняем предыдущий, чтобы не мигал при кратковременной потере.
    nowcast = parseNowcast(
      data["minutely_15"] as Map<String, dynamic>?,
      currentTime,
    );
    if (nowcast != null) _prevNowcast = nowcast;

    alerts = computeAlerts(
      todayMax: days.isNotEmpty ? days.first.tempMax.toDouble() : null,
      tomorrowMax: days.length > 1 ? days[1].tempMax.toDouble() : null,
      todayWmo: wmo,
      todayWindMax: days.isNotEmpty ? days.first.windSpeedMax : null,
      windUnit: settings.windSpeedUnit.apiValue,
    );
  }

  /// Предыдущий успешный nowcast — для плавности при сбоях.
  Nowcast? get nowcastOrLast => nowcast ?? _prevNowcast;

  static double? _num(dynamic v) => v is num ? v.toDouble() : null;

  static dynamic _at(List list, int i) => i < list.length ? list[i] : null;

  static double _round1(num v) => (v * 10).round() / 10;
}
