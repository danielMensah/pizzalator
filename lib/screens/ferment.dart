// Fermentation plan: leavening, preferment, stage timeline, yeast result.
// Mockup: mockups/Ferment.dc.html. Model: spec/PRD.md §4.5.
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/calc.dart';
import '../core/schedule.dart';
import '../routes.dart';
import '../state/recipe.dart';
import '../theme/pizza_theme.dart';
import '../widgets/widgets.dart';

// Stage editor limits and steps, hours.
const _roomMaxH = 24.0, _fridgeMaxH = 96.0, _warmMaxH = 4.0;
const _roomStepH = 1.0, _fridgeStepH = 12.0, _warmStepH = 1.0;

/// Preferment flour share and hydration step, %.
const _pctStep = 5.0;

const _yeasts = [
  (Yeast.idy, 'Instant'),
  (Yeast.ady, 'Active dry'),
  (Yeast.fresh, 'Fresh'),
  (Yeast.sourdough, 'Sourdough'),
];

const _prefs = [Preferment.none, Preferment.poolish, Preferment.biga];

String _prefName(PrefermentKind k) => switch (k) {
  PrefermentKind.none => 'None',
  PrefermentKind.poolish => 'Poolish',
  PrefermentKind.biga => 'Biga',
  PrefermentKind.sourdough => 'Starter',
};

double _sum(List<Line> lines, LineKind kind) =>
    lines.where((l) => l.kind == kind).fold(0.0, (g, l) => g + l.grams);

String _note(Yeast yeast, Preferment p, List<Stage> plan) {
  if (yeast == Yeast.sourdough) {
    return 'Starter at ${pctText(p.hydration)}% hydration. No time model '
        'yet: adjust timing from your bakes.';
  }
  if (p.kind != PrefermentKind.none) {
    return '${_prefName(p.kind)}: ${pctText(p.flourShare)}% of flour at '
        '${pctText(p.hydration)}% hydration with '
        '${pctText(p.idyPctOfPrefFlour)}% IDY of its flour, '
        '${pctText(p.hours)} h at ${pctText(p.tempC)} °C. Final-dough yeast '
        'cut to ${pctText(kPrefermentFinalYeast * 100)}%.';
  }
  if (fridgeOnly(plan)) {
    return 'Fridge-only plan: +${pctText((kFridgeOnlyBoost - 1) * 100)}% '
        'yeast margin applied; the model under-doses cold ferments.';
  }
  return 'Scaled to time and temperature: longer or warmer needs less yeast.';
}

/// A − value + row stepping [v] by [step] within [lo]..[hi].
ValueStepper _stepper({
  required String label,
  String? sublabel,
  required String value,
  required double v,
  required double step,
  required double lo,
  required double hi,
  required ValueChanged<double> onChanged,
  bool canMinus = true,
  Widget? leading,
}) => ValueStepper(
  label: label,
  sublabel: sublabel,
  value: value,
  leading: leading,
  canMinus: canMinus && v > lo,
  canPlus: v < hi,
  onMinus: () => onChanged(max(lo, v - step)),
  onPlus: () => onChanged(min(hi, v + step)),
);

class FermentScreen extends StatelessWidget {
  const FermentScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const ScreenHeader(title: 'Fermentation', backLabel: 'Calculator'),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 14,
              children: [_Leavening(), _Schedule(), _YeastResult()],
            ),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: PrimaryButton(
              label: 'Build recipe',
              trailingIcon: Icons.arrow_forward,
              onPressed: () => Navigator.pushNamed(context, Routes.recipe),
            ),
          ),
        ),
      ],
    ),
  );
}

