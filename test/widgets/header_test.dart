import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pizzalator/theme/pizza_theme.dart';
import 'package:pizzalator/widgets/widgets.dart';

const c = PizzaColors.dark;

Widget host(Widget child) => MaterialApp(
  theme: pizzaTheme(Brightness.dark),
  home: Scaffold(body: child),
);

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('section label is uppercase ink-muted unless tinted', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        const Column(
          children: [
            SectionLabel('Hydration'),
            SectionLabel('Tip', color: Color(0xFF123456)),
          ],
        ),
      ),
    );
    expect(
      tester.widget<Text>(find.text('HYDRATION')).style!.color,
      c.inkMuted,
    );
    expect(
      tester.widget<Text>(find.text('TIP')).style!.color,
      const Color(0xFF123456),
    );
  });

  testWidgets('header shows title, eyebrow, subtitle, trailing and action', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        const ScreenHeader(
          eyebrow: 'Pizzalator',
          title: 'Dough',
          subtitle: 'New York',
          backLabel: 'Calculator',
          action: Text('Edit routine'),
          trailing: Text('63.5'),
        ),
      ),
    );
    expect(tester.widget<Text>(find.text('PIZZALATOR')).style!.color, c.ember);
    expect(tester.widget<Text>(find.text('Dough')).style!.fontSize, 30);
    expect(find.text('New York'), findsOneWidget);
    expect(find.text('Edit routine'), findsOneWidget);
    expect(find.text('63.5'), findsOneWidget);
  });

  testWidgets('a long title shrinks at large text, never splits a word', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: pizzaTheme(Brightness.dark),
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(390, 844),
            textScaler: TextScaler.linear(2),
          ),
          child: Scaffold(
            body: ScreenHeader(
              title: 'Fermentation',
              trailing: const Text('26 h'),
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    // 30 px × 1.1 line × 2: one line, however wide the word.
    final title = tester.getSize(find.text('Fermentation'));
    expect(title.height, lessThanOrEqualTo(66.5));
    expect(tester.getRect(find.text('Fermentation')).right, lessThan(370));
  });

  testWidgets('back label uses the medium weight', (tester) async {
    await tester.pumpWidget(
      host(const ScreenHeader(backLabel: 'Recipe', title: 'Dough')),
    );
    expect(
      tester.widget<Text>(find.text('Recipe')).style!.fontFamily,
      'Inter_500',
    );
  });

  testWidgets('no back row without back label or action', (tester) async {
    await tester.pumpWidget(host(const ScreenHeader(title: 'Dough')));
    expect(find.byIcon(Icons.arrow_back), findsNothing);
  });

  testWidgets('back link pops by default and meets tap target', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: pizzaTheme(Brightness.dark),
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const Scaffold(
                  body: ScreenHeader(
                    backLabel: 'Calculator',
                    title: 'Fermentation',
                  ),
                ),
              ),
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    final link = find
        .ancestor(
          of: find.text('Calculator'),
          matching: find.byType(GestureDetector),
        )
        .first;
    expect(tester.getSize(link).height, greaterThanOrEqualTo(44));
    await tester.tap(link);
    await tester.pumpAndSettle();
    expect(find.text('Fermentation'), findsNothing);
  });

  testWidgets('back link calls onBack when given', (tester) async {
    var backs = 0;
    await tester.pumpWidget(
      host(
        ScreenHeader(
          backLabel: 'Recipe',
          onBack: () => backs++,
          title: 'Dough routine',
        ),
      ),
    );
    await tester.tap(find.text('Recipe'));
    expect(backs, 1);
  });

  testWidgets('header icon button: 44 × 44 surface tile, labelled, taps', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      host(
        Center(
          child: HeaderIconButton(
            icon: Icons.bookmark_border,
            label: 'Saved recipes',
            onPressed: () => taps++,
          ),
        ),
      ),
    );
    expect(tester.getSize(find.byType(HeaderIconButton)), const Size(44, 44));
    final style = tester.widget<IconButton>(find.byType(IconButton)).style!;
    expect(style.backgroundColor!.resolve({}), c.surface);
    expect(style.side!.resolve({})!.color, c.line);
    expect(
      style.shape!.resolve({}),
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    );
    // TalkBack reads the tooltip.
    expect(find.byTooltip('Saved recipes'), findsOneWidget);
    await tester.tap(find.byType(HeaderIconButton));
    expect(taps, 1);
  });
}
