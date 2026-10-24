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

Container box(WidgetTester tester, Key key) => tester.widget<Container>(
  find.descendant(of: find.byKey(key), matching: find.byType(Container)).first,
);

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('variants use token fills, borders, radii and padding', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        Column(
          children: [
            for (final v in PizzaCardVariant.values)
              PizzaCard(key: ValueKey(v), variant: v, child: Text(v.name)),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    final expected = {
      PizzaCardVariant.plain: (c.surface, c.line, 20.0, 16.0),
      PizzaCardVariant.result: (c.surface, c.lineStrong, 20.0, 16.0),
      PizzaCardVariant.tip: (c.emberTint, c.emberLine, 16.0, 14.0),
      PizzaCardVariant.hint: (c.sageTint, c.sageLine, 20.0, 14.0),
    };
    for (final MapEntry(key: v, value: (fill, line, radius, pad))
        in expected.entries) {
      final b = box(tester, ValueKey(v));
      final d = b.decoration! as BoxDecoration;
      expect(d.color, fill, reason: v.name);
      expect((d.border! as Border).top.color, line, reason: v.name);
      expect(d.borderRadius, BorderRadius.circular(radius), reason: v.name);
      expect(b.padding, EdgeInsets.all(pad), reason: v.name);
    }
  });

  testWidgets('custom padding wins', (tester) async {
    const key = ValueKey('p');
    await tester.pumpWidget(
      host(
        const PizzaCard(key: key, padding: EdgeInsets.all(4), child: Text('x')),
      ),
    );
    expect(box(tester, key).padding, const EdgeInsets.all(4));
  });

  testWidgets('cards rise in from below, tips slide in from the left', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        const Column(
          children: [
            PizzaCard(key: ValueKey('card'), child: Text('card')),
            PizzaCard(
              key: ValueKey('tip'),
              variant: PizzaCardVariant.tip,
              child: Text('tip'),
            ),
          ],
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    Transform shift(String k) => tester.widget<Transform>(
      find.descendant(
        of: find.byKey(ValueKey(k)),
        matching: find.byType(Transform),
      ),
    );
    Opacity fade(String k) => tester.widget<Opacity>(
      find.descendant(
        of: find.byKey(ValueKey(k)),
        matching: find.byType(Opacity),
      ),
    );
    expect(fade('card').opacity, lessThan(1));
    expect(shift('card').transform.getTranslation().y, greaterThan(0));
    expect(shift('tip').transform.getTranslation().x, lessThan(0));
    await tester.pumpAndSettle();
    expect(fade('card').opacity, 1);
    expect(shift('card').transform.getTranslation().y, 0);
  });

  testWidgets('delay holds a card back for staggering', (tester) async {
    await tester.pumpWidget(
      host(
        const PizzaCard(
          delay: Duration(milliseconds: 200),
          child: Text('late'),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 150));
    expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, 0);
    await tester.pumpAndSettle();
    expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, 1);
  });

  testWidgets('reduced motion shows cards at rest', (tester) async {
    await tester.pumpWidget(
      host(const PizzaCard(child: Text('still')), reduce: true),
    );
    expect(
      find.descendant(
        of: find.byType(PizzaCard),
        matching: find.byType(Opacity),
      ),
      findsNothing,
    );
  });
}
