/// Стеклянная карточка — базовый контейнер всех секций (glassmorphism):
/// полупрозрачная заливка с «морозным» бликом + тонкая рамка, радиус 16.
///
/// Осознанно БЕЗ живого BackdropFilter: десяток блюров на экране — главный
/// источник лагов, а при скролле блюр внутри списка ещё и глючит (теряет
/// подложку). Статичный градиент даёт тот же вид стекла без цены блюра.
library;

import 'package:flutter/material.dart';

import '../../app_theme.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    return Padding(
      padding: margin ?? const EdgeInsets.symmetric(horizontal: 16),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: glass.cardBorder, width: 1),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withValues(alpha: 0.10),
              Colors.white.withValues(alpha: 0.04),
            ],
          ),
        ),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// Заголовок секции — как у виджета: небольшой, приглушённый.
class SectionTitle extends StatelessWidget {
  final String text;
  final String? trailing;

  const SectionTitle(this.text, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Row(
        children: [
          Text(
            text,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: glass.textSecondary,
              letterSpacing: 0.2,
            ),
          ),
          const Spacer(),
          if (trailing != null)
            Text(
              trailing!,
              style: TextStyle(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: glass.textSecondary,
              ),
            ),
        ],
      ),
    );
  }
}
