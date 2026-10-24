import 'package:flutter/material.dart';

import '../theme/pizza_theme.dart';
import 'feedback.dart';

enum PizzaCardVariant { plain, tip, hint, result }

/// Card container. Plain and result cards rise in, tips slide in from the
/// left; [delay] staggers cards down a screen (50–60 ms apart).
class PizzaCard extends StatelessWidget {
  const PizzaCard({
    super.key,
    this.variant = PizzaCardVariant.plain,
    required this.child,
    this.padding,
    this.delay = Duration.zero,
  });

  final PizzaCardVariant variant;
  final Widget child;
  final EdgeInsets? padding;
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (fill, line, radius, pad) = switch (variant) {
      PizzaCardVariant.plain => (c.surface, c.line, 20.0, 16.0),
      PizzaCardVariant.result => (c.surface, c.lineStrong, 20.0, 16.0),
      PizzaCardVariant.tip => (c.emberTint, c.emberLine, 16.0, 14.0),
      PizzaCardVariant.hint => (c.sageTint, c.sageLine, 20.0, 14.0),
    };
    final card = Container(
      padding: padding ?? EdgeInsets.all(pad),
      decoration: BoxDecoration(
        color: fill,
        border: Border.all(color: line),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: child,
    );
    if (reduceMotion(context)) return card;
    final tip = variant == PizzaCardVariant.tip;
    final total = Duration(milliseconds: tip ? 400 : 450) + delay;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: total,
      curve: Interval(
        delay.inMicroseconds / total.inMicroseconds,
        1,
        curve: Curves.ease,
      ),
      builder: (_, v, child) => Opacity(
        opacity: v,
        child: Transform.translate(
          offset: tip ? Offset(-14 * (1 - v), 0) : Offset(0, 10 * (1 - v)),
          child: child,
        ),
      ),
      child: card,
    );
  }
}
