import 'dart:math';

import 'grammar.dart';

/// How many choices a round shows for the score at the start of that round.
int choiceCountForScore(int score) {
  if (score < 0) {
    throw ArgumentError.value(score, 'score', 'Score cannot be negative.');
  }
  if (score <= 2) return 3;
  if (score <= 5) return 4;
  if (score <= 9) return 5;
  return 6;
}

/// The original icon and the shuffled choices, which include the original.
class BuiltRound {
  const BuiltRound({required this.original, required this.choices});

  final Assembly original;
  final List<Assembly> choices;

  int get choiceCount => choices.length;
}

enum _Slot { top, side, hole }

/// Draws a round for [scoreSoFar].
///
/// The original is one of [BuiltRound.choices]. Each other icon follows the
/// band for that score. A decoy is never equal to the original, and an
/// assembly appears at most once.
BuiltRound buildRound({required int scoreSoFar, Random? random}) {
  final rng = random ?? Random();
  final original = _randomOriginal(rng);
  final used = <Assembly>{original};
  final List<Assembly> decoys;
  if (scoreSoFar <= 2) {
    decoys = [
      _earlyDecoy(original, used, rng),
      _earlyDecoy(original, used, rng),
    ];
  } else if (scoreSoFar <= 5) {
    decoys = [
      _keepBodySlotColor(original, used, rng),
      _bodyOnly(original, used, rng),
      _bodySlotColor(original, used, rng),
    ];
  } else if (scoreSoFar <= 9) {
    decoys = [
      ..._colorTwins(original, used),
      for (final slot in _twoSlots(rng)) _oneSlot(original, used, rng, slot),
    ];
  } else {
    decoys = [
      ..._colorTwins(original, used),
      for (final slot in _Slot.values) _oneSlot(original, used, rng, slot),
    ];
  }
  final expected = choiceCountForScore(scoreSoFar);
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

List<Assembly> _colorTwins(Assembly original, Set<Assembly> used) {
  final twins = <Assembly>[];
  for (final color in adjacentColors(original.color)) {
    final candidate = original.copyWith(color: color);
    if (!used.add(candidate)) {
      throw StateError('Adjacent color collided with $candidate.');
    }
    twins.add(candidate);
  }
  return twins;
}

Assembly _oneSlot(
  Assembly original,
  Set<Assembly> used,
  Random rng,
  _Slot slot,
) {
  final options = _slotValues(original, slot)..shuffle(rng);
  for (final value in options) {
    final candidate = _applySlot(original, slot, value);
    if (used.add(candidate)) return candidate;
  }
  return _slotWithExtra(original, used, rng, slot);
}

/// The strict slot was taken. Change that slot and one other catalog value.
Assembly _slotWithExtra(
  Assembly original,
  Set<Assembly> used,
  Random rng,
  _Slot slot,
) {
  final extras = _Slot.values.where((other) => other != slot).toList()
    ..shuffle(rng);
  for (final extra in extras) {
    for (final first in _slotValues(original, slot)..shuffle(rng)) {
      final once = _applySlot(original, slot, first);
      for (final second in _slotValues(once, extra)..shuffle(rng)) {
        final candidate = _applySlot(once, extra, second);
        if (used.add(candidate)) return candidate;
      }
    }
  }
  throw StateError('No legal change for $slot on $original.');
}

Assembly _keepBodySlotColor(Assembly original, Set<Assembly> used, Random rng) {
  final slots = _Slot.values.toList()..shuffle(rng);
  final colors = nonAdjacentColors(original.color)..shuffle(rng);
  for (final slot in slots) {
    for (final value in _slotValues(original, slot)..shuffle(rng)) {
      for (final color in colors) {
        final candidate = _applySlot(
          original,
          slot,
          value,
        ).copyWith(color: color);
        if (used.add(candidate)) return candidate;
      }
    }
  }
  throw StateError('No keep-body decoy for $original.');
}

Assembly _bodyOnly(Assembly original, Set<Assembly> used, Random rng) {
  final bodies = BodyId.values.where((body) => body != original.body).toList()
    ..shuffle(rng);
  for (final body in bodies) {
    final candidate = original.copyWith(body: body);
    if (used.add(candidate)) return candidate;
  }
  // The other bodies were taken. Change one slot as the extra catalog value
  // and keep the color.
  final slots = _Slot.values.toList()..shuffle(rng);
  for (final body in bodies) {
    final shifted = original.copyWith(body: body);
    for (final slot in slots) {
      for (final value in _slotValues(shifted, slot)..shuffle(rng)) {
        final candidate = _applySlot(shifted, slot, value);
        if (used.add(candidate)) return candidate;
      }
    }
  }
  throw StateError('No body-only decoy for $original.');
}

Assembly _bodySlotColor(Assembly original, Set<Assembly> used, Random rng) {
  final bodies = BodyId.values.where((body) => body != original.body).toList()
    ..shuffle(rng);
  final slots = _Slot.values.toList()..shuffle(rng);
  final colors = nonAdjacentColors(original.color)..shuffle(rng);
  for (final body in bodies) {
    final shifted = original.copyWith(body: body);
    for (final slot in slots) {
      for (final value in _slotValues(shifted, slot)..shuffle(rng)) {
        for (final color in colors) {
          final candidate = _applySlot(
            shifted,
            slot,
            value,
          ).copyWith(color: color);
          if (!candidate.isLegal) continue;
          if (used.add(candidate)) return candidate;
        }
      }
    }
  }
  throw StateError('No body-and-slot decoy for $original.');
}

Assembly _earlyDecoy(Assembly original, Set<Assembly> used, Random rng) {
  final bodies = BodyId.values.where((body) => body != original.body).toList();
  final colors = nonAdjacentColors(original.color);
  for (var attempt = 0; attempt < 80; attempt++) {
    final candidate = _randomEarly(
      original,
      rng,
      bodies: bodies,
      colors: colors,
      changeHole: attempt >= 40,
    );
    if (!candidate.isLegal) continue;
    if (candidate.top == original.top && candidate.side == original.side) {
      continue;
    }
    if (used.add(candidate)) return candidate;
  }
  return _exhaustiveEarly(original, used, rng);
}

Assembly _randomEarly(
  Assembly original,
  Random rng, {
  required List<BodyId> bodies,
  required List<ColorId> colors,
  required bool changeHole,
}) {
  final mode = rng.nextInt(3);
  var top = original.top;
  var side = original.side;
  if (mode != 1) top = _pickOther(TopId.values, top, rng);
  if (mode != 0) side = _pickOther(SideId.values, side, rng);
  if (top == TopId.none && side == SideId.none) {
    if (rng.nextBool()) {
      top = _pick(const [TopId.knob, TopId.horn, TopId.loop], rng);
    } else {
      side = _pick(const [SideId.tab, SideId.handle, SideId.wing], rng);
    }
  }
  return Assembly(
    body: bodies[rng.nextInt(bodies.length)],
    top: top,
    side: side,
    hole: changeHole
        ? _pickOther(HoleId.values, original.hole, rng)
        : original.hole,
    color: colors[rng.nextInt(colors.length)],
    pulse: original.pulse,
  );
}

Assembly _exhaustiveEarly(Assembly original, Set<Assembly> used, Random rng) {
  final candidates = <Assembly>[
    for (final body in BodyId.values)
      if (body != original.body)
        for (final color in nonAdjacentColors(original.color))
          for (final top in TopId.values)
            for (final side in SideId.values)
              if ((top != TopId.none || side != SideId.none) &&
                  (top != original.top || side != original.side))
                for (final hole in HoleId.values)
                  Assembly(
                    body: body,
                    top: top,
                    side: side,
                    hole: hole,
                    color: color,
                    pulse: original.pulse,
                  ),
  ]..shuffle(rng);
  for (final candidate in candidates) {
    if (used.add(candidate)) return candidate;
  }
  throw StateError('Early decoy space exhausted for $original.');
}

List<Enum> _slotValues(Assembly assembly, _Slot slot) {
  switch (slot) {
    case _Slot.top:
      return [
        for (final top in TopId.values)
          if (top != assembly.top &&
              (top != TopId.none || assembly.side != SideId.none))
            top,
      ];
    case _Slot.side:
      return [
        for (final side in SideId.values)
          if (side != assembly.side &&
              (assembly.top != TopId.none || side != SideId.none))
            side,
      ];
    case _Slot.hole:
      return [
        for (final hole in HoleId.values)
          if (hole != assembly.hole) hole,
      ];
  }
}

Assembly _applySlot(Assembly assembly, _Slot slot, Object value) {
  switch (slot) {
    case _Slot.top:
      return assembly.copyWith(top: value as TopId);
    case _Slot.side:
      return assembly.copyWith(side: value as SideId);
    case _Slot.hole:
      return assembly.copyWith(hole: value as HoleId);
  }
}

List<_Slot> _twoSlots(Random rng) {
  final slots = _Slot.values.toList()..shuffle(rng);
  return slots.take(2).toList();
}

T _pick<T>(List<T> values, Random rng) => values[rng.nextInt(values.length)];

T _pickOther<T>(List<T> values, T current, Random rng) {
  final others = values.where((value) => value != current).toList();
  return others[rng.nextInt(others.length)];
}
