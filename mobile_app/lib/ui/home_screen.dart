/// Главный экран: динамический погодный фон + прокручиваемая лента
/// стеклянных карточек (hero → nowcast → почасовые → график → дни →
/// метрики → предупреждения → футер). Pull-to-refresh и автообновление.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../data/cities_store.dart';
import '../data/open_meteo_api.dart';
import '../data/settings_store.dart';
import '../data/weather_state.dart';
import 'background/weather_background.dart';
import 'cities_screen.dart';
import 'settings_screen.dart';
import 'widgets/alert_card.dart';
import 'widgets/daily_list.dart';
import 'widgets/glass_card.dart';
import 'widgets/hourly_strip.dart';
import 'widgets/metric_tiles.dart';
import 'widgets/nowcast_card.dart';
import 'widgets/temp_chart.dart';

class HomeScreen extends StatefulWidget {
  final WeatherState weather;
  final SettingsStore settings;
  final CitiesStore cities;

  const HomeScreen({
    super.key,
    required this.weather,
    required this.settings,
    required this.cities,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.weather.refresh();
    _restartTimer();
  }

  @override
  void didUpdateWidget(HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _restartTimer();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      widget.weather.refresh();
      _restartTimer();
    } else {
      _timer?.cancel();
    }
  }

  void _restartTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(
      Duration(minutes: widget.settings.updateInterval),
      (_) => widget.weather.refresh(),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _openCities() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            CitiesScreen(cities: widget.cities, api: OpenMeteoApi()),
      ),
    );
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SettingsScreen(settings: widget.settings),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: Listenable.merge([
          widget.weather,
          widget.settings,
          widget.cities,
        ]),
        builder: (context, _) {
          final state = widget.weather;
          final glass = context.glass;
          final cur = state.current;

          return Stack(
            children: [
              WeatherBackground(
                kind: cur != null
                    ? weatherKind(wmo: _wmoOf(state), isDay: cur.isDay)
                    : WeatherKind.clearNight,
                animate: widget.settings.animationsEnabled,
              ),
              SafeArea(
                child: RefreshIndicator(
                  color: glass.accent,
                  onRefresh: () => widget.weather.refresh(),
                  child: _buildBody(context, state),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  int _wmoOf(WeatherState state) => state.lastWmoCode;

  Widget _buildBody(BuildContext context, WeatherState state) {
    if (state.status == LoadStatus.loading && state.current == null) {
      return _LoadingView(
        cityName: state.cityName,
        onCities: _openCities,
        onSettings: _openSettings,
      );
    }
    if (state.status == LoadStatus.error && state.current == null) {
      return _ErrorView(
        cityName: state.cityName,
        message: state.errorMessage,
        onRetry: () => widget.weather.refresh(),
        onCities: _openCities,
        onSettings: _openSettings,
      );
    }
    return _ContentView(
      state: state,
      settings: widget.settings,
      onCities: _openCities,
      onSettings: _openSettings,
    );
  }
}

/// Контент основной ленты.
class _ContentView extends StatelessWidget {
  final WeatherState state;
  final SettingsStore settings;
  final VoidCallback onCities;
  final VoidCallback onSettings;

  const _ContentView({
    required this.state,
    required this.settings,
    required this.onCities,
    required this.onSettings,
  });

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    final cur = state.current!;
    final showHourly =
        settings.showForecast && settings.forecastMode != ForecastMode.daily;
    final showDaily =
        settings.showForecast && settings.forecastMode != ForecastMode.hourly;
    final chartHours = state.hours.take(48).toList();

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: _Header(
            cityName: state.cityName,
            onCities: onCities,
            onSettings: onSettings,
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.only(bottom: 24),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              // Hero.
              GlassCard(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(cur.emoji, style: const TextStyle(fontSize: 56)),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "${cur.temp}${state.tempUnitLabel}",
                              style: TextStyle(
                                fontSize: 64,
                                fontWeight: FontWeight.w200,
                                height: 1.0,
                                color: glass.textPrimary,
                              ),
                            ),
                            Text(
                              cur.condition,
                              style: TextStyle(
                                fontSize: 14,
                                color: glass.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "Ощущается как ${cur.feelsLike}${state.tempUnitLabel}",
                      style: TextStyle(
                        fontSize: 13,
                        color: glass.textSecondary,
                      ),
                    ),
                    if (state.jokeText.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        state.jokeText,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontStyle: FontStyle.italic,
                          height: 1.3,
                          color: glass.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (state.nowcastOrLast != null) ...[
                NowcastCard(nowcast: state.nowcastOrLast!),
                const SizedBox(height: 12),
              ],
              if (showHourly && state.hours.isNotEmpty) ...[
                HourlyStrip(hours: state.hours),
                const SizedBox(height: 12),
              ],
              if (showHourly && chartHours.length >= 2) ...[
                TempChart(
                  temps: chartHours.map((h) => h.temp).toList(),
                  timeLabels: chartHours
                      .map((h) => h.time.split("T").last)
                      .toList(),
                ),
                const SizedBox(height: 12),
              ],
              if (showDaily && state.days.isNotEmpty) ...[
                DailyList(days: state.days),
                const SizedBox(height: 12),
              ],
              MetricTiles(
                current: cur,
                tempUnit: state.tempUnitLabel,
                windUnit: state.windUnitLabel,
                pressureUnit: state.pressureUnitLabel,
                sunrise: state.sunrise,
                sunset: state.sunset,
                uvIndex: state.uvIndex,
                precipSum: state.precipSum,
              ),
              const SizedBox(height: 12),
              if (state.aqi != null) ...[
                AqiCard(aqi: state.aqi!),
                const SizedBox(height: 12),
              ],
              if (state.alerts.isNotEmpty) ...[
                AlertCard(alerts: state.alerts),
                const SizedBox(height: 12),
              ],
              if (state.lastUpdate != null)
                Center(
                  child: Text(
                    "Обновлено в "
                    "${state.lastUpdate!.toLocal().toString().substring(11, 16)}"
                    " · Open-Meteo",
                    style: TextStyle(
                      fontSize: 11.5,
                      color: glass.textSecondary,
                    ),
                  ),
                ),
            ]),
          ),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  final String cityName;
  final VoidCallback onCities;
  final VoidCallback onSettings;

  const _Header({
    required this.cityName,
    required this.onCities,
    required this.onSettings,
  });

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 12, 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              cityName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w500,
                color: glass.textPrimary,
              ),
            ),
          ),
          IconButton(
            tooltip: "Города",
            onPressed: onCities,
            icon: const Icon(Icons.format_list_bulleted_outlined),
          ),
          IconButton(
            tooltip: "Настройки",
            onPressed: onSettings,
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  final String cityName;
  final VoidCallback onCities;
  final VoidCallback onSettings;

  const _LoadingView({
    required this.cityName,
    required this.onCities,
    required this.onSettings,
  });

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    return Column(
      children: [
        _Header(cityName: cityName, onCities: onCities, onSettings: onSettings),
        Expanded(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: glass.accent),
                const SizedBox(height: 16),
                Text(
                  "Загружаем погоду…",
                  style: TextStyle(fontSize: 14, color: glass.textSecondary),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String cityName;
  final String message;
  final VoidCallback onRetry;
  final VoidCallback onCities;
  final VoidCallback onSettings;

  const _ErrorView({
    required this.cityName,
    required this.message,
    required this.onRetry,
    required this.onCities,
    required this.onSettings,
  });

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        _Header(cityName: cityName, onCities: onCities, onSettings: onSettings),
        Padding(
          padding: const EdgeInsets.all(24),
          child: GlassCard(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Text(
                  "⛈️",
                  style: TextStyle(fontSize: 44, color: glass.textPrimary),
                ),
                const SizedBox(height: 12),
                Text(
                  "Не удалось загрузить погоду",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: glass.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: glass.textSecondary),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text("Повторить"),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
