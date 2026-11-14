import 'dart:math';

import 'package:gizmo_rules/gizmo_rules.dart';

class PlayedRound {
  const PlayedRound({
    required this.index,
    required this.assembly,
    required this.choiceCount,
    required this.correct,
  });

  final int index;
  final Assembly assembly;
  final int choiceCount;
  final bool correct;
}

/// One run. Chances start at three and do not refill.
class GameSession {
  GameSession({
    Random? random,
    this.adminMode = false,
    this.decoySimilarity = 0,
    this.decoySimilarityMax = 1,
    this.decoySimilarityRampSlope = 0.5,
    this.levelBasedProximity = false,
  }) : _random = random ?? Random();

  final Random _random;

  /// Misses do not end the run.
  final bool adminMode;

  /// Start similarity; see [levelBasedProximity].
  final double decoySimilarity;
  final double decoySimilarityMax;
  final double decoySimilarityRampSlope;

  /// When false, [decoySimilarity] alone sets how close decoys are.
  final bool levelBasedProximity;
  final List<PlayedRound> rounds = [];
  int score = 0;

  /// Starts at 1 and steps up once per finished round. A queued value replaces
  /// that step for the next round. Difficulty follows this, not [score].
  int level = 1;
  int chances = 3;
  int? _queuedLevel;

  BuiltRound deal() {
    for (var attempt = 0; attempt < 12; attempt++) {
      final round = buildRound(
        level: level,
        random: _random,
        decoySimilarity: decoySimilarity,
        decoySimilarityMax: decoySimilarityMax,
        decoySimilarityRampSlope: decoySimilarityRampSlope,
        levelBasedProximity: levelBasedProximity,
      );
      if (_decoysDiffer(round)) return round;
    }
    throw StateError('Decoy equals the original.');
  }

  /// The next finished round moves to [value] instead of stepping up by one.
  void queueLevel(int value) {
    if (value < 1) {
      throw ArgumentError.value(value, 'value', 'Level starts at 1.');
    }
    _queuedLevel = value;
  }

  void clearQueuedLevel() {
    _queuedLevel = null;
  }

  bool _decoysDiffer(BuiltRound round) {
    for (final choice in round.choices) {
      if (choice.appearance == round.baseline) continue;
      if (samePictureSnapshots(choice.appearance, round.baseline)) {
        return false;
      }
    }
    return true;
  }

  /// Records the pick. Returns true when the run is over.
  bool answer({required BuiltRound round, required bool correct}) {
    rounds.add(
      PlayedRound(
        index: rounds.length,
        assembly: round.original,
        choiceCount: round.choiceCount,
        correct: correct,
      ),
    );
    if (correct) {
      score += 1;
    } else if (!adminMode) {
      chances -= 1;
    }
    final queued = _queuedLevel;
    if (queued != null) {
      level = queued;
      _queuedLevel = null;
    } else {
      level += 1;
    }
    return !adminMode && chances == 0;
  }

  SubmittedRun transcript(String playerName) {
    return SubmittedRun(
      playerName: playerName,
      score: score,
      rounds: [
        for (final round in rounds)
          SubmittedRound(
            index: round.index,
            body: round.assembly.body.name,
            topPart: round.assembly.top.name,
            sidePart: round.assembly.side.name,
            hole: round.assembly.hole.name,
            color: round.assembly.color.name,
            pulse: round.assembly.pulse.name,
            choiceCount: round.choiceCount,
            correct: round.correct,
          ),
      ],
    );
  }
}
