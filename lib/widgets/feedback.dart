import 'package:flutter/material.dart';

import '../theme/pizza_theme.dart';

/// True when the platform asks for reduced motion. Drop breathe, ding and
/// pop under it; keep tweens and fills (mockups/DESIGN.md).
bool reduceMotion(BuildContext context) =>
    MediaQuery.maybeDisableAnimationsOf(context) ?? false;

/// One-line confirmation, bottom-centred above the CTA, gone after 2 s.
void showPizzaToast(BuildContext context, String message) {
  final c = context.colors;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        elevation: 0,
        padding: EdgeInsets.zero,
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 96),
        content: Center(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: c.ink,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Text(
                message,
                style: context.text.button.copyWith(
                  fontSize: 13,
                  color: c.ground,
                ),
              ),
            ),
          ),
        ),
      ),
    );
}
