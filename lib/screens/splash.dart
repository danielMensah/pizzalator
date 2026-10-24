import 'package:flutter/material.dart';

import '../theme/pizza_theme.dart';
import '../widgets/widgets.dart';

/// How long the splash plays, hold included.
const kSplashDuration = Duration(milliseconds: 3200);

/// The still at the end (and the whole splash under reduced motion).
const kSplashHold = Duration(milliseconds: 480);

const _ring = 240.0;
const _mark = 112.0;

// Beats, as fractions of kSplashDuration. The arc closes at 0.62; the hold
// starts at 0.85.
const _arcEnd = 0.62;
const _holdStart = 0.85;

/// Launch screen, concept 03 "Rest ring" from the splash canvas: the rest
/// ring draws around the breathing mark; when it closes the arc turns sage,
/// the mark dings, Resting becomes Ready and the wordmark rises. Plays once,
/// then [onDone]. Reduced motion shows the final frame for [kSplashHold].
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: kSplashDuration)
    ..addStatusListener((s) {
      if (s == AnimationStatus.completed) widget.onDone();
    });

  Animation<double> _beat(
    double from,
    double to, [
    Curve curve = Curves.ease,
  ]) => CurvedAnimation(
    parent: _c,
    curve: Interval(from, to, curve: curve),
  );

  // fill: the arc, 0 → 1.
  late final _arc = _beat(0, _arcEnd, const Cubic(.2, .8, .2, 1));
  // breathe: 1 → 1.025 → 1 while the arc draws.
  late final _breath = TweenSequence([
    for (final (a, b) in [(1.0, 1.025), (1.025, 1.0)])
      TweenSequenceItem(
        tween: Tween(begin: a, end: b),
        weight: 1,
      ),
  ]).animate(_beat(0, _arcEnd, Curves.easeInOut));
  // Done: ember-bright → sage.
  late final _done = _beat(_arcEnd, 0.70);
  // ding: ±14° wobble.
  late final _turns = TweenSequence([
    for (final (a, b) in [(0, -14), (-14, 12), (12, -8), (-8, 5), (5, 0)])
      TweenSequenceItem(
        tween: Tween(begin: a / 360, end: b / 360),
        weight: 1,
      ),
  ]).animate(_beat(_arcEnd, 0.81));
  late final _resting = ReverseAnimation(_beat(_arcEnd, 0.68));
  late final _ready = _beat(0.64, 0.72);
  late final _wordmark = _beat(0.70, 0.84);
  late final _tagline = _beat(0.74, 0.88);

  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (reduceMotion(context)) _c.value = _holdStart;
    _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Widget _rise(Animation<double> a, Widget child) => FadeTransition(
    opacity: a,
    child: SlideTransition(
      position: Tween(
        begin: const Offset(0, 0.25),
        end: Offset.zero,
      ).animate(a),
      child: child,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    return Semantics(
      label: 'Pizzalator',
      excludeSemantics: true,
      child: Scaffold(
        backgroundColor: c.ground,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox.square(
                dimension: _ring,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned.fill(
                      child: AnimatedBuilder(
                        animation: _c,
                        builder: (_, _) => CustomPaint(
                          painter: RingPainter(
                            _arc.value,
                            c.surfaceRaised,
                            Color.lerp(c.emberBright, c.sage, _done.value)!,
                          ),
                        ),
                      ),
                    ),
                    RotationTransition(
                      turns: _turns,
                      child: ScaleTransition(
                        scale: _breath,
                        child: const PizzaMark(size: _mark),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              SizedBox(
                height: 16,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    FadeTransition(
                      opacity: _resting,
                      child: Text('RESTING', style: t.label),
                    ),
                    _rise(
                      _ready,
                      Text(
                        'READY',
                        style: t.label.copyWith(color: c.sageBright),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              _rise(_wordmark, Text('Pizzalator', style: t.displayLg)),
              const SizedBox(height: 12),
              _rise(
                _tagline,
                Text('Dough math for the home oven', style: t.bodySm),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Root while the app starts: the splash on its own dark theme until it has
/// played and [ready] (bootstrap) has settled, then [child]. A failed
/// [ready] still opens the app: bootstrap already swallows its own errors.
class Launch extends StatefulWidget {
  const Launch({super.key, required this.ready, required this.child});

  final Future<void> ready;
  final Widget child;

  @override
  State<Launch> createState() => _LaunchState();
}

class _LaunchState extends State<Launch> {
  bool _played = false, _ready = false;

  @override
  void initState() {
    super.initState();
    widget.ready.then<void>((_) {}, onError: (Object _) {}).whenComplete(() {
      if (mounted) setState(() => _ready = true);
    });
  }

  @override
  Widget build(BuildContext context) => _played && _ready
      ? widget.child
      : MaterialApp(
          title: 'Pizzalator',
          theme: pizzaTheme(Brightness.dark),
          home: SplashScreen(onDone: () => setState(() => _played = true)),
        );
}
