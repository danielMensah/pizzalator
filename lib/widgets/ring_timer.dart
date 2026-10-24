import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/pizza_theme.dart';
import 'feedback.dart';

const _size = 236.0;
const _stroke = 14.0;

/// Text inside the face never scales past this: the 180 px column has no
/// room to grow, and the step's note sits under the ring instead.
const _maxFaceTextScale = 1.5;

/// Timer face. [progress] is time remaining over total (1 = full arc); the arc
/// starts at 12 o'clock and shrinks clockwise. [color] is ember resting,
/// wheat hands-on, sage done. Breathes while [breathing]; wobbles once each
/// time [dings] goes up (a timer ended); rings in when [stepKey] changes.
/// Breathe, ding and ring-in are dropped under reduced motion.
class RingTimer extends StatefulWidget {
  const RingTimer({
    super.key,
    required this.progress,
    required this.clock,
    this.label,
    this.title,
    required this.color,
    this.breathing = false,
    this.dings = 0,
    this.stepKey,
  });

  final double progress;
  final String clock;

  /// State word above the clock, e.g. Resting.
  final String? label;

  /// Step name under the clock.
  final String? title;
  final Color color;
  final bool breathing;

  /// Timer ends so far. A chained end jumps straight to the next step's full
  /// arc, so the arc alone cannot say when to ding.
  final int dings;

  /// The current step; a change plays ringIn.
  final Object? stepKey;

  @override
  State<RingTimer> createState() => _RingTimerState();
}

class _RingTimerState extends State<RingTimer> with TickerProviderStateMixin {
  // breathe: scale 1 → 1.025 → 1 over 4 s.
  late final _breath = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  );
  // ding: ±14° wobble over 600 ms.
  late final _ding = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  );
  // ringIn: fade and scale up over 400 ms. Rests at 1 (no entrance at first).
  late final _enter = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 400),
    value: 1,
  );
  late final _scale = Tween(
    begin: 1.0,
    end: 1.025,
  ).animate(CurvedAnimation(parent: _breath, curve: Curves.easeInOut));
  late final _enterScale = Tween(
    begin: 0.92,
    end: 1.0,
  ).animate(CurvedAnimation(parent: _enter, curve: Curves.easeOutCubic));
  late final _turns = TweenSequence([
    for (final (a, b) in [(0, -14), (-14, 12), (12, -8), (-8, 5), (5, 0)])
      TweenSequenceItem(
        tween: Tween(begin: a / 360, end: b / 360),
        weight: 1,
      ),
  ]).animate(CurvedAnimation(parent: _ding, curve: Curves.ease));

  void _syncBreath() {
    final on = widget.breathing && !reduceMotion(context);
    if (on && !_breath.isAnimating) {
      _breath.repeat(reverse: true);
    } else if (!on) {
      _breath.reset();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncBreath();
  }

  @override
  void didUpdateWidget(RingTimer old) {
    super.didUpdateWidget(old);
    _syncBreath();
    if (reduceMotion(context)) return;
    if (widget.dings > old.dings) _ding.forward(from: 0);
    if (widget.stepKey != old.stepKey) _enter.forward(from: 0);
  }

  @override
  void dispose() {
    _breath.dispose();
    _ding.dispose();
    _enter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final spoken = [
      ?widget.label,
      ?widget.title,
      '${widget.clock} remaining',
    ].join(', ');
    return Semantics(
      label: spoken,
      excludeSemantics: true,
      child: FadeTransition(
        opacity: _enter,
        child: ScaleTransition(
          scale: _enterScale,
          child: ScaleTransition(
            scale: _scale,
            child: SizedBox.square(
              dimension: _size,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned.fill(
                    child: RotationTransition(
                      turns: _turns,
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(end: widget.progress),
                        duration: const Duration(milliseconds: 900),
                        builder: (_, p, _) => CustomPaint(
                          painter: _RingPainter(
                            p,
                            c.surfaceRaised,
                            widget.color,
                          ),
                        ),
                      ),
                    ),
                  ),
                  MediaQuery.withClampedTextScaling(
                    maxScaleFactor: _maxFaceTextScale,
                    child: SizedBox(
                      width: 180,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (widget.label != null)
                            Text(
                              widget.label!.toUpperCase(),
                              style: t.label.copyWith(color: widget.color),
                            ),
                          // h:mm:ss at 54 px is wider than the face: shrink,
                          // never wrap.
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(widget.clock, style: t.displayXl),
                          ),
                          if (widget.title != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                widget.title!,
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: t.bodyStrong,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.progress, this.track, this.color);

  final double progress;
  final Color track, color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - _stroke) / 2;
    final pen = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _stroke;
    canvas.drawCircle(center, radius, pen..color = track);
    if (progress <= 0) return;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress.clamp(0.0, 1.0),
      false,
      pen
        ..color = color
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.track != track || old.color != color;
}
