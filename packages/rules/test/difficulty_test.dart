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

  test('choice count follows the level bands', () {
    expect(choiceCountForLevel(1), 3);
    expect(choiceCountForLevel(3), 3);
    expect(choiceCountForLevel(4), 4);
    expect(choiceCountForLevel(6), 4);
    expect(choiceCountForLevel(7), 5);
    expect(choiceCountForLevel(10), 5);
    expect(choiceCountForLevel(11), 6);
    expect(choiceCountForLevel(14), 6);
    expect(choiceCountForLevel(15), 7);
    expect(choiceCountForLevel(18), 7);
    expect(choiceCountForLevel(19), 8);
    expect(choiceCountForLevel(41), 8);
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
      final round = buildRound(level: 1, random: Random(seed));
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
    for (final level in [1, 3, 4, 6, 7, 10, 11, 41]) {
      for (var seed = 0; seed < 80; seed++) {
        final round = buildRound(level: level, random: Random(seed));
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
      final round = buildRound(level: 1, random: Random(seed));
      positions.add(round.choices.indexOf(round.original));
    }
    expect(positions.length, greaterThan(1));
  });

  for (final level in [1, 2, 3]) {
    test('level $level decoys differ in body, color, and a side part', () {
      for (var seed = 0; seed < 40; seed++) {
        final round = buildRound(level: level, random: Random(seed));
        expectRoundShape(round, level);
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

  for (final level in [4, 5, 6]) {
    test('level $level fills the three mid-band roles', () {
      for (var seed = 0; seed < 40; seed++) {
        final round = buildRound(level: level, random: Random(seed));
        expectRoundShape(round, level);
        expectMidRoles(round.original, [
          for (final choice in round.choices)
            if (choice != round.original) choice,
        ]);
      }
    });
  }

  for (final level in [7, 8, 9, 10]) {
    test('level $level uses distant colors and two different slots', () {
      for (var seed = 0; seed < 25; seed++) {
        final round = buildRound(level: level, random: Random(seed));
        expectRoundShape(round, level);
        expectHighBand(round.original, decoysOf(round), slots: 2);
      }
    });
  }

  for (final level in [11, 12, 14]) {
    test('level $level uses distant colors and every slot', () {
      for (var seed = 0; seed < 25; seed++) {
        final round = buildRound(level: level, random: Random(seed));
        expectRoundShape(round, level);
        expectHighBand(round.original, decoysOf(round), slots: 3);
      }
    });
  }

  for (final level in [15, 16, 18]) {
    test('level $level adds a body decoy', () {
      for (var seed = 0; seed < 25; seed++) {
        final round = buildRound(level: level, random: Random(seed));
        expectRoundShape(round, level);
        expectWideBand(round.original, decoysOf(round), pulse: false);
      }
    });
  }

  for (final level in [19, 20, 41]) {
    test('level $level adds a body decoy and a pulse decoy', () {
      for (var seed = 0; seed < 25; seed++) {
        final round = buildRound(level: level, random: Random(seed));
        expectRoundShape(round, level);
        expectWideBand(round.original, decoysOf(round), pulse: true);
      }
    });
  }
}

List<Assembly> decoysOf(BuiltRound round) => [
      for (final choice in round.choices)
        if (choice != round.original) choice,
    ];

void expectRoundShape(BuiltRound round, int level) {
  expect(round.choiceCount, choiceCountForLevel(level));
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

void expectWideBand(
  Assembly original,
  List<Assembly> decoys, {
  required bool pulse,
}) {
  expect(decoys, hasLength(pulse ? 7 : 6));
  var colors = 0;
  var body = 0;
  var pulses = 0;
  final slots = <String>{};
  for (final decoy in decoys) {
    final diffs = <String>[
      if (decoy.body != original.body) 'body',
      if (decoy.top != original.top) 'top',
      if (decoy.side != original.side) 'side',
      if (decoy.hole != original.hole) 'hole',
      if (decoy.color != original.color) 'color',
      if (decoy.pulse != original.pulse) 'pulse',
    ];
    if (diffs.length == 1 && diffs.single == 'color') {
      colors += 1;
      expect(
        distantColors(original.color),
        contains(decoy.color),
      );
    } else if (diffs.length == 1 && diffs.single == 'body') {
      body += 1;
    } else if (diffs.length == 1 && diffs.single == 'pulse') {
      pulses += 1;
    } else if (diffs.length == 1 &&
        decoy.body == original.body &&
        decoy.color == original.color &&
        decoy.pulse == original.pulse) {
      slots.add(diffs.single);
    } else {
      fail('Decoy $decoy does not match a wide-band role for $original.');
    }
  }
  expect(colors, 2);
  expect(body, 1);
  expect(pulses, pulse ? 1 : 0);
  expect(slots, {'top', 'side', 'hole'});
}
