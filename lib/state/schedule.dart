import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/calc.dart';
import '../core/export_text.dart';
import '../core/routine.dart';
import '../core/schedule.dart';
import 'recipe.dart';
import 'routine.dart';

/// Starting flour temperature, °C. Edited on the Recipe screen. The room
/// temperature is the plan's (StagePlan.roomC): one kitchen, one number.
const int kDefaultFlourC = 20;

/// Range the flour temperature stepper allows, °C.
const int kKitchenMinC = 0;
const int kKitchenMaxC = 40;

/// Recipe-screen inputs that are not part of the formula. Not persisted.
class BakeSetup {
  const BakeSetup({
    this.bakeAt,
    this.flourC = kDefaultFlourC,
    this.mixer = false,
  });

  /// Target bake time; null keeps the schedule relative.
  final DateTime? bakeAt;
  final int flourC;

  /// Stand mixer (more friction) instead of hand mixing.
  final bool mixer;

  BakeSetup copyWith({DateTime? bakeAt, int? flourC, bool? mixer}) => BakeSetup(
    bakeAt: bakeAt ?? this.bakeAt,
    flourC: flourC ?? this.flourC,
    mixer: mixer ?? this.mixer,
  );
}

final bakeSetupProvider = NotifierProvider<BakeSetupNotifier, BakeSetup>(
  BakeSetupNotifier.new,
);

class BakeSetupNotifier extends Notifier<BakeSetup> {
  @override
  BakeSetup build() => const BakeSetup();

  void setBakeAt(DateTime at) => state = state.copyWith(bakeAt: at);
  void setFlourC(int c) =>
      state = state.copyWith(flourC: c.clamp(kKitchenMinC, kKitchenMaxC));
  void setMixer(bool mixer) => state = state.copyWith(mixer: mixer);
}

/// Preferment → mix + routine → bulk → fridge → divide → warm-up → bake.
final scheduleProvider = Provider<List<ScheduleItem>>((ref) {
  final i = ref.watch(recipeProvider);
  final steps = ref.watch(routineProvider).current.steps;
  return buildSchedule(
    plan: i.activePlan,
    preferment: effectivePreferment(i),
    handsOn: handsOnDuration(steps),
    afterBulk: afterBulkDuration(steps),
    bakeAt: ref.watch(bakeSetupProvider).bakeAt,
  );
});

/// Water temperature to land the dough on 24 °C, rounded to 1 °C, with the
/// caption that explains it.
final waterTempProvider = Provider<({int celsius, String caption})>((ref) {
  final s = ref.watch(bakeSetupProvider);
  final i = ref.watch(recipeProvider);
  final roomC = StagePlan.of(i.activePlan).roomC.round();
  final pref = effectivePreferment(i);
  final has = pref.kind != PrefermentKind.none;
  // A starter has no fermenting temperature of its own: it sits at room temp.
  final prefC = pref.tempC > 0 ? pref.tempC.round() : roomC;
  final celsius = waterTempC(
    flourC: s.flourC.toDouble(),
    roomC: roomC.toDouble(),
    frictionC: s.mixer ? kFrictionMixerC : kFrictionHandC,
    prefermentC: has ? prefC.toDouble() : null,
  ).round();
  return (
    celsius: celsius,
    caption: [
      'for ${kTargetDoughC.round()} °C dough',
      'flour ${s.flourC} °C',
      'room $roomC °C',
      if (has) '${prefermentLabel(pref.kind).toLowerCase()} $prefC °C',
      s.mixer ? 'mixer' : 'hand mix',
    ].join(' · '),
  );
});
