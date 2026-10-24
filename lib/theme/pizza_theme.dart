// Tokens from mockups/design-system/project/tokens.json.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

@immutable
class PizzaColors extends ThemeExtension<PizzaColors> {
  const PizzaColors({
    required this.ground,
    required this.surface,
    required this.surfaceRaised,
    required this.surfaceSheet,
    required this.line,
    required this.lineStrong,
    required this.ink,
    required this.inkSoft,
    required this.inkMuted,
    required this.ember,
    required this.emberBright,
    required this.onEmber,
    required this.emberTint,
    required this.emberLine,
    required this.sage,
    required this.sageBright,
    required this.sageTint,
    required this.sageLine,
    required this.wheat,
    required this.alert,
    required this.alertTint,
    required this.scrim,
  });

  final Color ground, surface, surfaceRaised, surfaceSheet, line, lineStrong;
  final Color ink, inkSoft, inkMuted;
  final Color ember, emberBright, onEmber, emberTint, emberLine;
  final Color sage, sageBright, sageTint, sageLine;
  final Color wheat, alert, alertTint, scrim;

  static const dark = PizzaColors(
    ground: Color(0xFF15110F),
    surface: Color(0xFF201A17),
    surfaceRaised: Color(0xFF2E2622),
    surfaceSheet: Color(0xFF1B1614),
    line: Color(0xFF2E2622),
    lineStrong: Color(0xFF3A302B),
    ink: Color(0xFFF3EDE4),
    inkSoft: Color(0xFFCFC4B8),
    inkMuted: Color(0xFFA89F93),
    ember: Color(0xFFE8863A),
    emberBright: Color(0xFFF3A25B),
    onEmber: Color(0xFF15110F),
    emberTint: Color(0xFF2A1F14),
    emberLine: Color(0xFF6B4420),
    sage: Color(0xFF5BA8A0),
    sageBright: Color(0xFF8FD3CB),
    sageTint: Color(0xFF1C2A2A),
    sageLine: Color(0xFF2F5B57),
    wheat: Color(0xFFC9A227),
    alert: Color(0xFFF0A3A3),
    alertTint: Color(0xFF3A2222),
    scrim: Color(0x99000000),
  );

  static const light = PizzaColors(
    ground: Color(0xFFFAF6F0),
    surface: Color(0xFFFFFFFF),
    surfaceRaised: Color(0xFFF1EAE0),
    surfaceSheet: Color(0xFFFFFDF9),
    line: Color(0xFFE4DCD0),
    lineStrong: Color(0xFFD2C8BA),
    ink: Color(0xFF1A1512),
    inkSoft: Color(0xFF4A423C),
    inkMuted: Color(0xFF6B6058),
    ember: Color(0xFFB85A17),
    emberBright: Color(0xFFD9752B),
    onEmber: Color(0xFFFFFFFF),
    emberTint: Color(0xFFFBEADB),
    emberLine: Color(0xFFE8C4A3),
    sage: Color(0xFF2E7E76),
    sageBright: Color(0xFF3C9A90),
    sageTint: Color(0xFFE3F2F0),
    sageLine: Color(0xFF9ED0CA),
    wheat: Color(0xFF8F6F0E),
    alert: Color(0xFFB3261E),
    alertTint: Color(0xFFFBE9E7),
    scrim: Color(0x661A1512),
  );

  @override
  PizzaColors copyWith() => this;

  // ponytail: theme switch snaps instead of cross-fading; per-field Color.lerp if it ever looks bad.
  @override
  PizzaColors lerp(PizzaColors? other, double t) =>
      t < 0.5 ? this : (other ?? this);
}

@immutable
class PizzaText extends ThemeExtension<PizzaText> {
  PizzaText(PizzaColors c)
    : displayXl = _display(54, -0.03, c.ink),
      displayLg = _display(44, -0.02, c.ink),
      displayMd = _display(34, -0.02, c.ink),
      h1 = _display(30, -0.02, c.ink, height: 1.1),
      h2 = _display(20, 0, c.ink, height: 1.2),
      body = _sans(15, 22, FontWeight.w400, c.ink),
      bodyStrong = _sans(15, 22, FontWeight.w600, c.ink),
      bodySm = _sans(13, 19, FontWeight.w400, c.inkSoft),
      caption = _sans(12, 16, FontWeight.w500, c.inkMuted),
      label = _sans(11, 16, FontWeight.w600, c.inkMuted, letterSpacing: 0.88),
      captionRegular = _sans(12, 16, FontWeight.w400, c.inkMuted),
      number = _sans(15, 20, FontWeight.w700, c.ink),
      numberMuted = _sans(15, 20, FontWeight.w500, c.inkMuted),
      unit = _sans(15, 22, FontWeight.w500, c.inkMuted),
      button = _sans(14, 20, FontWeight.w600, c.ink),
      buttonCta = _sans(16, 24, FontWeight.w700, c.ink),
      buttonMd = _sans(14, 20, FontWeight.w500, c.ink),
      segment = _sans(13, 19, FontWeight.w500, c.inkSoft);

  final TextStyle displayXl, displayLg, displayMd, h1, h2;
  final TextStyle body, bodyStrong, bodySm, caption, captionRegular, label;
  final TextStyle number, numberMuted, unit, button, buttonCta, buttonMd;

  /// Segmented control and chip labels.
  final TextStyle segment;

  static const _tabular = [FontFeature.tabularFigures()];

  static TextStyle _display(
    double size,
    double tracking,
    Color color, {
    double height = 1,
  }) => GoogleFonts.bricolageGrotesque(
    fontSize: size,
    height: height,
    fontWeight: FontWeight.w700,
    letterSpacing: size * tracking,
    color: color,
    fontFeatures: _tabular,
  );

  static TextStyle _sans(
    double size,
    double lineHeight,
    FontWeight weight,
    Color color, {
    double letterSpacing = 0,
  }) => GoogleFonts.inter(
    fontSize: size,
    height: lineHeight / size,
    fontWeight: weight,
    letterSpacing: letterSpacing,
    color: color,
    fontFeatures: _tabular,
  );

  @override
  PizzaText copyWith() => this;

  @override
  PizzaText lerp(PizzaText? other, double t) =>
      t < 0.5 ? this : (other ?? this);
}

ThemeData pizzaTheme(Brightness brightness) {
  final c = brightness == Brightness.dark
      ? PizzaColors.dark
      : PizzaColors.light;
  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    scaffoldBackgroundColor: c.ground,
    colorScheme: ColorScheme.fromSeed(
      seedColor: c.ember,
      brightness: brightness,
      primary: c.ember,
      onPrimary: c.onEmber,
      surface: c.surface,
      onSurface: c.ink,
      error: c.alert,
    ),
    textTheme: GoogleFonts.interTextTheme().apply(
      bodyColor: c.ink,
      displayColor: c.ink,
    ),
    // showPizzaSheet styles the sheet; only the theme reaches the handle.
    bottomSheetTheme: BottomSheetThemeData(
      dragHandleColor: c.lineStrong,
      dragHandleSize: const Size(40, 4),
    ),
    extensions: [c, PizzaText(c)],
  );
}

extension PizzaThemeX on BuildContext {
  PizzaColors get colors => Theme.of(this).extension<PizzaColors>()!;
  PizzaText get text => Theme.of(this).extension<PizzaText>()!;
}
