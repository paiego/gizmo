import 'dart:math';

import 'grammar.dart';
import 'icon_shapes.dart';

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
const double colorDecoyScale = 25;

/// How many catalog fields a decoy changes at [level].
///
/// Used only when [buildRound] is called with `levelBasedProximity: true`.
/// Each decoy is the original with exactly this many fields replaced.
/// The count steps down on the same bands as [choiceCountForLevel], so a
/// higher level is a closer copy.
///
/// * Levels 1–3: 4 fields.
/// * Levels 4–6: 3 fields.
/// * Levels 7–10: 2 fields.
/// * Levels 11 and up: 1 field.
int decoyVariationCount(int level) {
  if (level < 1) {
    throw ArgumentError.value(level, 'level', 'Level starts at 1.');
  }
  if (level <= 3) return 4;
  if (level <= 6) return 3;
  if (level <= 10) return 2;
  return 1;
}

/// Largest RGB distance allowed when a level-based mutation changes color.
///
/// Used only when [buildRound] is called with `levelBasedProximity: true`.
/// Levels 1–6 may use any other catalog color. Later levels pull that
/// color toward the original, down to about 60 RGB from level 19.
double maxMutationColorDistance(int level) {
  if (level < 1) {
    throw ArgumentError.value(level, 'level', 'Level starts at 1.');
  }
  if (level <= 6) return double.infinity;
  if (level <= 10) return 220;
  if (level <= 14) return 160;
  if (level <= 18) return 110;
  return 60;
}

/// How many catalog fields [decoySimilarity] changes. Level is not an input.
///
/// [decoySimilarity] is clamped to 0..1. 0 is the wide baseline (4 fields).
/// 1 changes a single field. The steps are 4, 3, 2, and 1 at 0, 0.25, 0.5,
/// and 0.75.
int decoyVariationCountForSimilarity(double decoySimilarity) {
  final similarity = _clampSimilarity(decoySimilarity);
  if (similarity >= 0.75) return 1;
  if (similarity >= 0.5) return 2;
  if (similarity >= 0.25) return 3;
  return 4;
}

/// Largest RGB distance when a similarity mutation changes color.
///
/// 0 allows any other catalog color. Values near 1 use ring neighbors only;
/// just below that, about 60 RGB. In between, the cap falls linearly from
/// 320 to 60. Level does not enter this.
double maxMutationColorDistanceForSimilarity(double decoySimilarity) {
  final similarity = _clampSimilarity(decoySimilarity);
  if (similarity <= 0) return double.infinity;
  return 60 + (1 - similarity) * 260;
}

double _clampSimilarity(double decoySimilarity) {
  if (decoySimilarity.isNaN) return 0;
  return decoySimilarity.clamp(0.0, 1.0);
}

/// Highest level the ramp targets before it stays at [endSimilarity].
const int decoySimilarityRampMaxLevel = 19;

/// Slider values at 1 mean instant max (infinite ramp slope).
const double _instantRampSlopeThreshold = 0.999;

/// Fraction of the start→max span applied at [level] when ramping (0..1).
///
/// [rampSlope] is 0..1 from the profile UI. 0 keeps progress at zero (flat at
/// start similarity). 1 jumps to max on the first level. Values in between use
/// an exponential curve across levels up to [maxLevel].
double decoySimilarityRampProgress({
  required int level,
  required double rampSlope,
  int maxLevel = decoySimilarityRampMaxLevel,
}) {
  if (level < 1) {
    throw ArgumentError.value(level, 'level', 'Level starts at 1.');
  }
  if (maxLevel < 1) {
    throw ArgumentError.value(maxLevel, 'maxLevel', 'maxLevel starts at 1.');
  }
  final slope = _clampSimilarity(rampSlope);
  if (slope <= 0) return 0;
  if (slope >= _instantRampSlopeThreshold) return 1;
  if (level >= maxLevel || maxLevel == 1) return 1;
  final t = (level - 1) / (maxLevel - 1);
  if (t <= 0) return 0;
  final k = 0.25 + slope * 15;
  final scaled = exp(k * t) - 1;
  final full = exp(k) - 1;
  return (scaled / full).clamp(0.0, 1.0);
}

/// Active decoy similarity for a round at [level].
///
/// When [levelBasedProximity] is false, returns [startSimilarity] only. When
/// true, interpolates from [startSimilarity] to [endSimilarity] using
/// [rampSlope] and [maxLevel].
double activeDecoySimilarityForLevel({
  required int level,
  required double startSimilarity,
  required double endSimilarity,
  required double rampSlope,
  required bool levelBasedProximity,
  int maxLevel = decoySimilarityRampMaxLevel,
}) {
  final start = _clampSimilarity(startSimilarity);
  if (!levelBasedProximity) return start;
  final end = _clampSimilarity(endSimilarity);
  final progress = decoySimilarityRampProgress(
    level: level,
    rampSlope: rampSlope,
    maxLevel: maxLevel,
  );
  return start + (end - start) * progress;
}

