import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pizzalator/theme/pizza_theme.dart';
import 'package:pizzalator/widgets/widgets.dart';

const c = PizzaColors.dark;

Widget host(Widget child, {bool reduce = false}) => MaterialApp(
  theme: pizzaTheme(Brightness.dark),
  builder: (context, app) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: reduce),
    child: app!,
  ),
  home: Scaffold(
    body: Center(child: SizedBox(width: 300, child: child)),
  ),
);

String grams(double v) => '${v.round()} g';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  for (final reduce in [false, true]) {
    testWidgets('number tweens over 450 ms (reduced motion: $reduce)', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(TweenNumber(value: 0, format: grams), reduce: reduce),
      );
      expect(find.text('0 g'), findsOneWidget);
      expect(tester.widget<Text>(find.text('0 g')).style!.fontSize, 15);
      await tester.pumpWidget(
        host(TweenNumber(value: 100, format: grams), reduce: reduce),
      );
      await tester.pump(const Duration(milliseconds: 150));
      final mid = tester.widget<Text>(find.byType(Text)).data!;
      expect(mid, isNot(anyOf('0 g', '100 g')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('100 g'), findsOneWidget);
    });
  }

  testWidgets('stat shows label, big value and muted unit', (tester) async {
    await tester.pumpWidget(
      host(
        const Column(
          children: [
            Stat(label: 'Hydration', value: '63.5', unit: '%'),
            Stat(
              label: 'Yeast',
              value: '2.35',
              color: Color(0xFF00FF00),
              size: 44,
            ),
          ],
        ),
      ),
    );
    expect(find.text('HYDRATION'), findsOneWidget);
    final big = tester.widget<Text>(find.text('63.5')).style!;
    expect(big.color, c.emberBright);
    expect(big.fontSize, 34);
    expect(tester.widget<Text>(find.text('%')).style!.color, c.inkMuted);
    final yeast = tester.widget<Text>(find.text('2.35')).style!;
    expect(yeast.color, const Color(0xFF00FF00));
    expect(yeast.fontSize, 44);
  });

  testWidgets('stat is one TalkBack stop, label first', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      host(
        const Stat(
          label: 'Hydration',
          value: '62.5',
          unit: '%',
          labelBelow: true,
        ),
      ),
    );
    expect(find.bySemanticsLabel('Hydration 62.5%'), findsOneWidget);
    expect(find.bySemanticsLabel('62.5'), findsNothing);
    await tester.pumpWidget(
      host(
        Stat.tween(
          label: 'Yeast',
          value: 2,
          format: (v) => v.toStringAsFixed(2),
          unit: 'g',
        ),
      ),
    );
    expect(find.bySemanticsLabel('Yeast 2.00 g'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('stat unit uses the medium weight', (tester) async {
    await tester.pumpWidget(
      host(const Stat(label: 'Hydration', value: '63.5', unit: '%')),
    );
    expect(tester.widget<Text>(find.text('%')).style!.fontFamily, 'Inter_500');
  });

  testWidgets('stat can put its label below, right aligned', (tester) async {
    await tester.pumpWidget(
      host(
        const Stat(
          label: 'balls ready',
          value: '18:40',
          labelBelow: true,
          alignment: CrossAxisAlignment.end,
        ),
      ),
    );
    expect(
      tester.getTopLeft(find.text('BALLS READY')).dy,
      greaterThan(tester.getTopLeft(find.text('18:40')).dy),
    );
  });

  testWidgets('stat.tween tweens its value', (tester) async {
    String f(double v) => v.toStringAsFixed(2);
    await tester.pumpWidget(
      host(Stat.tween(label: 'Yeast', value: 1, format: f, unit: 'g')),
    );
    expect(find.text('1.00'), findsOneWidget);
    await tester.pumpWidget(
      host(Stat.tween(label: 'Yeast', value: 2, format: f, unit: 'g')),
    );
    await tester.pump(const Duration(milliseconds: 150));
    expect(find.text('2.00'), findsNothing);
    await tester.pumpAndSettle();
    expect(find.text('2.00'), findsOneWidget);
    expect(tester.widget<Text>(find.text('2.00')).style!.fontSize, 34);
  });

  testWidgets('range bar fills between min and max and clamps', (tester) async {
    double factor() => tester
        .widget<AnimatedFractionallySizedBox>(
          find.byType(AnimatedFractionallySizedBox),
        )
        .widthFactor!;
    await tester.pumpWidget(
      host(
        const RangeBar(
          min: 40,
          max: 90,
          value: 65,
          minLabel: '60% style min',
          centerLabel: 'protein 13%',
          maxLabel: '67% max',
        ),
      ),
    );
    expect(factor(), 0.5);
    expect(find.text('60% style min'), findsOneWidget);
    expect(find.text('protein 13%'), findsOneWidget);
    expect(find.text('67% max'), findsOneWidget);
    final fill = tester.widget<DecoratedBox>(
      find.descendant(
        of: find.byType(AnimatedFractionallySizedBox),
        matching: find.byType(DecoratedBox),
      ),
    );
    expect((fill.decoration as BoxDecoration).color, c.ember);

    await tester.pumpWidget(host(const RangeBar(min: 40, max: 90, value: 120)));
    expect(factor(), 1);
    await tester.pump(const Duration(milliseconds: 100));
    final w = tester
        .getSize(
          find.descendant(
            of: find.byType(AnimatedFractionallySizedBox),
            matching: find.byType(DecoratedBox),
          ),
        )
        .width;
    expect(w, inExclusiveRange(150, 300));
    await tester.pumpAndSettle();
    expect(find.byType(Text), findsNothing);
  });

  testWidgets('range bar track uses surface-raised', (tester) async {
    await tester.pumpWidget(
      host(const RangeBar(min: 0, max: 1, value: 0, maxLabel: 'max')),
    );
    final track = tester.widget<Container>(
      find
          .ancestor(
            of: find.byType(AnimatedFractionallySizedBox),
            matching: find.byType(Container),
          )
          .first,
    );
    expect(track.color, c.surfaceRaised);
    expect(find.text('max'), findsOneWidget);
  });
}
