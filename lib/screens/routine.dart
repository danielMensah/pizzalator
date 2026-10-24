import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/presets.dart';
import '../core/routine.dart';
import '../core/schedule.dart';
import '../state/recipe.dart';
import '../state/routine.dart';
import '../theme/pizza_theme.dart';
import '../widgets/widgets.dart';

const _newStep = RoutineStep(
  name: 'New step',
  kind: StepKind.rest,
  minutes: 15,
);

String _hm(int m) => hmText(Duration(minutes: m));

/// −/+ step: coarser for longer steps (mockup: 5 / 15 / 60 min). Minus uses
/// the size below the value so plus then minus lands back where it started.
int _stepFor(int m) => m >= 120
    ? 60
    : m >= 30
    ? 15
    : 5;

/// Routine editor: mockups/Routine.dc.html, PRD §4.7.
class RoutineScreen extends ConsumerWidget {
  const RoutineScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final t = context.text;
    final s = ref.watch(routineProvider);
    final n = ref.read(routineProvider.notifier);
    final plan = ref.watch(recipeProvider.select((i) => i.activePlan));
    final steps = s.current.steps;
    return Scaffold(
      body: Column(
        children: [
          ScreenHeader(
            title: 'Routine',
            backLabel: 'Timers',
            // One TalkBack stop, label first.
            trailing: Semantics(
              label:
                  'Hands-on and rests ${_hm(routineTotal(steps, plan).inMinutes)}',
              excludeSemantics: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  TweenNumber(
                    value: routineTotal(steps, plan).inMinutes.toDouble(),
                    format: (v) => _hm(v.round()),
                    style: t.number.copyWith(color: c.emberBright),
                  ),
                  const SectionLabel('hands-on + rests'),
                ],
              ),
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: s.presets.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, i) => PizzaChip(
                label: s.presets[i].name,
                selected: i == s.selected,
                secondary: true,
                // Re-tapping the selection must not drop a working copy.
                onTap: () => i == s.selected ? null : n.select(i),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
              children: [
                PizzaCard(
                  padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final (i, step) in steps.indexed) ...[
                        if (i > 0) Divider(height: 1, color: c.line),
                        _StepTile(
                          index: i,
                          step: step,
                          count: steps.length,
                          plan: plan,
                        ),
                      ],
                      const SizedBox(height: 10),
                      SecondaryButton(
                        label: 'Add step',
                        icon: Icons.add,
                        onPressed: () => n.addStep(_newStep),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                SecondaryButton(
                  label: 'Reset to default routine',
                  onPressed: s.selected == 0 && !s.dirty
                      ? null
                      : () {
                          unawaited(n.resetToDefault());
                          showPizzaToast(context, 'Default routine restored');
                        },
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: PrimaryButton(
                label: 'Save as preset',
                icon: Icons.bookmark_add_outlined,
                onPressed: () => _save(context, ref),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _save(BuildContext context, WidgetRef ref) async {
    final v = await _ask(context, 'Save as preset', 'Save preset', [
      ('Preset name', '', 'e.g. Same-day NY'),
    ]);
    if (v == null || !context.mounted) return;
    unawaited(ref.read(routineProvider.notifier).saveAsPreset(v.single));
    final name = ref.read(routineProvider).current.name;
    showPizzaToast(context, 'Preset "$name" saved');
  }
}

class _StepTile extends ConsumerWidget {
  const _StepTile({
    required this.index,
    required this.step,
    required this.count,
    required this.plan,
  });

  final int index;
  final RoutineStep step;
  final int count;
  final List<Stage> plan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final t = context.text;
    final n = ref.read(routineProvider.notifier);
    final rest = step.kind == StepKind.rest;
    final bound = step.bindsToPlan;
    final m = step.minutes;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Toggle rest or hands-on',
                style: IconButton.styleFrom(
                  backgroundColor: rest ? c.emberTint : c.surfaceRaised,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () => n.editStep(
                  index,
                  step.copyWith(kind: rest ? StepKind.active : StepKind.rest),
                ),
                icon: Icon(
                  rest ? Icons.schedule : Icons.back_hand_outlined,
                  size: 18,
                  color: rest ? c.emberBright : c.wheat,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Semantics(
                  button: true,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _edit(context, ref),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 44),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            step.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: t.bodyStrong.copyWith(fontSize: 14),
                          ),
                          Text(
                            bound
                                ? 'From the ferment plan'
                                : rest
                                ? 'Covered rest · auto'
                                : 'Hands on · tap when done',
                            style: t.caption,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Remove step',
                color: c.inkMuted,
                onPressed: count > 1 ? () => n.removeStep(index) : null,
                icon: const Icon(Icons.close, size: 18),
              ),
            ],
          ),
          ValueStepper(
            label: 'Time',
            value: _hm(stepDuration(step, plan).inMinutes),
            canMinus: !bound && m > 1,
            canPlus: !bound,
            onMinus: () => n.setMinutes(index, m - _stepFor(m - 1)),
            onPlus: () => n.setMinutes(index, m + _stepFor(m)),
            leading: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Move up',
                  color: c.inkMuted,
                  onPressed: index > 0
                      ? () => n.moveStep(index, index - 1)
                      : null,
                  icon: const Icon(Icons.arrow_upward, size: 18),
                ),
                IconButton(
                  tooltip: 'Move down',
                  color: c.inkMuted,
                  onPressed: index < count - 1
                      ? () => n.moveStep(index, index + 1)
                      : null,
                  icon: const Icon(Icons.arrow_downward, size: 18),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _edit(BuildContext context, WidgetRef ref) async {
    final v = await _ask(context, 'Edit step', 'Save step', [
      ('Name', step.name, null),
      ('Note', step.note, 'Shown on the timer'),
    ]);
    if (v == null || !context.mounted) return;
    final name = v[0].trim();
    unawaited(
      ref
          .read(routineProvider.notifier)
          .editStep(
            index,
            step.copyWith(
              name: name.isEmpty ? step.name : name,
              note: v[1].trim(),
            ),
          ),
    );
  }
}

/// Bottom sheet of (label, value, hint) text fields; returns the values, or
/// null when dismissed.
Future<List<String>?> _ask(
  BuildContext context,
  String title,
  String action,
  List<(String, String, String?)> fields,
) => showModalBottomSheet<List<String>>(
  context: context,
  isScrollControlled: true,
  backgroundColor: context.colors.surfaceSheet,
  barrierColor: context.colors.scrim,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
  ),
  builder: (_) => _TextSheet(title: title, action: action, fields: fields),
);

class _TextSheet extends StatefulWidget {
  const _TextSheet({
    required this.title,
    required this.action,
    required this.fields,
  });

  final String title, action;
  final List<(String, String, String?)> fields;

  @override
  State<_TextSheet> createState() => _TextSheetState();
}

class _TextSheetState extends State<_TextSheet> {
  late final _controllers = [
    for (final (_, value, _) in widget.fields)
      TextEditingController(text: value),
  ];

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    OutlineInputBorder border(Color color) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: color),
    );
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        24,
        20,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.title, style: t.h2),
          for (final (i, (label, _, hint)) in widget.fields.indexed) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _controllers[i],
              autofocus: i == 0,
              textCapitalization: TextCapitalization.sentences,
              style: t.body,
              decoration: InputDecoration(
                labelText: label,
                hintText: hint,
                filled: true,
                fillColor: c.ground,
                enabledBorder: border(c.lineStrong),
                focusedBorder: border(c.ember),
              ),
            ),
          ],
          const SizedBox(height: 16),
          PrimaryButton(
            label: widget.action,
            onPressed: () => Navigator.pop(context, [
              for (final ctl in _controllers) ctl.text,
            ]),
          ),
        ],
      ),
    );
  }
}
