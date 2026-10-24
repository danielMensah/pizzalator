import 'package:flutter/material.dart';

import '../theme/pizza_theme.dart';

/// Uppercase section label in ink-muted, or a tinted-card bright colour.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: context.text.label.copyWith(color: color),
  );
}

/// Screen header: optional back link (and action beside it), H1 title with
/// optional eyebrow and subtitle, optional key number on the right.
class ScreenHeader extends StatelessWidget {
  const ScreenHeader({
    super.key,
    required this.title,
    this.backLabel,
    this.onBack,
    this.eyebrow,
    this.subtitle,
    this.trailing,
    this.action,
  });

  final String title;

  /// Name of the screen the back link returns to. No link when null.
  final String? backLabel;

  /// Defaults to popping the current route.
  final VoidCallback? onBack;
  final String? eyebrow;
  final String? subtitle;

  /// Key number, right-aligned on the title row.
  final Widget? trailing;

  /// Small control right of the back link, e.g. Edit routine.
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (backLabel != null || action != null)
              Row(
                children: [
                  if (backLabel != null)
                    Semantics(
                      button: true,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: onBack ?? () => Navigator.maybePop(context),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 44),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.arrow_back,
                                size: 16,
                                color: c.inkMuted,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                backLabel!,
                                style: t.buttonMd.copyWith(color: c.inkMuted),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  const Spacer(),
                  ?action,
                ],
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (eyebrow != null)
                        SectionLabel(eyebrow!, color: c.ember),
                      // Shrinks at large text sizes instead of splitting a
                      // word across lines.
                      Semantics(
                        header: true,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(title, style: t.h1),
                        ),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          style: t.bodySm.copyWith(color: c.inkMuted),
                        ),
                    ],
                  ),
                ),
                ?trailing,
              ],
            ),
          ],
        ),
      ),
    );
  }
}
