import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/pizza_theme.dart';
import 'feedback.dart';

const _colorShift = Duration(milliseconds: 250);

/// Single-select pill. The main style row selects to ember; [secondary]
/// rows (filters, presets) select to ink and draw 40 px inside a 44 px target.
class PizzaChip extends StatefulWidget {
  const PizzaChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.secondary = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool secondary;

  @override
  State<PizzaChip> createState() => _PizzaChipState();
}

class _PizzaChipState extends State<PizzaChip>
    with SingleTickerProviderStateMixin {
  // pop: scale .94 → 1.04 → 1 over 300 ms. Rests at 1.
  late final _pop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
    value: 1,
  );
  late final _scale = TweenSequence([
    TweenSequenceItem(tween: Tween(begin: 0.94, end: 1.04), weight: 60),
    TweenSequenceItem(tween: Tween(begin: 1.04, end: 1.0), weight: 40),
  ]).animate(CurvedAnimation(parent: _pop, curve: Curves.easeOut));

  @override
  void didUpdateWidget(PizzaChip old) {
    super.didUpdateWidget(old);
    if (widget.selected && !old.selected && !reduceMotion(context)) {
      _pop.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _pop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final on = widget.selected;
    final small = widget.secondary;
    final (fill, fg) = !on
        ? (c.surface, c.inkSoft)
        : small
        ? (c.ink, c.ground)
        : (c.ember, c.onEmber);
    return ScaleTransition(
      scale: _scale,
      child: Semantics(
        button: true,
        selected: on,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            unawaited(HapticFeedback.selectionClick());
            widget.onTap();
          },
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: small ? 2 : 0),
            // A minimum, not a fixed height: large text grows the pill.
            child: AnimatedContainer(
              duration: _colorShift,
              constraints: BoxConstraints(minHeight: small ? 40 : 44),
              alignment: Alignment.center,
              padding: EdgeInsets.symmetric(horizontal: small ? 14 : 16),
              decoration: BoxDecoration(
                color: fill,
                border: Border.all(color: on ? fill : c.lineStrong),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                widget.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.buttonMd.copyWith(
                  fontSize: small ? 13 : 14,
                  color: fg,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Two to four mutually exclusive options. Each segment draws 40 px inside a
/// 44 px tap target. [selectedFill] / [selectedInk] tint the selected one
/// (a bad or good bake outcome); raised and ink by default.
class Segmented<T> extends StatelessWidget {
  const Segmented({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    this.selectedFill,
    this.selectedInk,
  });

  final List<(T, String)> options;
  final T value;
  final ValueChanged<T> onChanged;
  final Color? selectedFill, selectedInk;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.lineStrong),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          for (final (v, label) in options)
            Expanded(
              child: Semantics(
                button: true,
                selected: v == value,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onChanged(v),
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: AnimatedContainer(
                      duration: _colorShift,
                      constraints: const BoxConstraints(minHeight: 40),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: v == value
                            ? selectedFill ?? c.surfaceRaised
                            : null,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: v == value
                            ? const [
                                BoxShadow(
                                  color: Color(0x59000000),
                                  offset: Offset(0, 2),
                                  blurRadius: 6,
                                ),
                              ]
                            : null,
                      ),
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.segment.copyWith(
                          color: v == value ? selectedInk ?? c.ink : c.inkMuted,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
