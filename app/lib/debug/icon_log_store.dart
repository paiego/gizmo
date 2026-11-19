import 'package:gizmo_rules/gizmo_rules.dart';

/// In-memory icon/decoy log for admin debug sessions only.
class IconLogStore {
  IconLogStore._();
  static final IconLogStore instance = IconLogStore._();

  final List<IconRoundLogEntry> entries = [];

  void clear() => entries.clear();

  void logDealtRound({
    required int level,
    required BuiltRound round,
  }) {
    entries.add(
      IconRoundLogEntry(
        level: level,
        dealtAt: DateTime.now(),
        original: round.original,
        baseline: round.baseline,
        choices: [
          for (var i = 0; i < round.choices.length; i++)
            IconChoiceLog(
              boardIndex: i,
              choice: round.choices[i],
              isBaselineAppearance:
                  round.choices[i].appearance == round.baseline,
            ),
        ],
      ),
    );
  }

  void markLastIncorrectTap(int tappedIndex) {
    if (entries.isEmpty) return;
    final last = entries.last;
    entries[entries.length - 1] = last.copyWith(
      incorrectTapIndex: tappedIndex,
    );
  }
}

class IconRoundLogEntry {
  const IconRoundLogEntry({
    required this.level,
    required this.dealtAt,
    required this.original,
    required this.baseline,
    required this.choices,
    this.incorrectTapIndex,
  });

  final int level;
  final DateTime dealtAt;
  final Assembly original;
  final IconSnapshot baseline;
  final List<IconChoiceLog> choices;
  final int? incorrectTapIndex;

  IconRoundLogEntry copyWith({int? incorrectTapIndex}) {
    return IconRoundLogEntry(
      level: level,
      dealtAt: dealtAt,
      original: original,
      baseline: baseline,
      choices: choices,
      incorrectTapIndex: incorrectTapIndex ?? this.incorrectTapIndex,
    );
  }
}

class IconChoiceLog {
  const IconChoiceLog({
    required this.boardIndex,
    required this.choice,
    required this.isBaselineAppearance,
  });

  final int boardIndex;
  final RoundChoice choice;
  final bool isBaselineAppearance;
}