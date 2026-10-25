import 'dart:math';

import 'package:gizmo_rules/gizmo_rules.dart';

SubmittedRun scriptedRun(String name, List<bool> answers, {int seed = 1}) {
  final random = Random(seed);
  final rounds = <SubmittedRound>[];
  var score = 0;
  for (final correct in answers) {
    final built = buildRound(scoreSoFar: score, random: random);
    rounds.add(
      SubmittedRound(
        index: rounds.length,
        body: built.original.body.name,
        topPart: built.original.top.name,
        sidePart: built.original.side.name,
        hole: built.original.hole.name,
        color: built.original.color.name,
        pulse: built.original.pulse.name,
        choiceCount: built.choiceCount,
        correct: correct,
      ),
    );
    if (correct) score += 1;
  }
  final run = SubmittedRun(playerName: name, score: score, rounds: rounds);
  final reason = validateSubmittedRun(run);
  if (reason != null) {
    throw StateError('Scripted run is not valid: $reason');
  }
  return run;
}
