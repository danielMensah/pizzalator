import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pizzalator/theme/pizza_theme.dart';
import 'package:pizzalator/widgets/widgets.dart';

const c = PizzaColors.dark;

Widget host(Widget child) => MaterialApp(
  theme: pizzaTheme(Brightness.dark),
  home: Scaffold(
    body: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(children: [child]),
    ),
  ),
);

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('primary is a 56 px full-width ember button', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      host(
        PrimaryButton(
          label: 'Plan fermentation',
          trailingIcon: Icons.arrow_forward,
          onPressed: () => taps++,
        ),
      ),
    );
    final button = find.byType(PrimaryButton);
    expect(tester.getSize(button), const Size(760, 56));
    expect(find.byIcon(Icons.arrow_forward), findsOneWidget);
    final style = tester.widget<FilledButton>(find.byType(FilledButton)).style!;
    // Bold from its own Inter_700 file, not a weight laid on SemiBold.
    expect(style.textStyle!.resolve({})!.fontFamily, 'Inter_700');
    expect(style.backgroundColor!.resolve({}), c.ember);
    expect(style.foregroundColor!.resolve({}), c.onEmber);
    await tester.tap(button);
    expect(taps, 1);
  });

  testWidgets('primary leading icon and disabled state', (tester) async {
    await tester.pumpWidget(
      host(const PrimaryButton(label: 'Start', icon: Icons.play_arrow)),
    );
    expect(find.byIcon(Icons.play_arrow), findsOneWidget);
    final b = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(b.enabled, isFalse);
    expect(
      b.style!.backgroundColor!.resolve({WidgetState.disabled}),
      c.ember.withValues(alpha: 0.4),
    );
  });

  testWidgets('secondary is surface with line-strong border', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      host(
        SecondaryButton(
          label: 'Copy recipe',
          icon: Icons.copy,
          onPressed: () => taps++,
        ),
      ),
    );
    final button = find.byType(SecondaryButton);
    expect(tester.getSize(button).height, greaterThanOrEqualTo(44));
    final style = tester
        .widget<OutlinedButton>(find.byType(OutlinedButton))
        .style!;
    expect(style.backgroundColor!.resolve({}), c.surface);
    expect(style.foregroundColor!.resolve({}), c.ink);
    expect(style.side!.resolve({})!.color, c.lineStrong);
    expect(
      tester.getTopLeft(find.byIcon(Icons.copy)).dx,
      lessThan(tester.getTopLeft(find.text('Copy recipe')).dx),
    );
    await tester.tap(button);
    expect(taps, 1);
  });

  testWidgets('secondary success turns sage', (tester) async {
    await tester.pumpWidget(
      host(SecondaryButton(label: 'Copied', success: true, onPressed: () {})),
    );
    final style = tester
        .widget<OutlinedButton>(find.byType(OutlinedButton))
        .style!;
    expect(style.backgroundColor!.resolve({}), c.sage);
    expect(style.foregroundColor!.resolve({}), c.onEmber);
    expect(style.side!.resolve({})!.color, c.sage);
  });
}
