import 'package:flutter_test/flutter_test.dart';
import 'package:pizzalator/core/label_scan.dart';

/// A line ML Kit returned: text and its box in image pixels.
OcrLine l(String text, double left, double top, double right, double bottom) =>
    OcrLine(text, left, top, right, bottom);

/// One table row per entry, 40 px apart, one block per column: label at
/// x 20–200, then a column every 160 px (how ML Kit splits most panels).
List<OcrLine> table(List<List<String>> rows, {double y0 = 100}) => [
  for (final (r, row) in rows.indexed)
    for (final (col, text) in row.indexed)
      l(
        text,
        col == 0 ? 20 : 220 + (col - 1) * 160.0,
        y0 + r * 40,
        col == 0 ? 200 : 320 + (col - 1) * 160.0,
        y0 + r * 40 + 24,
      ),
];

void main() {
  test('UK two columns, per 100 g first: the per-100 g column', () {
    final lines = table([
      ['Typical values', 'Per 100g', 'Per 80g'],
      ['Energy', '1480kJ', '1184kJ'],
      ['Fat', '1.4g', '1.1g'],
      ['Carbohydrate', '68.5g', '54.8g'],
      ['Fibre', '3.1g', '2.5g'],
      ['Protein', '13.7g', '11.0g'],
      ['Salt', '0.01g', '<0.01g'],
    ]);
    final r = readLabel(lines);
    expect(r.proteinG, 13.7);
    expect(r.fibreG, 3.1);
    expect(r.confident, isTrue);
    expect(r.hits.map((h) => h.text), ['Protein', '13.7g', 'Fibre', '3.1g']);
  });

  test('per 80 g printed first: the 100 g header still wins', () {
    final lines = table([
      ['Typical values', 'Per 80g serving', 'Per 100g'],
      ['Fibre', '2.5g', '3.1g'],
      ['Protein', '11.0g', '13.7g'],
    ]);
    final r = readLabel(lines);
    expect(r.proteinG, 13.7);
    expect(r.fibreG, 3.1);
    expect(r.confident, isTrue);
  });

  test('a single line per row, value on the keyword line', () {
    final r = readLabel([
      l('NUTRITION · per 100 g', 20, 20, 300, 44),
      l('Fibre 3.1 g', 20, 100, 300, 124),
      l('Protein 13.7 g', 20, 140, 300, 164),
    ]);
    expect(r.proteinG, 13.7);
    expect(r.fibreG, 3.1);
    expect(r.confident, isTrue);
    expect(r.hits.map((h) => h.text), ['Protein 13.7 g', 'Fibre 3.1 g']);
  });

  test('German panel: decimal comma, Eiweiß, Ballaststoffe', () {
    final lines = table([
      ['Nährwerte', 'pro 100 g'],
      ['Ballaststoffe', '3,8 g'],
      ['Eiweiß', '12,5g'],
    ]);
    final r = readLabel(lines);
    expect(r.proteinG, 12.5);
    expect(r.fibreG, 3.8);
    expect(r.confident, isTrue);
    expect(readLabel([l('EIWEISS 11,9 g', 0, 0, 200, 20)]).proteinG, 11.9);
  });

  test('French, Spanish and Italian keywords', () {
    double? p(String s) => readLabel([l(s, 0, 0, 300, 20)]).proteinG;
    double? f(String s) => readLabel([l(s, 0, 0, 300, 20)]).fibreG;
    expect(p('Protéines 12 g'), 12);
    expect(p('Proteínas 12.5 g'), 12.5);
    expect(p('Proteinas 11 g'), 11);
    expect(p('Proteine 13 g'), 13);
    expect(f('Fibres alimentaires 2.9 g'), 2.9);
    expect(f('Fibra 3 g'), 3);
    expect(f('Dietary fiber 3.4g'), 3.4);
    expect(f('Fibre / Ballaststoffe / Fibra 3,1 g'), 3.1);
  });

  test('no fibre on the panel: protein only, not confident', () {
    final r = readLabel(
      table([
        ['Nutrition', 'Per 100g'],
        ['Protein', '12.9g'],
      ]),
    );
    expect(r.proteinG, 12.9);
    expect(r.fibreG, isNull);
    expect(r.confident, isFalse);
    expect(r.hits.map((h) => h.text), ['Protein', '12.9g']);
  });

  test('the value column OCR’d as one block, rows aligned by height', () {
    // Labels in one block, values in another, as ML Kit often returns a
    // panel: each value line sits level with its label, further right.
    final r = readLabel([
      l('Energy', 20, 100, 120, 124),
      l('Fibre', 20, 140, 100, 164),
      l('Protein', 20, 180, 120, 204),
      l('1480 kJ', 240, 102, 330, 126),
      l('3.1 g', 240, 142, 300, 166),
      l('13.7 g', 240, 182, 310, 206),
    ]);
    expect(r.proteinG, 13.7);
    expect(r.fibreG, 3.1);
    expect(r.confident, isTrue, reason: 'one column: nothing to disagree');
  });

  test('two columns that disagree, no 100 g header: left one, unsure', () {
    final r = readLabel(
      table([
        ['Fibre', '3.1g', '2.5g'],
        ['Protein', '13.7g', '11.0g'],
      ]),
    );
    expect(r.proteinG, 13.7);
    expect(r.fibreG, 3.1);
    expect(r.confident, isFalse);
  });

  test('no header, right column listed first: still the left-most', () {
    // ML Kit does not promise block order.
    final r = readLabel([
      l('Fibre', 20, 100, 200, 124),
      l('Protein', 20, 140, 200, 164),
      l('2.5g', 380, 100, 480, 124),
      l('11.0g', 380, 140, 480, 164),
      l('3.1g', 220, 100, 320, 124),
      l('13.7g', 220, 140, 320, 164),
    ]);
    expect(r.proteinG, 13.7);
    expect(r.fibreG, 3.1);
    expect(r.confident, isFalse);
  });

  test('header and both columns on one OCR line: x from the text', () {
    final r = readLabel([
      l('Typical values Per 80g Per 100g', 20, 20, 620, 44),
      l('Fibre 2.5g 3.1g', 20, 100, 620, 124),
      l('Protein 11.0g 13.7g', 20, 140, 620, 164),
    ]);
    expect(r.proteinG, 13.7);
    expect(r.fibreG, 3.1);
    expect(r.confident, isTrue);
  });

  test('a paragraph panel: only numbers after the keyword', () {
    final r = readLabel([
      l('Typical values per 100g: Energy 1450kJ', 20, 20, 620, 44),
      l('Carbohydrate 70g, Fibre 3.7g, Protein 11g', 20, 60, 620, 84),
    ]);
    expect(r.fibreG, 3.7);
    expect(r.proteinG, 11);
  });

  test('vitamin codes on an ingredients line are not values', () {
    final r = readLabel([
      l(
        'Ingredients: Wheat flour, wheat protein, Niacin (B3), Thiamin (B1), '
        'E330',
        20,
        20,
        620,
        44,
      ),
      l('Typical values Per 100g', 20, 60, 620, 84),
      l('Fibre 3.1g', 20, 100, 620, 124),
      l('Protein 13.7g', 20, 140, 620, 164),
    ]);
    expect(r.proteinG, 13.7);
    expect(r.fibreG, 3.1);
    expect(r.hits.map((h) => h.text), ['Protein 13.7g', 'Fibre 3.1g']);
  });

  test('the 100 of "per 100g" is never a value', () {
    final r = readLabel([
      l('High protein: 13g per 100g', 20, 20, 620, 44),
      l('Fibre 3.1g', 20, 100, 620, 124),
      l('Protein 13.7g', 20, 140, 620, 164),
    ]);
    expect(r.proteinG, 13, reason: 'the claim: in range, read first');
    expect(readLabel([l('Protein per 100g', 0, 0, 300, 20)]).proteinG, isNull);
  });

  test('a keyword line off the label range gives way to one in range', () {
    final r = readLabel([
      l('Protein-rich since 1886', 20, 20, 620, 44),
      l('Fibre 31g', 20, 60, 620, 84), // a dropped decimal point
      l('Fibre 3.1g', 20, 100, 620, 124),
      l('Protein 13.7g', 20, 140, 620, 164),
    ]);
    expect(r.proteinG, 13.7);
    expect(r.fibreG, 3.1);
    expect(r.confident, isTrue);
    expect(r.hits.map((h) => h.text), ['Protein 13.7g', 'Fibre 3.1g']);
    // Nothing in range: the first reading, kept, not confident.
    final off = readLabel([
      l('Protein 25 g', 0, 0, 200, 20),
      l('Protein 30 g', 0, 40, 200, 60),
      l('Fibre 3 g', 0, 80, 200, 100),
    ]);
    expect(off.proteinG, 25);
    expect(off.confident, isFalse);
  });

  test('two columns that agree, no header: confident', () {
    final r = readLabel(
      table([
        ['Fibre', '3.1g', '3.1g'],
        ['Protein', '13.7g', '13.7g'],
      ]),
    );
    expect(r.confident, isTrue);
  });

  test('values off the label range: kept, not confident', () {
    final high = readLabel([
      l('Protein 25 g', 0, 0, 200, 20),
      l('Fibre 3 g', 0, 40, 200, 60),
    ]);
    expect(high.proteinG, 25);
    expect(high.confident, isFalse);
    final fibre = readLabel([
      l('Protein 12 g', 0, 0, 200, 20),
      l('Fibre 16 g', 0, 40, 200, 60),
    ]);
    expect(fibre.fibreG, 16);
    expect(fibre.confident, isFalse);
  });

  test('"<0.5 g" reads 0.5; %RI and lines with no number are skipped', () {
    final r = readLabel([
      l('High protein strong white flour', 0, 0, 400, 20),
      l('Protein 13.7g 27%', 0, 40, 400, 60),
      l('Fibre <0.5 g', 0, 80, 400, 100),
    ]);
    expect(r.proteinG, 13.7);
    expect(r.fibreG, 0.5);
    expect(r.confident, isTrue);
    expect(r.hits.first.text, 'Protein 13.7g 27%');
  });

  test('a value line above or below the keyword line is not a candidate', () {
    final r = readLabel([
      l('Protein', 20, 100, 120, 124),
      l('13.7 g', 240, 130, 300, 154), // centre below the keyword line
      l('9 g', 240, 60, 300, 84), // above
      l('8 g', 0, 100, 18, 124), // level, but left of it
    ]);
    expect(r.proteinG, isNull);
    expect(r.hits, isEmpty);
  });

  test('nothing read: nothing found, not confident', () {
    final r = readLabel(const []);
    expect(r.proteinG, isNull);
    expect(r.fibreG, isNull);
    expect(r.confident, isFalse);
    expect(r.hits, isEmpty);
  });
}
