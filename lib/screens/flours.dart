import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../core/calc.dart';
import '../core/label_scan.dart';
import '../services/label_scanner.dart';
import '../state/flours.dart';
import '../theme/pizza_theme.dart';
import '../widgets/widgets.dart';

/// Settings › Flours: the user's own flours and the presets to copy from.
/// Layout and copy: mockups/Flours.dc.html, FR12, PRD §4.3.
class FloursScreen extends ConsumerStatefulWidget {
  const FloursScreen({super.key});

  @override
  ConsumerState<FloursScreen> createState() => _FloursScreenState();
}

class _FloursScreenState extends ConsumerState<FloursScreen> {
  /// A scan is running (camera open or OCR): a second tap would open a
  /// second camera, or image_picker's "already active" error.
  var _scanning = false;

  void _open({
    Flour? from,
    int? index,
    bool scanned = false,
    LabelScan? scan,
  }) => unawaited(
    showPizzaSheet<void>(
      context,
      (_) =>
          _FlourSheet(from: from, index: index, scanned: scanned, scan: scan),
    ),
  );

  /// A failed scan opens the same sheet, empty, to type by hand (PRD §4.8).
  Future<void> _scanBag(ImageSource source) async {
    if (_scanning) return;
    setState(() => _scanning = true);
    LabelScan? photo;
    try {
      photo = await ref.read(labelScannerProvider).scan(source);
      if (photo == null) return; // backed out of the camera
    } on Exception catch (e) {
      debugPrint('label scan: $e');
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
    if (mounted) _open(scanned: true, scan: photo);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.text;
    final c = context.colors;
    final mine = ref.watch(customFloursProvider);

    return Scaffold(
      body: Column(
        children: [
          ScreenHeader(
            backLabel: 'Calculator',
            eyebrow: 'Settings',
            eyebrowColor: c.inkMuted,
            title: 'Flours',
            trailing: SectionLabel(
              '${mine.length + Flour.presets.length} flours',
            ),
          ),
          Expanded(
            child: ListView(
              // Edge to edge: the end clears the system navigation bar.
              padding: EdgeInsets.fromLTRB(
                20,
                4,
                20,
                24 + MediaQuery.paddingOf(context).bottom,
              ),
              children: [
                // Both 48 px, as in the mockup: not the screen's bottom CTA.
                SizedBox(
                  height: 48,
                  child: Row(
                    spacing: 10,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: PrimaryButton(
                          label: 'Scan a bag',
                          icon: Icons.photo_camera_outlined,
                          compact: true,
                          onPressed: _scanning
                              ? null
                              : () => unawaited(_scanBag(ImageSource.camera)),
                        ),
                      ),
                      Expanded(
                        child: SecondaryButton(
                          label: 'Add by hand',
                          icon: Icons.add,
                          onPressed: _open,
                        ),
                      ),
                    ],
                  ),
                ),
                Center(
                  child: TextLink(
                    label: 'Read a photo from the gallery',
                    onTap: () => unawaited(_scanBag(ImageSource.gallery)),
                  ),
                ),
                const SizedBox(height: 4),
                _FlourList(
                  title: 'My flours',
                  flours: mine,
                  mine: true,
                  onTap: (i) => _open(from: mine[i], index: i),
                  empty:
                      'None yet. Add one by hand, or tap a preset to '
                      'start from it.',
                ),
                const SizedBox(height: 14),
                _FlourList(
                  title: 'Presets · tap to duplicate and edit',
                  flours: Flour.presets,
                  mine: false,
                  onTap: (i) => _open(from: Flour.presets[i]),
                  delay: const Duration(milliseconds: 60),
                ),
                const SizedBox(height: 14),
                Text(
                  'Protein per 100 g is the label number that matters: it '
                  'sets absorption and chew. Fibre tells wholegrain apart '
                  '(white ≈ 3 g, wholemeal 7–11 g). Bags never print W '
                  'strength.',
                  style: t.captionRegular.copyWith(height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FlourList extends StatelessWidget {
  const _FlourList({
    required this.title,
    required this.flours,
    required this.mine,
    required this.onTap,
    this.empty = '',
    this.delay = Duration.zero,
  });

  final String title;
  final List<Flour> flours;
  final bool mine;
  final ValueChanged<int> onTap;
  final String empty;
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return PizzaCard(
      delay: delay,
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 32,
            child: Align(
              alignment: Alignment.centerLeft,
              child: SectionLabel(title),
            ),
          ),
          if (flours.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                spacing: 10,
                children: [
                  const PizzaMark(size: 56),
                  Text(
                    empty,
                    textAlign: TextAlign.center,
                    style: context.text.captionRegular,
                  ),
                ],
              ),
            ),
          for (final (i, f) in flours.indexed) ...[
            if (i > 0) Divider(height: 1, color: c.line),
            _FlourRow(flour: f, mine: mine, onTap: () => onTap(i)),
          ],
        ],
      ),
    );
  }
}

/// Name and sub-line, a type pill, protein. 56 px tall at least.
class _FlourRow extends StatelessWidget {
  const _FlourRow({
    required this.flour,
    required this.mine,
    required this.onTap,
  });

  final Flour flour;
  final bool mine;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final f = flour;
    final sub = [
      if (f.note.isNotEmpty) f.note,
      if (f.fibrePct case final g?) 'fibre ${pctText(g)} g',
    ].join(' · ');
    final (pill, fill, ink) = f.wholegrain
        ? ('wholemeal', c.emberTint, c.emberBright)
        : mine
        ? ('mine', c.sageTint, c.sageBright)
        : ('white', c.surfaceRaised, c.inkSoft);
    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              spacing: 12,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: 2,
                    children: [
                      Text(
                        f.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.bodyStrong.copyWith(fontSize: 14),
                      ),
                      Text(
                        sub.isEmpty ? (mine ? 'custom' : 'preset') : sub,
                        style: t.captionRegular,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: fill,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    pill,
                    style: t.label.copyWith(letterSpacing: 0, color: ink),
                  ),
                ),
                Text('${pctText(f.proteinPct)}%', style: t.number),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// New, copied-from-preset, scanned or edited flour. Save writes it and
/// closes; editing one of mine also offers Delete.
class _FlourSheet extends ConsumerStatefulWidget {
  const _FlourSheet({this.from, this.index, this.scanned = false, this.scan});

  /// Prefill: the flour of mine being edited (with [index]) or a preset.
  final Flour? from;

  /// Position in my flours when editing; null adds a new one.
  final int? index;

  /// Opened by a label scan; [scan] is null when the scanner failed.
  final bool scanned;
  final LabelScan? scan;

  @override
  ConsumerState<_FlourSheet> createState() => _FlourSheetState();
}

class _FlourSheetState extends ConsumerState<_FlourSheet> {
  late final _read = switch (widget.scan) {
    final s? => readLabel(s.lines),
    null => const LabelReading(),
  };
  late final _protein = TextEditingController(
    text: _fmt(widget.from?.proteinPct ?? _read.proteinG),
  );
  late final _fibre = TextEditingController(
    text: _fmt(widget.from?.fibrePct ?? _read.fibreG),
  );
  late final _name = TextEditingController(text: widget.from?.name ?? '');
  late var _wholegrain =
      widget.from?.wholegrain ??
      switch (_fibreG) {
        final g? => wholegrainFromFibre(g),
        null => false,
      };

  /// Flipped by hand: fibre no longer sets the switch. A saved flour that
  /// disagrees with the fibre rule was flipped by hand.
  late var _byHand = switch (widget.from) {
    Flour(fibrePct: final g?, :final wholegrain) =>
      wholegrainFromFibre(g) != wholegrain,
    _ => false,
  };

  static String _fmt(double? v) => v == null ? '' : pctText(v);

  /// Accepts a decimal comma (EU labels and keyboards). Rounded to label
  /// precision, so what is saved is what the edit sheet shows again.
  static double? _parse(TextEditingController c) =>
      switch (double.tryParse(c.text.trim().replaceAll(',', '.'))) {
        final v? when v.isFinite => r01(v),
        _ => null,
      };

  /// Fibre as typed, when it is a label value.
  double? get _fibreG {
    final g = _parse(_fibre);
    return inLabelRange(g, kFibreRangeG) ? g : null;
  }

  /// Another flour's name, case aside. Names tell flours apart in the
  /// picker, and an unchanged preset copy would hide behind its preset.
  bool get _nameTaken {
    final name = _name.text.trim().toLowerCase();
    return [
      ...Flour.presets,
      for (final (j, f) in ref.watch(customFloursProvider).indexed)
        if (j != widget.index) f,
    ].any((f) => f.name.toLowerCase() == name);
  }

  /// What Save writes; null while a field is missing or off the label.
  Flour? get _flour {
    final name = _name.text.trim();
    final protein = _parse(_protein);
    final fibre = _fibreG;
    if (name.isEmpty || !inLabelRange(protein, kProteinRangeG)) return null;
    if (fibre == null && _fibre.text.trim().isNotEmpty) return null;
    return Flour(
      name,
      protein!,
      wholegrain: _wholegrain,
      fibrePct: fibre,
      // A preset's note describes the preset, not the copy.
      note: widget.index != null
          ? widget.from!.note
          : _read.proteinG != null || _read.fibreG != null
          ? 'scanned'
          : '',
    );
  }

  @override
  void dispose() {
    _protein.dispose();
    _fibre.dispose();
    _name.dispose();
    super.dispose();
  }

  void _save(Flour flour) {
    final n = ref.read(customFloursProvider.notifier);
    final i = widget.index;
    unawaited(i == null ? n.add(flour) : n.replace(i, flour));
    showPizzaToast(context, 'Saved to my flours');
    Navigator.pop(context);
  }

  void _delete(int i) {
    unawaited(ref.read(customFloursProvider.notifier).remove(i));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.text;
    final c = context.colors;
    final taken = _nameTaken;
    final flour = taken ? null : _flour;
    final fibre = _fibreG;
    final i = widget.index;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        28 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 12,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.scanned)
                      SectionLabel('On-device OCR', color: c.emberBright),
                    Text(
                      widget.scanned
                          ? _read.confident
                                ? 'Found the panel'
                                : 'Could not read the panel'
                          : i == null
                          ? 'New flour'
                          : 'Edit flour',
                      style: t.h2,
                    ),
                  ],
                ),
              ),
              SecondaryButton(
                label: 'Close',
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          if (widget.scan case final scan?)
            _ScanPhoto(scan: scan, hits: _read.hits),
          if (widget.scanned)
            Text(
              _read.confident
                  ? 'Protein and fibre read from the per-100 g column'
                  : 'Check these against the bag',
              style: t.captionRegular,
            ),
          Row(
            spacing: 10,
            children: [
              Expanded(
                child: LabelledField(
                  label: 'Protein',
                  controller: _protein,
                  unit: 'g',
                  found: _read.proteinG != null,
                  onChanged: (_) => setState(() {}),
                ),
              ),
              Expanded(
                child: LabelledField(
                  label: 'Fibre',
                  controller: _fibre,
                  unit: 'g',
                  found: _read.fibreG != null,
                  onChanged: (_) => setState(() {
                    final g = _fibreG;
                    if (!_byHand && g != null) {
                      _wholegrain = wholegrainFromFibre(g);
                    }
                  }),
                ),
              ),
            ],
          ),
          LabelledField(
            label: 'Name',
            controller: _name,
            hint: 'e.g. Sainsbury’s strong white',
            onChanged: (_) => setState(() {}),
          ),
          if (taken)
            Text(
              'Another flour has this name',
              style: t.captionRegular.copyWith(color: c.alert),
            ),
          SwitchListTile(
            value: _wholegrain,
            onChanged: (v) => setState(() {
              _wholegrain = v;
              _byHand = true;
            }),
            contentPadding: EdgeInsets.zero,
            activeTrackColor: c.ember,
            thumbColor: WidgetStatePropertyAll(c.ink),
            inactiveTrackColor: c.surfaceRaised,
            trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
            title: Text(
              'Wholegrain',
              style: t.bodyStrong.copyWith(fontSize: 14),
            ),
            subtitle: Text(
              _byHand
                  ? 'Set by hand'
                  : fibre == null
                  ? 'Auto-set from fibre ≥ ${pctText(kWholegrainFibreG)} g'
                  : 'Fibre ${pctText(fibre)} g → '
                        '${wholegrainFromFibre(fibre) ? 'wholegrain' : 'white flour'}',
              style: t.captionRegular,
            ),
          ),
          PrimaryButton(
            label: 'Save flour',
            onPressed: flour == null ? null : () => _save(flour),
          ),
          if (i != null)
            SecondaryButton(
              label: 'Delete flour',
              alert: true,
              onPressed: () => _delete(i),
            ),
        ],
      ),
    );
  }
}