class _Leavening extends ConsumerWidget {
  const _Leavening();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final i = ref.watch(recipeProvider);
    final hydration = ref.watch(outputsProvider.select((o) => o.hydrationPct));
    final update = ref.read(recipeProvider.notifier).update;
    final pref = effectivePreferment(i);
    final kind = pref.kind;
    final starter = kind == PrefermentKind.sourdough;
    void setPref(Preferment p) => update((i) => i.copyWith(preferment: p));
    // Never more water in the preferment than in the whole dough.
    final cap =
        (maxPrefermentShare(pref, hydration) / _pctStep).floor() * _pctStep;
    final (hLo, hHi) = kind.hours;
    final (tLo, tHi) = kind.temps;
    return PizzaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          const SectionLabel('Leavening'),
          Segmented<Yeast>(
            options: _yeasts,
            value: i.yeast,
            onChanged: (y) => update((i) => withYeast(i, y)),
          ),
          // Sourdough excludes commercial-yeast preferments (PRD §4.1).
          if (i.yeast != Yeast.sourdough) ...[
            const SectionLabel('Preferment'),
            Row(
              spacing: 8,
              children: [
                for (final p in _prefs)
                  Expanded(
                    child: PizzaChip(
                      label: _prefName(p.kind),
                      selected: p.kind == kind,
                      onTap: () {
                        if (p.kind != kind) setPref(p);
                      },
                    ),
                  ),
              ],
            ),
          ],
          if (kind != PrefermentKind.none) ...[
            // A starter's share is its own mass (PRD §4.5 "starter 15 %").
            _stepper(
              label: starter ? 'Starter' : 'Flour share',
              sublabel: starter
                  ? '% of flour, ${pctText(kind.shareMin)}–'
                        '${pctText(kind.shareMax)}%'
                  : 'of total flour, ${pctText(kind.shareMin)}–'
                        '${pctText(kind.shareMax)}%',
              value: '${pctText(pref.flourShare)}%',
              v: pref.flourShare,
              step: _pctStep,
              lo: kind.shareMin,
              hi: min(kind.shareMax, cap),
              onChanged: (v) => setPref(pref.copyWith(flourShare: v)),
            ),
            if (kind.hydrationMax > kind.hydrationMin)
              _stepper(
                label: 'Hydration',
                sublabel:
                    '${pctText(kind.hydrationMin)}–'
                    '${pctText(kind.hydrationMax)}%',
                value: '${pctText(pref.hydration)}%',
                v: pref.hydration,
                step: _pctStep,
                lo: kind.hydrationMin,
                hi: kind.hydrationMax,
                onChanged: (v) => setPref(pref.copyWith(hydration: v)),
              ),
            if (hHi > hLo)
              _stepper(
                label: 'Hours',
                sublabel: '${pctText(hLo)}–${pctText(hHi)} h',
                value: '${pctText(pref.hours)} h',
                v: pref.hours,
                step: 1,
                lo: hLo,
                hi: hHi,
                onChanged: (v) => setPref(pref.copyWith(hours: v)),
              ),
            if (tHi > tLo)
              _stepper(
                label: 'Temperature',
                sublabel: '${pctText(tLo)}–${pctText(tHi)} °C',
                value: '${pctText(pref.tempC)} °C',
                v: pref.tempC,
                step: 1,
                lo: tLo,
                hi: tHi,
                onChanged: (v) => setPref(pref.copyWith(tempC: v)),
              ),
          ],
        ],
      ),
    );
  }
}

