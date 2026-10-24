import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pizzalator/theme/pizza_theme.dart';
import 'package:pizzalator/widgets/widgets.dart';

const c = PizzaColors.dark;

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  /// Opens [open] from a button and returns what it completes with.
  Future<Future<T?>> launch<T>(
    WidgetTester tester,
    Future<T?> Function(BuildContext) open,
  ) async {
    late Future<T?> result;
    await tester.pumpWidget(
      MaterialApp(
        theme: pizzaTheme(Brightness.dark),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => result = open(context),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    return result;
  }

  testWidgets('showPizzaSheet: sheet surface, 28 px top, drag handle', (
    tester,
  ) async {
    final result = await launch(
      tester,
      (context) => showPizzaSheet<int>(
        context,
        (context) => TextButton(
          onPressed: () => Navigator.pop(context, 7),
          child: const Text('Seven'),
        ),
      ),
    );
    final sheet = tester.widget<BottomSheet>(find.byType(BottomSheet));
    expect(sheet.backgroundColor, c.surfaceSheet);
    expect(sheet.showDragHandle, isTrue);
    expect(
      (sheet.shape! as RoundedRectangleBorder).borderRadius,
      const BorderRadius.vertical(top: Radius.circular(28)),
    );
    expect(
      tester.widget<ModalBarrier>(find.byType(ModalBarrier).last).color,
      c.scrim,
    );
    await tester.tap(find.text('Seven'));
    await tester.pumpAndSettle();
    expect(await result, 7);
  });

  testWidgets('sheets clear the system navigation bar', (tester) async {
    // 48 dp of 3-button navigation under an edge-to-edge app.
    tester.view.padding = const FakeViewPadding(bottom: 144);
    tester.view.viewPadding = const FakeViewPadding(bottom: 144);
    addTearDown(tester.view.reset);
    final bar = tester.view.physicalSize.height / 3 - 48;
    await launch(
      tester,
      (context) =>
          showPizzaSheet<void>(context, (_) => const Text('Last button')),
    );
    expect(
      tester.getRect(find.text('Last button')).bottom,
      lessThanOrEqualTo(bar),
    );
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    await launch(
      tester,
      (context) => askText(context, 'Name', 'Save', [('Name', '', null)]),
    );
    expect(tester.getRect(find.text('Save')).bottom, lessThanOrEqualTo(bar));
  });

  testWidgets('askText: prefilled fields in, typed values out', (tester) async {
    final result = await launch(
      tester,
      (context) => askText(context, 'Edit step', 'Save step', [
        ('Name', 'Mix', null),
        ('Note', '', 'Shown on the timer'),
      ]),
    );
    expect(find.text('Edit step'), findsOneWidget);
    expect(find.text('Mix'), findsOneWidget);
    expect(find.text('Shown on the timer'), findsOneWidget);
    final field = tester.widget<TextField>(find.byType(TextField).first);
    expect(field.decoration!.fillColor, c.ground);
    expect(
      (field.decoration!.focusedBorder! as OutlineInputBorder).borderSide.color,
      c.ember,
    );
    await tester.enterText(find.byType(TextField).last, 'Wet hands');
    await tester.tap(find.text('Save step'));
    await tester.pumpAndSettle();
    expect(await result, ['Mix', 'Wet hands']);
  });

  testWidgets('askText dismissed gives null', (tester) async {
    final result = await launch(
      tester,
      (context) => askText(context, 'Name', 'Save', [('Name', '', null)]),
    );
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.text('Save'), findsNothing);
    expect(await result, isNull);
  });

  testWidgets('pizzaInput: ground and line-strong; found is sage', (
    tester,
  ) async {
    late InputDecoration plain, found;
    await tester.pumpWidget(
      MaterialApp(
        theme: pizzaTheme(Brightness.dark),
        home: Builder(
          builder: (context) {
            plain = pizzaInput(context, hint: 'e.g.');
            found = pizzaInput(context, found: true);
            return const SizedBox();
          },
        ),
      ),
    );
    OutlineInputBorder border(InputDecoration d) =>
        d.enabledBorder! as OutlineInputBorder;
    expect(plain.fillColor, c.ground);
    expect(border(plain).borderSide.color, c.lineStrong);
    expect(plain.hintText, 'e.g.');
    expect(found.fillColor, c.sageTint);
    expect(border(found).borderSide.color, c.sage);
    expect(border(found).borderRadius, BorderRadius.circular(12));
    expect(
      (found.focusedBorder! as OutlineInputBorder).borderSide.color,
      c.ember,
    );
  });
  testWidgets('LabelledField: label, field, unit; number keyboard; one stop', (
    tester,
  ) async {
    final ctl = TextEditingController(text: '22');
    addTearDown(ctl.dispose);
    final typed = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: pizzaTheme(Brightness.dark),
        home: Scaffold(
          body: LabelledField(
            label: 'Room',
            controller: ctl,
            unit: '°C',
            labelWidth: 48,
            onChanged: typed.add,
          ),
        ),
      ),
    );
    expect(find.text('Room'), findsOneWidget);
    expect(find.text('°C'), findsOneWidget);
    final label = find.ancestor(
      of: find.text('Room'),
      matching: find.byType(SizedBox),
    );
    expect(tester.getSize(label.first).width, 48);
    final field = tester.widget<TextField>(find.byKey(const ValueKey('room')));
    expect(
      field.keyboardType,
      const TextInputType.numberWithOptions(decimal: true),
    );
    expect(find.byType(MergeSemantics), findsOneWidget);
    await tester.enterText(find.byType(TextField), '23');
    expect(typed, ['23']);
  });

  testWidgets('LabelledField: text without a unit, sage when found', (
    tester,
  ) async {
    final ctl = TextEditingController();
    addTearDown(ctl.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: pizzaTheme(Brightness.dark),
        home: Scaffold(
          body: LabelledField(label: 'Name', controller: ctl, found: true),
        ),
      ),
    );
    final field = tester.widget<TextField>(find.byKey(const ValueKey('name')));
    expect(field.keyboardType, TextInputType.text);
    expect(field.decoration!.fillColor, c.sageTint);
  });
}
