import 'presets.dart';

/// One line of text the OCR read, with its box in image pixels.
class OcrLine {
  const OcrLine(this.text, this.left, this.top, this.right, this.bottom);
  final String text;
  final double left, top, right, bottom;

  double get _midY => (top + bottom) / 2;

  /// Horizontal position of [text] from [start] to [end], estimated from the
  /// character offsets.
  // ponytail: x from character offsets; ML Kit element boxes if columns mis-pick
  double _x(int start, int end) =>
      left + (right - left) * (start + end) / 2 / text.length;
}

/// What a nutrition panel gave: protein and fibre per 100 g, and the lines
/// they came from (to highlight on the photo). Not [confident] when a value
/// is missing or off the label range, or two columns disagree and no
/// "per 100 g" header says which one to trust (PRD §4.8).
class LabelReading {
  const LabelReading({
    this.proteinG,
    this.fibreG,
    this.confident = false,
    this.hits = const [],
  });

  final double? proteinG, fibreG;
  final bool confident;
  final List<OcrLine> hits;
}

final _protein = RegExp(
  r'prote[ií]n|prot[ée]ine|eiwei(?:ß|ss)',
  caseSensitive: false,
  unicode: true,
);
final _fibre = RegExp(
  r'fib(?:re|er|ra)|ballaststoffe',
  caseSensitive: false,
  unicode: true,
);
final _per100 = RegExp(r'100\s*g\b|per\s*100', caseSensitive: false);

/// A number, "<" allowed, not part of a word ("B3", "E330"); a trailing %
/// (reference intake) marks it as not a weight.
final _number = RegExp(
  r'(?<![\p{L}\d])(?:<\s*)?(\d+(?:[.,]\d+)?)\s*(%?)',
  unicode: true,
);

typedef _Candidate = ({double x, double g, OcrLine line});

/// Weights in [line] from [from] on, never the 100 of a "per 100 g".
Iterable<_Candidate> _numbers(OcrLine line, [int from = 0]) sync* {
  final per100 = _per100.allMatches(line.text).toList();
  for (final m in _number.allMatches(line.text, from)) {
    if (m[2]!.isNotEmpty) continue;
    if (per100.any((h) => m.start < h.end && h.start < m.end)) continue;
    yield (
      x: line._x(m.start, m.end),
      g: double.parse(m[1]!.replaceAll(',', '.')),
      line: line,
    );
  }
}

typedef _Row = ({double g, bool disagree, Set<OcrLine> hits});

/// Reads protein and fibre off OCR'd lines. For each row the candidates are
/// the numbers after the keyword on its line, then numbers in lines level
/// with it (vertical centre inside its span) further right, ordered by x.
/// The column is the candidate nearest a "100 g" header, else the left-most.
/// The first row in the label range wins, else the first row.
// ponytail: first in-range row, so a front-of-bag "13g per 100g" claim above
// the panel beats its "13.7g" row; rank rows by panel shape if claims mislead
LabelReading readLabel(List<OcrLine> lines) {
  final header = [
    for (final l in lines)
      if (_per100.firstMatch(l.text) case final m?) l._x(m.start, m.end),
  ].firstOrNull;

  Iterable<_Row> rows(RegExp keyword) sync* {
    for (final l in lines) {
      final m = keyword.firstMatch(l.text);
      if (m == null) continue;
      final found = [
        ..._numbers(l, m.end),
        for (final o in lines)
          if (o != l &&
              o._midY >= l.top &&
              o._midY <= l.bottom &&
              (o.left + o.right) / 2 > l.right)
            ..._numbers(o),
      ]..sort((a, b) => a.x.compareTo(b.x));
      if (found.isEmpty) continue;
      final pick = header == null
          ? found.first
          : found.reduce(
              (a, b) => (a.x - header).abs() <= (b.x - header).abs() ? a : b,
            );
      yield (
        g: pick.g,
        disagree: header == null && found.any((c) => c.g != pick.g),
        hits: {l, pick.line},
      );
    }
  }

  _Row? read(RegExp keyword, (double, double) range) {
    final all = rows(keyword);
    return all.where((r) => inLabelRange(r.g, range)).firstOrNull ??
        all.firstOrNull;
  }

  final protein = read(_protein, kProteinRangeG);
  final fibre = read(_fibre, kFibreRangeG);
  return LabelReading(
    proteinG: protein?.g,
    fibreG: fibre?.g,
    confident:
        protein?.disagree == false &&
        fibre?.disagree == false &&
        inLabelRange(protein?.g, kProteinRangeG) &&
        inLabelRange(fibre?.g, kFibreRangeG),
    hits: [...?protein?.hits, ...?fibre?.hits],
  );
}
