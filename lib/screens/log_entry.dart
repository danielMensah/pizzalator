import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../core/bake_log.dart';
import '../core/calc.dart';
import '../core/export_text.dart';
import '../services/photos.dart';
import '../state/bake_log.dart';
import '../theme/pizza_theme.dart';
import '../widgets/widgets.dart';

const _ratingText = [
  'Tap a star',
  'Bin it',
  'Edible',
  'Decent',
  'Good',
  'Best yet',
];

const _gap = SizedBox(height: 12);

/// Log a bake, or edit one: mockups/LogEntry.dc.html, PRD §5. A new bake
/// is of the working copy; [id] edits a logged one.
class LogEntryScreen extends ConsumerStatefulWidget {
  const LogEntryScreen({super.key, this.id});

  final String? id;

  @override
  ConsumerState<LogEntryScreen> createState() => _LogEntryScreenState();
}

class _LogEntryScreenState extends ConsumerState<LogEntryScreen> {
  /// The logged bake being edited; null logs a new one.
  late final _logged = ref
      .read(bakeLogProvider)
      .where((e) => e.id == widget.id)
      .firstOrNull;
  late final _entry = _logged ?? ref.read(bakeLogProvider.notifier).draft();
  late var _rating = _entry.rating;
  late final _outcomes = {for (final o in Outcome.values) o: _entry.choice(o)};
  late var _photo = _entry.photo;
  late final _room = _number(_entry.roomC);
  late final _fridge = _number(_entry.fridgeH);
  late final _oven = _number(_entry.ovenC);
  late final _bake = _number(_entry.bakeMin);
  late final _notes = TextEditingController(text: _entry.notes);

  /// Saved: a photo picked here now belongs to the log.
  var _saved = false;

  static TextEditingController _number(double? v) =>
      TextEditingController(text: v == null ? '' : pctText(v));

  /// Accepts a decimal comma; blank or not a number is null.
  static double? _parse(TextEditingController c) =>
      switch (double.tryParse(c.text.trim().replaceAll(',', '.'))) {
        final v? when v.isFinite => v,
        _ => null,
      };

  /// Kept, not read again: dispose may need it, and ref is gone by then.
  /// Read first by a pick or a photo shown, always before dispose needs it.
  late final PhotoStore _photos = ref.read(photoStoreProvider);

  /// A photo picked here and not kept goes, so none is left behind.
  void _dropPicked() {
    if (_photo case final p? when p != _entry.photo) {
      unawaited(_photos.delete(p));
    }
  }

