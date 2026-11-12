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
const double colorDecoyScale = 25;

/// How many catalog fields a decoy changes at [level].
///
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

/// Largest RGB distance allowed when a mutation changes color.
///
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
/// The original is one of [BuiltRound.choices]. Every decoy is that same
/// assembly with [decoyVariationCount] fields replaced. A decoy is legal,
/// unique, and never equal to the original.
BuiltRound buildRound({required int level, Random? random}) {
  final rng = random ?? Random();
  final original = _randomOriginal(rng);
  final decoys = _mutateOriginal(original, level, rng);
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

/// Legal mutations of [original] that change exactly [decoyVariationCount]
/// fields. Shuffled, then trimmed to the decoy count for [level].
List<Assembly> _mutateOriginal(Assembly original, int level, Random rng) {
  final changes = decoyVariationCount(level);
  final colorCap = maxMutationColorDistance(level);
  final pool = _mutations(original, changes, colorCap)..shuffle(rng);
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

List<Assembly> _mutations(Assembly original, int changes, double colorCap) {
  final found = <Assembly>[];
  for (final combo in _combinations(changes)) {
    final options = [
      for (final field in combo) _alternatives(original, field, colorCap),
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

List<Object> _alternatives(Assembly original, _Field field, double colorCap) {
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
