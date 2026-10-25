import 'difficulty.dart';
import 'grammar.dart';
import 'names.dart';

/// One finished round, as the client sends it. Decoys are not included.
class SubmittedRound {
  const SubmittedRound({
    required this.index,
    required this.body,
    required this.topPart,
    required this.sidePart,
    required this.hole,
    required this.color,
    required this.pulse,
    required this.choiceCount,
    required this.correct,
  });

  final int index;
  final String body;
  final String topPart;
  final String sidePart;
  final String hole;
  final String color;
  final String pulse;
  final int choiceCount;
  final bool correct;

  SubmittedRound copyWith({
    int? index,
    String? body,
    String? topPart,
    String? sidePart,
    String? hole,
    String? color,
    String? pulse,
    int? choiceCount,
    bool? correct,
  }) {
    return SubmittedRound(
      index: index ?? this.index,
      body: body ?? this.body,
      topPart: topPart ?? this.topPart,
      sidePart: sidePart ?? this.sidePart,
      hole: hole ?? this.hole,
      color: color ?? this.color,
      pulse: pulse ?? this.pulse,
      choiceCount: choiceCount ?? this.choiceCount,
      correct: correct ?? this.correct,
    );
  }

  Map<String, Object?> toJson() => {
        'index': index,
        'body': body,
        'topPart': topPart,
        'sidePart': sidePart,
        'hole': hole,
        'color': color,
        'pulse': pulse,
        'choiceCount': choiceCount,
        'correct': correct,
      };
}

/// A finished run. It has exactly three incorrect rounds.
class SubmittedRun {
  const SubmittedRun({
    required this.playerName,
    required this.score,
    required this.rounds,
  });

  final String playerName;
  final int score;
  final List<SubmittedRound> rounds;

  Map<String, Object?> toJson() => {
        'playerName': playerName,
        'score': score,
        'rounds': [for (final round in rounds) round.toJson()],
      };
}

/// Returns a short reason when [run] breaks the rules, otherwise null.
///
/// Checks follow the API contract: name, score, the three misses, length,
/// indexes, grammar, attached parts, then the choice count for each score.
String? validateSubmittedRun(SubmittedRun run) {
  if (parsePlayerName(run.playerName) == null) return 'invalid_name';
  if (run.score < 0) return 'invalid_score';

  final correctCount = run.rounds.where((round) => round.correct).length;
  if (run.score != correctCount) return 'score_mismatch';

  final wrongCount = run.rounds.length - correctCount;
  if (wrongCount != 3) return 'wrong_count';

  if (run.rounds.length != run.score + 3) return 'round_count';

  final seen = <int>{};
  for (final round in run.rounds) {
    if (round.index < 0 ||
        round.index >= run.rounds.length ||
        !seen.add(round.index)) {
      return 'invalid_index';
    }
  }

  for (final round in run.rounds) {
    if (parseBody(round.body) == null) return 'invalid_body';
    if (parseTop(round.topPart) == null) return 'invalid_top';
    if (parseSide(round.sidePart) == null) return 'invalid_side';
    if (parseHole(round.hole) == null) return 'invalid_hole';
    if (parseColor(round.color) == null) return 'invalid_color';
    if (parsePulse(round.pulse) == null) return 'invalid_pulse';
    if (round.topPart == 'none' && round.sidePart == 'none') {
      return 'invalid_parts';
    }
  }

  final ordered = List<SubmittedRound>.generate(
    run.rounds.length,
    (index) => run.rounds.firstWhere((round) => round.index == index),
  );
  var priorCorrect = 0;
  for (final round in ordered) {
    if (round.choiceCount != choiceCountForScore(priorCorrect)) {
      return 'invalid_choice_count';
    }
    if (round.correct) priorCorrect += 1;
  }
  return null;
}
