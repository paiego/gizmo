import 'dart:math';

import 'grammar.dart';

/// How many choices a round shows. [level] starts at 1.
///
/// Levels 1–3 show 3 choices, 4–6 show 4, 7–10 show 5, 11–14 show 6,
/// 15–18 show 7, and 19 or more show 8 (seven decoys).
int choiceCountForLevel(int level) {
  if (level < 1) {
    throw ArgumentError.value(level, 'level', 'Level starts at 1.');
  }
  if (level <= 3) return 3;
  if (level <= 6) return 4;
  if (level <= 10) return 5;
  if (level <= 14) return 6;
  if (level <= 18) return 7;
  return 8;
}

/// Body, top, side, hole, and pulse weights inside [decoyDistance].
const double bodyDecoyWeight = 8;
const double topDecoyWeight = 3;
const double sideDecoyWeight = 3;
const double holeDecoyWeight = 2;
const double pulseDecoyWeight = 2;

/// RGB distance is divided by this before it is added to [decoyDistance].
///
/// The nearest catalog pair (orange/amber, about 46) contributes about 1.9.
/// The farthest pair (about 318) contributes about 12.7.
const double colorDecoyScale = 25;

/// How far [decoy] sits from [original].
///
/// A changed body adds [bodyDecoyWeight], top [topDecoyWeight], side
/// [sideDecoyWeight], hole [holeDecoyWeight], and pulse [pulseDecoyWeight].
/// A changed color adds [colorDistance] / [colorDecoyScale]. Zero is the
/// same icon. The smallest two-field change is hole plus pulse, weight 4.
double decoyDistance(Assembly original, Assembly decoy) {
  var distance = 0.0;
  if (original.body != decoy.body) distance += bodyDecoyWeight;
  if (original.top != decoy.top) distance += topDecoyWeight;
  if (original.side != decoy.side) distance += sideDecoyWeight;
  if (original.hole != decoy.hole) distance += holeDecoyWeight;
  if (original.pulse != decoy.pulse) distance += pulseDecoyWeight;
  if (original.color != decoy.color) {
    distance += colorDistance(original.color, decoy.color) / colorDecoyScale;
  }
  return distance;
}

/// How many catalog fields differ. Color counts as one field.
int decoyFieldChanges(Assembly original, Assembly decoy) {
  var count = 0;
  if (original.body != decoy.body) count += 1;
  if (original.top != decoy.top) count += 1;
  if (original.side != decoy.side) count += 1;
  if (original.hole != decoy.hole) count += 1;
  if (original.color != decoy.color) count += 1;
  if (original.pulse != decoy.pulse) count += 1;
  return count;
}

/// Largest [decoyDistance] a decoy may have at [level].
///
/// The steps match [choiceCountForLevel]. A round keeps the farthest legal
/// icons that still fit, so a higher level is a closer copy of the original.
///
/// * Levels 1–3 (32): body, top, side, hole, pulse, and a far color.
/// * Levels 4–6 (22): those parts only with a nearer color, or fewer parts.
/// * Levels 7–10 (14): a body plus two parts, or a body plus a mid color.
/// * Levels 11–14 (9): a body, a few small parts, or a mid color.
/// * Levels 15–18 (5): one part, or a color within about 125 RGB.
/// * Levels 19 and up (3.25): one of top, side, hole, or pulse, or a color
///   within 81 RGB. A body is 8 and the smallest two-part change is 4, so
///   neither fits.
double maxDecoyDistance(int level) {
  if (level < 1) {
    throw ArgumentError.value(level, 'level', 'Level starts at 1.');
  }
  if (level <= 3) return 32;
  if (level <= 6) return 22;
  if (level <= 10) return 14;
  if (level <= 14) return 9;
  if (level <= 18) return 5;
  return 3.25;
}

/// The original icon and the shuffled choices, which include the original.
class BuiltRound {
  const BuiltRound({required this.original, required this.choices});

  final Assembly original;
  final List<Assembly> choices;

  int get choiceCount => choices.length;
}

/// Draws a round for [level].
///
/// The original is one of [BuiltRound.choices]. Each decoy is legal, unique,
/// and within [maxDecoyDistance] of the original. Higher levels use a
/// smaller cap, so shape, color, and the other catalog fields sit closer
/// to the icon the player has to remember.
BuiltRound buildRound({required int level, Random? random}) {
  final rng = random ?? Random();
  final original = _randomOriginal(rng);
  final decoys = _decoysWithinCap(original, level, rng);
  final expected = choiceCountForLevel(level);
  if (decoys.length + 1 != expected) {
    throw StateError('Built ${decoys.length + 1} choices, expected $expected.');
  }
  _requireDecoysDiffer(original, decoys);
  final choices = <Assembly>[original, ...decoys]..shuffle(rng);
  return BuiltRound(original: original, choices: List.unmodifiable(choices));
}

void _requireDecoysDiffer(Assembly original, List<Assembly> decoys) {
  final seen = <Assembly>{};
  for (final decoy in decoys) {
    if (decoy == original) {
      throw StateError('Decoy equals the original ($original).');
    }
    if (!seen.add(decoy)) {
      throw StateError('Repeated decoy $decoy.');
    }
  }
}

Assembly _randomOriginal(Random rng) {
  final pairs = <(TopId, SideId)>[
    for (final top in TopId.values)
      for (final side in SideId.values)
        if (top != TopId.none || side != SideId.none) (top, side),
  ];
  final pair = pairs[rng.nextInt(pairs.length)];
  return Assembly(
    body: BodyId.values[rng.nextInt(BodyId.values.length)],
    top: pair.$1,
    side: pair.$2,
    hole: HoleId.values[rng.nextInt(HoleId.values.length)],
    color: ColorId.values[rng.nextInt(ColorId.values.length)],
    pulse: PulseId.values[rng.nextInt(PulseId.values.length)],
  );
}

/// Farthest legal icons that still fit under [maxDecoyDistance].
///
/// Shuffling before the stable sort keeps a tie from always picking the
/// same catalog order.
List<Assembly> _decoysWithinCap(Assembly original, int level, Random rng) {
  final cap = maxDecoyDistance(level);
  final pool = <(Assembly, double)>[];
  for (final candidate in _catalog()) {
    if (candidate == original) continue;
    final distance = decoyDistance(original, candidate);
    if (distance <= cap) pool.add((candidate, distance));
  }
  pool.shuffle(rng);
  pool.sort((a, b) => b.$2.compareTo(a.$2));
  final count = choiceCountForLevel(level) - 1;
  if (pool.length < count) {
    throw StateError(
      'Only ${pool.length} decoys within $cap of $original at level $level.',
    );
  }
  return [for (final scored in pool.take(count)) scored.$1];
}

Iterable<Assembly> _catalog() sync* {
  for (final body in BodyId.values) {
    for (final top in TopId.values) {
      for (final side in SideId.values) {
        if (top == TopId.none && side == SideId.none) continue;
        for (final hole in HoleId.values) {
          for (final color in ColorId.values) {
            for (final pulse in PulseId.values) {
              yield Assembly(
                body: body,
                top: top,
                side: side,
                hole: hole,
                color: color,
                pulse: pulse,
              );
            }
          }
        }
      }
    }
  }
}
