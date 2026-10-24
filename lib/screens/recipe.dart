import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/calc.dart';
import '../core/export_text.dart';
import '../core/schedule.dart';
import '../routes.dart';
import '../state/oven.dart';
import '../state/recipe.dart';
import '../state/recipes.dart';
import '../state/schedule.dart';
import '../state/timer_run.dart';
import '../state/units.dart';
import '../theme/pizza_theme.dart';
import '../widgets/widgets.dart';
import 'bake_log.dart';
import 'recipes.dart';

/// Recipe and bake card: mockups/Recipe.dc.html.
class RecipeScreen extends ConsumerStatefulWidget {
  const RecipeScreen({super.key});

  @override
  ConsumerState<RecipeScreen> createState() => _RecipeScreenState();
}

enum _Tab { preferment, dough, schedule, bake }

const _gap = SizedBox(height: 14);

class _RecipeScreenState extends ConsumerState<RecipeScreen> {
  /// Null opens on the first tab.
  _Tab? _tab;

  /// Ticked rows as (preferment table?, line index). Screen-local on purpose.
  final _ticked = <(bool, int)>{};

  @override
  Widget build(BuildContext context) {
    final inputs = ref.watch(recipeProvider);
    final out = ref.watch(outputsProvider);
    final oven = ref.watch(ovenProvider);
    final hasPref = out.preferment.isNotEmpty;
    final prefName = prefermentLabel(effectivePreferment(inputs).kind);
    // Four tabs get short names so each fits one line at large text sizes.
    final tabs = hasPref
        ? [
            (_Tab.preferment, prefName),
            (_Tab.dough, 'Dough'),
            (_Tab.schedule, 'Times'),
            (_Tab.bake, 'Bake'),
          ]
        : [
            (_Tab.dough, 'Ingredients'),
            (_Tab.schedule, 'Schedule'),
            (_Tab.bake, 'Bake card'),
          ];
    final live = ref.watch(timerRunProvider) != null;
    final tab = tabs.any((t) => t.$1 == _tab) ? _tab! : tabs.first.$1;

    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ScreenHeader(
            title: ref.watch(activeRecipeProvider)?.name ?? 'Recipe',
            backLabel: 'Fermentation',
            subtitle: summaryText(
              inputs,
              out,
              oven,
              unit: ref.watch(lengthUnitProvider),
            ),
            trailing: Stat(
              label: 'Hydration',
              value: pctText(out.hydrationPct),
              unit: '%',
              size: 28,
              labelBelow: true,
              alignment: CrossAxisAlignment.end,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Segmented(
              options: tabs,
              value: tab,
              onChanged: (t) => setState(() => _tab = t),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
              children: [
                const CalibrationHints(),
                ...switch (tab) {
                  _Tab.preferment => [
                    _ingredients(prefName, true, out.preferment),
                  ],
                  _Tab.dough => [
                    _ingredients('Final dough', false, out.finalDough),
                    _gap,
                    const _WaterCard(),
                    _gap,
                    _yield(inputs, out),
                  ],
                  _Tab.schedule => [_schedule()],
                  _Tab.bake => _bake(),
                },
                _gap,
                Row(
                  spacing: 10,
                  children: [
                    Expanded(
                      child: SecondaryButton(
                        label: 'Copy as text',
                        icon: Icons.copy_outlined,
                        onPressed: _copy,
                      ),
                    ),
                    Expanded(child: _saveButton()),
                  ],
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: PrimaryButton(
                label: live ? 'Open dough timers' : 'Start dough timers',
                icon: Icons.timer_outlined,
                onPressed: () => Navigator.pushNamed(context, Routes.timers),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _ingredients(String label, bool pref, List<Line> lines) {
    final done = [
      for (var i = 0; i < lines.length; i++)
        if (_ticked.contains((pref, i))) i,
    ];
    return PizzaCard(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Column(
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 36),
            child: Row(
              children: [
                Expanded(child: SectionLabel(label)),
                SectionLabel('${done.length} / ${lines.length} added'),
              ],
            ),
          ),
          for (final (i, l) in lines.indexed)
            _TickRow(
              name: lineLabel(l),
              pct: pctOfFlour(l),
              grams: gramsText(l),
              done: done.contains(i),
              onTap: () => setState(() {
                if (!_ticked.remove((pref, i))) _ticked.add((pref, i));
              }),
            ),
        ],
      ),
    );
  }

  Widget _yield(RecipeInputs inputs, RecipeOutputs out) {
    final number = context.text.number.copyWith(fontSize: 18);
    return PizzaCard(
      delay: const Duration(milliseconds: 120),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionLabel('Yield'),
                Text(yieldText(inputs, out), style: number),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const SectionLabel('Total dough'),
              Text('${out.totalDoughG.toStringAsFixed(0)} g', style: number),
            ],
          ),
        ],
      ),
    );
  }

