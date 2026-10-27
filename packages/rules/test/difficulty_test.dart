import 'dart:math';

import 'package:gizmo_rules/gizmo_rules.dart';
import 'package:test/test.dart';

void main() {
  test('the catalog has 4320 legal assemblies', () {
    var count = 0;
    for (final _ in BodyId.values) {
      for (final top in TopId.values) {
        for (final side in SideId.values) {
          if (top == TopId.none && side == SideId.none) continue;
          for (final _ in HoleId.values) {
            for (final _ in ColorId.values) {
              for (final _ in PulseId.values) {
                count += 1;
              }
            }
          }
        }
      }
    }
    expect(count, assemblyCount);
    expect(assemblyCount, 4320);
  });

  test('colors form a ring and amber is readable yellow', () {
    expect(adjacentColors(ColorId.red), [ColorId.pink, ColorId.orange]);
    expect(adjacentColors(ColorId.pink), [ColorId.purple, ColorId.red]);
    expect(adjacentColors(ColorId.amber), [ColorId.orange, ColorId.green]);
    expect(nonAdjacentColors(ColorId.red), hasLength(5));
    expect(nonAdjacentColors(ColorId.red), isNot(contains(ColorId.red)));
    expect(nonAdjacentColors(ColorId.red), isNot(contains(ColorId.pink)));
    expect(colorValue[ColorId.amber], 0xFFF9A825);
    expect(colorValue, hasLength(8));
  });

  test('a decoy color stays at least 100 away in RGB', () {
    var minimum = double.infinity;
    final closest = <(ColorId, ColorId)>[];
    for (final color in ColorId.values) {
      final distant = distantColors(color);
      expect(distant.length, greaterThanOrEqualTo(2));
      expect(distant, isNot(contains(color)));
      for (final neighbor in adjacentColors(color)) {
        expect(distant, isNot(contains(neighbor)));
      }
      for (final other in distant) {
        final distance = colorDistance(color, other);
        expect(distance, greaterThanOrEqualTo(minDecoyColorDistance));
        if (distance < minimum - 1e-9) {
          minimum = distance;
          closest
            ..clear()
            ..add((color, other));
        } else if ((distance - minimum).abs() <= 1e-9) {
          closest.add((color, other));
        }
      }
    }
    expect(minimum, colorDistance(ColorId.red, ColorId.amber));
    expect(minimum, greaterThan(minDecoyColorDistance));
    expect(closest, [
      (ColorId.red, ColorId.amber),
      (ColorId.amber, ColorId.red),
    ]);
  });

  test('choice count follows the score bands', () {
    expect(choiceCountForScore(0), 3);
    expect(choiceCountForScore(2), 3);
    expect(choiceCountForScore(3), 4);
    expect(choiceCountForScore(5), 4);
    expect(choiceCountForScore(6), 5);
    expect(choiceCountForScore(9), 5);
    expect(choiceCountForScore(10), 6);
    expect(choiceCountForScore(40), 6);
  });

  test('pulse is none, core, or rim and is part of identity', () {
    expect(PulseId.values, [PulseId.none, PulseId.core, PulseId.rim]);
    const assembly = Assembly(
      body: BodyId.slab,
      top: TopId.knob,
      side: SideId.tab,
      hole: HoleId.slot,
      color: ColorId.blue,
      pulse: PulseId.none,
    );
    final core = assembly.copyWith(pulse: PulseId.core);
    expect(core, isNot(assembly));
    expect(core.pulse, PulseId.core);
    expect(core.hashCode, isNot(assembly.hashCode));
    expect(assembly.copyWith(), assembly);
    expect(assembly.toString(), 'slab/knob/tab/slot/blue/none');
    expect(parsePulse('rim'), PulseId.rim);
    expect(parsePulse('flash'), isNull);
  });

  test('originals use every body, hole, color, and pulse', () {
    final bodies = <BodyId>{};
    final holes = <HoleId>{};
    final colors = <ColorId>{};
    final pulses = <PulseId>{};
    for (var seed = 0; seed < 200; seed++) {
      final round = buildRound(scoreSoFar: 0, random: Random(seed));
      bodies.add(round.original.body);
      holes.add(round.original.hole);
      colors.add(round.original.color);
      pulses.add(round.original.pulse);
      expect(round.original.isLegal, isTrue);
    }
    expect(bodies, BodyId.values.toSet());
    expect(holes, HoleId.values.toSet());
    expect(colors, ColorId.values.toSet());
    expect(pulses, PulseId.values.toSet());
  });

  test('a decoy is never equal to the original', () {
    for (final score in [0, 2, 3, 5, 6, 9, 10, 40]) {
      for (var seed = 0; seed < 80; seed++) {
        final round = buildRound(scoreSoFar: score, random: Random(seed));
        for (final choice in round.choices) {
          if (choice == round.original) continue;
          expect(choice, isNot(round.original));
        }
        expect(
          round.choices.where((choice) => choice == round.original),
          hasLength(1),
        );
      }
    }
  });

  test('the original is not always in the same cell', () {
    final positions = <int>{};
    for (var seed = 0; seed < 30; seed++) {
      final round = buildRound(scoreSoFar: 0, random: Random(seed));
      positions.add(round.choices.indexOf(round.original));
    }
    expect(positions.length, greaterThan(1));
  });

  for (final score in [0, 1, 2]) {
    test('score $score decoys differ in body, color, and a side part', () {
      for (var seed = 0; seed < 40; seed++) {
        final round = buildRound(scoreSoFar: score, random: Random(seed));
        expectRoundShape(round, score);
        final decoys = round.choices.where((item) => item != round.original);
        expect(decoys, hasLength(2));
        for (final decoy in decoys) {
          expect(decoy.body, isNot(round.original.body));
          expect(
            distantColors(round.original.color),
            contains(decoy.color),
          );
          expect(
            colorDistance(round.original.color, decoy.color),
            greaterThanOrEqualTo(minDecoyColorDistance),
          );
          expect(
            decoy.top != round.original.top ||
                decoy.side != round.original.side,
            isTrue,
          );
        }
      }
    });
  }

  for (final score in [3, 4, 5]) {
    test('score $score fills the three mid-band roles', () {
      for (var seed = 0; seed < 40; seed++) {
        final round = buildRound(scoreSoFar: score, random: Random(seed));
        expectRoundShape(round, score);
        expectMidRoles(round.original, [
          for (final choice in round.choices)
            if (choice != round.original) choice,
        ]);
      }
    });
  }

  for (final score in [6, 7, 8, 9]) {
    test('score $score uses distant colors and two different slots', () {
      for (var seed = 0; seed < 25; seed++) {
        final round = buildRound(scoreSoFar: score, random: Random(seed));
        expectRoundShape(round, score);
        expectHighBand(round.original, decoysOf(round), slots: 2);
      }
    });
  }

  for (final score in [10, 11, 25]) {
    test('score $score uses distant colors and every slot', () {
      for (var seed = 0; seed < 25; seed++) {
        final round = buildRound(scoreSoFar: score, random: Random(seed));
        expectRoundShape(round, score);
        expectHighBand(round.original, decoysOf(round), slots: 3);
      }
    });
  }
}

