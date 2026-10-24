import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pizzalator/theme/pizza_theme.dart';
import 'package:pizzalator/widgets/mark.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  Future<CustomPaint> pump(WidgetTester tester, PizzaMark mark) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: pizzaTheme(Brightness.dark),
        home: Center(child: mark),
      ),
    );
    return tester.widget<CustomPaint>(
      find.descendant(
        of: find.byType(PizzaMark),
        matching: find.byType(CustomPaint),
      ),
    );
  }

  testWidgets('ember by default, sized by width, hidden from TalkBack', (
    tester,
  ) async {
    final paint = await pump(tester, const PizzaMark(size: 96.5));
    expect((paint.painter! as MarkPainter).color, PizzaColors.dark.ember);
    expect(tester.getSize(find.byType(PizzaMark)), const Size(96.5, 96));
    expect(
      find.descendant(
        of: find.byType(PizzaMark),
        matching: find.byType(ExcludeSemantics),
      ),
      findsOneWidget,
    );
  });

  testWidgets('takes a colour; repaints only when it changes', (tester) async {
    final paint = await pump(tester, const PizzaMark(color: Colors.white));
    final p = paint.painter! as MarkPainter;
    expect(p.color, Colors.white);
    expect(p.shouldRepaint(const MarkPainter(Colors.white)), isFalse);
    expect(p.shouldRepaint(const MarkPainter(Colors.black)), isTrue);
  });
}
