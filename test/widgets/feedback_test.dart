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
  home: Scaffold(body: Center(child: child)),
);

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('reduceMotion reads MediaQuery', (tester) async {
    final seen = <bool>[];
    final probe = Builder(
      builder: (context) {
        seen.add(reduceMotion(context));
        return const SizedBox();
      },
    );
    await tester.pumpWidget(host(probe));
    await tester.pumpWidget(host(probe, reduce: true));
    expect(seen.first, isFalse);
    expect(seen.last, isTrue);
  });

  testWidgets('reduceMotion is false without MediaQuery', (tester) async {
    late bool seen;
    await tester.pumpWidget(
      Builder(
        builder: (context) {
          seen = reduceMotion(context);
          return const SizedBox();
        },
      ),
    );
    expect(seen, isFalse);
  });

  testWidgets('toast shows an ink pill for 2 s and replaces the last one', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        Builder(
          builder: (context) => TextButton(
            onPressed: () {
              showPizzaToast(context, 'First');
              showPizzaToast(context, 'Saved');
            },
            child: const Text('Go'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Go'));
    await tester.pumpAndSettle();
    expect(find.text('First'), findsNothing);
    expect(find.text('Saved'), findsOneWidget);
    expect(tester.widget<Text>(find.text('Saved')).style!.color, c.ground);
    final pill = tester.widget<DecoratedBox>(
      find
          .ancestor(of: find.text('Saved'), matching: find.byType(DecoratedBox))
          .first,
    );
    expect((pill.decoration as BoxDecoration).color, c.ink);

    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text('Saved'), findsNothing);
  });
}
