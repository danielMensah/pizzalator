import 'package:flutter/material.dart';
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

Widget ring({
  double progress = 0.75,
  bool breathing = false,
  int dings = 0,
  Object? step,
}) => RingTimer(
  progress: progress,
  clock: '22:30',
  label: 'Resting',
  title: 'Rest in bowl',
  color: c.ember,
  breathing: breathing,
  dings: dings,
  stepKey: step,
);

double enter(WidgetTester tester) => tester
    .widget<FadeTransition>(
      find.descendant(
        of: find.byType(RingTimer),
        matching: find.byType(FadeTransition),
      ),
    )
    .opacity
    .value;

Finder paint() => find.descendant(
  of: find.byType(RingTimer),
  matching: find.byType(CustomPaint),
);

/// The inner scale is the breath; the outer one is ringIn.
double breath(WidgetTester tester) => tester
    .widget<ScaleTransition>(
      find
          .descendant(
            of: find.byType(RingTimer),
            matching: find.byType(ScaleTransition),
          )
          .last,
    )
    .scale
    .value;

double wobble(WidgetTester tester) => tester
    .widget<RotationTransition>(
      find.descendant(
        of: find.byType(RingTimer),
        matching: find.byType(RotationTransition),
      ),
    )
    .turns
    .value;

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('an h:mm:ss clock and long texts stay inside the face', (
    tester,
  ) async {
    const title = 'Stretch, fold and shape one ball, then into the container';
    for (final scale in [1.0, 2.0]) {
      await tester.pumpWidget(
        host(
          scale: scale,
          RingTimer(
            progress: 1,
            clock: '23:59:59',
            label: 'Resting',
            title: title,
            color: c.ember,
          ),
        ),
      );
      expect(tester.takeException(), isNull, reason: 'no overflow at $scale');
      final clock = tester.getRect(find.text('23:59:59'));
      expect(clock.width, lessThanOrEqualTo(180));
      expect(tester.widget<Text>(find.text(title)).maxLines, 2);
    }
    expect(tester.getSize(find.byType(RingTimer)), const Size(236, 236));
  });

  testWidgets('one TalkBack stop: state, step and time left', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(host(ring()));
    expect(
      find.bySemanticsLabel('Resting, Rest in bowl, 22:30 remaining'),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('22:30'), findsNothing);
    semantics.dispose();
  });

  testWidgets('paints track and arc, shows the clock and step', (tester) async {
    await tester.pumpWidget(host(ring()));
    expect(tester.getSize(find.byType(RingTimer)), const Size(236, 236));
    expect(
      paint(),
      paints
        ..circle(color: c.surfaceRaised)
        ..arc(color: c.ember),
    );
    expect(tester.widget<Text>(find.text('RESTING')).style!.color, c.ember);
    expect(tester.widget<Text>(find.text('22:30')).style!.fontSize, 54);
    expect(find.text('Rest in bowl'), findsOneWidget);
  });

  testWidgets('clock only, empty arc at zero', (tester) async {
    await tester.pumpWidget(
      host(RingTimer(progress: 0, clock: '00:00', color: c.sage)),
    );
    expect(find.text('00:00'), findsOneWidget);
    expect(paint(), isNot(paints..arc()));
  });

  testWidgets('arc moves between ticks', (tester) async {
    await tester.pumpWidget(host(ring(progress: 0.5)));
    await tester.pumpWidget(host(ring(progress: 0.4)));
    await tester.pump(const Duration(milliseconds: 450));
    expect(paint(), paints..arc(color: c.ember));
    await tester.pumpAndSettle();
  });

  testWidgets('breathes only while breathing and motion is allowed', (
    tester,
  ) async {
    await tester.pumpWidget(host(ring(breathing: true)));
    await tester.pump(const Duration(seconds: 1));
    expect(breath(tester), greaterThan(1));

    await tester.pumpWidget(host(ring()));
    expect(breath(tester), 1);

    await tester.pumpWidget(host(ring(breathing: true)));
    await tester.pump(const Duration(seconds: 1));
    expect(breath(tester), greaterThan(1));
    await tester.pumpWidget(host(ring(breathing: true), reduce: true));
    expect(breath(tester), 1);
    await tester.pump(const Duration(seconds: 1));
    expect(breath(tester), 1);
  });

  testWidgets('dings once per timer end the screen reports', (tester) async {
    // A chained end goes straight to the next step's full arc, so the arc
    // never shows zero: the ding follows the end count, not the arc.
    await tester.pumpWidget(host(ring(progress: 0.1)));
    expect(wobble(tester), 0);
    await tester.pumpWidget(host(ring(progress: 1, dings: 1)));
    await tester.pump(const Duration(milliseconds: 120));
    expect(wobble(tester), isNot(0));
    await tester.pumpAndSettle();
    expect(wobble(tester), 0);
    await tester.pumpWidget(host(ring(progress: 0, dings: 1)));
    await tester.pump(const Duration(milliseconds: 120));
    expect(wobble(tester), 0, reason: 'no new end, no ding');
  });

  testWidgets('no ding under reduced motion', (tester) async {
    await tester.pumpWidget(host(ring(progress: 0.1), reduce: true));
    await tester.pumpWidget(host(ring(dings: 1), reduce: true));
    await tester.pump(const Duration(milliseconds: 120));
    expect(wobble(tester), 0);
  });

  testWidgets('rings in on a step change, not under reduced motion', (
    tester,
  ) async {
    await tester.pumpWidget(host(ring(step: 0)));
    expect(enter(tester), 1, reason: 'no entrance on first build');
    await tester.pumpWidget(host(ring(step: 1)));
    await tester.pump(const Duration(milliseconds: 50));
    expect(enter(tester), lessThan(1));
    await tester.pumpAndSettle();
    expect(enter(tester), 1);

    await tester.pumpWidget(host(ring(step: 1), reduce: true));
    await tester.pumpWidget(host(ring(step: 2), reduce: true));
    await tester.pump(const Duration(milliseconds: 50));
    expect(enter(tester), 1);
  });
}
