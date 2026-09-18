/// Тёмная glass-тема приложения. Токены унаследованы от виджета и
/// new_template.html: карточки 5% белого с радиусом 16, акцент #3daee9,
/// градиент темп-бара #4fc3f7 → #ffb74d.
library;

import 'package:flutter/material.dart';

/// Палитра «стекла», доступна из контекста: `context.glass`.
class GlassPalette extends ThemeExtension<GlassPalette> {
  final Color bgTop;
  final Color bgBottom;
  final Color card;
  final Color cardBorder;
  final Color divider;
  final Color textPrimary;
  final Color textSecondary;
  final Color accent;
  final Color danger;
  final Color levelOk;
  final Color levelMid;
  final Color levelBad;

  static const barCold = Color(0xFF4fc3f7);
  static const barWarm = Color(0xFFffb74d);

  const GlassPalette({
    required this.bgTop,
    required this.bgBottom,
    required this.card,
    required this.cardBorder,
    required this.divider,
    required this.textPrimary,
    required this.textSecondary,
    required this.accent,
    required this.danger,
    required this.levelOk,
    required this.levelMid,
    required this.levelBad,
  });

  static const dark = GlassPalette(
    bgTop: Color(0xFF1e1e28),
    bgBottom: Color(0xFF101018),
    card: Color(0x0Dffffff), // 5% белого
    cardBorder: Color(0x1Affffff), // 10% белого
    divider: Color(0x1Fffffff), // 12% белого
    textPrimary: Color(0xF2ffffff),
    textSecondary: Color(0x99ffffff),
    accent: Color(0xFF3daee9),
    danger: Color(0xFFef5350),
    levelOk: Color(0xFF66bb6a),
    levelMid: Color(0xFFffb74d),
    levelBad: Color(0xFFef5350),
  );

  static const light = GlassPalette(
    bgTop: Color(0xFFe8ebf2),
    bgBottom: Color(0xFFd6dae4),
    card: Color(0x14ffffff),
    cardBorder: Color(0x3D000000),
    divider: Color(0x29000000),
    textPrimary: Color(0xF01b1b22),
    textSecondary: Color(0x8C1b1b22),
    accent: Color(0xFF2a8fc4),
    danger: Color(0xFFd32f2f),
    levelOk: Color(0xFF2e7d32),
    levelMid: Color(0xFFb26a00),
    levelBad: Color(0xFFc62828),
  );

  @override
  GlassPalette copyWith({Color? card, Color? divider}) => GlassPalette(
    bgTop: bgTop,
    bgBottom: bgBottom,
    card: card ?? this.card,
    cardBorder: cardBorder,
    divider: divider ?? this.divider,
    textPrimary: textPrimary,
    textSecondary: textSecondary,
    accent: accent,
    danger: danger,
    levelOk: levelOk,
    levelMid: levelMid,
    levelBad: levelBad,
  );

  @override
  GlassPalette lerp(GlassPalette? other, double t) {
    if (other == null) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return GlassPalette(
      bgTop: c(bgTop, other.bgTop),
      bgBottom: c(bgBottom, other.bgBottom),
      card: c(card, other.card),
      cardBorder: c(cardBorder, other.cardBorder),
      divider: c(divider, other.divider),
      textPrimary: c(textPrimary, other.textPrimary),
      textSecondary: c(textSecondary, other.textSecondary),
      accent: c(accent, other.accent),
      danger: c(danger, other.danger),
      levelOk: c(levelOk, other.levelOk),
      levelMid: c(levelMid, other.levelMid),
      levelBad: c(levelBad, other.levelBad),
    );
  }
}

extension GlassContext on BuildContext {
  GlassPalette get glass =>
      Theme.of(this).extension<GlassPalette>() ?? GlassPalette.dark;
}

class AppTheme {
  AppTheme._();

  static ThemeData dark() => _theme(Brightness.dark, GlassPalette.dark);
  static ThemeData light() => _theme(Brightness.light, GlassPalette.light);

  static ThemeData _theme(Brightness brightness, GlassPalette palette) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: palette.accent,
      brightness: brightness,
      surface: palette.bgBottom,
    );
    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: Colors.transparent,
    );
    return base.copyWith(
      extensions: [palette],
      textTheme: base.textTheme.apply(
        bodyColor: palette.textPrimary,
        displayColor: palette.textPrimary,
      ),
      iconTheme: IconThemeData(color: palette.textPrimary),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: palette.textPrimary,
        elevation: 0,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: palette.bgTop,
        contentTextStyle: TextStyle(color: palette.textPrimary),
        behavior: SnackBarBehavior.floating,
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: palette.accent,
        thumbColor: palette.accent,
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        menuStyle: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(palette.bgTop),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: palette.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: palette.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: palette.accent),
        ),
        hintStyle: TextStyle(color: palette.textSecondary),
      ),
    );
  }
}
