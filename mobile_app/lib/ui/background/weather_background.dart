/// Динамический погодный фон (фишка Apple Weather + тренд 2026):
/// градиент по группе погодных условий и времени суток + лёгкие частицы
/// (дождь / снег / звёзды / облачность / туман). Анимации отключаются настройкой.
///
/// Производительность: частицы предрассчитаны один раз (не генерируются
/// заново в каждом кадре), прогресс квантован до 30 fps (дрейф медленный —
/// глазу неотличимо, растровых проходов вдвое меньше), painter обёрнут
/// в RepaintBoundary, чтобы его перерисовки не задевали остальные слои.
library;

import 'dart:math';

import 'package:flutter/material.dart';

enum WeatherKind { clearDay, clearNight, cloudy, rain, snow, storm, fog }

WeatherKind weatherKind({required int wmo, required bool isDay}) {
  if (isFoggyCode(wmo)) return WeatherKind.fog;
  if (wmo >= 95) return WeatherKind.storm;
  if (isRainyCode(wmo)) return WeatherKind.rain;
  if (isSnowyCode(wmo)) return WeatherKind.snow;
  if (wmo == 0 || wmo == 1 || wmo == 2) {
    return isDay ? WeatherKind.clearDay : WeatherKind.clearNight;
  }
  return WeatherKind.cloudy;
}

bool isRainyCode(int c) => const [
  51,
  53,
  55,
  56,
  57,
  61,
  63,
  65,
  66,
  67,
  80,
  81,
  82,
  95,
  96,
  99,
].contains(c);
bool isSnowyCode(int c) => const [71, 73, 75, 77, 85, 86].contains(c);
bool isFoggyCode(int c) => c == 45 || c == 48;

/// Пара цветов фона по условию — приглушённая версия палитры шаблона.
/// Светлая ветка — для системной светлой темы.
List<Color> _gradientFor(WeatherKind kind, bool light) => light
    ? switch (kind) {
        WeatherKind.clearDay => const [Color(0xFF9ec9ee), Color(0xFFcfe3f5)],
        WeatherKind.clearNight => const [Color(0xFF8fa5c4), Color(0xFFc5d2e4)],
        WeatherKind.cloudy => const [Color(0xFFaab6c5), Color(0xFFdde3ea)],
        WeatherKind.rain => const [Color(0xFF8ea0b5), Color(0xFFcdd7e0)],
        WeatherKind.snow => const [Color(0xFFb8c6d8), Color(0xFFe6ecf2)],
        WeatherKind.storm => const [Color(0xFF7f8aa5), Color(0xFFc6ccda)],
        WeatherKind.fog => const [Color(0xFFc2c9d2), Color(0xFFe8ebee)],
      }
    : switch (kind) {
        WeatherKind.clearDay => const [Color(0xFF2b5b8f), Color(0xFF1e3a5f)],
        WeatherKind.clearNight => const [Color(0xFF141428), Color(0xFF0a0a14)],
        WeatherKind.cloudy => const [Color(0xFF3a4453), Color(0xFF232a34)],
        WeatherKind.rain => const [Color(0xFF2c3a4d), Color(0xFF1a222d)],
        WeatherKind.snow => const [Color(0xFF46586e), Color(0xFF2a3543)],
        WeatherKind.storm => const [Color(0xFF2c2540), Color(0xFF17131f)],
        WeatherKind.fog => const [Color(0xFF454b55), Color(0xFF2c3038)],
      };

class WeatherBackground extends StatefulWidget {
  final WeatherKind kind;
  final bool animate;

  const WeatherBackground({
    super.key,
    required this.kind,
    required this.animate,
  });

  @override
  State<WeatherBackground> createState() => _WeatherBackgroundState();
}

