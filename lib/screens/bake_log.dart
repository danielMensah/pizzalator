import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/bake_log.dart';
import '../core/calc.dart';
import '../core/calibration.dart';
import '../core/export_text.dart';
import '../routes.dart';
import '../services/photos.dart';
import '../state/bake_log.dart';
import '../state/calibration.dart';
import '../state/oven.dart';
import '../state/recipe.dart';
import '../theme/pizza_theme.dart';
import '../widgets/widgets.dart';

String _count(int n) => '$n ${n == 1 ? 'bake' : 'bakes'}';

/// Logged bakes, newest first, filtered by style: mockups/BakeLog.dc.html,
/// PRD §5.
class BakeLogScreen extends ConsumerStatefulWidget {
  const BakeLogScreen({super.key});

  @override
  ConsumerState<BakeLogScreen> createState() => _BakeLogScreenState();
}

class _BakeLogScreenState extends ConsumerState<BakeLogScreen> {
  /// Null: All.
  PizzaStyle? _filter;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final log = ref.watch(bakeLogProvider);
    final styles = [
      for (final s in PizzaStyle.values)
        if (log.any((e) => e.inputs.style == s)) s,
    ];
    // A style whose last bake went falls back to All.
    final filter = styles.contains(_filter) ? _filter : null;
    final style = ref.watch(recipeProvider.select((i) => i.style));
    final shown = [
      for (final e in log)
        if (filter == null || e.inputs.style == filter) e,
    ];
    return Scaffold(
      floatingActionButton: SizedBox.square(
        dimension: 60,
        child: FloatingActionButton(
          tooltip: 'Log a bake',
          backgroundColor: c.ember,
          foregroundColor: c.onEmber,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          onPressed: () =>
              unawaited(Navigator.pushNamed(context, Routes.logEntry)),
          child: const Icon(Icons.add, size: 26),
        ),
      ),
      body: Column(
        children: [
          ScreenHeader(
            // Always straight over the calculator: see RecipeScreen._logBake.
            backLabel: 'Calculator',
            title: 'Bake log',
            trailing: SectionLabel(_count(shown.length)),
          ),
          if (log.isNotEmpty)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
              child: Row(
                spacing: 8,
                children: [
                  for (final s in [null, ...styles])
                    PizzaChip(
                      label: s?.label ?? 'All',
                      selected: s == filter,
                      secondary: true,
                      onTap: () => setState(() => _filter = s),
                    ),
                ],
              ),
            ),
          Expanded(
            child: ListView(
              // Clears the + button.
              padding: EdgeInsets.fromLTRB(
                20,
                4,
                20,
                110 + MediaQuery.paddingOf(context).bottom,
              ),
              children: [
                // Hints are for the working copy: All or its style.
                if (filter == null || filter == style) const CalibrationHints(),
                if (log.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 32),
                    child: Column(
                      spacing: 10,
                      children: [
                        const PizzaMark(size: 56),
                        Text(
                          'No bakes logged yet. After a bake, tap + to note '
                          'how it went: the next one gets better.',
                          textAlign: TextAlign.center,
                          style: context.text.captionRegular,
                        ),
                      ],
                    ),
                  ),
                for (final (i, e) in shown.indexed)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _BakeCard(index: i, entry: e),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Photo, name and date, stars, up to three tags; tap to edit.
class _BakeCard extends StatelessWidget {
  const _BakeCard({required this.index, required this.entry});

  final int index;
  final BakeEntry entry;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final e = entry;
    return PizzaCard(
      delay: Duration(milliseconds: 60 * index.clamp(0, 5)),
      padding: const EdgeInsets.all(14),
      child: Semantics(
        button: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => unawaited(
            Navigator.pushNamed(context, Routes.logEntry, arguments: e.id),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 12,
            children: [
              _Thumb(e.photo),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 6,
                  children: [
                    Row(
                      spacing: 8,
                      children: [
                        Expanded(
                          child: Text(
                            e.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: t.bodyStrong,
                          ),
                        ),
                        Text(
                          dayText(e.date.toLocal()),
                          style: t.captionRegular,
                        ),
                      ],
                    ),
                    Semantics(
                      label: '${e.rating} of 5 stars',
                      child: Row(
                        spacing: 2,
                        children: [
                          for (var n = 1; n <= 5; n++)
                            Icon(
                              Icons.star_rounded,
                              size: 14,
                              color: n <= e.rating
                                  ? c.emberBright
                                  : c.lineStrong,
                            ),
                        ],
                      ),
                    ),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final (text, good) in e.tags)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: good ? c.sageTint : c.alertTint,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              text,
                              style: t.label.copyWith(
                                letterSpacing: 0,
                                fontWeight: FontWeight.w500,
                                color: good ? c.sageBright : c.alert,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 72 px, the bake's photo or a warm crust gradient. Decorative.
class _Thumb extends ConsumerWidget {
  const _Thumb(this.photo);

  final String? photo;

  static const _size = 72.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final warm = DecoratedBox(
      key: const ValueKey('no photo'),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [c.emberTint, c.emberLine, c.emberTint],
        ),
      ),
    );
    return ExcludeSemantics(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: SizedBox.square(
          dimension: _size,
          child: switch (photo) {
            null => warm,
            final name => Image.file(
              ref.watch(photoStoreProvider).file(name),
              fit: BoxFit.cover,
              cacheWidth: (_size * MediaQuery.devicePixelRatioOf(context))
                  .round(),
              // Gone from the folder: the placeholder, not a broken icon.
              errorBuilder: (_, _, _) => warm,
            ),
          },
        ),
      ),
    );
  }
}

/// The working copy's calibration hints (PRD §5), each 14 px above what
/// follows. Apply or Not now lands at the tap; the card then collapses
/// (450 ms, at once under reduced motion).
class CalibrationHints extends ConsumerStatefulWidget {
  const CalibrationHints({super.key});

  @override
  ConsumerState<CalibrationHints> createState() => _CalibrationHintsState();
}

class _CalibrationHintsState extends ConsumerState<CalibrationHints> {
  /// Tapped and collapsing: the provider has already dropped them.
  final _leaving = <CalibrationHint>[];

  void _act(CalibrationHint h, {required bool apply}) {
    if (apply) {
      if (h.apply case final f?) ref.read(recipeProvider.notifier).update(f);
      if (h.applyOven case final f?) {
        ref.read(ovenProvider.notifier).set(f(ref.read(ovenProvider)));
      }
      showPizzaToast(context, h.done);
    } else {
      unawaited(ref.read(hintDismissalsProvider.notifier).dismiss(h.id));
    }
    if (!reduceMotion(context)) setState(() => _leaving.add(h));
  }

  @override
  Widget build(BuildContext context) {
    final live = ref.watch(calibrationHintsProvider);
    final hints = [
      ..._leaving,
      for (final h in live)
        if (!_leaving.any((l) => l.id == h.id)) h,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final h in hints)
          _HintCard(
            key: ValueKey(h.id),
            hint: h,
            leaving: _leaving.contains(h),
            onApply: () => _act(h, apply: true),
            onDismiss: () => _act(h, apply: false),
            onGone: () => setState(() => _leaving.remove(h)),
          ),
      ],
    );
  }
}

/// Sage card: sparkle, label, text, "Apply …" and "Not now"
/// (mockups/BakeLog.dc.html). [leaving] folds it away, taps off.
class _HintCard extends StatelessWidget {
  const _HintCard({
    super.key,
    required this.hint,
    required this.leaving,
    required this.onApply,
    required this.onDismiss,
    required this.onGone,
  });

  final CalibrationHint hint;
  final bool leaving;
  final VoidCallback onApply, onDismiss, onGone;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final card = Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: PizzaCard(
        variant: PizzaCardVariant.hint,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 10,
          children: [
            Icon(Icons.auto_awesome_outlined, size: 20, color: c.sageBright),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionLabel(hint.title, color: c.sageBright),
                  Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 10),
                    child: Text(
                      hint.text,
                      style: context.text.bodySm.copyWith(color: c.ink),
                    ),
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      SecondaryButton(
                        label: hint.applyLabel,
                        success: true,
                        onPressed: onApply,
                      ),
                      SecondaryButton(label: 'Not now', onPressed: onDismiss),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    // Same tree either way, so the card does not rise in again as it goes.
    return IgnorePointer(
      ignoring: leaving,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 1, end: leaving ? 0 : 1),
        duration: const Duration(milliseconds: 450),
        curve: Curves.ease,
        onEnd: leaving ? onGone : null,
        builder: (_, v, child) => ClipRect(
          child: Align(
            alignment: Alignment.topCenter,
            heightFactor: v,
            child: Opacity(opacity: v, child: child),
          ),
        ),
        child: card,
      ),
    );
  }
}