/// The scanned photo, contained in 220 px, the lines the values came from
/// boxed in sage (mockups/Flours.dc.html). Decorative: the values are in the
/// fields below.
class _ScanPhoto extends StatelessWidget {
  const _ScanPhoto({required this.scan, required this.hits});

  final LabelScan scan;
  final List<OcrLine> hits;

  static const _height = 220.0;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final size = scan.size;
    return ExcludeSemantics(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: ColoredBox(
          color: c.ground,
          child: SizedBox(
            height: _height,
            child: LayoutBuilder(
              builder: (context, box) {
                final s = min(box.maxWidth / size.width, _height / size.height);
                return Center(
                  child: SizedBox(
                    width: size.width * s,
                    height: size.height * s,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.file(
                          File(scan.imagePath),
                          fit: BoxFit.fill,
                          // Decode no bigger than shown: camera photos are
                          // 12 MP and up.
                          cacheHeight:
                              (_height * MediaQuery.devicePixelRatioOf(context))
                                  .round(),
                        ),
                        for (final h in hits)
                          Positioned(
                            left: h.left * s,
                            top: h.top * s,
                            width: (h.right - h.left) * s,
                            height: (h.bottom - h.top) * s,
                            child: DecoratedBox(
                              key: const ValueKey('hit'),
                              decoration: BoxDecoration(
                                color: c.sage.withValues(alpha: 0.18),
                                border: Border.all(color: c.sage, width: 2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
