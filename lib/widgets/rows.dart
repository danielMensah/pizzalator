import 'package:flutter/material.dart';

import '../theme/pizza_theme.dart';

/// 44 px square −/+ button. Disabled (null [onPressed]) at 40% opacity.
class StepButton extends StatelessWidget {
  const StepButton({
    super.key,
    required this.icon,
    required this.semanticLabel,
    this.onPressed,
  });

  final IconData icon;
  final String semanticLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: semanticLabel,
      excludeSemantics: true,
      child: Opacity(
        opacity: onPressed == null ? 0.4 : 1,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onPressed,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: c.ground,
              border: Border.all(color: c.lineStrong),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: c.ink),
          ),
        ),
      ),
    );
  }
}

/// A "label · − value +" row, as in the Ferment schedule and Routine editor.
class ValueStepper extends StatelessWidget {
  const ValueStepper({
    super.key,
    required this.label,
    this.sublabel,
    required this.value,
    required this.onMinus,
    required this.onPlus,
    this.canMinus = true,
    this.canPlus = true,
    this.leading,
    this.trailing,
  });

  final String label;
  final String? sublabel;
  final String value;
  final VoidCallback onMinus, onPlus;
  final bool canMinus, canPlus;

  /// E.g. the stage colour dot or the routine kind toggle.
  final Widget? leading;

  /// E.g. the routine remove button.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final t = context.text;
    final name = label.toLowerCase();
    return Row(
      children: [
        if (leading != null) ...[leading!, const SizedBox(width: 10)],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: t.bodyStrong),
              if (sublabel != null) Text(sublabel!, style: t.caption),
            ],
          ),
        ),
        StepButton(
          icon: Icons.remove,
          semanticLabel: 'Less $name',
          onPressed: canMinus ? onMinus : null,
        ),
        SizedBox(
          width: 56,
          child: Text(value, textAlign: TextAlign.center, style: t.number),
        ),
        StepButton(
          icon: Icons.add,
          semanticLabel: 'More $name',
          onPressed: canPlus ? onPlus : null,
        ),
        if (trailing != null) ...[const SizedBox(width: 4), trailing!],
      ],
    );
  }
}

enum StepRowState { done, current, upcoming }

/// One routine or schedule step: kind icon, name, sub-line, duration.
/// [accent] is the step kind's colour (ember rest, wheat hands-on) on an
/// upcoming icon; the current tile is ember whatever the kind, so the row
/// carries one accent (DESIGN principle 5).
class StepRow extends StatelessWidget {
  const StepRow({
    super.key,
    required this.name,
    this.sub,
    this.trailing,
    required this.state,
    required this.accent,
    this.icon = Icons.schedule,
  });

  final String name;
  final String? sub;
  final String? trailing;
  final StepRowState state;
  final Color accent;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    const shift = Duration(milliseconds: 300);
    final (iconFill, iconInk) = switch (state) {
      StepRowState.done => (c.sageTint, c.ink),
      StepRowState.current => (c.ember, c.onEmber),
      StepRowState.upcoming => (c.surfaceRaised, accent),
    };
    return AnimatedOpacity(
      duration: shift,
      opacity: state == StepRowState.done ? 0.45 : 1,
      child: AnimatedContainer(
        duration: shift,
        constraints: const BoxConstraints(minHeight: 50),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: state == StepRowState.current ? c.emberTint : null,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: iconFill,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 16, color: iconInk),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.bodyStrong.copyWith(fontSize: 14),
                  ),
                  if (sub != null) Text(sub!, style: t.caption),
                ],
              ),
            ),
            if (trailing != null) Text(trailing!, style: t.numberMuted),
          ],
        ),
      ),
    );
  }
}