  Widget _schedule() {
    final items = ref.watch(scheduleProvider);
    final bakeAt = ref.watch(bakeSetupProvider).bakeAt;
    final now = ref.read(clockProvider)();
    return PizzaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: SectionLabel(
                  bakeAt == null
                      ? 'Bake time not set'
                      : 'Bake ${clockText(bakeAt)}',
                ),
              ),
              SecondaryButton(
                label: bakeAt == null ? 'Set bake time' : 'Change',
                icon: Icons.event_outlined,
                onPressed: _pickBakeAt,
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final (i, item) in items.indexed)
            _TimelineRow(
              item: item,
              // Where you are, once there is a bake time: the step's kind is
              // in its note (StepRow timeline spec).
              state: switch (item.at) {
                null => StepRowState.upcoming,
                final at when !now.isBefore(at.add(item.duration)) =>
                  StepRowState.done,
                final at when !now.isBefore(at) => StepRowState.current,
                _ => StepRowState.upcoming,
              },
              last: i == items.length - 1,
            ),
        ],
      ),
    );
  }

  List<Widget> _bake() {
    final c = context.colors;
    final t = context.text;
    final card = ref.watch(bakeCardProvider);
    final why = whyTheseNumbers(
      ref.watch(recipeProvider),
      ref.watch(outputsProvider),
      ref.watch(ovenProvider),
    );
    return [
      PizzaCard(
        variant: PizzaCardVariant.tip,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.local_fire_department_outlined,
                  size: 22,
                  color: c.emberBright,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SectionLabel(card.title, color: c.emberBright),
                      Text(card.subtitle, style: t.bodyStrong),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            for (final (i, step) in card.steps.indexed)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 22,
                      child: Text('${i + 1}.', style: t.bodySm),
                    ),
                    Expanded(
                      child: Text(
                        step,
                        style: t.body.copyWith(fontSize: 14, color: c.inkSoft),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      _gap,
      PizzaCard(
        delay: const Duration(milliseconds: 80),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionLabel('Why these numbers'),
            const SizedBox(height: 8),
            Text(why, style: t.bodySm),
          ],
        ),
      ),
      _gap,
      PrimaryButton(
        label: 'Log this bake',
        icon: Icons.edit_note,
        compact: true,
        onPressed: _logBake,
      ),
    ];
  }

  /// Over the bake log, so Back and Save land where the new bake shows. The
  /// log goes straight over the calculator, as from its header, so its
  /// "Calculator" link and system Back agree.
  void _logBake() {
    unawaited(
      Navigator.pushNamedAndRemoveUntil(
        context,
        Routes.bakeLog,
        ModalRoute.withName(Routes.calculator),
      ),
    );
    unawaited(Navigator.pushNamed(context, Routes.logEntry));
  }

  Future<void> _pickBakeAt() async {
    final now = ref.read(clockProvider)();
    final today = DateTime(now.year, now.month, now.day);
    final set = ref.read(bakeSetupProvider).bakeAt;
    final initial = set == null || set.isBefore(today)
        ? DateTime(now.year, now.month, now.day + 1, 19)
        : set;
    final day = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: today,
      lastDate: DateTime(now.year, now.month, now.day + 60),
    );
    if (day == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null || !mounted) return;
    ref
        .read(bakeSetupProvider.notifier)
        .setBakeAt(
          DateTime(day.year, day.month, day.day, time.hour, time.minute),
        );
  }

  /// Save recipe (asks a name), Save changes, or a spent "Saved".
  Widget _saveButton() {
    if (ref.watch(activeRecipeProvider) == null) {
      return SecondaryButton(
        label: 'Save recipe',
        icon: Icons.bookmark_add_outlined,
        onPressed: () => unawaited(saveAsNew(context, ref)),
      );
    }
    if (ref.watch(recipeDirtyProvider)) {
      return SecondaryButton(
        label: 'Save changes',
        icon: Icons.bookmark_add_outlined,
        onPressed: () =>
            unawaited(ref.read(savedRecipesProvider.notifier).saveChanges()),
      );
    }
    return const SecondaryButton(
      label: 'Saved',
      icon: Icons.bookmark_added_outlined,
      success: true,
    );
  }

  Future<void> _copy() async {
    final text = recipeText(
      inputs: ref.read(recipeProvider),
      outputs: ref.read(outputsProvider),
      oven: ref.read(ovenProvider),
      schedule: ref.read(scheduleProvider),
      water: ref.read(waterTempProvider),
      unit: ref.read(lengthUnitProvider),
    );
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) showPizzaToast(context, 'Recipe copied');
  }
}

