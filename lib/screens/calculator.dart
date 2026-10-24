import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/calc.dart';
import '../core/calibration.dart' show kYeastKnobMax, kYeastKnobMin;
import '../core/export_text.dart';
import '../core/oven.dart';
import '../routes.dart';
import '../state/flours.dart';
import '../state/oven.dart';
import '../state/recipe.dart';
import '../state/recipes.dart';
import '../state/units.dart';
import '../theme/pizza_theme.dart';
import '../widgets/widgets.dart';

// Input bounds from mockups/Main.dc.html.
const _minFlourG = 100.0;
const _minSizeCm = 20.0;

/// Oven max-temperature stepper step, °C.
const _ovenStepC = 25;

/// Advanced panel steps and ranges (FR5): (step, min, max).
const _pctSteps = {
  Pct.hydration: (1.0, 40.0, 95.0),
  Pct.salt: (0.1, 0.0, 4.0),
  Pct.oil: (0.5, 0.0, 10.0),
  Pct.sugar: (0.5, 0.0, 5.0),
  Pct.residue: (1.0, 0.0, 20.0),
};
const _kStep = (0.1, 0.0, 2.0);
const _absorptionStep = (1.0, 60.0, 90.0);
const _knobStep = (0.05, kYeastKnobMin, kYeastKnobMax);

