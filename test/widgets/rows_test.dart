import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pizzalator/theme/pizza_theme.dart';
import 'package:pizzalator/widgets/widgets.dart';

const c = PizzaColors.dark;

Widget host(Widget child) => MaterialApp(
  theme: pizzaTheme(Brightness.dark),
  home: Scaffold(
    body: Center(child: SizedBox(width: 350, child: child)),
  ),
);

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('step button is 44 px, ground fill, line-strong border', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      host(
        Row(
          children: [
            StepButton(
              icon: Icons.add,
              semanticLabel: 'More',
              onPressed: () => taps++,
            ),
            const StepButton(icon: Icons.remove, semanticLabel: 'Less'),
          ],
        ),
      ),
    );
    final more = find.byType(StepButton).first;
    expect(tester.getSize(more), const Size(44, 44));
    final d =
        tester
                .widget<Container>(
                  find.descendant(of: more, matching: find.byType(Container)),
                )
                .decoration!
            as BoxDecoration;
    expect(d.color, c.ground);
    expect((d.border! as Border).top.color, c.lineStrong);
    await tester.tap(more);
    await tester.tap(find.byIcon(Icons.remove));
    expect(taps, 1);
    expect(
      tester
          .widget<Opacity>(
            find.descendant(
              of: find.byType(StepButton).last,
              matching: find.byType(Opacity),
            ),
          )
          .opacity,
      0.4,
    );
  });

  testWidgets('value stepper shows its row and steps both ways', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    var value = 2;
    await tester.pumpWidget(
      host(
        StatefulBuilder(
          builder: (context, setState) => ValueStepper(
            leading: const SizedBox(
              key: ValueKey('dot'),
              width: 10,
              height: 10,
            ),
            label: 'Room bulk',
            sublabel: '21 °C · yeast works fast',
            value: '${value}h',
            onMinus: () => setState(() => value--),
            onPlus: () => setState(() => value++),
            canMinus: value > 1,
            trailing: const Text('x'),
          ),
        ),
      ),
    );
    expect(find.text('Room bulk'), findsOneWidget);
    expect(find.text('21 °C · yeast works fast'), findsOneWidget);
    expect(find.byKey(const ValueKey('dot')), findsOneWidget);
    expect(find.text('x'), findsOneWidget);
    expect(find.bySemanticsLabel('Less room bulk'), findsOneWidget);
    expect(find.bySemanticsLabel('More room bulk'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();
    expect(find.text('3h'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.remove));
    await tester.tap(find.byIcon(Icons.remove));
    await tester.pump();
    expect(find.text('1h'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.remove));
    await tester.pump();
    expect(find.text('1h'), findsOneWidget, reason: 'minus disabled at 1');
    semantics.dispose();
  });

  testWidgets('value stepper without extras', (tester) async {
    await tester.pumpWidget(
      host(
        ValueStepper(
          label: 'Fridge',
          value: '24h',
          onMinus: () {},
          onPlus: () {},
          canPlus: false,
        ),
      ),
    );
    expect(find.text('24h'), findsOneWidget);
    expect(find.byType(StepButton), findsNWidgets(2));
  });

  BoxDecoration iconBox(WidgetTester tester, Finder row) =>
      tester
              .widget<Container>(
                find
                    .ancestor(
                      of: find.descendant(of: row, matching: find.byType(Icon)),
                      matching: find.byType(Container),
                    )
                    .first,
              )
              .decoration!
          as BoxDecoration;

  Color? iconColor(WidgetTester tester, Finder row) => tester
      .widget<Icon>(find.descendant(of: row, matching: find.byType(Icon)))
      .color;

  testWidgets('step row tints by state and accent', (tester) async {
    const accent = Color(0xFFC9A227);
    await tester.pumpWidget(
      host(
        const Column(
          children: [
            StepRow(
              key: ValueKey('done'),
              name: 'Rest in bowl',
              sub: 'done',
              trailing: '30 min',
              state: StepRowState.done,
              accent: accent,
            ),
            StepRow(
              key: ValueKey('now'),
              name: 'Fold in bowl',
              sub: 'in progress',
              state: StepRowState.current,
              accent: accent,
              icon: Icons.back_hand_outlined,
            ),
            StepRow(
              key: ValueKey('next'),
              name: 'Rest, covered',
              state: StepRowState.upcoming,
              accent: accent,
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    final done = find.byKey(const ValueKey('done'));
    final now = find.byKey(const ValueKey('now'));
    final next = find.byKey(const ValueKey('next'));

    expect(find.text('30 min'), findsOneWidget);
    expect(
      tester.widget<Text>(find.text('30 min')).style!.fontFamily,
      'Inter_500',
    );
    expect(
      tester
          .widget<AnimatedOpacity>(
            find.descendant(of: done, matching: find.byType(AnimatedOpacity)),
          )
          .opacity,
      0.45,
    );
    expect(iconBox(tester, done).color, c.sageTint);
    expect(iconColor(tester, done), c.ink);

    final nowRow =
        tester
                .widget<AnimatedContainer>(
                  find.descendant(
                    of: now,
                    matching: find.byType(AnimatedContainer),
                  ),
                )
                .decoration!
            as BoxDecoration;
    expect(nowRow.color, c.emberTint);
    // Ember when current, whatever the kind: one accent per row.
    expect(iconBox(tester, now).color, c.ember);
    expect(iconColor(tester, now), c.onEmber);
    expect(find.byIcon(Icons.back_hand_outlined), findsOneWidget);

    expect(iconBox(tester, next).color, c.surfaceRaised);
    expect(iconColor(tester, next), accent);
    expect(
      tester
          .widget<AnimatedOpacity>(
            find.descendant(of: next, matching: find.byType(AnimatedOpacity)),
          )
          .opacity,
      1,
    );
  });
}
