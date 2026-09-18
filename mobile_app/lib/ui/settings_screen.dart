/// Экран настроек: единицы измерения, обновление, оформление, прогноз.
/// Зеркало configGeneral.qml виджета, адаптированное под мобильный UI.
library;

import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../data/settings_store.dart';
import 'background/weather_background.dart';
import 'widgets/glass_card.dart';

class SettingsScreen extends StatelessWidget {
  final SettingsStore settings;

  const SettingsScreen({super.key, required this.settings});

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    return Scaffold(
      body: Stack(
        children: [
          const WeatherBackground(kind: WeatherKind.clearNight, animate: false),
          SafeArea(
            child: AnimatedBuilder(
              animation: settings,
              builder: (context, _) => CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
                      child: Row(
                        children: [
                          BackButton(color: glass.textPrimary),
                          Expanded(
                            child: Text(
                              "Настройки",
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w500,
                                color: glass.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.only(bottom: 24),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        _unitsSection(context),
                        const SizedBox(height: 12),
                        _updateSection(context),
                        const SizedBox(height: 12),
                        _appearanceSection(context),
                        const SizedBox(height: 12),
                        _forecastSection(context),
                        const SizedBox(height: 16),
                        Center(
                          child: Text(
                            "Данные: Open-Meteo (CC BY 4.0)",
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
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _unitsSection(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel(context, "Единицы измерения"),
          _dropdownRow<TemperatureUnit>(
            context,
            title: "Температура",
            value: settings.temperatureUnit,
            items: {for (final v in TemperatureUnit.values) v: v.title},
            onChanged: settings.setTemperatureUnit,
          ),
          _dropdownRow<WindSpeedUnit>(
            context,
            title: "Ветер",
            value: settings.windSpeedUnit,
            items: {for (final v in WindSpeedUnit.values) v: v.title},
            onChanged: settings.setWindSpeedUnit,
          ),
          _dropdownRow<PressureUnit>(
            context,
            title: "Давление",
            value: settings.pressureUnit,
            items: {for (final v in PressureUnit.values) v: v.title},
            onChanged: settings.setPressureUnit,
          ),
        ],
      ),
    );
  }

  Widget _updateSection(BuildContext context) {
    final glass = context.glass;
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel(context, "Обновление"),
          Row(
            children: [
              Expanded(
                child: Slider(
                  value: settings.updateInterval.toDouble(),
                  min: 5,
                  max: 180,
                  divisions: 35,
                  label: "${settings.updateInterval} мин",
                  onChanged: (v) => settings.setUpdateInterval(v.round()),
                ),
              ),
              SizedBox(
                width: 64,
                child: Text(
                  "${settings.updateInterval} мин",
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: glass.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 4, right: 4, bottom: 8),
            child: Text(
              "Автообновление, пока приложение открыто",
              style: TextStyle(fontSize: 12, color: glass.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _appearanceSection(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel(context, "Оформление"),
          _dropdownRow<AppThemeMode>(
            context,
            title: "Тема",
            value: settings.themeMode,
            items: {for (final v in AppThemeMode.values) v: v.title},
            onChanged: settings.setThemeMode,
          ),
          _switchRow(
            context,
            "Анимированный погодный фон",
            settings.animationsEnabled,
            settings.setAnimationsEnabled,
          ),
          _switchRow(
            context,
            "Сарказм «ощущается как»",
            settings.jokesEnabled,
            settings.setJokesEnabled,
          ),
        ],
      ),
    );
  }

  Widget _forecastSection(BuildContext context) {
    final glass = context.glass;
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel(context, "Прогноз"),
          _switchRow(
            context,
            "Показывать прогноз",
            settings.showForecast,
            settings.setShowForecast,
          ),
          Opacity(
            opacity: settings.showForecast ? 1 : 0.45,
            child: Column(
              children: [
                IgnorePointer(
                  ignoring: !settings.showForecast,
                  child: Column(
                    children: [
                      _dropdownRow<ForecastMode>(
                        context,
                        title: "Режим",
                        value: settings.forecastMode,
                        items: {
                          for (final v in ForecastMode.values) v: v.title,
                        },
                        onChanged: settings.setForecastMode,
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: Slider(
                              value: settings.forecastDays.toDouble(),
                              min: 1,
                              max: 16,
                              divisions: 15,
                              label: "${settings.forecastDays} дн.",
                              onChanged: settings.showForecast
                                  ? (v) => settings.setForecastDays(v.round())
                                  : null,
                            ),
                          ),
                          SizedBox(
                            width: 56,
                            child: Text(
                              "${settings.forecastDays} дн.",
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: glass.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(BuildContext context, String text) {
    final glass = context.glass;
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: glass.textSecondary,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _dropdownRow<T extends Enum>(
    BuildContext context, {
    required String title,
    required T value,
    required Map<T, String> items,
    required ValueChanged<T> onChanged,
  }) {
    final glass = context.glass;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(fontSize: 14.5, color: glass.textPrimary),
            ),
          ),
          DropdownButton<T>(
            value: value,
            underline: const SizedBox.shrink(),
            dropdownColor: glass.bgTop,
            borderRadius: BorderRadius.circular(12),
            style: TextStyle(fontSize: 14, color: glass.textPrimary),
            icon: Icon(Icons.expand_more, color: glass.textSecondary, size: 20),
            items: [
              for (final e in items.entries)
                DropdownMenuItem<T>(value: e.key, child: Text(e.value)),
            ],
            onChanged: (v) => v == null ? null : onChanged(v),
          ),
        ],
      ),
    );
  }

  Widget _switchRow(
    BuildContext context,
    String title,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    final glass = context.glass;
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: TextStyle(fontSize: 14.5, color: glass.textPrimary),
          ),
        ),
        Switch(value: value, onChanged: onChanged),
      ],
    );
  }
}
