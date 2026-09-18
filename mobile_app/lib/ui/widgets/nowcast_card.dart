/// Карточка nowcast «Осадки сейчас»: статус + 8 столбиков по 15 минут.
/// Аналог фишки Яндекс Погоды на данных minutely_15.
library;

import 'package:flutter/material.dart';

import '../../app_theme.dart';
import '../../domain/nowcast.dart';
import 'glass_card.dart';

class NowcastCard extends StatelessWidget {
  final Nowcast nowcast;

  const NowcastCard({super.key, required this.nowcast});

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    final maxP = nowcast.maxPrecipitation;
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text("🌧", style: const TextStyle(fontSize: 15)),
              const SizedBox(width: 8),
              Text(
                "Осадки сейчас",
                style: TextStyle(fontSize: 13, color: glass.textSecondary),
              ),
              const Spacer(),
              Flexible(
                child: Text(
                  nowcast.statusText,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                    color: glass.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 44,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final slot in nowcast.slots)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: _Bar(
                        fraction: maxP > 0
                            ? (slot.precipitation / maxP).clamp(0.04, 1.0)
                            : 0.04,
                        raining: slot.precipitation > 0,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "сейчас",
                style: TextStyle(fontSize: 10, color: glass.textSecondary),
              ),
              Text(
                "через 2 часа",
                style: TextStyle(fontSize: 10, color: glass.textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  final double fraction;
  final bool raining;

  const _Bar({required this.fraction, required this.raining});

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    final Gradient gradient = raining
        ? const LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [GlassPalette.barCold, Color(0x884fc3f7)],
          )
        : LinearGradient(colors: [glass.divider, glass.divider]);
    return FractionallySizedBox(
      heightFactor: fraction,
      widthFactor: 1,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          gradient: gradient,
        ),
      ),
    );
  }
}