/// Slider values near 1.0 may sit slightly below one because of floats.
const double _maxSimilarityThreshold = 0.999;

bool _isMaxSimilarity(double decoySimilarity) {
  return _clampSimilarity(decoySimilarity) >= _maxSimilarityThreshold;
}

/// When similarity is high, decoys should differ in rendered properties, not
/// raw catalog field counts.
bool _useVisualProximity(
  double decoySimilarity,
  bool levelBasedProximity,
) {
  return !levelBasedProximity && _clampSimilarity(decoySimilarity) >= 0.75;
}

/// Target [visualPropertyDelta] for a decoy at [decoySimilarity].
int decoyVisualVariationCountForSimilarity(double decoySimilarity) {
  final similarity = _clampSimilarity(decoySimilarity);
  if (similarity >= _maxSimilarityThreshold) return 1;
  if (similarity >= 0.75) return 1;
  if (similarity >= 0.5) return 3;
  if (similarity >= 0.25) return 6;
  return 10;
}

/// How far [decoy] sits from [original].
///
/// A changed body adds [bodyDecoyWeight], top [topDecoyWeight], side
/// [sideDecoyWeight], hole [holeDecoyWeight], and pulse [pulseDecoyWeight].
/// A changed color adds [colorDistance] / [colorDecoyScale]. Zero is the
/// same icon.
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

/// The original icon and the shuffled choices, which include the original.
class BuiltRound {
  const BuiltRound({required this.original, required this.choices});

  final Assembly original;
  final List<Assembly> choices;

  int get choiceCount => choices.length;
}

