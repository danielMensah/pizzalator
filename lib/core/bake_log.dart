// Pure Dart. No Flutter imports. Bake log entries: spec/PRD.md §5,
// mockups/BakeLog.dc.html and LogEntry.dc.html.
import 'calc.dart';
import 'oven.dart';
import 'recipe_json.dart';

/// "How did it go": three options each, the middle one by default.
enum Outcome {
  dough(
    'Dough felt',
    ['too wet', 'right', 'too dry'],
    ['too wet', 'dough right', 'too dry'],
  ),
  proof(
    'Proof',
    ['under', 'right', 'over'],
    ['under-proofed', 'proof right', 'over-proofed'],
  ),
  crust(
    'Crust colour',
    ['pale', 'right', 'burnt'],
    ['pale', 'crust right', 'burnt'],
  ),
  crumb(
    'Crumb',
    ['dense', 'right', 'open'],
    ['dense crumb', 'crumb right', 'open crumb'],
  ),
  bottom(
    'Bottom',
    ['soggy', 'right', 'burnt'],
    ['bottom soggy', 'bottom right', 'bottom burnt'],
  );

  const Outcome(this.label, this.options, this.tags);
  final String label;

  /// Segment names, and the bake log card's tag for each.
  final List<String> options, tags;

  static const right = 1;

  /// The middle option, and an open crumb.
  bool good(int choice) => choice == right || (this == crumb && choice == 2);
}

/// One bake, against a snapshot of the recipe and oven it used (PRD §5).
class BakeEntry {
  const BakeEntry({
    required this.id,
    required this.date,
    required this.name,
    this.recipeId,
    required this.inputs,
    required this.oven,
    this.rating = 0,
    this.outcomes = const {},
    this.roomC,
    this.fridgeH,
    this.ovenC,
    this.bakeMin,
    this.photo,
    this.notes = '',
  });

  /// Throws on a wrong shape; [parseBake] does not.
  factory BakeEntry.fromJson(Map<String, Object?> j) {
    final rating = (j['rating']! as num).toInt();
    final outcomes = {
      for (final MapEntry(:key, :value)
          in (j['outcomes']! as Map<String, Object?>).entries)
        Outcome.values.byName(key): (value! as num).toInt(),
    };
    if (rating < 0 ||
        rating > 5 ||
        outcomes.values.any((v) => v < 0 || v > 2)) {
      throw ArgumentError('Rating or outcome out of range');
    }
    double? opt(String key) => (j[key] as num?)?.toDouble();
    return BakeEntry(
      id: j['id']! as String,
      date: DateTime.parse(j['date']! as String),
      name: j['name']! as String,
      recipeId: j['recipeId'] as String?,
      inputs: inputsFromJson(j['inputs']! as Map<String, Object?>),
      oven: ovenFromJson(j['oven']! as Map<String, Object?>),
      rating: rating,
      outcomes: outcomes,
      roomC: opt('roomC'),
      fridgeH: opt('fridgeH'),
      ovenC: opt('ovenC'),
      bakeMin: opt('bakeMin'),
      photo: j['photo'] as String?,
      notes: j['notes']! as String,
    );
  }

  final String id, name;
  final DateTime date;

  /// The saved recipe it was baked from, if any.
  final String? recipeId;
  final RecipeInputs inputs;
  final OvenSetup oven;

  /// 0: not rated yet.
  final int rating;
  final Map<Outcome, int> outcomes;

  /// What actually happened; null when left blank.
  final double? roomC, fridgeH, ovenC, bakeMin;

  /// File name in the photo store.
  final String? photo;
  final String notes;

  int choice(Outcome o) => outcomes[o] ?? Outcome.right;

  /// The card's tags, three at most: bad ones first, then a notable good
  /// one (an open crumb), then the plain "right"s. True when good.
  List<(String, bool)> get tags {
    final all = [for (final o in Outcome.values) (o, choice(o))];
    return [
      for (final (o, v) in all)
        if (!o.good(v)) (o.tags[v], false),
      for (final (o, v) in all)
        if (o.good(v) && v != Outcome.right) (o.tags[v], true),
      for (final (o, v) in all)
        if (v == Outcome.right) (o.tags[v], true),
    ].take(3).toList();
  }

  Map<String, Object?> toJson() => {
    'id': id,
    // UTC, like saved recipes.
    'date': date.toUtc().toIso8601String(),
    'name': name,
    'recipeId': recipeId,
    'inputs': inputsToJson(inputs),
    'oven': ovenToJson(oven),
    'rating': rating,
    'outcomes': {for (final o in Outcome.values) o.name: choice(o)},
    'roomC': roomC,
    'fridgeH': fridgeH,
    'ovenC': ovenC,
    'bakeMin': bakeMin,
    'photo': photo,
    'notes': notes,
  };
}

/// Null for anything that is not an entry this build can read.
BakeEntry? parseBake(Object? json) {
  try {
    return BakeEntry.fromJson(json! as Map<String, Object?>);
  } on Error {
    return null; // wrong shape: older, newer or hand-edited
  } on FormatException {
    return null; // a date that is not one
  }
}
