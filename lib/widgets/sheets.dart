import 'package:flutter/material.dart';

import '../theme/pizza_theme.dart';
import 'buttons.dart';

/// Bottom sheet per the design system: sheet surface over the scrim, 28 px
/// top corners, drag handle (its colour and size are in the theme), as tall
/// as its content needs, keyboard and system navigation bar included (the
/// sheet itself runs under the bar, edge to edge).
Future<T?> showPizzaSheet<T>(BuildContext context, WidgetBuilder builder) =>
    showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: context.colors.surfaceSheet,
      barrierColor: context.colors.scrim,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => SafeArea(top: false, child: builder(context)),
    );

/// Text field look inside sheets: ground fill, line-strong border, ember
/// when focused. [found]: sage, a value the app read for the user (label
/// scan, mockups/Flours.dc.html).
InputDecoration pizzaInput(
  BuildContext context, {
  String? label,
  String? hint,
  bool found = false,
}) {
  final c = context.colors;
  OutlineInputBorder border(Color color) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: color),
  );
  return InputDecoration(
    labelText: label,
    hintText: hint,
    filled: true,
    fillColor: found ? c.sageTint : c.ground,
    enabledBorder: border(found ? c.sage : c.lineStrong),
    focusedBorder: border(c.ember),
  );
}

/// Label, field, unit on one line (Flours sheet, Log a bake); one TalkBack
/// stop. A [unit] means a number: decimal keyboard. The field's key is the
/// label in lower case.
class LabelledField extends StatelessWidget {
  const LabelledField({
    super.key,
    required this.label,
    required this.controller,
    this.unit,
    this.hint,
    this.found = false,
    this.labelWidth = 54,
    this.onChanged,
  });

  final String label;
  final TextEditingController controller;
  final String? unit, hint;

  /// See [pizzaInput].
  final bool found;
  final double labelWidth;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.text;
    return MergeSemantics(
      child: Row(
        spacing: 10,
        children: [
          SizedBox(
            width: labelWidth,
            child: Text(label, style: t.captionRegular),
          ),
          Expanded(
            child: TextField(
              key: ValueKey(label.toLowerCase()),
              controller: controller,
              keyboardType: unit == null
                  ? TextInputType.text
                  : const TextInputType.numberWithOptions(decimal: true),
              textCapitalization: TextCapitalization.words,
              style: t.bodyStrong,
              cursorColor: context.colors.ember,
              decoration: pizzaInput(context, hint: hint, found: found)
                  .copyWith(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                  ),
              onChanged: onChanged,
            ),
          ),
          if (unit != null) Text(unit!, style: t.captionRegular),
        ],
      ),
    );
  }
}

/// Sheet of (label, value, hint) text fields; returns the values, or null
/// when dismissed.
Future<List<String>?> askText(
  BuildContext context,
  String title,
  String action,
  List<(String, String, String?)> fields,
) => showPizzaSheet<List<String>>(
  context,
  (_) => _TextSheet(title: title, action: action, fields: fields),
);

class _TextSheet extends StatefulWidget {
  const _TextSheet({
    required this.title,
    required this.action,
    required this.fields,
  });

  final String title, action;
  final List<(String, String, String?)> fields;

  @override
  State<_TextSheet> createState() => _TextSheetState();
}

class _TextSheetState extends State<_TextSheet> {
  late final _controllers = [
    for (final (_, value, _) in widget.fields)
      TextEditingController(text: value),
  ];

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.text;
    return Padding(
      // The drag handle sits above.
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.title, style: t.h2),
          for (final (i, (label, _, hint)) in widget.fields.indexed) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _controllers[i],
              autofocus: i == 0,
              textCapitalization: TextCapitalization.sentences,
              style: t.body,
              decoration: pizzaInput(context, label: label, hint: hint),
            ),
          ],
          const SizedBox(height: 16),
          PrimaryButton(
            label: widget.action,
            onPressed: () => Navigator.pop(context, [
              for (final ctl in _controllers) ctl.text,
            ]),
          ),
        ],
      ),
    );
  }
}
