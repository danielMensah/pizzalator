import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pizzalator/screens/splash.dart';
import 'package:pizzalator/theme/pizza_theme.dart';
import 'package:pizzalator/widgets/widgets.dart';

const c = PizzaColors.dark;
const app = Directionality(
  textDirection: TextDirection.ltr,
  child: Text('app'),
);

Widget host(Widget child, {bool reduce = false}) => MaterialApp(
  theme: pizzaTheme(Brightness.dark),
  builder: (context, app) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: reduce),
    child: app!,
  ),
  home: child,
);

RingPainter ring(WidgetTester tester) =>
    tester
            .widget<CustomPaint>(
              find.byWidgetPredicate(
                (w) => w is CustomPaint && w.painter is RingPainter,
              ),
            )
            .painter!
        as RingPainter;

double fade(WidgetTester tester, String text) => tester
    .widget<FadeTransition>(
      find
          .ancestor(of: find.text(text), matching: find.byType(FadeTransition))
          .first,
    )
    .opacity
    .value;

double wobble(WidgetTester tester) => tester
    .widget<RotationTransition>(
      find
          .ancestor(
            of: find.byType(PizzaMark),
            matching: find.byType(RotationTransition),
          )
          .first,
    )
    .turns
    .value;

double breath(WidgetTester tester) => tester
    .widget<ScaleTransition>(
      find
          .ancestor(
            of: find.byType(PizzaMark),
            matching: find.byType(ScaleTransition),
          )
          .first,
    )
    .scale
    .value;

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('ring draws, then sage, ding, Ready and the wordmark rises', (
    tester,
  ) async {
    var done = 0;
    await tester.pumpWidget(host(SplashScreen(onDone: () => done++)));
    expect(tester.takeException(), isNull);
    expect(ring(tester).progress, 0);
    expect(ring(tester).track, c.surfaceRaised);
    expect(find.byType(PizzaMark), findsOneWidget);
    expect(fade(tester, 'RESTING'), 1);
    expect(fade(tester, 'READY'), 0);
    expect(fade(tester, 'Pizzalator'), 0);
    expect(fade(tester, 'Dough math for the home oven'), 0);

    await tester.pump(const Duration(milliseconds: 1000));
    expect(ring(tester).progress, inExclusiveRange(0, 1));
    expect(ring(tester).color, c.emberBright);
    expect(breath(tester), greaterThan(1));
    expect(wobble(tester), 0);
    expect(done, 0);

    await tester.pump(const Duration(milliseconds: 1150));
    expect(ring(tester).progress, 1);
    expect(wobble(tester), isNot(0), reason: 'dings when the arc closes');

    await tester.pumpAndSettle();
    expect(ring(tester).color, c.sage);
    expect(breath(tester), 1);
    expect(wobble(tester), 0);
    expect(fade(tester, 'RESTING'), 0);
    expect(fade(tester, 'READY'), 1);
    expect(tester.widget<Text>(find.text('READY')).style!.color, c.sageBright);
    expect(fade(tester, 'Pizzalator'), 1);
    expect(fade(tester, 'Dough math for the home oven'), 1);
    expect(done, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('one TalkBack stop', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(host(SplashScreen(onDone: () {})));
    expect(find.bySemanticsLabel('Pizzalator'), findsOneWidget);
    expect(find.bySemanticsLabel('RESTING'), findsNothing);
    await tester.pumpAndSettle();
    semantics.dispose();
  });

  testWidgets('reduced motion: the final frame, held, then done', (
    tester,
  ) async {
    var done = 0;
    await tester.pumpWidget(
      host(SplashScreen(onDone: () => done++), reduce: true),
    );
    expect(ring(tester).progress, 1);
    expect(ring(tester).color, c.sage);
    expect(wobble(tester), 0);
    expect(breath(tester), 1);
    expect(fade(tester, 'READY'), 1);
    expect(fade(tester, 'Pizzalator'), 1);
    expect(done, 0);
    await tester.pump(kSplashHold + const Duration(milliseconds: 20));
    expect(done, 1);
  });

  testWidgets('Launch shows the app once the splash played and ready is done', (
    tester,
  ) async {
    final ready = Completer<void>();
    await tester.pumpWidget(Launch(ready: ready.future, child: app));
    expect(find.byType(SplashScreen), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('app'), findsNothing, reason: 'still loading');
    ready.complete();
    await tester.pumpAndSettle();
    expect(find.text('app'), findsOneWidget);
    expect(find.byType(SplashScreen), findsNothing);
  });

  testWidgets('Launch waits for the splash even when ready is done first', (
    tester,
  ) async {
    final ready = Completer<void>();
    await tester.pumpWidget(Launch(ready: ready.future, child: app));
    ready.completeError('disk');
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(SplashScreen), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('app'), findsOneWidget);
  });
}