/// One ingredient: tick box, name, baker's %, grams. At least 48 px tall;
/// large text grows the row, and the grams never wrap.
class _TickRow extends StatelessWidget {
  const _TickRow({
    required this.name,
    required this.pct,
    required this.grams,
    required this.done,
    required this.onTap,
  });

  final String name, pct, grams;
  final bool done;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    const shift = Duration(milliseconds: 250);
    return Semantics(
      checked: done,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedOpacity(
          duration: shift,
          opacity: done ? 0.45 : 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: shift,
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: done ? c.ember : null,
                    border: Border.all(
                      color: done ? c.ember : c.lineStrong,
                      width: 1.5,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: done
                      ? Icon(Icons.check, size: 16, color: c.onEmber)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    name,
                    style: t.body.copyWith(
                      decoration: done ? TextDecoration.lineThrough : null,
                    ),
                  ),
                ),
                Text(pct, style: t.captionRegular),
                ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 72),
                  child: Text(
                    grams,
                    textAlign: TextAlign.right,
                    softWrap: false,
                    style: t.number,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Water temperature with the kitchen inputs that drive it.
class _WaterCard extends ConsumerWidget {
  const _WaterCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.text;
    final s = ref.watch(bakeSetupProvider);
    final w = ref.watch(waterTempProvider);
    final n = ref.read(bakeSetupProvider.notifier);
    final recipe = ref.read(recipeProvider.notifier);
    // One kitchen: the plan's room temperature, as Fermentation sets it.
    final plan = StagePlan.of(ref.watch(recipeProvider).activePlan);
    final roomC = plan.roomC;
    final hasRoom = plan.roomH + plan.warmH > 0;
    return PizzaCard(
      delay: const Duration(milliseconds: 80),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionLabel('Water temperature'),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '${w.celsius} °C',
                style: t.displayMd.copyWith(fontSize: 28),
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(w.caption, style: t.caption)),
            ],
          ),
          const SizedBox(height: 12),
          ValueStepper(
            label: 'Flour temp',
            value: '${s.flourC} °C',
            onMinus: () => n.setFlourC(s.flourC - 1),
            onPlus: () => n.setFlourC(s.flourC + 1),
            canMinus: s.flourC > kKitchenMinC,
            canPlus: s.flourC < kKitchenMaxC,
          ),
          const SizedBox(height: 10),
          ValueStepper(
            label: 'Room temp',
            sublabel: 'also times the yeast',
            value: '${roomC.round()} °C',
            onMinus: () => recipe.setRoomC(roomC - 1),
            onPlus: () => recipe.setRoomC(roomC + 1),
            canMinus: hasRoom && roomC > StagePlan.roomMinC,
            canPlus: hasRoom && roomC < StagePlan.roomMaxC,
          ),
          const SizedBox(height: 12),
          Segmented(
            options: const [(false, 'Hand'), (true, 'Mixer')],
            value: s.mixer,
            onChanged: n.setMixer,
          ),
        ],
      ),
    );
  }
}

/// Schedule timeline row: state dot and connector, name, time, note. Past
/// sage, current ember with a pulse, upcoming line-strong (StepRow spec).
class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.item,
    required this.state,
    required this.last,
  });

  final ScheduleItem item;
  final StepRowState state;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              _Dot(state),
              if (!last) Expanded(child: Container(width: 2, color: c.line)),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: last ? 0 : 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(item.name, style: t.bodyStrong)),
                      Text(whenText(item), style: t.numberMuted),
                    ],
                  ),
                  Text(item.note, style: t.bodySm.copyWith(color: c.inkMuted)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The current dot pulses (opacity 1 → .35, 1.6 s); not under reduced
/// motion.
class _Dot extends StatefulWidget {
  const _Dot(this.state);

  final StepRowState state;

  @override
  State<_Dot> createState() => _DotState();
}

class _DotState extends State<_Dot> with SingleTickerProviderStateMixin {
  late final _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  );
  late final _opacity = Tween(begin: 1.0, end: 0.35).animate(_pulse);

  void _sync() {
    final on = widget.state == StepRowState.current && !reduceMotion(context);
    if (on && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    } else if (!on) {
      _pulse.reset();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(_Dot old) {
    super.didUpdateWidget(old);
    _sync();
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final now = widget.state == StepRowState.current;
    return FadeTransition(
      opacity: _opacity,
      child: Container(
        width: 12,
        height: 12,
        margin: const EdgeInsets.only(top: 4),
        decoration: BoxDecoration(
          color: switch (widget.state) {
            StepRowState.done => c.sage,
            StepRowState.current => c.ember,
            StepRowState.upcoming => c.lineStrong,
          },
          shape: BoxShape.circle,
          boxShadow: now
              ? [
                  BoxShadow(
                    color: c.ember.withValues(alpha: 0.2),
                    spreadRadius: 4,
                  ),
                ]
              : null,
        ),
      ),
    );
  }
}
