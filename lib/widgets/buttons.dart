import 'package:flutter/material.dart';

import '../theme/pizza_theme.dart';

Widget _content(String label, IconData? icon, IconData? trailingIcon) => Row(
  mainAxisSize: MainAxisSize.min,
  children: [
    if (icon != null) ...[Icon(icon, size: 18), const SizedBox(width: 8)],
    Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
    if (trailingIcon != null) ...[
      const SizedBox(width: 8),
      Icon(trailingIcon, size: 18),
    ],
  ],
);

/// The screen's one CTA: ember, 56 px, fills its parent's width (wrap it in
/// Expanded inside a Row).
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.trailingIcon,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  /// E.g. the forward arrow on navigation CTAs.
  final IconData? trailingIcon;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: c.ember,
        foregroundColor: c.onEmber,
        disabledBackgroundColor: c.ember.withValues(alpha: 0.4),
        disabledForegroundColor: c.onEmber.withValues(alpha: 0.4),
        minimumSize: const Size.fromHeight(56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        textStyle: context.text.buttonCta,
      ),
      child: _content(label, icon, trailingIcon),
    );
  }
}

/// Surface button with a line-strong border, 48 px. [success] turns it sage
/// for an action that just completed (Copied, Saved) or Apply.
class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.success = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool success;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (fill, ink, line) = success
        ? (c.sage, c.onEmber, c.sage)
        : (c.surface, c.ink, c.lineStrong);
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        backgroundColor: fill,
        foregroundColor: ink,
        disabledBackgroundColor: fill.withValues(alpha: 0.4),
        disabledForegroundColor: ink.withValues(alpha: 0.4),
        side: BorderSide(color: line),
        minimumSize: const Size(44, 48),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: context.text.button,
      ),
      child: _content(label, icon, null),
    );
  }
}
