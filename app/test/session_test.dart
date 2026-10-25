import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:gizmo/game/session.dart';
import 'package:gizmo_rules/gizmo_rules.dart';

void main() {
  test('three misses end the run and the transcript is valid', () {
    final session = GameSession(random: Random(3));
    var finished = false;
    for (var turn = 0; turn < 3; turn++) {
      final round = session.deal();
      expect(round.choiceCount, choiceCountForScore(session.score));
      finished = session.answer(round: round, correct: false);
    }
    expect(finished, isTrue);
    expect(session.score, 0);
    expect(session.chances, 0);
    final transcript = session.transcript('Paul');
    expect(validateSubmittedRun(transcript), isNull);
  });

  test('correct picks raise the score and do not refill chances', () {
    final session = GameSession(random: Random(4));
    final pattern = [true, true, false, true, false, false];
    var finished = false;
    for (final correct in pattern) {
      final round = session.deal();
      finished = session.answer(round: round, correct: correct);
    }
    expect(finished, isTrue);
    expect(session.score, 3);
    expect(session.chances, 0);
    expect(validateSubmittedRun(session.transcript('Ada')), isNull);
  });

  test('leaving before three misses is not a finished run', () {
    final session = GameSession(random: Random(5));
    final round = session.deal();
    session.answer(round: round, correct: true);
    expect(validateSubmittedRun(session.transcript('Paul')), 'wrong_count');
  });
}
