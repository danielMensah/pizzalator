import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pizzalator/theme/pizza_theme.dart';
import 'package:pizzalator/widgets/widgets.dart';

const c = PizzaColors.dark;

Widget host(Widget child, {bool reduce = false, double scale = 1}) =>
    MaterialApp(
      theme: pizzaTheme(Brightness.dark),
      builder: (context, app) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          disableAnimations: reduce,
          textScaler: TextScaler.linear(scale),
        ),
        child: app!,
      ),
      home: Scaffold(body: Center(child: child)),
    );

BoxDecoration fillOf(WidgetTester tester, String label) =>
    tester
            .widget<AnimatedContainer>(
              find
                  .ancestor(
                    of: find.text(label),
                    matching: find.byType(AnimatedContainer),
                  )
                  .first,
            )
            .decoration!
        as BoxDecoration;

/// A chip that selects itself on tap, like a style row with one entry.
Widget toggleChip() {
  var on = false;
  return StatefulBuilder(
    builder: (context, setState) => PizzaChip(
      label: 'Detroit',
      selected: on,
      onTap: () => setState(() => on = true),
    ),
  );
}

double popScale(WidgetTester tester) => tester
    .widget<ScaleTransition>(
      find.descendant(
        of: find.byType(PizzaChip),
        matching: find.byType(ScaleTransition),
      ),
    )
    .scale
    .value;

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('chip colours follow selection and variant', (tester) async {
    await tester.pumpWidget(
      host(
        Row(
          children: [
            PizzaChip(label: 'Off', selected: false, onTap: () {}),
            PizzaChip(label: 'On', selected: true, onTap: () {}),
            PizzaChip(
              label: 'Filter',
              selected: true,
              secondary: true,
              onTap: () {},
            ),
          ],
        ),
      ),
    );
    expect(fillOf(tester, 'Off').color, c.surface);
    expect((fillOf(tester, 'Off').border! as Border).top.color, c.lineStrong);
    expect(tester.widget<Text>(find.text('Off')).style!.color, c.inkSoft);
    expect(fillOf(tester, 'On').color, c.ember);
    expect(tester.widget<Text>(find.text('On')).style!.color, c.onEmber);
    expect(fillOf(tester, 'Filter').color, c.ink);
    expect(tester.widget<Text>(find.text('Filter')).style!.color, c.ground);
    for (final chip in tester.widgetList(find.byType(PizzaChip))) {
      expect(
        tester.getSize(find.byWidget(chip)).height,
        greaterThanOrEqualTo(44),
      );
    }
  });

  testWidgets('large text: chips and segments grow, labels stay one line', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        scale: 2.5,
        SizedBox(
          width: 350,
          child: Column(
            children: [
              Row(
                children: [
                  for (final l in ['None', 'Poolish', 'Biga'])
                    Expanded(
                      child: PizzaChip(label: l, selected: false, onTap: () {}),
                    ),
                ],
              ),
              Segmented<int>(
                options: const [(0, 'Steel'), (1, 'Stone')],
                value: 0,
                onChanged: (_) {},
              ),
            ],
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    final chip = tester.getSize(find.byType(PizzaChip).first);
    expect(chip.height, greaterThan(44), reason: 'min height, not fixed');
    final poolish = tester.widget<Text>(find.text('Poolish'));
    expect(poolish.maxLines, 1);
    expect(poolish.overflow, TextOverflow.ellipsis);
    final label = tester.getSize(find.text('Poolish'));
    expect(
      tester
          .getSize(
            find
                .ancestor(
                  of: find.text('Poolish'),
                  matching: find.byType(AnimatedContainer),
                )
                .first,
          )
          .height,
      greaterThanOrEqualTo(label.height),
    );
    final steel = tester.getSize(
      find
          .ancestor(
            of: find.text('Steel'),
            matching: find.byType(AnimatedContainer),
          )
          .first,
    );
    expect(steel.height, greaterThan(40));
    expect(
      tester.widget<Text>(find.text('Steel')).style!.fontFamily,
      'Inter_500',
    );
    expect(
      tester.widget<Text>(find.text('Poolish')).style!.fontFamily,
      'Inter_500',
    );
  });

  testWidgets('tap selects with a selection haptic and a pop', (tester) async {
    final calls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        calls.add(call);
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await tester.pumpWidget(host(toggleChip()));
    expect(popScale(tester), 1);
    await tester.tap(find.text('Detroit'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    expect(popScale(tester), isNot(1));
    expect(
      calls,
      contains(
        isMethodCall(
          'HapticFeedback.vibrate',
          arguments: 'HapticFeedbackType.selectionClick',
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(popScale(tester), 1);
    expect(fillOf(tester, 'Detroit').color, c.ember);
  });

  testWidgets('reduced motion skips the pop', (tester) async {
    await tester.pumpWidget(host(toggleChip(), reduce: true));
    await tester.tap(find.text('Detroit'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    expect(popScale(tester), 1);
  });

  testWidgets('segmented marks the value and reports taps', (tester) async {
    final picked = <int>[];
    await tester.pumpWidget(
      host(
        Segmented<int>(
          options: const [(0, 'Steel'), (1, 'Stone'), (2, 'Tray')],
          value: 1,
          onChanged: picked.add,
        ),
      ),
    );
    expect(fillOf(tester, 'Stone').color, c.surfaceRaised);
    expect(fillOf(tester, 'Stone').boxShadow, isNotEmpty);
    expect(fillOf(tester, 'Steel').color, isNull);
    expect(tester.widget<Text>(find.text('Stone')).style!.color, c.ink);
    expect(tester.widget<Text>(find.text('Steel')).style!.color, c.inkMuted);

    final tray = find
        .ancestor(of: find.text('Tray'), matching: find.byType(GestureDetector))
        .first;
    expect(tester.getSize(tray).height, greaterThanOrEqualTo(44));
    await tester.tap(tray);
    expect(picked, [2]);
  });
}
