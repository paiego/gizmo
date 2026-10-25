import 'dart:math';

import 'package:gizmo_rules/gizmo_rules.dart';

import '../widgets/icon_paths.dart';

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
  GameSession({Random? random}) : _random = random ?? Random();

  final Random _random;
  final List<PlayedRound> rounds = [];
  int score = 0;
  int chances = 3;

  BuiltRound deal() {
    for (var attempt = 0; attempt < 12; attempt++) {
      final round = buildRound(scoreSoFar: score, random: _random);
      if (_decoysDiffer(round)) return round;
    }
    throw StateError('Decoy equals the original.');
  }

  bool _decoysDiffer(BuiltRound round) {
    for (final choice in round.choices) {
      if (choice == round.original) continue;
      if (samePicture(choice, round.original)) return false;
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
    } else {
      chances -= 1;
    }
    return chances == 0;
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