/// Calculator: style, entry mode, flour blend, oven, live formula, advanced
/// overrides and tips. Layout, copy and behaviour: mockups/Main.dc.html.
class CalculatorScreen extends ConsumerWidget {
  const CalculatorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final out = ref.watch(outputsProvider);
    final warnings = [...out.warnings, ...ref.watch(ovenWarningsProvider)];
    final tips = [
      ...ref.watch(doughTipsProvider),
      ...ref.watch(ovenTipsProvider),
    ];
    final active = ref.watch(activeRecipeProvider);
    final edited = ref.watch(recipeDirtyProvider) ? ' · edited' : '';
    return Scaffold(
      body: Column(
        children: [
          ScreenHeader(
            eyebrow: 'Pizzalator',
            title: 'Dough',
            subtitle: active == null ? null : '${active.name}$edited',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 8,
              children: [
                HeaderIconButton(
                  icon: Icons.bookmark_border,
                  label: 'Saved recipes',
                  onPressed: () =>
                      unawaited(Navigator.pushNamed(context, Routes.recipes)),
                ),
                HeaderIconButton(
                  icon: Icons.article_outlined,
                  label: 'Bake log',
                  onPressed: () =>
                      unawaited(Navigator.pushNamed(context, Routes.bakeLog)),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(top: 4, bottom: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _StyleChips(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      spacing: 14,
                      children: [
                        const _EntryCard(),
                        const _FlourCard(),
                        const _OvenCard(),
                        const _FormulaCard(),
                        const _AdvancedCard(),
                        if (warnings.isNotEmpty) _WarningsCard(warnings),
                        if (out.notes.isNotEmpty) _NotesCard(out.notes),
                        for (final tip in tips) _TipCard(tip),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: PrimaryButton(
                label: 'Plan fermentation',
                trailingIcon: Icons.arrow_forward,
                onPressed: () =>
                    unawaited(Navigator.pushNamed(context, Routes.ferment)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StyleChips extends ConsumerWidget {
  const _StyleChips();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final style = ref.watch(recipeProvider.select((i) => i.style));
    final recipe = ref.read(recipeProvider.notifier);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Row(
        spacing: 8,
        children: [
          for (final s in PizzaStyle.values)
            PizzaChip(
              label: s.label,
              selected: s == style,
              onTap: () => recipe.setStyle(s),
            ),
        ],
      ),
    );
  }
}

class _EntryCard extends ConsumerWidget {
  const _EntryCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final t = context.text;
    final i = ref.watch(recipeProvider);
    final unit = ref.watch(lengthUnitProvider);
    final recipe = ref.read(recipeProvider.notifier);
    final round = i.style.shape == Shape.round;
    final muted = t.number.copyWith(color: c.inkMuted);

    Widget size(
      String key,
      String label,
      double cm,
      RecipeInputs Function(RecipeInputs, double cm) set,
    ) => _NumberField(
      key: ValueKey(key),
      label: label,
      value: unit.fromCm(cm),
      min: unit.fromCm(_minSizeCm),
      digits: 3,
      decimal: true,
      width: round ? 84 : 72,
      onChanged: (v) => recipe.update((i) => set(i, unit.toCm(v))),
    );

    return PizzaCard(
      delay: const Duration(milliseconds: 50),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          Segmented<EntryMode>(
            options: const [
              (EntryMode.flour, 'I have flour'),
              (EntryMode.pizzas, 'I want pizzas'),
            ],
            value: i.mode,
            onChanged: recipe.setMode,
          ),
          if (i.mode == EntryMode.flour)
            _inputRow('Total flour', [
              _NumberField(
                key: const ValueKey('flour'),
                label: 'Total flour in grams',
                value: i.flourG,
                min: _minFlourG,
                digits: 5,
                width: 120,
                onChanged: recipe.setFlourG,
              ),
              Text('g', style: muted),
            ])
          else ...[
            _inputRow('Pizzas', [
              _NumberField(
                key: const ValueKey('pizzas'),
                label: 'Pizzas',
                value: i.pizzas.toDouble(),
                min: 1,
                digits: 2,
                onChanged: (v) =>
                    recipe.update((i) => i.copyWith(pizzas: v.round())),
              ),
            ]),
            _inputRow(round ? 'Size' : 'Pan', [
              if (round)
                size(
                  'diameter',
                  'Diameter',
                  i.diameterCm,
                  (i, cm) => i.copyWith(diameterCm: cm),
                )
              else ...[
                size(
                  'panW',
                  'Pan width',
                  i.panWCm,
                  (i, cm) => i.copyWith(panWCm: cm),
                ),
                Text('×', style: muted),
                size(
                  'panL',
                  'Pan length',
                  i.panLCm,
                  (i, cm) => i.copyWith(panLCm: cm),
                ),
              ],
              const _UnitButton(),
            ]),
          ],
        ],
      ),
    );
  }
}

Widget _inputRow(String label, List<Widget> controls) => Row(
  spacing: 10,
  children: [
    Expanded(child: SectionLabel(label)),
    ...controls,
  ],
);

/// The size unit suffix; tapping it switches every size between cm and in.
class _UnitButton extends ConsumerWidget {
  const _UnitButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final unit = ref.watch(lengthUnitProvider);
    return Semantics(
      button: true,
      label: unit == LengthUnit.cm
          ? 'Switch sizes to inches'
          : 'Switch sizes to centimetres',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: ref.read(lengthUnitProvider.notifier).toggle,
        child: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: c.surfaceRaised,
            border: Border.all(color: c.lineStrong),
            borderRadius: BorderRadius.circular(12),
          ),
          // Large text shrinks the label inside the 44 px target.
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              unit.label,
              style: context.text.number.copyWith(color: c.inkSoft),
            ),
          ),
        ),
      ),
    );
  }
}

/// FR2: one to three flours, each a preset and a share; the last row takes
/// what the others leave.
class _FlourCard extends ConsumerWidget {
  const _FlourCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.text;
    final c = context.colors;
    final rows = ref.watch(recipeProvider.select((i) => i.flours));
    final choices = ref.watch(flourChoicesProvider);
    final recipe = ref.read(recipeProvider.notifier);
    void set(List<FlourShare> next) =>
        recipe.update((i) => i.copyWith(flours: balanceFlours(next)));
    List<FlourShare> edit(int k, FlourShare row) => [...rows]..[k] = row;
    final last = rows.length - 1;
    final next = Flour.presets
        .where((f) => rows.every((r) => r.flour != f))
        .sortedByWholemealFirst;
    final added = next.isEmpty ? null : addFlour(rows, next.first);

