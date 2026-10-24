import 'package:flutter/material.dart';

import '../theme/pizza_theme.dart';
import 'header.dart';

/// Any changed number lerps 450 ms ease-out cubic. Kept under reduced motion.
class TweenNumber extends StatelessWidget {
  const TweenNumber({
    super.key,
    required this.value,
    required this.format,
    this.style,
  });

  final double value;
  final String Function(double) format;

  /// Defaults to the inline `number` style.
  final TextStyle? style;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(end: value),
    duration: const Duration(milliseconds: 450),
    curve: Curves.easeOutCubic,
    builder: (context, v, _) =>
        Text(format(v), style: style ?? context.text.number),
  );
}

/// Label plus a big tabular number with an optional muted unit.
class Stat extends StatelessWidget {
  const Stat({
    super.key,
    required this.label,
    required String value,
    this.unit,
    this.color,
    this.size = 34,
    this.labelBelow = false,
    this.alignment = CrossAxisAlignment.start,
  }) : _text = value,
       _number = null,
       _format = null;

  /// Same, but the value tweens when it changes.
  const Stat.tween({
    super.key,
    required this.label,
    required double value,
    required String Function(double) format,
    this.unit,
    this.color,
    this.size = 34,
    this.labelBelow = false,
    this.alignment = CrossAxisAlignment.start,
  }) : _text = null,
       _number = value,
       _format = format;

  final String label;
  final String? unit;

  /// Defaults to ember-bright (key numbers).
  final Color? color;
  final double size;
  final bool labelBelow;
  final CrossAxisAlignment alignment;
  final String? _text;
  final double? _number;
  final String Function(double)? _format;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final style = t.displayMd.copyWith(
      fontSize: size,
      color: color ?? c.emberBright,
    );
    final number = _number;
    final value = Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        if (number == null)
          Text(_text!, style: style)
        else
          TweenNumber(value: number, format: _format!, style: style),
        if (unit != null) ...[
          const SizedBox(width: 4),
          Text(
            unit!,
            style: t.unit.copyWith(fontSize: (size / 2).clamp(14, 18)),
          ),
        ],
      ],
    );
    final caption = SectionLabel(label);
    // One TalkBack stop, label first, wherever the label is drawn.
    final shown = number == null ? _text! : _format!(number);
    final spokenUnit = switch (unit) {
      null => '',
      '%' => '%',
      final u => ' $u',
    };
    return Semantics(
      label: '$label $shown$spokenUnit',
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: alignment,
        children: labelBelow
            ? [value, caption]
            : [caption, const SizedBox(height: 4), value],
      ),
    );
  }
}

/// 10 px bar whose fill sits at [value] between [min] and [max], with
/// optional captions under it. Fill animates 500 ms, also under reduced motion.
class RangeBar extends StatelessWidget {
  const RangeBar({
    super.key,
    required this.min,
    required this.max,
    required this.value,
    this.minLabel,
    this.centerLabel,
    this.maxLabel,
  }) : assert(max > min);

  final double min, max, value;
  final String? minLabel, centerLabel, maxLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final caption = context.text.caption.copyWith(fontSize: 11);
    final pill = BorderRadius.circular(999);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: pill,
          child: Container(
            height: 10,
            color: c.surfaceRaised,
            alignment: Alignment.centerLeft,
            child: AnimatedFractionallySizedBox(
              duration: const Duration(milliseconds: 500),
              curve: const Cubic(0.2, 0.8, 0.2, 1),
              widthFactor: ((value - min) / (max - min)).clamp(0.0, 1.0),
              heightFactor: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(color: c.ember, borderRadius: pill),
              ),
            ),
          ),
        ),
        if (minLabel != null || centerLabel != null || maxLabel != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (final s in [minLabel ?? '', ?centerLabel, maxLabel ?? ''])
                  Flexible(
                    child: Text(
                      s,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: caption,
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
