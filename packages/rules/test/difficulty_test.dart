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

  test('distant colors stay at least 100 away in RGB', () {
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

  test('the closeness cap tightens on the choice-count bands', () {
    expect(maxDecoyDistance(1), 32);
    expect(maxDecoyDistance(3), maxDecoyDistance(1));
    expect(maxDecoyDistance(4), 22);
    expect(maxDecoyDistance(6), maxDecoyDistance(4));
    expect(maxDecoyDistance(7), 14);
    expect(maxDecoyDistance(10), maxDecoyDistance(7));
    expect(maxDecoyDistance(11), 9);
    expect(maxDecoyDistance(14), maxDecoyDistance(11));
    expect(maxDecoyDistance(15), 5);
    expect(maxDecoyDistance(18), maxDecoyDistance(15));
    expect(maxDecoyDistance(19), 3.25);
    expect(maxDecoyDistance(41), maxDecoyDistance(19));
    expect(maxDecoyDistance(1), greaterThan(maxDecoyDistance(6)));
    expect(maxDecoyDistance(6), greaterThan(maxDecoyDistance(10)));
    expect(maxDecoyDistance(10), greaterThan(maxDecoyDistance(14)));
    expect(maxDecoyDistance(14), greaterThan(maxDecoyDistance(18)));
    expect(maxDecoyDistance(18), greaterThan(maxDecoyDistance(19)));
    expect(
      holeDecoyWeight + pulseDecoyWeight,
      greaterThan(maxDecoyDistance(19)),
    );
    expect(bodyDecoyWeight, greaterThan(maxDecoyDistance(19)));
  });

  test('every decoy stays inside its level cap', () {
    for (final level in [1, 3, 4, 6, 7, 10, 11, 14, 15, 18, 19, 41]) {
      for (var seed = 0; seed < 20; seed++) {
        final round = buildRound(level: level, random: Random(seed));
        expectRoundShape(round, level);
        for (final decoy in decoysOf(round)) {
          expect(
            decoyDistance(round.original, decoy),
            lessThanOrEqualTo(maxDecoyDistance(level)),
          );
        }
      }
    }
  });

  test('late decoys sit closer than early ones', () {
    final means = <int, double>{};
    for (final level in [1, 6, 10, 14, 18, 19]) {
      var total = 0.0;
      var count = 0;
      for (var seed = 0; seed < 24; seed++) {
        final round = buildRound(level: level, random: Random(seed));
        for (final decoy in decoysOf(round)) {
          total += decoyDistance(round.original, decoy);
          count += 1;
        }
      }
      means[level] = total / count;
    }
    expect(means[1]!, greaterThan(means[6]!));
    expect(means[6]!, greaterThan(means[10]!));
    expect(means[10]!, greaterThan(means[14]!));
    expect(means[14]!, greaterThan(means[18]!));
    expect(means[18]!, greaterThan(means[19]!));
    expect(means[1]!, greaterThan(means[19]! * 4));
  });

  test('level 1 changes every field and level 19 changes one nearby field', () {
    var earlyColor = 0.0;
    var earlyColorCount = 0;
    var lateColor = 0.0;
    var lateColorCount = 0;
    var earlyMin = double.infinity;
    var lateMax = 0.0;
    for (var seed = 0; seed < 30; seed++) {
      final early = buildRound(level: 1, random: Random(seed));
      final late = buildRound(level: 41, random: Random(seed + 1000));
      for (final decoy in decoysOf(early)) {
        final distance = decoyDistance(early.original, decoy);
        earlyMin = min(earlyMin, distance);
        expect(decoyFieldChanges(early.original, decoy), 6);
        expect(decoy.body, isNot(early.original.body));
        expect(
          decoy.top != early.original.top || decoy.side != early.original.side,
          isTrue,
        );
        final colorGap = colorDistance(early.original.color, decoy.color);
        expect(colorGap, greaterThanOrEqualTo(minDecoyColorDistance));
        earlyColor += colorGap;
        earlyColorCount += 1;
      }
      for (final decoy in decoysOf(late)) {
        final distance = decoyDistance(late.original, decoy);
        lateMax = max(lateMax, distance);
        expect(decoyFieldChanges(late.original, decoy), 1);
        expect(decoy.body, late.original.body);
        if (decoy.color != late.original.color) {
          final colorGap = colorDistance(late.original.color, decoy.color);
          expect(colorGap, lessThan(minDecoyColorDistance));
          lateColor += colorGap;
          lateColorCount += 1;
        }
      }
    }
    expect(earlyMin, greaterThan(lateMax));
    expect(earlyColorCount, greaterThan(0));
    if (lateColorCount > 0) {
      expect(
        earlyColor / earlyColorCount,
        greaterThan(lateColor / lateColorCount),
      );
    }
  });
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
