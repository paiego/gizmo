import 'dart:math' as math;

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
      final round = buildRound(level: 1, random: math.Random(seed));
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
        final round = buildRound(level: level, random: math.Random(seed));
        for (final choice in round.choices) {
          if (choice.appearance == round.baseline) continue;
          expect(samePictureSnapshots(choice.appearance, round.baseline), isFalse);
        }
        expect(
          round.choices.where((c) => c.appearance == round.baseline),
          hasLength(1),
        );
      }
    }
  });

  test('the original is not always in the same cell', () {
    final positions = <int>{};
    for (var seed = 0; seed < 30; seed++) {
      final round = buildRound(level: 1, random: math.Random(seed));
      positions.add(round.indexOfOriginal());
    }
    expect(positions.length, greaterThan(1));
  });

  test('mutation count and color cap tighten with level', () {
    expect(decoyVariationCount(1), 4);
    expect(decoyVariationCount(3), 4);
    expect(decoyVariationCount(4), 3);
    expect(decoyVariationCount(6), 3);
    expect(decoyVariationCount(7), 2);
    expect(decoyVariationCount(10), 2);
    expect(decoyVariationCount(11), 1);
    expect(decoyVariationCount(18), 1);
    expect(decoyVariationCount(19), 1);
    expect(decoyVariationCount(41), 1);
    expect(decoyVariationCount(1), greaterThan(decoyVariationCount(6)));
    expect(decoyVariationCount(6), greaterThan(decoyVariationCount(10)));
    expect(decoyVariationCount(10), greaterThan(decoyVariationCount(19)));
    expect(maxMutationColorDistance(1), double.infinity);
    expect(maxMutationColorDistance(6), double.infinity);
    expect(maxMutationColorDistance(7), 220);
    expect(maxMutationColorDistance(11), 160);
    expect(maxMutationColorDistance(15), 110);
    expect(maxMutationColorDistance(19), 60);
    expect(
      maxMutationColorDistance(7),
      greaterThan(maxMutationColorDistance(19)),
    );
  });

  test('decoy similarity ramp progress edge cases', () {
    expect(decoySimilarityRampProgress(level: 1, rampSlope: 0), 0);
    expect(decoySimilarityRampProgress(level: 19, rampSlope: 0), 0);
    expect(decoySimilarityRampProgress(level: 1, rampSlope: 1), 1);
    expect(decoySimilarityRampProgress(level: 5, rampSlope: 1), 1);
    final mid = decoySimilarityRampProgress(level: 10, rampSlope: 0.5);
    expect(mid, greaterThan(0));
    expect(mid, lessThan(1));
    expect(
      activeDecoySimilarityForLevel(
        level: 1,
        startSimilarity: 0.2,
        endSimilarity: 0.8,
        rampSlope: 0,
        levelBasedProximity: true,
      ),
      0.2,
    );
    expect(
      activeDecoySimilarityForLevel(
        level: 3,
        startSimilarity: 0.2,
        endSimilarity: 0.8,
        rampSlope: 1,
        levelBasedProximity: true,
      ),
      0.8,
    );
    expect(
      activeDecoySimilarityForLevel(
        level: 10,
        startSimilarity: 0,
        endSimilarity: 1,
        rampSlope: 0.5,
        levelBasedProximity: false,
      ),
      0,
    );
  });

  test('level ramp uses active similarity at each level', () {
    for (final level in [1, 3, 4, 6, 7, 10, 11, 14, 15, 18, 19, 41]) {
      final effective = activeDecoySimilarityForLevel(
        level: level,
        startSimilarity: 0,
        endSimilarity: 1,
        rampSlope: 0.5,
        levelBasedProximity: true,
      );
      final changes = decoyVariationCountForSimilarity(effective);
      final colorCap = maxMutationColorDistanceForSimilarity(effective);
      for (var seed = 0; seed < 20; seed++) {
        final round = buildRound(
          level: level,
          random: math.Random(seed),
          decoySimilarity: 0,
          decoySimilarityMax: 1,
          decoySimilarityRampSlope: 0.5,
          levelBasedProximity: true,
        );
        expectRoundShape(round, level);
        for (final decoy in decoyChoicesOf(round)) {
          if (effective >= 0.75) {
            expect(
              snapshotPropertyDelta(round.baseline, decoy.appearance),
              decoyVisualVariationCountForSimilarity(effective),
            );
            expect(
              samePictureSnapshots(decoy.appearance, round.baseline),
              isFalse,
            );
          } else {
            expect(decoyFieldChanges(round.original, decoy.assembly), changes);
            expect(_unchangedFields(round.original, decoy.assembly), 6 - changes);
            if (decoy.assembly.color != round.original.color) {
              expect(
                colorDistance(round.original.color, decoy.assembly.color),
                lessThanOrEqualTo(colorCap),
              );
            }
          }
        }
      }
    }
  });

  test('early decoys change more fields and sit farther than late ones', () {
    var early = 0.0;
    var mid = 0.0;
    var late = 0.0;
    var earlyCount = 0;
    var midCount = 0;
    var lateCount = 0;
    for (var seed = 0; seed < 24; seed++) {
      final first = buildRound(
        level: 1,
        random: math.Random(seed),
        decoySimilarity: 0,
        decoySimilarityMax: 1,
        decoySimilarityRampSlope: 0.5,
        levelBasedProximity: true,
      );
      final tenth = buildRound(
        level: 10,
        random: math.Random(seed),
        decoySimilarity: 0,
        decoySimilarityMax: 1,
        decoySimilarityRampSlope: 0.5,
        levelBasedProximity: true,
      );
      final last = buildRound(
        level: 19,
        random: math.Random(seed + 100),
        decoySimilarity: 0,
        decoySimilarityMax: 1,
        decoySimilarityRampSlope: 0.5,
        levelBasedProximity: true,
      );
      for (final decoy in decoyAssembliesOf(first)) {
        final distance = decoyDistance(first.original, decoy);
        early += distance;
        earlyCount += 1;
      }
      for (final decoy in decoyAssembliesOf(tenth)) {
        mid += decoyDistance(tenth.original, decoy);
        midCount += 1;
      }
      for (final decoy in decoyAssembliesOf(last)) {
        late += decoyDistance(last.original, decoy);
        lateCount += 1;
      }
    }
    expect(early / earlyCount, greaterThan(late / lateCount));
  });

  test('similarity sets the field count and ignores level', () {
    expect(decoyVariationCountForSimilarity(0), 4);
    expect(decoyVariationCountForSimilarity(0.24), 4);
    expect(decoyVariationCountForSimilarity(0.25), 3);
    expect(decoyVariationCountForSimilarity(0.5), 2);
    expect(decoyVariationCountForSimilarity(0.75), 1);
    expect(decoyVariationCountForSimilarity(1), 1);
    expect(decoyVariationCountForSimilarity(-1), 4);
    expect(decoyVariationCountForSimilarity(2), 1);
    expect(maxMutationColorDistanceForSimilarity(0), double.infinity);
    expect(maxMutationColorDistanceForSimilarity(1), 60);
    expect(maxMutationColorDistanceForSimilarity(0.5), closeTo(190, 0.001));

    for (final similarity in [0.0, 0.25, 0.5]) {
      final changes = decoyVariationCountForSimilarity(similarity);
      final colorCap = maxMutationColorDistanceForSimilarity(similarity);
      for (var seed = 0; seed < 6; seed++) {
        final early = buildRound(
          level: 1,
          random: math.Random(seed),
          decoySimilarity: similarity,
        );
        final late = buildRound(
          level: 99,
          random: math.Random(seed + 50),
          decoySimilarity: similarity,
        );
        expect(early.choiceCount, choiceCountForLevel(1));
        expect(late.choiceCount, choiceCountForLevel(99));
        for (final round in [early, late]) {
          final level = round == early ? 1 : 99;
          expectRoundShape(round, level);
          for (final decoy in decoyAssembliesOf(round)) {
            expect(decoyFieldChanges(round.original, decoy), changes);
            expect(_unchangedFields(round.original, decoy), 6 - changes);
            if (decoy.color != round.original.color) {
              expect(
                colorDistance(round.original.color, decoy.color),
                lessThanOrEqualTo(colorCap),
              );
            }
          }
        }
      }
    }
  });

  test('high similarity uses one rendered property change', () {
    for (final similarity in [0.75, 1.0]) {
      final visualDelta = decoyVisualVariationCountForSimilarity(similarity);
      expect(visualDelta, 1);
      for (var seed = 0; seed < 12; seed++) {
        final round = buildRound(
          level: 6,
          random: math.Random(seed),
          decoySimilarity: similarity,
        );
        expectRoundShape(round, 6);
        for (final decoy in decoyChoicesOf(round)) {
          expect(
            snapshotPropertyDelta(round.baseline, decoy.appearance),
            1,
          );
          expect(
            classifySingleVisualDiff(round.baseline, decoy.appearance),
            isNotNull,
          );
        }
      }
    }
  });

  test('similarity 1.0 rotates single-diff kinds on snapshots', () {
    for (final level in [4, 6, 19]) {
      final decoyCount = choiceCountForLevel(level) - 1;
      for (var seed = 0; seed < 24; seed++) {
        final round = buildRound(
          level: level,
          random: math.Random(seed),
          decoySimilarity: 1,
        );
        expectRoundShape(round, level);
        final kinds = <SingleVisualDiffKind>{};
        for (final decoy in decoyChoicesOf(round)) {
          expect(snapshotPropertyDelta(round.baseline, decoy.appearance), 1);
          expect(decoy.singleDiffKind, isNotNull);
          kinds.add(decoy.singleDiffKind!);
          expect(
            classifySingleVisualDiff(round.baseline, decoy.appearance),
            decoy.singleDiffKind,
          );
        }
        expect(kinds.length, greaterThan(1));
        if (decoyCount >= 7) {
          expect(kinds.length, greaterThanOrEqualTo(4));
        }
      }
    }
  });
}

int _unchangedFields(Assembly original, Assembly decoy) {
  var count = 0;
  if (original.body == decoy.body) count += 1;
  if (original.top == decoy.top) count += 1;
  if (original.side == decoy.side) count += 1;
  if (original.hole == decoy.hole) count += 1;
  if (original.color == decoy.color) count += 1;
  if (original.pulse == decoy.pulse) count += 1;
  return count;
}

List<Assembly> decoyAssembliesOf(BuiltRound round) => [
      for (final choice in round.choices)
        if (choice.appearance != round.baseline) choice.assembly,
    ];

List<RoundChoice> decoyChoicesOf(BuiltRound round) => [
      for (final choice in round.choices)
        if (choice.appearance != round.baseline) choice,
    ];

void expectRoundShape(BuiltRound round, int level) {
  expect(round.choiceCount, choiceCountForLevel(level));
  expect(round.indexOfOriginal(), greaterThanOrEqualTo(0));
  expect(
    round.choices.map((c) => c.appearance).toSet(),
    hasLength(round.choices.length),
  );
  for (final choice in round.choices) {
    expect(choice.assembly.isLegal, isTrue);
    if (choice.appearance == round.baseline) continue;
    expect(choice.appearance, isNot(round.baseline));
  }
}