    return PizzaCard(
      delay: const Duration(milliseconds: 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          const SectionLabel('Flour'),
          for (final (k, row) in rows.indexed) ...[
            if (k > 0) Divider(height: 1, thickness: 1, color: c.line),
            Row(
              spacing: 8,
              children: [
                Expanded(
                  child: _FlourPicker(
                    choices: choices,
                    value: row.flour,
                    onChanged: (f) => set(edit(k, FlourShare(f, row.sharePct))),
                  ),
                ),
                if (rows.length > 1)
                  StepButton(
                    icon: Icons.close,
                    semanticLabel: 'Remove flour ${k + 1}',
                    onPressed: () => set([...rows]..removeAt(k)),
                  ),
              ],
            ),
            if (rows.length > 1 && k < last)
              ValueStepper(
                label: 'Share',
                value: '${pctText(row.sharePct)}%',
                canMinus: row.sharePct >= 2 * kFlourStepPct,
                // The last row keeps at least one step.
                canPlus: rows[last].sharePct >= 2 * kFlourStepPct,
                onMinus: () => set(
                  edit(k, FlourShare(row.flour, row.sharePct - kFlourStepPct)),
                ),
                onPlus: () => set(
                  edit(k, FlourShare(row.flour, row.sharePct + kFlourStepPct)),
                ),
              )
            else if (rows.length > 1)
              Row(
                children: [
                  Expanded(child: Text('Share', style: t.bodyStrong)),
                  Text('${pctText(row.sharePct)}%', style: t.number),
                  const SizedBox(width: 6),
                  Text('auto', style: t.caption),
                ],
              ),
          ],
          // → Settings › Flours (mockups/Main.dc.html).
          Align(
            alignment: Alignment.centerRight,
            child: TextLink(
              label: 'Manage flours · scan a bag',
              onTap: () =>
                  unawaited(Navigator.pushNamed(context, Routes.flours)),
            ),
          ),
          if (added != null)
            SecondaryButton(
              label: 'Add flour',
              icon: Icons.add,
              onPressed: () => recipe.update((i) => i.copyWith(flours: added)),
            ),
        ],
      ),
    );
  }
}

extension on Iterable<Flour> {
  /// Wholemeal first: the blend most kitchens add.
  List<Flour> get sortedByWholemealFirst => [
    ...where((f) => f.wholegrain),
    ...where((f) => !f.wholegrain),
  ];
}

/// Flour dropdown. The protein sits in its own trailing text so a long name
/// truncates without hiding the number that drives hydration.
class _FlourPicker extends StatelessWidget {
  const _FlourPicker({
    required this.choices,
    required this.value,
    required this.onChanged,
  });

  final List<Flour> choices;
  final Flour value;
  final ValueChanged<Flour> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    // One item per value: a snapshot equal to a choice is that choice.
    final flours = {...choices, value};
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: c.ground,
        border: Border.all(color: c.lineStrong),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<Flour>(
          value: value,
          isExpanded: true,
          itemHeight: null,
          dropdownColor: c.surfaceRaised,
          borderRadius: BorderRadius.circular(12),
          iconEnabledColor: c.inkMuted,
          style: t.buttonMd,
          items: [
            for (final f in flours)
              DropdownMenuItem(
                value: f,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        f.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${pctText(f.proteinPct)}%',
                      style: t.buttonMd.copyWith(color: c.inkMuted),
                    ),
                  ],
                ),
              ),
          ],
          onChanged: (f) => onChanged(f!),
        ),
      ),
    );
  }
}

class _OvenCard extends ConsumerWidget {
  const _OvenCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final oven = ref.watch(ovenProvider);
    final n = ref.read(ovenProvider.notifier);
    final (lo, hi) = oven.maxTempRange;
    return PizzaCard(
      delay: const Duration(milliseconds: 150),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 10,
        children: [
          const SectionLabel('Oven'),
          // By name: a changed temperature keeps its surface selected.
          Segmented<String>(
            options: [for (final o in OvenSetup.presets) (o.name, o.name)],
            value: oven.name,
            onChanged: (name) =>
                n.pick(OvenSetup.presets.firstWhere((o) => o.name == name)),
          ),
          ValueStepper(
            label: 'Max temperature',
            value: '${oven.maxTempC} °C',
            canMinus: oven.maxTempC > lo,
            canPlus: oven.maxTempC < hi,
            onMinus: () => n.setMaxTemp(oven.maxTempC - _ovenStepC),
            onPlus: () => n.setMaxTemp(oven.maxTempC + _ovenStepC),
          ),
        ],
      ),
    );
  }
}

class _FormulaCard extends ConsumerWidget {
  const _FormulaCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final i = ref.watch(recipeProvider);
    final out = ref.watch(outputsProvider);
    final s = i.style;
    final round = s.shape == Shape.round;

