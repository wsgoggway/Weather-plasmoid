/// Карточка предупреждений о резких изменениях (Яндекс-стиль): янтарная
/// стеклянная карточка со списком событий — перепад t°, гроза, сильный ветер.
library;

import 'package:flutter/material.dart';

import '../../app_theme.dart';
import '../../domain/alerts.dart';
import 'glass_card.dart';

class AlertCard extends StatelessWidget {
  final List<WeatherAlert> alerts;

  const AlertCard({super.key, required this.alerts});

  @override
  Widget build(BuildContext context) {
    if (alerts.isEmpty) return const SizedBox.shrink();
    final glass = context.glass;
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                size: 16,
                color: glass.levelMid,
              ),
              const SizedBox(width: 8),
              Text(
                "Погода меняется",
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: glass.levelMid,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          for (final a in alerts)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(a.icon, style: const TextStyle(fontSize: 14)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      a.text,
                      style: TextStyle(
                        fontSize: 13.5,
                        height: 1.25,
                        color: glass.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
