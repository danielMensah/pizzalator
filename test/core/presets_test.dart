import 'package:flutter_test/flutter_test.dart';
import 'package:pizzalator/core/presets.dart';

void main() {
  test('Stage has value equality', () {
    expect(const Stage(2, 20), const Stage(2.0, 20.0));
    expect(const Stage(2, 20), isNot(const Stage(2, 4)));
    expect(const Stage(2, 20).hashCode, const Stage(2.0, 20.0).hashCode);
  });

  test('Preferment.copyWith changes only the given params', () {
    final p = Preferment.biga.copyWith(flourShare: 80, hydration: 55);
    expect(p.kind, PrefermentKind.biga);
    expect(p.flourShare, 80);
    expect(p.hydration, 55);
    expect(p.hours, Preferment.biga.hours);
    expect(p.tempC, Preferment.biga.tempC);
    expect(p.idyPctOfPrefFlour, Preferment.biga.idyPctOfPrefFlour);
    final same = Preferment.poolish.copyWith();
    expect(same.flourShare, 30);
    expect(same.hydration, 100);
  });

  test('poolish IDY follows its hours: 0.25 % at 8 h, 0.1 % from 12 h', () {
    double idy(double h) =>
        Preferment.poolish.copyWith(hours: h).idyPctOfPrefFlour;
    expect(idy(8), 0.25);
    expect(idy(6), 0.25);
    expect(idy(10), closeTo(0.175, 1e-9));
    expect(idy(12), closeTo(0.1, 1e-9));
    expect(idy(16), closeTo(0.1, 1e-9));
    expect(Preferment.poolish.idyPctOfPrefFlour, closeTo(0.1, 1e-9));
    expect(Preferment.biga.copyWith(hours: 24).idyPctOfPrefFlour, 0.7);
    expect(Preferment.sourdough.idyPctOfPrefFlour, 0);
    expect(Preferment.none.idyPctOfPrefFlour, 0);
  });

  test('poolish and biga hours and temperatures have ranges', () {
    expect(PrefermentKind.poolish.hours, (8.0, 16.0));
    expect(PrefermentKind.biga.hours, (16.0, 24.0));
    expect(PrefermentKind.biga.temps, (16.0, 18.0));
    expect(PrefermentKind.sourdough.hours, (0.0, 0.0));
    for (final p in [Preferment.poolish, Preferment.biga]) {
      expect(p.hours, inInclusiveRange(p.kind.hours.$1, p.kind.hours.$2));
      expect(p.tempC, inInclusiveRange(p.kind.temps.$1, p.kind.temps.$2));
    }
  });

  test('preferment kinds carry the PRD 4.5 ranges', () {
    expect(PrefermentKind.poolish.shareMin, 20);
    expect(PrefermentKind.poolish.shareMax, 50);
    expect(PrefermentKind.poolish.hydrationMin, 100);
    expect(PrefermentKind.poolish.hydrationMax, 100);
    expect(PrefermentKind.biga.shareMin, 30);
    expect(PrefermentKind.biga.shareMax, 100);
    expect(PrefermentKind.biga.hydrationMin, 45);
    expect(PrefermentKind.biga.hydrationMax, 55);
    expect(PrefermentKind.sourdough.shareMin, 10);
    expect(PrefermentKind.sourdough.shareMax, 25);
    expect(PrefermentKind.sourdough.hydrationMin, 50);
    expect(PrefermentKind.sourdough.hydrationMax, 125);
    for (final p in [
      Preferment.poolish,
      Preferment.biga,
      Preferment.sourdough,
    ]) {
      expect(p.flourShare, inInclusiveRange(p.kind.shareMin, p.kind.shareMax));
      expect(
        p.hydration,
        inInclusiveRange(p.kind.hydrationMin, p.kind.hydrationMax),
      );
    }
  });

  test('styles carry the mockup default sizes', () {
    expect(
      [
        for (final s in [PizzaStyle.neapolitan, PizzaStyle.newYork])
          s.diameterCm,
      ],
      [30, 35],
    );
    expect(PizzaStyle.thin.diameterCm, 30);
    expect(
      [
        for (final s in [
          PizzaStyle.detroit,
          PizzaStyle.roman,
          PizzaStyle.sicilian,
        ])
          (s.panWCm, s.panLCm),
      ],
      [(25.0, 35.0), (30.0, 40.0), (33.0, 46.0)],
    );
  });

  test(
    'splitPlan: bulk before the first fridge stage, then fridge, warm-up',
    () {
      final p = splitPlan(const [Stage(1, 22), Stage(48, 5), Stage(2, 22)]);
      expect(p.bulk, const [Stage(1, 22)]);
      expect(p.fridge, const [Stage(48, 5)]);
      expect(p.warm, const [Stage(2, 22)]);
      final day = splitPlan(const [Stage(4, 24), Stage(2, 24)]);
      expect([day.bulk.length, day.fridge, day.warm], [2, isEmpty, isEmpty]);
      // The empty fridge stage the Ferment editor writes keeps a warm-up apart.
      final proof = splitPlan(const [Stage(2, 20), Stage(0, 4), Stage(1, 20)]);
      expect(proof.bulk, const [Stage(2, 20)]);
      expect(proof.warm, const [Stage(1, 20)]);
    },
  );

  group('StagePlan', () {
    test('reads a style default plan as room bulk then fridge', () {
      final p = StagePlan.of(PizzaStyle.neapolitan.plan);
      expect(p.roomH, 2);
      expect(p.fridgeH, 24);
      expect(p.warmH, 0);
      expect(p.roomC, 20);
      expect(p.fridgeC, 4);
      expect(p.totalH, 26);
    });

    test('round-trips every style default plan unchanged', () {
      for (final s in PizzaStyle.values) {
        expect(StagePlan.of(s.plan).stages, s.plan, reason: s.label);
      }
    });

    test('reads room, fridge and warm-up stages', () {
      final p = StagePlan.of(const [Stage(1, 22), Stage(48, 5), Stage(2, 22)]);
      expect(
        [p.roomH, p.fridgeH, p.warmH, p.roomC, p.fridgeC],
        [1, 48, 2, 22, 5],
      );
    });

    test('same-day plan is all room bulk; fridge-only has no room', () {
      final day = StagePlan.of(const [Stage(4, 24), Stage(2, 24)]);
      expect([day.roomH, day.fridgeH, day.warmH], [6, 0, 0]);
      expect([day.roomC, day.fridgeC], [24, StagePlan.defaultFridgeC]);
      final cold = StagePlan.of(const [Stage(48, 3)]);
      expect([cold.roomH, cold.fridgeH, cold.warmH], [0, 48, 0]);
      expect([cold.roomC, cold.fridgeC], [StagePlan.defaultRoomC, 3]);
      expect(StagePlan.of(const []).totalH, 0);
    });

    test('writes room, fridge, warm-up and drops empty room stages', () {
      const p = StagePlan(roomH: 2, fridgeH: 24, warmH: 1, roomC: 21);
      expect(p.stages, const [Stage(2, 21), Stage(24, 4), Stage(1, 21)]);
      expect(p.copyWith(roomH: 0, warmH: 0).stages, const [Stage(24, 4)]);
      expect(p.copyWith(fridgeH: 0, warmH: 0).stages, const [Stage(2, 21)]);
    });

    test('keeps an empty fridge stage so a warm-up stays a warm-up', () {
      const p = StagePlan(roomH: 2, fridgeH: 0, warmH: 1);
      expect(p.stages, const [Stage(2, 20), Stage(0, 4), Stage(1, 20)]);
      final back = StagePlan.of(p.stages);
      expect([back.roomH, back.fridgeH, back.warmH], [2, 0, 1]);
    });

    test('copyWith changes only the given fields', () {
      const p = StagePlan(roomH: 2, fridgeH: 24, warmH: 1);
      final q = p.copyWith(fridgeH: 36, roomC: 25, fridgeC: 6);
      expect(
        [q.roomH, q.fridgeH, q.warmH, q.roomC, q.fridgeC],
        [2, 36, 1, 25, 6],
      );
    });
  });

  group('Flour', () {
    const mine = Flour(
      'Marriage’s wholemeal',
      12.9,
      wholegrain: true,
      fibrePct: 9.2,
      note: 'scanned',
    );

    test('json round trip, fibre and note optional', () {
      expect(Flour.fromJson(mine.toJson()), mine);
      expect(Flour.fromJson(mine.toJson()).note, 'scanned');
      // A JSON file stores 13.0 as 13.
      final plain = Flour.fromJson({'name': 'Plain', 'proteinPct': 10});
      expect(plain, const Flour('Plain', 10));
      expect([plain.fibrePct, plain.note, plain.wholegrain], [null, '', false]);
    });

    test('equal by name, protein, wholegrain and fibre; not by note', () {
      expect(
        mine,
        const Flour(
          'Marriage’s wholemeal',
          12.9,
          wholegrain: true,
          fibrePct: 9.2,
        ),
      );
      expect(
        mine.hashCode,
        const Flour(
          'Marriage’s wholemeal',
          12.9,
          wholegrain: true,
          fibrePct: 9.2,
        ).hashCode,
      );
      expect(Flour.ukStrong, Flour.presets[4]);
      for (final other in const [
        Flour('Marriage’s wholemeal', 12.9, fibrePct: 9.2),
        Flour('Marriage’s wholemeal', 13, wholegrain: true, fibrePct: 9.2),
        Flour('Marriage’s wholemeal', 12.9, wholegrain: true),
        Flour('Wholemeal', 12.9, wholegrain: true, fibrePct: 9.2),
      ]) {
        expect(mine, isNot(other));
      }
    });

    test('fibre from 6 g reads as wholegrain (PRD 4.3)', () {
      expect(kWholegrainFibreG, 6);
      expect(wholegrainFromFibre(3.1), isFalse);
      expect(wholegrainFromFibre(5.9), isFalse);
      expect(wholegrainFromFibre(6), isTrue);
      expect(wholegrainFromFibre(9.2), isTrue);
    });

    test('presets keep their names and carry the mockup notes', () {
      expect(
        {for (final f in Flour.presets) f.name: f.note},
        {
          'Italian 00 pizza': 'Caputo Pizzeria class',
          'Italian 00 weak': 'supermarket, pasta grade',
          'Italian 0 / Manitoba': '',
          'UK plain': '',
          'UK strong white': 'Sainsbury’s 13.7, Doves 12–14',
          'UK very strong / Canadian': 'Waitrose Canadian 15',
          'US all-purpose': '',
          'US bread flour': 'King Arthur 12.7',
          'Wholemeal': 'absorbs ~75%',
          'Semolina rimacinata': '10–20% blend',
        },
      );
      expect(Flour.presets.where((f) => f.fibrePct != null), isEmpty);
    });
  });
}