    // Whole-recipe totals by kind: a preferment's share is added back in.
    final all = [...out.preferment, ...out.finalDough];
    double total(LineKind k) =>
        all.where((l) => l.kind == k).fold(0.0, (t, l) => t + l.grams);
    // Blend row [k]: calc gives each part one flour line per row, in order.
    // By position, not name: two flours may share a name.
    List<Line> flours(List<Line> part) => [
      for (final l in part)
        if (l.kind == LineKind.flour) l,
    ];
    final prefFlours = flours(out.preferment),
        mainFlours = flours(out.finalDough);
    double flour(int k) =>
        mainFlours[k].grams + (prefFlours.isEmpty ? 0 : prefFlours[k].grams);
    String Function(double) g(int decimals) =>
        (v) => '${v.toStringAsFixed(decimals)} g';
    final leaven = out.finalDough.firstWhere(
      (l) => l.kind == LineKind.yeast || l.kind == LineKind.starter,
    );
    final plan = i.activePlan
        .map((st) => '${pctText(st.hours)} h @ ${pctText(st.tempC)} °C')
        .join(' + ');
    final n = out.ballCount;
    final noun = round ? 'ball' : 'pan';
    final g0 = g(0);

    final rows = [
      _Line('Flour', out.totalFlourG, g0),
      if (i.flours.length > 1)
        for (final (k, f) in i.flours.indexed)
          _Line('· ${f.flour.name}', flour(k), g0, muted: true),
      _Line('Water', total(LineKind.water), g0, color: c.emberBright),
      _Line('Salt', total(LineKind.salt), g(1)),
      if (total(LineKind.oil) > 0) _Line('Oil', total(LineKind.oil), g(1)),
      if (total(LineKind.sugar) > 0)
        _Line(sweetenerName(s), total(LineKind.sugar), g(1)),
      _Line(
        lineLabel(leaven),
        total(leaven.kind),
        g(leaven.decimals),
        sub: plan,
      ),
      if (i.mode == EntryMode.flour)
        _Line(
          round ? 'Makes' : 'Fills',
          out.ballWeightG,
          (v) => '$n ${n == 1 ? noun : '${noun}s'} · ${v.round()} g',
        )
      else
        _Line(round ? 'Per ball' : 'Per pan', out.ballWeightG, g0),
    ];

    return PizzaCard(
      variant: PizzaCardVariant.result,
      delay: const Duration(milliseconds: 200),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Stat.tween(
            label: 'Hydration',
            value: out.hydrationPct,
            format: (v) => v.toStringAsFixed(1),
            unit: '%',
          ),
          const SizedBox(height: 10),
          RangeBar(
            min: s.hMin,
            max: s.hMax,
            value: out.hydrationPct,
            minLabel: '${pctText(s.hMin)}% style min',
            centerLabel: 'protein ${pctText(out.proteinPct)}%',
            maxLabel: '${pctText(s.hMax)}% max',
          ),
          const SizedBox(height: 4),
          for (final (k, row) in rows.indexed) ...[
            if (k > 0) Divider(height: 1, thickness: 1, color: c.line),
            row,
          ],
        ],
      ),
    );
  }
}

/// One formula row: name (and caption) left, tweened grams right. One
/// TalkBack stop.
class _Line extends StatelessWidget {
  const _Line(
    this.label,
    this.value,
    this.format, {
    this.sub,
    this.color,
    this.muted = false,
  });

  final String label;
  final double value;
  final String Function(double) format;
  final String? sub;
  final Color? color;