class _Schedule extends ConsumerWidget {
  const _Schedule();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final t = context.text;
    final p = StagePlan.of(ref.watch(recipeProvider).activePlan);
    final recipe = ref.read(recipeProvider.notifier);
    void set(StagePlan next) =>
        recipe.update((i) => i.copyWith(plan: next.stages));
    Widget stage(
      String label,
      String sub,
      Color color,
      double v,
      double step,
      double hi,
      StagePlan Function(double) next,
    ) => _stepper(
      label: label,
      sublabel: sub,
      value: '${pctText(v)}h',
      v: v,
      step: step,
      lo: 0,
      hi: hi,
      // Never step the whole plan down to 0 h.
      canMinus: p.totalH > min(v, step),
      leading: Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      onChanged: (h) => set(next(h)),
    );
    return PizzaCard(
      delay: const Duration(milliseconds: 60),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 14,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SectionLabel('Schedule'),
              Text(
                '${pctText(p.totalH)} h total',
                style: t.number.copyWith(color: c.emberBright),
              ),
            ],
          ),
          _Track(p),
          stage(
            'Room bulk',
            '${pctText(p.roomC)} °C · yeast works fast',
            c.emberBright,
            p.roomH,
            _roomStepH,
            _roomMaxH,
            (h) => p.copyWith(roomH: h),
          ),
          stage(
            'Fridge',
            '${pctText(p.fridgeC)} °C · flavour, slow rise',
            c.sage,
            p.fridgeH,
            _fridgeStepH,
            _fridgeMaxH,
            (h) => p.copyWith(fridgeH: h),
          ),
          stage(
            'Warm up before bake',
            'balls reach ${kWarmUpTargetC.round()} °C',
            c.wheat,
            p.warmH,
            _warmStepH,
            _warmMaxH,
            (h) => p.copyWith(warmH: h),
          ),
          Row(
            children: [
              const SizedBox(width: 110, child: SectionLabel('Room temp')),
              Expanded(
                child: Semantics(
                  label: 'Room temperature',
                  child: Slider(
                    min: StagePlan.roomMinC,
                    max: StagePlan.roomMaxC,
                    divisions: (StagePlan.roomMaxC - StagePlan.roomMinC)
                        .round(),
                    value: p.roomC.clamp(
                      StagePlan.roomMinC,
                      StagePlan.roomMaxC,
                    ),
                    activeColor: c.ember,
                    inactiveColor: c.surfaceRaised,
                    semanticFormatterCallback: (v) => '${v.round()} °C',
                    // A fridge-only plan has no room stage to retime.
                    onChanged: p.roomH + p.warmH > 0
                        ? (v) => recipe.setRoomC(v.roundToDouble())
                        : null,
                  ),
                ),
              ),
              SizedBox(
                width: 48,
                child: Text(
                  '${pctText(p.roomC)}°',
                  textAlign: TextAlign.right,
                  style: t.number,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Room → fridge → warm-up proportions; widths fill 500 ms on change.
class _Track extends StatelessWidget {
  const _Track(this.plan);

  final StagePlan plan;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final total = plan.totalH;
    return ExcludeSemantics(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(7),
        child: Container(
          height: 14,
          color: c.surfaceRaised,
          child: LayoutBuilder(
            builder: (context, box) => Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (h, color) in [
                  (plan.roomH, c.emberBright),
                  (plan.fridgeH, c.sage),
                  (plan.warmH, c.wheat),
                ])
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 500),
                    curve: const Cubic(0.2, 0.8, 0.2, 1),
                    width: total > 0 ? box.maxWidth * h / total : 0,
                    color: color,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _YeastResult extends ConsumerWidget {
  const _YeastResult();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final t = context.text;
    final i = ref.watch(recipeProvider);
    final out = ref.watch(outputsProvider);
    final pref = effectivePreferment(i);
    final yeast = out.finalDough.firstWhere(
      (l) => l.kind == LineKind.yeast || l.kind == LineKind.starter,
    );
    final digits = yeast.decimals;
    final label = switch (i.yeast) {
      Yeast.idy => 'Instant dry yeast',
      Yeast.ady => 'Active dry yeast',
      Yeast.fresh => 'Fresh yeast',
      Yeast.sourdough => 'Sourdough starter',
    };
    return PizzaCard(
      variant: PizzaCardVariant.result,
      delay: const Duration(milliseconds: 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 8,
        children: [
          SectionLabel(label),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              TweenNumber(
                value: yeast.grams,
                format: (v) => v.toStringAsFixed(digits),
                style: t.displayLg.copyWith(color: c.emberBright),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  'g · ${yeast.pct.toStringAsFixed(digits)}% of flour',
                  style: t.unit.copyWith(fontSize: 16),
                ),
              ),
            ],
          ),
          Text(_note(i.yeast, pref, i.activePlan), style: t.bodySm),
          // The calc core decides when a pinch is due.
          if (out.notes.contains(kPinchNote))
            Text(kPinchNote, style: t.bodySm.copyWith(color: c.emberBright)),
          if (pref.kind != PrefermentKind.none)
            _Split(
              name: _prefName(pref.kind),
              prefFlour: _sum(out.preferment, LineKind.flour),
              prefWater: _sum(out.preferment, LineKind.water),
              totalFlour: out.totalFlourG,
              finalWater: _sum(out.finalDough, LineKind.water),
            ),
        ],
      ),
    );
  }
}

/// Preferment vs final dough, flour and water grams.
class _Split extends StatelessWidget {
  const _Split({
    required this.name,
    required this.prefFlour,
    required this.prefWater,
    required this.totalFlour,
    required this.finalWater,
  });

  final String name;
  final double prefFlour, prefWater, totalFlour, finalWater;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final num = t.number.copyWith(fontSize: 13);
    Widget row(String label, double flour, double water) => Row(
      children: [
        Expanded(
          child: Text(label, style: t.bodySm.copyWith(color: c.inkMuted)),
        ),
        Expanded(
          child: Text(
            '${pctText(flour)} g flour',
            textAlign: TextAlign.right,
            style: num,
          ),
        ),
        Expanded(
          child: Text(
            '${pctText(water)} g water',
            textAlign: TextAlign.right,
            style: num,
          ),
        ),
      ],
    );
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: c.line)),
      ),
      child: Column(
        spacing: 6,
        children: [
          row(name, prefFlour, prefWater),
          row('Final dough', totalFlour - prefFlour, finalWater),
        ],
      ),
    );
  }
}
