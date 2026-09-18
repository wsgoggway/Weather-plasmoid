/// График температуры на 48 часов: линия + мягкая заливка, подписи
/// min/max. Собственный CustomPainter — без внешних зависимостей.
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../app_theme.dart';
import 'glass_card.dart';

class TempChart extends StatelessWidget {
  final List<int> temps;
  final List<String> timeLabels; // "HH:MM" по точкам (для оси)

  const TempChart({super.key, required this.temps, required this.timeLabels});

  @override
  Widget build(BuildContext context) {
    if (temps.length < 2) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle("Температура по часам"),
        GlassCard(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
          child: SizedBox(
            height: 120,
            width: double.infinity,
            child: CustomPaint(
              painter: _TempChartPainter(
                temps: temps,
                labels: timeLabels,
                line: context.glass.accent,
                fill: context.glass.accent.withValues(alpha: 0.18),
                labelColor: context.glass.textSecondary,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _TempChartPainter extends CustomPainter {
  final List<int> temps;
  final List<String> labels;
  final Color line;
  final Color fill;
  final Color labelColor;

  static const _hPadding = 6.0;
  static const _vPadding = 22.0;

  _TempChartPainter({
    required this.temps,
    required this.labels,
    required this.line,
    required this.fill,
    required this.labelColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width - _hPadding * 2;
    final h = size.height - _vPadding * 2;
    final minT = temps.reduce(math.min).toDouble();
    final maxT = temps.reduce(math.max).toDouble();
    final span = (maxT - minT).clamp(1.0, double.infinity);

    Offset pointAt(int i) => Offset(
      _hPadding + w * i / (temps.length - 1),
      _vPadding + h * (1 - (temps[i] - minT) / span),
    );

    final path = ui.Path()..moveTo(pointAt(0).dx, pointAt(0).dy);
    for (var i = 1; i < temps.length; i++) {
      path.lineTo(pointAt(i).dx, pointAt(i).dy);
    }

    // Заливка под линией.
    final fillPath = ui.Path.from(path)
      ..lineTo(pointAt(temps.length - 1).dx, size.height - _vPadding + 8)
      ..lineTo(pointAt(0).dx, size.height - _vPadding + 8)
      ..close();
    canvas.drawPath(fillPath, Paint()..color = fill);
    canvas.drawPath(
      path,
      Paint()
        ..color = line
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );

    // Точка «сейчас».
    canvas.drawCircle(pointAt(0), 4, Paint()..color = line);
    canvas.drawCircle(
      pointAt(0),
      8,
      Paint()..color = line.withValues(alpha: 0.25),
    );

    // Подписи min/max у крайних точек.
    final minIdx = temps.indexOf(temps.reduce(math.min));
    final maxIdx = temps.indexOf(temps.reduce(math.max));
    _label(canvas, "${temps[minIdx]}°", pointAt(minIdx), above: false);
    _label(canvas, "${temps[maxIdx]}°", pointAt(maxIdx), above: true);

    // Метки времени каждые 6 часов (кроме первой — там «сейчас»-точка).
    final tp = TextPainter(
      text: TextSpan(
        text: "сейчас",
        style: TextStyle(fontSize: 10, color: labelColor),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(pointAt(0).dx, size.height - tp.height));
    for (var i = 6; i < temps.length; i += 6) {
      final label = i < labels.length ? labels[i] : "";
      if (label.isEmpty) continue;
      final painter = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(fontSize: 10, color: labelColor),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final x = (pointAt(i).dx - painter.width / 2).clamp(
        0.0,
        size.width - painter.width,
      );
      painter.paint(canvas, Offset(x, size.height - painter.height));
    }
  }

  void _label(Canvas canvas, String text, Offset at, {required bool above}) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: labelColor,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final dy = above ? at.dy - tp.height - 6 : at.dy + 6;
    final dx = (at.dx - tp.width / 2).clamp(0.0, 10000.0);
    tp.paint(canvas, Offset(dx, dy));
  }

  @override
  bool shouldRepaint(_TempChartPainter oldDelegate) =>
      oldDelegate.temps != temps || oldDelegate.line != line;
}