  /// Indented secondary row, e.g. one flour of a blend.
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final ink = muted ? c.inkMuted : null;
    return MergeSemantics(
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 34),
        child: Padding(
          padding: EdgeInsets.fromLTRB(muted ? 12 : 0, 4, 0, 4),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: t.body.copyWith(color: ink ?? c.inkSoft),
                    ),
                    if (sub != null) Text(sub!, style: t.caption),
                  ],
                ),
              ),
              TweenNumber(
                value: value,
                format: format,
                style: t.number.copyWith(color: color ?? ink),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// FR5: every baker's %, thickness, `k`, wholegrain absorption and the yeast
/// knob. Closed by default, one tap from the hydration override (PRD §9).
class _AdvancedCard extends ConsumerStatefulWidget {
  const _AdvancedCard();

  @override
  ConsumerState<_AdvancedCard> createState() => _AdvancedCardState();
}

class _AdvancedCardState extends ConsumerState<_AdvancedCard> {
  var _open = false;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final i = ref.watch(recipeProvider);
    final recipe = ref.read(recipeProvider.notifier);
    final edited = Pct.values.where((p) => p.of(i) != null).length;
    final presets = thicknessPresets(i.style);
    final detroit = i.style == PizzaStyle.detroit;

    ValueStepper knob(
      String label,
      String? sub,
      double v,
      (double, double, double) range,
      String Function(double) text,
      RecipeInputs Function(RecipeInputs, double) set,
    ) {
      final (step, lo, hi) = range;
      double to(double x) => r001(x.clamp(lo, hi));
      return ValueStepper(
        label: label,
        sublabel: sub,
        value: text(v),
        canMinus: v > lo,
        canPlus: v < hi,
        onMinus: () => recipe.update((i) => set(i, to(v - step))),
        onPlus: () => recipe.update((i) => set(i, to(v + step))),
      );
    }

    return PizzaCard(
      delay: const Duration(milliseconds: 250),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          Semantics(
            button: true,
            expanded: _open,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _open = !_open),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44),
                child: Row(
                  children: [
                    const Expanded(child: SectionLabel('Advanced')),
                    if (edited > 0) Text('$edited modified', style: t.caption),
                    Icon(
                      _open ? Icons.expand_less : Icons.expand_more,
                      color: c.inkMuted,
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_open) ...[
            for (final p in Pct.values)
              _PctRow(pct: p, inputs: i, range: _pctSteps[p]!),
            const SectionLabel('Thickness'),
            Segmented<double>(
              options: [
                for (final (k, f) in presets.indexed)
                  (
                    f,
                    detroit
                        ? '${(f * 2.95).toStringAsFixed(2)} g/in²'
                        : const ['Thin', 'Standard', 'Thick'][k],
                  ),
              ],
              value: i.thickness,
              onChanged: (f) => recipe.update((i) => i.copyWith(thickness: f)),
            ),
            knob(
              'Protein slope k',
              'pp hydration per 1 % protein',
              i.hydrationSlope,
              _kStep,
              pctText,
              (i, v) => i.copyWith(hydrationSlope: v),
            ),
            knob(
              'Wholegrain absorption',
              'least water for wholemeal',
              i.wholegrainAbsorption,
              _absorptionStep,
              (v) => '${pctText(v)}%',
              (i, v) => i.copyWith(wholegrainAbsorption: v),
            ),
            knob(
              'Yeast knob',
              'my kitchen runs fast or slow',
              i.yeastKnob,
              _knobStep,
              (v) => '${(v * 100).round()}%',
              (i, v) => i.copyWith(yeastKnob: v),
            ),
            SecondaryButton(
              label: 'Reset to style',
              onPressed: edited == 0
                  ? null
                  : () => recipe.update((i) => i.resetToStyle()),
            ),
          ],
        ],
      ),
    );
  }
}

/// One baker's %: style default, current value, a badge and reset when
/// modified (FR1).
class _PctRow extends ConsumerWidget {
  const _PctRow({required this.pct, required this.inputs, required this.range});

  final Pct pct;
  final RecipeInputs inputs;
  final (double, double, double) range;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final t = context.text;
    final recipe = ref.read(recipeProvider.notifier);
    final (step, lo, hi) = range;
    final v = pct.value(inputs);
    final modified = pct.of(inputs) != null;
    final label = pct == Pct.sugar ? sweetenerName(inputs.style) : pct.label;
    void set(double x) =>
        recipe.update((i) => i.set(pct, r001(max(lo, min(hi, x)))));
    return ValueStepper(
      label: label,
      sublabel: 'style ${pctText(pct.base(inputs))}%',
      value: '${pctText(v)}%',
      canMinus: v > lo,
      canPlus: v < hi,
      onMinus: () => set(v - step),
      onPlus: () => set(v + step),
      trailing: modified
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                StepButton(
                  icon: Icons.undo,
                  semanticLabel: 'Reset ${label.toLowerCase()} to style',
                  onPressed: () => recipe.update((i) => i.clear({pct})),
                ),
                Text(
                  'MODIFIED',
                  style: t.label.copyWith(color: c.emberBright, fontSize: 9),
                ),
              ],
            )
          : null,
    );
  }
}

