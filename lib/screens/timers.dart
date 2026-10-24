import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/routine.dart';
import '../core/timer_run.dart';
import '../routes.dart';
import '../state/timer_run.dart';
import '../theme/pizza_theme.dart';
import '../widgets/widgets.dart';

/// Chained routine timers: mockups/Timers.dc.html, PRD §4.7.
class TimersScreen extends ConsumerStatefulWidget {
  const TimersScreen({super.key});

  @override
  ConsumerState<TimersScreen> createState() => _TimersScreenState();
}

class _TimersScreenState extends ConsumerState<TimersScreen> {
  late final Timer _ticker;
  late DateTime _last;

  /// Timer ends seen while on screen; the ring dings on each.
  var _dings = 0;

  @override
  void initState() {
    super.initState();
    _last = ref.read(clockProvider)();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  @override
  void dispose() {
    _ticker.cancel();
    super.dispose();
  }

  void _tick() {
    final now = ref.read(clockProvider)();
    // On the saved run: a chained end has moved on by the time it settles.
    if (ref.read(timerRunProvider)?.endedBetween(_last, now) ?? false) {
      unawaited(HapticFeedback.heavyImpact());
      _dings++;
    }
    _last = now;
    unawaited(ref.read(timerRunProvider.notifier).tick());
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final now = ref.read(clockProvider)();
    // Settled, as every action settles before it acts: what is shown is what
    // a tap changes, also between ticks and on coming back to the screen.
    final live = ref.watch(timerRunProvider)?.settle(now);
    final TimerRun run = live ?? ref.watch(previewRunProvider);
    final n = ref.read(timerRunProvider.notifier);
    final step = run.step;
    final rest = step.kind == StepKind.rest;
    final timed = isTimed(step);
    final phase = run.phaseAt(now);
    final ended = phase == RunPhase.ended;
    final remaining = run.remainingAt(now);
    final note = ended && !run.isLast
        ? 'Next: ${run.nextStep!.name}'
        : step.note;

    void next() {
      if (run.isLast) Navigator.maybePop(context);
      unawaited(n.next());
    }

    final done = run.isLast ? 'Finish' : 'Done, next';
    final (String label, IconData icon, VoidCallback onMain) = live == null
        ? ('Start', Icons.play_arrow, n.start)
        : switch (phase) {
            RunPhase.running => ('Pause', Icons.pause, n.pause),
            RunPhase.paused => ('Resume', Icons.play_arrow, n.start),
            RunPhase.ready when timed => (
              'Start ${_length(step.minutes)}',
              Icons.play_arrow,
              n.start,
            ),
            _ => (done, Icons.check, next),
          };
    final VoidCallback? plus = live != null && timed ? n.extend : null;

    return Scaffold(
      body: Column(
        children: [
          ScreenHeader(
            title: 'Dough routine',
            backLabel: 'Recipe',
            action: SecondaryButton(
              label: 'Edit routine',
              onPressed: () => Navigator.pushNamed(context, Routes.routine),
            ),
            trailing: Semantics(
              label: 'Balls ready ${_hhmm(run.readyAt(now))}',
              excludeSemantics: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _hhmm(run.readyAt(now)),
                    style: t.number.copyWith(color: c.sageBright),
                  ),
                  const SectionLabel('balls ready'),
                ],
              ),
            ),
          ),
          Expanded(
            child: SafeArea(
              top: false,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _Bar(progress: run.progressAt(now)),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Step ${run.index + 1} of ${run.steps.length}',
                              style: t.caption,
                            ),
                            Text(
                              '${_left(run.totalLeftAt(now))} left',
                              style: t.caption,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  RingTimer(
                    progress: timed
                        ? (remaining.inMilliseconds /
                                  math.max(1, step.minutes * 60000))
                              .clamp(0.0, 1.0)
                        : 1,
                    clock: timed ? _clock(remaining) : '~${step.minutes} min',
                    label: ended
                        ? (rest ? 'Rest over' : 'Step done')
                        : phase == RunPhase.paused
                        ? 'Paused'
                        : rest
                        ? 'Resting'
                        : 'Hands on',
                    title: step.name,
                    color: ended
                        ? c.sage
                        : rest
                        ? c.ember
                        : c.wheat,
                    breathing: rest && phase == RunPhase.running,
                    dings: _dings,
                    stepKey: run.index,
                  ),
                  // The step's instruction, in full, under the face.
                  if (note.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(28, 8, 28, 0),
                      child: Text(
                        note,
                        textAlign: TextAlign.center,
                        style: t.bodySm,
                      ),
                    ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: SizedBox(
                      height: 56,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Semantics(
                            label: 'Add five minutes',
                            button: true,
                            enabled: plus != null,
                            onTap: plus,
                            excludeSemantics: true,
                            child: SecondaryButton(
                              label: '+5',
                              onPressed: plus,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: PrimaryButton(
                              label: label,
                              icon: icon,
                              onPressed: onMain,
                            ),
                          ),
                          const SizedBox(width: 10),
                          SecondaryButton(
                            label: 'Skip',
                            onPressed: live == null ? null : next,
                          ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                      children: [
                        for (final (i, s) in run.steps.indexed)
                          _row(context, s, i, live),
                        if (live != null) ...[
                          SwitchListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 4,
                            ),
                            title: Text('Auto-start', style: t.bodyStrong),
                            subtitle: Text(
                              'Every timer starts on its own',
                              style: t.caption,
                            ),
                            value: live.autoStart,
                            onChanged: n.setAutoStart,
                          ),
                          const SizedBox(height: 8),
                          SecondaryButton(
                            label: 'End routine',
                            onPressed: _confirmStop,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// An abandoned run would otherwise come back on every launch.
  Future<void> _confirmStop() async {
    final end = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('End this routine?'),
        content: const Text('Its timers and alarms stop.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep going'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('End'),
          ),
        ],
      ),
    );
    if ((end ?? false) && mounted) {
      await ref.read(timerRunProvider.notifier).stop();
    }
  }

  Widget _row(BuildContext context, RoutineStep s, int i, TimerRun? live) {
    final c = context.colors;
    final rest = s.kind == StepKind.rest;
    final state = live == null || i > live.index
        ? StepRowState.upcoming
        : i < live.index
        ? StepRowState.done
        : StepRowState.current;
    return StepRow(
      name: s.name,
      sub: switch (state) {
        StepRowState.done => 'done',
        StepRowState.current => rest ? 'resting now' : 'in progress',
        StepRowState.upcoming => rest ? 'covered rest' : 'hands on',
      },
      trailing: isTimed(s) ? _length(s.minutes) : '~${s.minutes} min',
      state: state,
      accent: rest ? c.ember : c.wheat,
      icon: rest ? Icons.schedule : Icons.back_hand_outlined,
    );
  }
}

/// Whole-routine progress: sage fill on a raised track.
class _Bar extends StatelessWidget {
  const _Bar({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final radius = BorderRadius.circular(3);
    return Container(
      height: 6,
      decoration: BoxDecoration(color: c.surfaceRaised, borderRadius: radius),
      child: AnimatedFractionallySizedBox(
        duration: const Duration(milliseconds: 900),
        alignment: Alignment.centerLeft,
        widthFactor: progress,
        child: DecoratedBox(
          decoration: BoxDecoration(color: c.sage, borderRadius: radius),
        ),
      ),
    );
  }
}

String _two(int n) => n.toString().padLeft(2, '0');

/// mm:ss, or h:mm:ss from an hour. Rounds up so a fresh 30 min reads 30:00.
String _clock(Duration d) {
  final s = (d.inMilliseconds / 1000).ceil();
  final mmss = '${_two(s ~/ 60 % 60)}:${_two(s % 60)}';
  return s >= 3600 ? '${s ~/ 3600}:$mmss' : mmss;
}

String _hhmm(DateTime t) => '${_two(t.hour)}:${_two(t.minute)}';

/// 10 min, 4 h, 1.5 h.
String _length(int minutes) => minutes >= 60
    ? '${(minutes / 60).toStringAsFixed(1).replaceAll('.0', '')} h'
    : '$minutes min';

String _left(Duration d) => d.inSeconds >= 3600
    ? '${(d.inSeconds / 3600).toStringAsFixed(1)} h'
    : '${(d.inSeconds / 60).ceil()} min';