/// Draws a round for [level].
///
/// The original is one of [BuiltRound.choices]. Choice count still follows
/// [level]. Closeness follows [activeDecoySimilarityForLevel] from profile
/// settings unless [levelBasedProximity] is false, in which case only
/// [decoySimilarity] applies.
///
/// Below 0.75 active similarity, [decoyVariationCountForSimilarity] catalog-field
/// mutations apply. From 0.75 up, decoys use a fixed [visualPropertyDelta]
/// from the original (1 at 0.75 and 1.0).
///
/// With level-based proximity on, [decoySimilarity] is the start value,
/// [decoySimilarityMax] the end value, and [decoySimilarityRampSlope] the ramp
/// (0 flat, 1 instant max). Those produce the active similarity at [level].
BuiltRound buildRound({
  required int level,
  Random? random,
  double decoySimilarity = 0,
  double decoySimilarityMax = 1,
  double decoySimilarityRampSlope = 0.5,
  bool levelBasedProximity = false,
}) {
  final rng = random ?? Random();
  final original = _randomOriginal(rng);
  final effectiveSimilarity = activeDecoySimilarityForLevel(
    level: level,
    startSimilarity: decoySimilarity,
    endSimilarity: decoySimilarityMax,
    rampSlope: decoySimilarityRampSlope,
    levelBasedProximity: levelBasedProximity,
  );
  final changes = decoyVariationCountForSimilarity(effectiveSimilarity);
  final colorCap = maxMutationColorDistanceForSimilarity(effectiveSimilarity);
  final decoys = _useVisualProximity(effectiveSimilarity, false)
      ? _mutateOriginalVisual(
          original,
          level,
          rng,
          decoyVisualVariationCountForSimilarity(effectiveSimilarity),
          colorCap,
          preferAdjacentColor: _isMaxSimilarity(effectiveSimilarity),
        )
      : _mutateOriginal(
          original,
          level,
          rng,
          changes,
          colorCap,
          decoySimilarity: effectiveSimilarity,
          levelBasedProximity: false,
        );
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

enum _Field { body, top, side, hole, color, pulse }

List<Assembly> _mutateOriginalVisual(
  Assembly original,
  int level,
  Random rng,
  int visualDelta,
  double colorCap, {
  bool preferAdjacentColor = false,
}) {
  final pool = _visualMutations(original, visualDelta, colorCap);
  pool.shuffle(rng);
  pool.sort((a, b) {
    final deltaA = visualPropertyDelta(original, a);
    final deltaB = visualPropertyDelta(original, b);
    if (deltaA != deltaB) return deltaA.compareTo(deltaB);
    if (preferAdjacentColor) {
      final colorA = _colorPickRank(original, a);
      final colorB = _colorPickRank(original, b);
      if (colorA != colorB) return colorA.compareTo(colorB);
    }
    return decoyDistance(original, a).compareTo(decoyDistance(original, b));
  });
  final count = choiceCountForLevel(level) - 1;
  final picked = <Assembly>[];
  final used = <Assembly>{original};
  for (final candidate in pool) {
    if (!used.add(candidate)) continue;
    picked.add(candidate);
    if (picked.length == count) return picked;
  }
  throw StateError(
    'Only ${picked.length} visual mutations with delta $visualDelta for '
    '$original at level $level.',
  );
}

List<Assembly> _visualMutations(
  Assembly original,
  int visualDelta,
  double colorCap,
) {
  final found = <Assembly>[];
  for (final candidate in legalAssemblies()) {
    if (candidate == original) continue;
    if (visualPropertyDelta(original, candidate) != visualDelta) continue;
    if (!_visualMutationColorAllowed(original, candidate, colorCap)) continue;
    found.add(candidate);
  }
  return found;
}

bool _visualMutationColorAllowed(
  Assembly original,
  Assembly candidate,
  double colorCap,
) {
  if (original.color == candidate.color) return true;
  if (decoyFieldChanges(original, candidate) == 1) {
    return true;
  }
  return colorDistance(original.color, candidate.color) <= colorCap;
}

/// Lower is closer. Ring neighbors beat distant palette colors.
int _colorPickRank(Assembly original, Assembly candidate) {
  if (original.color == candidate.color) return 0;
  if (adjacentColors(original.color).contains(candidate.color)) return 1;
  return 100 + colorDistance(original.color, candidate.color).round();
}

/// Legal mutations of [original] that change exactly [changes] fields.
///
/// [level] chooses how many decoys to keep. It does not choose [changes]
/// or [colorCap]; the caller does.
List<Assembly> _mutateOriginal(
  Assembly original,
  int level,
  Random rng,
  int changes,
  double colorCap, {
  double decoySimilarity = 0,
  bool levelBasedProximity = false,
}) {
  final tightColor = !levelBasedProximity && _isMaxSimilarity(decoySimilarity);
  final pool = _mutations(
    original,
    changes,
    colorCap,
    tightColor: tightColor,
  );
  if (!levelBasedProximity &&
      _clampSimilarity(decoySimilarity) >= 0.75) {
    _sortMutationsByProximity(original, pool, rng);
  } else {
    pool.shuffle(rng);
  }
  final count = choiceCountForLevel(level) - 1;
  final picked = <Assembly>[];
  final used = <Assembly>{original};
  for (final candidate in pool) {
    if (!used.add(candidate)) continue;
    picked.add(candidate);
    if (picked.length == count) return picked;
  }
  throw StateError(
    'Only ${picked.length} mutations of $changes fields within color '
    '$colorCap for $original at level $level.',
  );
}

void _sortMutationsByProximity(
  Assembly original,
  List<Assembly> pool,
  Random rng,
) {
  pool.shuffle(rng);
  pool.sort(
    (a, b) => decoyDistance(original, a).compareTo(decoyDistance(original, b)),
  );
}

List<Assembly> _mutations(
  Assembly original,
  int changes,
  double colorCap, {
  bool tightColor = false,
}) {
  final found = <Assembly>[];
  for (final combo in _combinations(changes)) {
    final options = [
      for (final field in combo)
        _alternatives(original, field, colorCap, tightColor: tightColor),
    ];
    if (options.any((values) => values.isEmpty)) continue;
    void walk(int index, Map<_Field, Object> picked) {
      if (index == combo.length) {
        final candidate = _assemble(original, picked);
        if (candidate.isLegal && candidate != original) found.add(candidate);
        return;
      }
      for (final value in options[index]) {
        picked[combo[index]] = value;
        walk(index + 1, picked);
      }
      picked.remove(combo[index]);
    }

    walk(0, {});
  }
  return found;
}

List<List<_Field>> _combinations(int count) {
  final fields = _Field.values;
  final out = <List<_Field>>[];
  void walk(int start, List<_Field> picked) {
    if (picked.length == count) {
      out.add(List.of(picked));
      return;
    }
    for (var i = start; i < fields.length; i++) {
      picked.add(fields[i]);
      walk(i + 1, picked);
      picked.removeLast();
    }
  }

  walk(0, []);
  return out;
}

List<Object> _alternatives(
  Assembly original,
  _Field field,
  double colorCap, {
  bool tightColor = false,
}) {
  switch (field) {
    case _Field.body:
      return [
        for (final value in BodyId.values)
          if (value != original.body) value
      ];
    case _Field.top:
      return [
        for (final value in TopId.values)
          if (value != original.top) value
      ];
    case _Field.side:
      return [
        for (final value in SideId.values)
          if (value != original.side) value
      ];
    case _Field.hole:
      return [
        for (final value in HoleId.values)
          if (value != original.hole) value
      ];
    case _Field.pulse:
      return [
        for (final value in PulseId.values)
          if (value != original.pulse) value
      ];
    case _Field.color:
      if (tightColor) {
        return [
          for (final value in adjacentColors(original.color))
            if (value != original.color) value,
        ];
      }
      return [
        for (final value in ColorId.values)
          if (value != original.color &&
              colorDistance(original.color, value) <= colorCap)
            value,
      ];
  }
}

Assembly _assemble(Assembly original, Map<_Field, Object> changes) {
  return Assembly(
    body: changes[_Field.body] as BodyId? ?? original.body,
    top: changes[_Field.top] as TopId? ?? original.top,
    side: changes[_Field.side] as SideId? ?? original.side,
    hole: changes[_Field.hole] as HoleId? ?? original.hole,
    color: changes[_Field.color] as ColorId? ?? original.color,
    pulse: changes[_Field.pulse] as PulseId? ?? original.pulse,
  );
}