/// Problems with the formula as entered: alert red (DESIGN colour roles).
class _WarningsCard extends StatelessWidget {
  const _WarningsCard(this.warnings);

  final List<String> warnings;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return PizzaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 8,
        children: [
          SectionLabel('Warnings', color: c.alert),
          for (final w in warnings)
            Text(w, style: context.text.bodySm.copyWith(color: c.ink)),
        ],
      ),
    );
  }
}

/// Technique advice: nothing is wrong, so no red.
class _NotesCard extends StatelessWidget {
  const _NotesCard(this.notes);

  final List<String> notes;

  @override
  Widget build(BuildContext context) => PizzaCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 8,
      children: [
        const SectionLabel('Notes'),
        for (final n in notes) Text(n, style: context.text.bodySm),
      ],
    ),
  );
}

/// Suggestion with its one-tap edit. Suggest-only: nothing changes until
/// the button is tapped.
class _TipCard extends ConsumerWidget {
  const _TipCard(this.tip);

  final OvenTip tip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    return PizzaCard(
      variant: PizzaCardVariant.tip,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.local_fire_department_outlined,
            size: 20,
            color: c.emberBright,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionLabel(tip.title, color: c.emberBright),
                Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 10),
                  child: Text(
                    tip.text,
                    style: context.text.bodySm.copyWith(color: c.ink),
                  ),
                ),
                SecondaryButton(
                  label: tip.applyLabel,
                  onPressed: () =>
                      ref.read(recipeProvider.notifier).update(tip.apply),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Numeric entry. Values under [min] are ignored while typing and replaced by
/// the applied value when the field loses focus.
class _NumberField extends StatefulWidget {
  const _NumberField({
    required super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.digits,
    required this.onChanged,
    this.decimal = false,
    this.width = 84,
  });

  /// Spoken label; the visible one sits beside the field.
  final String label;
  final double value;
  final double min;

  /// Digits allowed before the (single) decimal place.
  final int digits;
  final bool decimal;
  final double width;
  final ValueChanged<double> onChanged;

  @override
  State<_NumberField> createState() => _NumberFieldState();
}

class _NumberFieldState extends State<_NumberField> {
  late final _text = TextEditingController(text: _fmt(widget.value));
  late final _focus = FocusNode()..addListener(_onFocus);
  late final _pattern = RegExp(
    widget.decimal
        ? '^\\d{0,${widget.digits}}(\\.\\d?)?\$'
        : '^\\d{0,${widget.digits}}\$',
  );

  String _fmt(double v) => widget.decimal ? pctText(r01(v)) : '${v.round()}';

  void _onFocus() {
    if (!_focus.hasFocus) _text.text = _fmt(widget.value);
  }

  @override
  void didUpdateWidget(_NumberField old) {
    super.didUpdateWidget(old);
    // Changed elsewhere (mode switch, unit toggle, another screen): show it,
    // unless it is just what was typed.
    final typed = double.tryParse(_text.text);
    if (widget.value != old.value &&
        (typed == null || _fmt(typed) != _fmt(widget.value))) {
      _text.text = _fmt(widget.value);
    }
  }

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    OutlineInputBorder border(Color color) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: color),
    );
    return SizedBox(
      width: widget.width,
      child: Semantics(
        label: widget.label,
        child: TextField(
          controller: _text,
          focusNode: _focus,
          keyboardType: widget.decimal
              ? const TextInputType.numberWithOptions(decimal: true)
              : TextInputType.number,
          textInputAction: TextInputAction.done,
          inputFormatters: [
            TextInputFormatter.withFunction(
              (old, next) => _pattern.hasMatch(next.text) ? next : old,
            ),
          ],
          style: context.text.number.copyWith(fontSize: 24, height: 32 / 24),
          cursorColor: c.ember,
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: c.ground,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            enabledBorder: border(c.lineStrong),
            focusedBorder: border(c.ember),
          ),
          onChanged: (s) {
            final v = double.tryParse(s);
            if (v != null && v >= widget.min) widget.onChanged(v);
          },
        ),
      ),
    );
  }
}