  @override
  void dispose() {
    if (!_saved) _dropPicked();
    for (final c in [_room, _fridge, _oven, _bake, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final e = _entry;
    final hydration = pctText(calc(e.inputs).hydrationPct);
    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ScreenHeader(
            backLabel: 'Bake log',
            title: _logged == null ? 'Log this bake' : 'Edit bake',
            subtitle:
                '${e.name} · ${dayText(e.date.toLocal())} · $hydration% · '
                '${e.oven.name.toLowerCase()}',
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
              children: [
                _ratingCard(),
                _gap,
                _outcomesCard(),
                _gap,
                _actualsCard(),
                _gap,
                _photoCard(),
                if (_logged != null) ...[
                  _gap,
                  SecondaryButton(
                    label: 'Delete bake',
                    icon: Icons.delete_outline,
                    alert: true,
                    onPressed: () => unawaited(_delete()),
                  ),
                ],
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: PrimaryButton(label: 'Save bake', onPressed: _save),
            ),
          ),
        ],
      ),
    );
  }

  Widget _ratingCard() {
    final c = context.colors;
    return PizzaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 6,
        children: [
          Row(
            children: [
              const Expanded(child: SectionLabel('Rating')),
              Text(
                _ratingText[_rating],
                style: context.text.bodySm.copyWith(color: c.inkSoft),
              ),
            ],
          ),
          // The first star's glyph lines up with the label.
          Transform.translate(
            offset: const Offset(-7, 0),
            child: Row(
              spacing: 2,
              children: [
                for (var n = 1; n <= 5; n++)
                  IconButton(
                    tooltip: '$n star${n > 1 ? 's' : ''}',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: 44,
                      height: 44,
                    ),
                    onPressed: () => setState(() => _rating = n),
                    icon: Icon(
                      n <= _rating
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      size: 30,
                      color: n <= _rating ? c.emberBright : c.lineStrong,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _outcomesCard() {
    final c = context.colors;
    final t = context.text;
    return PizzaCard(
      delay: const Duration(milliseconds: 60),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 10,
        children: [
          const SectionLabel('How did it go'),
          for (final o in Outcome.values)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 6,
              children: [
                Text(o.label, style: t.bodySm.copyWith(color: c.inkSoft)),
                Segmented<int>(
                  key: ValueKey(o),
                  options: [
                    for (final (i, name) in o.options.indexed) (i, name),
                  ],
                  value: _outcomes[o]!,
                  onChanged: (v) => setState(() => _outcomes[o] = v),
                  selectedFill: o.good(_outcomes[o]!)
                      ? c.sageTint
                      : c.alertTint,
                  selectedInk: o.good(_outcomes[o]!) ? c.sageBright : c.alert,
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _actualsCard() {
    Widget field(String label, TextEditingController ctl, String unit) =>
        Expanded(
          child: LabelledField(
            label: label,
            controller: ctl,
            unit: unit,
            labelWidth: 48,
          ),
        );
    return PizzaCard(
      delay: const Duration(milliseconds: 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 10,
        children: [
          const SectionLabel('What actually happened'),
          Row(
            spacing: 10,
            children: [
              field('Room', _room, '°C'),
              field('Fridge', _fridge, 'h'),
            ],
          ),
          Row(
            spacing: 10,
            children: [field('Oven', _oven, '°C'), field('Bake', _bake, 'min')],
          ),
        ],
      ),
    );
  }

  Widget _photoCard() {
    final c = context.colors;
    final t = context.text;
    final photo = _photo;
    return PizzaCard(
      delay: const Duration(milliseconds: 180),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 10,
        children: [
          Semantics(
            button: true,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => unawaited(_pickPhoto()),
              child: Container(
                height: 96,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: photo == null ? c.lineStrong : c.emberLine,
                    width: 1.5,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (photo != null) ...[
                      Image.file(
                        _photos.file(photo),
                        fit: BoxFit.cover,
                        cacheWidth:
                            (400 * MediaQuery.devicePixelRatioOf(context))
                                .round(),
                        errorBuilder: (_, _, _) => const SizedBox(),
                      ),
                      // Keeps the label readable over the photo.
                      ColoredBox(color: c.ground.withValues(alpha: 0.55)),
                    ],
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      spacing: 8,
                      children: [
                        Icon(
                          Icons.photo_camera_outlined,
                          size: 20,
                          color: photo == null ? c.inkMuted : c.ink,
                        ),
                        Text(
                          photo == null
                              ? 'Add photo'
                              : 'Photo added · tap to replace',
                          style: t.buttonMd.copyWith(
                            fontSize: 13,
                            color: photo == null ? c.inkMuted : c.ink,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SectionLabel('Notes'),
          TextField(
            key: const ValueKey('notes'),
            controller: _notes,
            minLines: 3,
            maxLines: 8,
            textCapitalization: TextCapitalization.sentences,
            style: t.body.copyWith(fontSize: 14),
            cursorColor: c.ember,
            decoration: pizzaInput(
              context,
              hint:
                  'Rim blistered well, centre a touch floppy. '
                  'Try 61.5% next time.',
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickPhoto() async {
    final source = await showPizzaSheet<ImageSource>(
      context,
      (sheet) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 10,
          children: [
            Text(
              _photo == null ? 'Add photo' : 'Replace photo',
              style: sheet.text.h2,
            ),
            SecondaryButton(
              label: 'Camera',
              icon: Icons.photo_camera_outlined,
              onPressed: () => Navigator.pop(sheet, ImageSource.camera),
            ),
            SecondaryButton(
              label: 'Gallery',
              icon: Icons.photo_library_outlined,
              onPressed: () => Navigator.pop(sheet, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;
    final String? name;
    try {
      name = await _photos.pick(source);
    } on Exception catch (e) {
      debugPrint('photo: $e'); // camera refused, say
      if (mounted) showPizzaToast(context, 'Could not add the photo');
      return;
    }
    if (name == null || !mounted) return;
    _dropPicked();
    setState(() => _photo = name);
  }

  void _save() {
    final e = _entry;
    final entry = BakeEntry(
      id: e.id,
      date: e.date,
      name: e.name,
      recipeId: e.recipeId,
      inputs: e.inputs,
      oven: e.oven,
      rating: _rating,
      outcomes: Map.of(_outcomes),
      roomC: _parse(_room),
      fridgeH: _parse(_fridge),
      ovenC: _parse(_oven),
      bakeMin: _parse(_bake),
      photo: _photo,
      notes: _notes.text.trim(),
    );
    final log = ref.read(bakeLogProvider.notifier);
    unawaited(_logged == null ? log.add(entry) : log.update(entry));
    _saved = true;
    showPizzaToast(context, 'Saved · calibration will update after 2 logs');
    Navigator.pop(context);
  }

  Future<void> _delete() async {
    final sure = await showPizzaSheet<bool>(
      context,
      (sheet) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 10,
          children: [
            Text('Delete this bake?', style: sheet.text.h2),
            Text(
              'Its photo and notes go too.',
              style: sheet.text.captionRegular,
            ),
            SecondaryButton(
              label: 'Delete',
              icon: Icons.delete_outline,
              alert: true,
              onPressed: () => Navigator.pop(sheet, true),
            ),
            SecondaryButton(
              label: 'Keep it',
              onPressed: () => Navigator.pop(sheet, false),
            ),
          ],
        ),
      ),
    );
    if (sure != true || !mounted) return;
    unawaited(ref.read(bakeLogProvider.notifier).delete(_entry.id));
    Navigator.pop(context);
  }
}
