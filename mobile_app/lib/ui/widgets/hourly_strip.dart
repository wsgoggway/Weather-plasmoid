/// Почасовая лента: горизонтальный скролл, «Сейчас» первым, эмодзи,
/// температура и вероятность осадков 💧 (акцент ≥40%, как в виджете).
library;

import 'package:flutter/material.dart';

import '../../app_theme.dart';
import '../../data/weather_state.dart';
import 'glass_card.dart';

class HourlyStrip extends StatelessWidget {
  final List<HourItem> hours;

  const HourlyStrip({super.key, required this.hours});

  @override
  Widget build(BuildContext context) {
    final overflow = hours.length > 8;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(
          "Почасовой прогноз",
          trailing: overflow ? "листай →" : null,
        ),
        GlassCard(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: SizedBox(
            height: 108,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: overflow
                  ? const ClampingScrollPhysics()
                  : const NeverScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: hours.length,
              separatorBuilder: (_, _) => const SizedBox(width: 6),
              itemBuilder: (context, i) => _HourCell(
                hour: hours[i],
                first: i == 0,
                accentRain: hours[i].precProb >= 40,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _HourCell extends StatelessWidget {
  final HourItem hour;
  final bool first;
  final bool accentRain;

  const _HourCell({
    required this.hour,
    required this.first,
    required this.accentRain,
  });

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    final label = first ? "Сейчас" : _hourLabel(hour.time);
    return SizedBox(
      width: 64,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 12, color: glass.textSecondary),
          ),
          Text(hour.emoji, style: const TextStyle(fontSize: 22)),
          Text(
            "${hour.temp}°",
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: glass.textPrimary,
            ),
          ),
          Text(
            "💧${hour.precProb}%",
            style: TextStyle(
              fontSize: 11,
              color: accentRain ? glass.accent : glass.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

String _hourLabel(String isoTime) {
  // "2026-09-18T15:00" → "15:00"
  final t = isoTime.split("T");
  if (t.length < 2) return isoTime;
  return t[1].substring(0, t[1].length >= 5 ? 5 : t[1].length);
}