List<Assembly> decoysOf(BuiltRound round) => [
      for (final choice in round.choices)
        if (choice != round.original) choice,
    ];

void expectRoundShape(BuiltRound round, int score) {
  expect(round.choiceCount, choiceCountForScore(score));
  expect(round.choices, contains(round.original));
  expect(round.choices.toSet(), hasLength(round.choices.length));
  for (final choice in round.choices) {
    expect(choice.isLegal, isTrue);
    if (choice == round.original) continue;
    final differs = choice.body != round.original.body ||
        choice.top != round.original.top ||
        choice.side != round.original.side ||
        choice.hole != round.original.hole ||
        choice.color != round.original.color ||
        choice.pulse != round.original.pulse;
    expect(differs, isTrue, reason: '$choice matches ${round.original}');
  }
}

int slotChanges(Assembly original, Assembly decoy) {
  var count = 0;
  if (original.top != decoy.top) count += 1;
  if (original.side != decoy.side) count += 1;
  if (original.hole != decoy.hole) count += 1;
  return count;
}

void expectMidRoles(Assembly original, List<Assembly> decoys) {
  var keepBody = 0;
  var bodyOnly = 0;
  var bodySlot = 0;
  for (final decoy in decoys) {
    final slots = slotChanges(original, decoy);
    final bodyChanged = decoy.body != original.body;
    final distant = distantColors(original.color).contains(decoy.color);
    if (!bodyChanged && slots == 1 && distant) {
      keepBody += 1;
    } else if (bodyChanged && decoy.color == original.color && slots == 0) {
      bodyOnly += 1;
    } else if (bodyChanged && slots == 1 && distant) {
      bodySlot += 1;
    } else {
      fail('Decoy $decoy does not match a mid-band role for $original.');
    }
  }
  expect(keepBody, 1);
  expect(bodyOnly, 1);
  expect(bodySlot, 1);
}

bool sameShape(Assembly a, Assembly b) =>
    a.body == b.body && a.top == b.top && a.side == b.side && a.hole == b.hole;

void expectHighBand(
  Assembly original,
  List<Assembly> decoys, {
  required int slots,
}) {
  final distant = distantColors(original.color).toSet();
  final colorDecoys = [
    for (final decoy in decoys)
      if (sameShape(decoy, original)) decoy,
  ];
  expect(colorDecoys, hasLength(2));
  final colors = colorDecoys.map((decoy) => decoy.color).toSet();
  expect(colors, hasLength(2));
  expect(distant.containsAll(colors), isTrue);
  for (final decoy in colorDecoys) {
    expect(
      colorDistance(original.color, decoy.color),
      greaterThanOrEqualTo(minDecoyColorDistance),
    );
  }

  final slotDecoys = [
    for (final decoy in decoys)
      if (decoy.body == original.body && decoy.color == original.color) decoy,
  ];
  expect(slotDecoys, hasLength(slots));
  final changed = <String>{};
  for (final decoy in slotDecoys) {
    final diffs = <String>[
      if (decoy.top != original.top) 'top',
      if (decoy.side != original.side) 'side',
      if (decoy.hole != original.hole) 'hole',
    ];
    expect(diffs, hasLength(1), reason: '$decoy vs $original');
    changed.add(diffs.single);
  }
  expect(changed, hasLength(slots));
  if (slots == 3) {
    expect(changed, {'top', 'side', 'hole'});
  }
  expect(colorDecoys.length + slotDecoys.length, decoys.length);
}
