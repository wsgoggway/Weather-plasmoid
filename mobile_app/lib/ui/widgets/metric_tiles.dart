/// Плитки метрик в стиле Apple Weather: сетка 2 колонки — ветер, порывы,
/// влажность, давление, точка росы, облачность, осадки, УФ, солнце.
/// Плюс отдельная карточка качества воздуха с цветной точкой.
library;

import 'package:flutter/material.dart';

import '../../app_theme.dart';
import '../../data/weather_state.dart';
import '../../domain/wmo.dart';
import 'glass_card.dart';

class MetricTiles extends StatelessWidget {
  final CurrentData current;
  final String tempUnit;
  final String windUnit;
  final String pressureUnit;
  final String sunrise;
  final String sunset;
  final double uvIndex;
  final double precipSum;

  const MetricTiles({
    super.key,
    required this.current,
    required this.tempUnit,
    required this.windUnit,
    required this.pressureUnit,
    required this.sunrise,
    required this.sunset,
    required this.uvIndex,
    required this.precipSum,
  });

  @override
  Widget build(BuildContext context) {
    final dewLabel = current.dewPoint.toStringAsFixed(1);
    final cells = <(String, String, String)>[
      (
        "💨",
        "Ветер",
        "${_fmt(current.windSpeed)} $windUnit ${current.windDir}",
      ),
      ("🌬", "Порывы", "${current.gusts.toStringAsFixed(1)} $windUnit"),
      ("💦", "Точка росы", "$dewLabel$tempUnit"),
      ("💧", "Влажность", "${current.humidity}%"),
      ("🧭", "Давление", "${current.pressure} $pressureUnit"),
      ("☁️", "Облачность", "${current.cloudCover}%"),
      ("🌧", "Осадки", "${precipSum.toStringAsFixed(1)} мм"),
      ("☀️", "УФ-индекс", uvText(uvIndex)),
      ("🌅", "Солнце", "$sunrise – $sunset"),
    ];

    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          for (var row = 0; row < cells.length; row += 2)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _tile(context, cells[row])),
                  if (row + 1 < cells.length)
                    Expanded(child: _tile(context, cells[row + 1]))
                  else
                    const Expanded(child: SizedBox()),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _tile(BuildContext context, (String, String, String) cell) {
    final glass = context.glass;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(cell.$1, style: const TextStyle(fontSize: 15)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                cell.$2,
                style: TextStyle(fontSize: 11.5, color: glass.textSecondary),
              ),
              const SizedBox(height: 2),
              Text(
                cell.$3,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w500,
                  color: glass.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static String _fmt(num v) => v % 1 == 0 ? v.toInt().toString() : v.toString();
}

/// Карточка качества воздуха: цветная точка по уровню + "NN · Плохое".
class AqiCard extends StatelessWidget {
  final double aqi;

  const AqiCard({super.key, required this.aqi});

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    final info = aqiInfo(aqi);
    final dotColor = switch (info.level) {
      0 => glass.levelOk,
      1 => glass.levelMid,
      _ => glass.levelBad,
    };
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Text("🌫", style: const TextStyle(fontSize: 15)),
          const SizedBox(width: 8),
          Text(
            "Качество воздуха",
            style: TextStyle(fontSize: 13, color: glass.textSecondary),
          ),
          const Spacer(),
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            info.text,
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w500,
              color: glass.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
