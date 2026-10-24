import 'package:flutter/material.dart';

import '../theme/pizza_theme.dart';

/// The Pizza Percent mark (two dough dots, a slice and its crust), drawn from
/// assets/brand/pizzalator-symbol-orange.svg so it stays crisp at any size
/// and takes the theme's ember. Decorative: hidden from screen readers.
class PizzaMark extends StatelessWidget {
  const PizzaMark({super.key, this.size = 64, this.color});

  /// Width; the mark is a touch wider than tall.
  final double size;

  /// Defaults to ember.
  final Color? color;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: CustomPaint(
      size: Size(size, size * _h / _w),
      painter: MarkPainter(color ?? context.colors.ember),
    ),
  );
}

// The SVG's view box.
const double _w = 193, _h = 192;

class MarkPainter extends CustomPainter {
  const MarkPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / _w, size.height / _h);
    final paint = Paint()..color = color;
    canvas
      ..drawCircle(const Offset(36, 48), 36, paint)
      ..drawCircle(const Offset(146, 148), 36.5, paint)
      // Slice.
      ..drawPath(
        Path()
          ..moveTo(124.5, 22.5)
          ..cubicTo(143.5, 28.5, 160.5, 41.5, 170.5, 61)
          ..lineTo(17, 185.5)
          ..cubicTo(12, 189.5, 4.5, 186, 8, 180)
          ..close(),
        paint,
      )
      // Crust.
      ..drawPath(
        Path()
          ..moveTo(135, 4)
          ..cubicTo(136.667, 0.667, 139.5, -0.5, 143.5, 0.5)
          ..cubicTo(165, 5.5, 182.5, 21, 191, 41.5)
          ..cubicTo(193, 45.167, 192.167, 48.333, 188.5, 51)
          ..lineTo(176, 59.5)
          ..cubicTo(166.5, 39, 151.5, 26, 128.5, 18)
          ..close(),
        paint,
      );
  }

  @override
  bool shouldRepaint(MarkPainter old) => old.color != color;
}