class _WeatherBackgroundState extends State<WeatherBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 20),
  )..repeat();

  List<_Particle> _particles = const [];

  @override
  void initState() {
    super.initState();
    _regenParticles();
  }

  @override
  void didUpdateWidget(WeatherBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.kind != widget.kind) _regenParticles();
  }

  void _regenParticles() {
    final rnd = Random(widget.kind.index * 7 + 3);
    _particles = List.generate(
      _particleCountFor(widget.kind),
      (_) => _Particle.seeded(rnd),
    );
  }

  static int _particleCountFor(WeatherKind kind) => switch (kind) {
    WeatherKind.rain || WeatherKind.storm => 70,
    WeatherKind.snow => 60,
    WeatherKind.clearNight => 50,
    WeatherKind.fog => 10,
    WeatherKind.cloudy || WeatherKind.clearDay => 6,
  };

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final light = Theme.of(context).brightness == Brightness.light;
    final colors = _gradientFor(widget.kind, light);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 800),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: colors,
        ),
      ),
      child: widget.animate
          ? RepaintBoundary(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) => CustomPaint(
                  painter: _ParticlesPainter(
                    kind: widget.kind,
                    progress: (_controller.value * 30).floorToDouble() / 30,
                    particles: _particles,
                  ),
                  child: const SizedBox.expand(),
                ),
              ),
            )
          : null,
    );
  }
}

class _Particle {
  final double x; // 0..1
  final double y; // 0..1
  final double speed; // множитель скорости
  final double size;
  final double phase;

  const _Particle(this.x, this.y, this.speed, this.size, this.phase);

  factory _Particle.seeded(Random rnd) => _Particle(
    rnd.nextDouble(),
    rnd.nextDouble(),
    0.5 + rnd.nextDouble(),
    0.5 + rnd.nextDouble(),
    rnd.nextDouble() * 2 * pi,
  );
}

class _ParticlesPainter extends CustomPainter {
  final WeatherKind kind;
  final double progress;
  final List<_Particle> particles;

  _ParticlesPainter({
    required this.kind,
    required this.progress,
    required this.particles,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    switch (kind) {
      case WeatherKind.rain || WeatherKind.storm:
        paint.style = PaintingStyle.stroke;
        for (final p in particles) {
          final fall = ((progress * (0.6 + p.speed) + p.y) % 1.0);
          final dx = 18 * p.speed; // лёгкий наклон
          final y = fall * size.height;
          final x = p.x * size.width + dx * fall;
          paint.color = Colors.white.withValues(alpha: 0.10 + 0.10 * p.size);
          paint.strokeWidth = 1.2 * p.size;
          canvas.drawLine(
            Offset(x, y),
            Offset(x - dx * 0.12, y + 14 * p.size),
            paint,
          );
        }
      case WeatherKind.snow:
        for (final p in particles) {
          final fall = ((progress * (0.15 + 0.1 * p.speed) + p.y) % 1.0);
          final sway = sin((progress * 2 * pi + p.phase)) * 12;
          paint
            ..style = PaintingStyle.fill
            ..color = Colors.white.withValues(alpha: 0.25 + 0.25 * p.size);
          canvas.drawCircle(
            Offset(p.x * size.width + sway, fall * size.height),
            1.2 + 1.6 * p.size,
            paint,
          );
        }
      case WeatherKind.clearNight:
        for (final p in particles) {
          final twinkle = 0.5 + 0.5 * sin(progress * 2 * pi * 3 + p.phase);
          paint.color = Colors.white.withValues(
            alpha: 0.15 + 0.45 * twinkle * p.size,
          );
          canvas.drawCircle(
            Offset(p.x * size.width, p.y * size.height * 0.8),
            0.6 + 1.1 * p.size,
            paint,
          );
        }
      case WeatherKind.cloudy || WeatherKind.clearDay || WeatherKind.fog:
        _driftClouds(
          canvas,
          size,
          paint,
          alpha: kind == WeatherKind.fog
              ? 0.10
              : kind == WeatherKind.cloudy
              ? 0.06
              : 0.05,
        );
    }
  }

  void _driftClouds(
    Canvas canvas,
    Size size,
    Paint paint, {
    required double alpha,
  }) {
    for (final p in particles) {
      final drift = ((progress * 0.05 * p.speed + p.x) % 1.2) - 0.1;
      final cx = drift * size.width;
      final cy = p.y * size.height * 0.7 + 40;
      paint.color = Colors.white.withValues(alpha: alpha);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(cx, cy),
          width: 180 * p.size,
          height: 56 * p.size,
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_ParticlesPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.kind != kind ||
      !identical(oldDelegate.particles, particles);
}
