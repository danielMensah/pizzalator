import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pizzalator/theme/pizza_theme.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  test('themes carry tokens', () {
    expect(
      pizzaTheme(Brightness.dark).scaffoldBackgroundColor,
      PizzaColors.dark.ground,
    );
    expect(
      pizzaTheme(Brightness.light).scaffoldBackgroundColor,
      PizzaColors.light.ground,
    );
    expect(
      pizzaTheme(Brightness.light).extension<PizzaColors>(),
      PizzaColors.light,
    );
  });

  test('text styles use tabular numerals and token sizes', () {
    final t = PizzaText(PizzaColors.dark);
    expect(t.displayMd.fontSize, 34);
    expect(t.h1.fontSize, 30);
    expect(t.label.letterSpacing, closeTo(0.88, 1e-9));
    for (final s in [t.displayXl, t.number, t.body]) {
      expect(s.fontFeatures, contains(const FontFeature.tabularFigures()));
    }
  });

  test('every weight is its own style: the family names the weight', () {
    // google_fonts picks the font file by family (Inter_600); a copyWith of
    // fontWeight keeps the old file. So each weight in use has a style.
    final t = PizzaText(PizzaColors.dark);
    final want = {
      t.body: 'Inter_regular',
      t.bodyStrong: 'Inter_600',
      t.caption: 'Inter_500',
      t.captionRegular: 'Inter_regular',
      t.number: 'Inter_700',
      t.numberMuted: 'Inter_500',
      t.button: 'Inter_600',
      t.buttonCta: 'Inter_700',
      t.buttonMd: 'Inter_500',
      t.segment: 'Inter_500',
      t.unit: 'Inter_500',
    };
    for (final MapEntry(key: style, value: family) in want.entries) {
      expect(style.fontFamily, family);
    }
    expect([t.buttonCta.fontSize, t.segment.fontSize], [16, 13]);
    expect(t.numberMuted.color, PizzaColors.dark.inkMuted);
  });

  test('no Material card or filled-button theme: the widgets own them', () {
    final theme = pizzaTheme(Brightness.dark);
    expect(theme.filledButtonTheme.style, isNull);
    expect(theme.cardTheme.shape, isNull);
  });

  test('lerp snaps at midpoint, copyWith is identity', () {
    const d = PizzaColors.dark;
    const l = PizzaColors.light;
    expect(d.lerp(l, 0.2), d);
    expect(d.lerp(l, 0.8), l);
    expect(d.lerp(null, 0.8), d);
    expect(d.copyWith(), d);
    final t = PizzaText(d);
    final u = PizzaText(l);
    expect(t.lerp(u, 0.2), t);
    expect(t.lerp(u, 0.8), u);
    expect(t.lerp(null, 0.8), t);
    expect(t.copyWith(), t);
  });

  testWidgets('context extensions resolve', (tester) async {
    late PizzaColors c;
    late PizzaText t;
    await tester.pumpWidget(
      MaterialApp(
        theme: pizzaTheme(Brightness.light),
        home: Builder(
          builder: (context) {
            c = context.colors;
            t = context.text;
            return const SizedBox();
          },
        ),
      ),
    );
    expect(c, PizzaColors.light);
    expect(t.body.color, PizzaColors.light.ink);
  });
}
