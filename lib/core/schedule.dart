// Pure Dart. No Flutter imports. Water temperature and schedule: PRD §4.6.
import 'presets.dart';

// ponytail: calibration knob. Mixing friction by hand, °C.
const double kFrictionHandC = 2;
// ponytail: calibration knob. Mixing friction with a stand mixer, °C.
const double kFrictionMixerC = 6;

/// Final dough temperature to aim for, °C.
const double kTargetDoughC = 24;

// ponytail: calibration knob. Ball temperature a warm-up aims for, °C.
const double kWarmUpTargetC = 15;

/// Water temperature that lands the dough on [targetC]. Unrounded.
/// 3-factor form; 4-factor when a preferment temperature is given.
double waterTempC({
  double targetC = kTargetDoughC,
  required double flourC,
  required double roomC,
  double frictionC = kFrictionHandC,
  double? prefermentC,
}) =>
    (prefermentC == null ? 3 : 4) * targetC -
    flourC -
    roomC -
    frictionC -
    (prefermentC ?? 0);

enum ScheduleStep { preferment, mix, bulk, ball, fridge, warmUp, bake }

class ScheduleItem {
  const ScheduleItem({
    required this.step,
    required this.name,
    required this.startOffset,
    required this.duration,
    required this.note,
    this.at,
  });

  final ScheduleStep step;
  final String name;

  /// Measured from the start of the whole process.
  final Duration startOffset;
  final Duration duration;
  final String note;

  /// Absolute start time; null unless a bake time was given.
  final DateTime? at;
}

/// Preferment → mix + routine → bulk → fridge → divide → warm-up → bake, the
/// order the dough routine runs (PRD §4.7: bulk in the container, fridge,
/// then divide). [handsOn] is the routine before its bound step, [afterBulk]
/// the routine after it, so mix time and the timers agree. Bulk is the room
/// stages before the first fridge stage, warm-up the room stages after the
/// last.
List<ScheduleItem> buildSchedule({
  required List<Stage> plan,
  required Preferment preferment,
  required Duration handsOn,
  required Duration afterBulk,
  DateTime? bakeAt,
}) {
  List<Stage> live(List<Stage> s) => [...s.where((st) => st.hours > 0)];
  final split = splitPlan(plan);
  final bulk = live(split.bulk);
  final cold = live(split.fridge);
  final warm = live(split.warm);
  final pref = _dur(preferment.hours);
  final prefAt = preferment.tempC > 0
      ? 'at ${preferment.tempC.round()} °C'
      : 'at room temperature';

  final entries = <(ScheduleStep, String, Duration, String)>[
    if (pref > Duration.zero)
      (
        ScheduleStep.preferment,
        preferment.kind == PrefermentKind.sourdough
            ? 'Feed starter'
            : 'Mix ${preferment.kind.name}',
        pref,
        '${hmText(pref)} $prefAt, covered.',
      ),
    (
      ScheduleStep.mix,
      'Mix + dough routine',
      handsOn,
      'Timers run it: ${hmText(handsOn)}.',
    ),
    if (bulk.isNotEmpty)
      (
        ScheduleStep.bulk,
        'Bulk in container',
        _sum(bulk),
        '${_stages(bulk)}, covered.',
      ),
    if (cold.isNotEmpty)
      (
        ScheduleStep.fridge,
        'Fridge',
        _sum(cold),
        '${_stages(cold)}, in the container.',
      ),
    (
      ScheduleStep.ball,
      'Divide into balls',
      afterBulk,
      'Into oiled tubs, covered.',
    ),
    if (warm.isNotEmpty && cold.isNotEmpty)
      (
        ScheduleStep.warmUp,
        'Warm up',
        _sum(warm),
        '${hmText(_sum(warm))} before bake, on the counter: '
            'balls reach ${kWarmUpTargetC.round()} °C and relax.',
      )
    else if (warm.isNotEmpty)
      (
        ScheduleStep.warmUp,
        'Proof balls',
        _sum(warm),
        '${_stages(warm)} on the counter, covered.',
      ),
    (ScheduleStep.bake, 'Bake', Duration.zero, 'See bake card.'),
  ];

  final start = bakeAt?.subtract(
    entries.fold(Duration.zero, (t, e) => t + e.$3),
  );
  final items = <ScheduleItem>[];
  var offset = Duration.zero;
  for (final (step, name, duration, note) in entries) {
    items.add(
      ScheduleItem(
        step: step,
        name: name,
        startOffset: offset,
        duration: duration,
        note: note,
        at: start?.add(offset),
      ),
    );
    offset += duration;
  }
  return items;
}

Duration _dur(double hours) => Duration(seconds: (hours * 3600).round());

Duration _sum(List<Stage> s) =>
    s.fold(Duration.zero, (t, st) => t + _dur(st.hours));

String _stages(List<Stage> s) => s
    .map((st) => '${hmText(_dur(st.hours))} at ${st.tempC.round()} °C')
    .join(', ');

/// "45 min", "2 h", "1 h 05".
String hmText(Duration d) {
  final h = d.inHours, m = d.inMinutes % 60;
  if (h == 0) return '$m min';
  return m == 0 ? '$h h' : '$h h ${'$m'.padLeft(2, '0')}';
}
