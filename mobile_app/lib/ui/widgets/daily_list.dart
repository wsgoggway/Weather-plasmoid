/// Прогноз по дням: строки с градиентным темп-баром (нормализация по
/// min/max всей недели), вероятностью осадков и min/max температурами.
library;

import 'dart:math';

import 'package:flutter/material.dart';

import '../../app_theme.dart';
import '../../data/weather_state.dart';
import '../../domain/wmo.dart';
import 'glass_card.dart';

class DailyList extends StatelessWidget {
  final List<DayItem> days;

  const DailyList({super.key, required this.days});

  @override
  Widget build(BuildContext context) {
    if (days.isEmpty) return const SizedBox.shrink();
    final weekMin = days.map((d) => d.tempMin).reduce(min);
    final weekMax = days.map((d) => d.tempMax).reduce(max);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle("Прогноз по дням"),
        GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Column(
            children: [
              for (var i = 0; i < days.length; i++)
                _DayRow(
                  day: days[i],
                  label: dayLabel(days[i].date, i),
                  weekMin: weekMin,
                  weekMax: weekMax,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DayRow extends StatelessWidget {
  final DayItem day;
  final String label;
  final int weekMin;
  final int weekMax;

  const _DayRow({
    required this.day,
    required this.label,
    required this.weekMin,
    required this.weekMax,
  });

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    final span = (weekMax - weekMin).clamp(1, 1 << 31);
    final start = (day.tempMin - weekMin) / span;
    final width = ((day.tempMax - day.tempMin) / span).clamp(0.03, 1.0);
    final rainAccent = day.precProb >= 40;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          SizedBox(
            width: 64,
            child: Text(
              label,
              style: TextStyle(fontSize: 14, color: glass.textPrimary),
            ),
          ),
          SizedBox(
            width: 30,
            child: Text(day.emoji, style: const TextStyle(fontSize: 18)),
          ),
          SizedBox(
            width: 52,
            child: Text(
              "💧${day.precProb}%",
              style: TextStyle(
                fontSize: 12,
                color: rainAccent ? glass.accent : glass.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: _TempBar(start: start, width: width, track: glass.divider),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 34,
            child: Text(
              "${day.tempMin}°",
              textAlign: TextAlign.right,
              style: TextStyle(fontSize: 14, color: glass.textSecondary),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 34,
            child: Text(
              "${day.tempMax}°",
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: glass.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Горизонтальный темп-бар: дорожка 6 px, заполнение градиентом
/// #4fc3f7 → #ffb74d — точь-в-точь как в виджете.
class _TempBar extends StatelessWidget {
  final double start;
  final double width;
  final Color track;

  const _TempBar({
    required this.start,
    required this.width,
    required this.track,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final barWidth = w * width;
        final left = (w * start).clamp(0.0, w - barWidth);
        return Container(
          height: 6,
          decoration: BoxDecoration(
            color: track,
            borderRadius: BorderRadius.circular(3),
          ),
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: EdgeInsets.only(left: left),
            child: Container(
              width: barWidth,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(3),
                gradient: const LinearGradient(
                  colors: [GlassPalette.barCold, GlassPalette.barWarm],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
