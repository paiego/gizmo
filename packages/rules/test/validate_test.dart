import 'dart:math';

import 'package:gizmo_rules/gizmo_rules.dart';
import 'package:test/test.dart';

void main() {
  test('a played transcript is accepted', () {
    final run = play(answers: [true, true, false, true, false, false]);
    expect(run.score, 3);
    expect(run.rounds, hasLength(6));
    expect(validateSubmittedRun(run), isNull);
  });

  test('three misses and a score of zero is a finished run', () {
    final run = play(answers: [false, false, false]);
    expect(run.score, 0);
    expect(validateSubmittedRun(run), isNull);
  });

  test('rejects a transcript that breaks one rule', () {
    final run = play(answers: [true, false, false, false]);
    expect(validateSubmittedRun(run.copy(playerName: '  ')), 'invalid_name');
    expect(validateSubmittedRun(run.copy(score: -1)), 'invalid_score');
    expect(validateSubmittedRun(run.copy(score: 0)), 'score_mismatch');
    expect(
      validateSubmittedRun(
        SubmittedRun(
          playerName: 'Paul',
          score: 0,
          rounds: [
            run.rounds[1].copyWith(index: 0),
            run.rounds[2].copyWith(index: 1),
          ],
        ),
      ),
      'wrong_count',
    );
    expect(
      validateSubmittedRun(
        run.copy(
          rounds: [
            for (final round in run.rounds)
              round.index == 3 ? round.copyWith(index: 0) : round,
          ],
        ),
      ),
      'invalid_index',
    );
    expect(
      validateSubmittedRun(
        run.copy(
          rounds: [
            for (final round in run.rounds)
              round.index == 0 ? round.copyWith(body: 'circle') : round,
          ],
        ),
      ),
      'invalid_body',
    );
    expect(
      validateSubmittedRun(
        run.copy(
          rounds: [
            for (final round in run.rounds)
              round.index == 0
                  ? round.copyWith(topPart: 'none', sidePart: 'none')
                  : round,
          ],
        ),
      ),
      'invalid_parts',
    );
    expect(
      validateSubmittedRun(
        run.copy(
          rounds: [
            for (final round in run.rounds)
              round.index == 0 ? round.copyWith(choiceCount: 6) : round,
          ],
        ),
      ),
      'invalid_choice_count',
    );
  });

  test('choice count uses correct rounds before that index', () {
    final run = play(answers: [true, true, true, false, false, false]);
    expect(run.rounds[0].choiceCount, 3);
    expect(run.rounds[2].choiceCount, 3);
    expect(run.rounds[3].choiceCount, 4);
    expect(validateSubmittedRun(run), isNull);

    final swapped = SubmittedRun(
      playerName: run.playerName,
      score: run.score,
      rounds: run.rounds.reversed.toList(),
    );
    expect(validateSubmittedRun(swapped), isNull);
  });
}

SubmittedRun play({required List<bool> answers}) {
  final random = Random(7);
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
        choiceCount: built.choiceCount,
        correct: correct,
      ),
    );
    if (correct) score += 1;
  }
  return SubmittedRun(playerName: 'Paul', score: score, rounds: rounds);
}

extension on SubmittedRun {
  SubmittedRun copy({
    String? playerName,
    int? score,
    List<SubmittedRound>? rounds,
  }) {
    return SubmittedRun(
      playerName: playerName ?? this.playerName,
      score: score ?? this.score,
      rounds: rounds ?? this.rounds,
    );
  }
}
