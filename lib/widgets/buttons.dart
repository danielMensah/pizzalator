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
/// Expanded inside a Row). [compact]: 48 px in a [SecondaryButton]'s shape
/// and type, for a lead button beside one (Flours "Scan a bag").
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.trailingIcon,
    this.compact = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  /// E.g. the forward arrow on navigation CTAs.
  final IconData? trailingIcon;
  final bool compact;

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
        minimumSize: Size.fromHeight(compact ? 48 : 56),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(compact ? 12 : 18),
        ),
        textStyle: compact ? context.text.button : context.text.buttonCta,
      ),
      child: _content(label, icon, trailingIcon),
    );
  }
}

/// Surface button with a line-strong border, 48 px. [success] turns it sage
/// for an action that just completed (Copied, Saved) or Apply; [alert] red
/// for a destructive one (Delete).
class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.success = false,
    this.alert = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool success, alert;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (fill, ink, line) = success
        ? (c.sage, c.onEmber, c.sage)
        : alert
        ? (c.alertTint, c.alert, c.alert)
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

/// Small ember-bright link with a chevron, e.g. "Manage flours · scan a
/// bag" (mockups/Main.dc.html). 44 px tall to tap.
class TextLink extends StatelessWidget {
  const TextLink({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ink = context.colors.emberBright;
    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 4,
            children: [
              Text(label, style: context.text.caption.copyWith(color: ink)),
              Icon(Icons.chevron_right, size: 14, color: ink),
            ],
          ),
        ),
      ),
    );
  }
}
