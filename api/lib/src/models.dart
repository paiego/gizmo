class SavedRun {
  const SavedRun({
    required this.runId,
    required this.playerName,
    required this.score,
    required this.personalBest,
    required this.isNewPersonalBest,
    required this.rank,
  });

  final String runId;
  final String playerName;
  final int score;
  final int personalBest;
  final bool isNewPersonalBest;
  final int rank;

  Map<String, Object?> toJson() => {
    'runId': runId,
    'playerName': playerName,
    'score': score,
    'personalBest': personalBest,
    'isNewPersonalBest': isNewPersonalBest,
    'rank': rank,
  };
}

class PlayerBest {
  const PlayerBest({
    required this.playerName,
    required this.bestScore,
    required this.bestAt,
    required this.runCount,
  });

  final String playerName;
  final int? bestScore;
  final DateTime? bestAt;
  final int runCount;

  Map<String, Object?> toJson() => {
    'playerName': playerName,
    'bestScore': bestScore,
    'bestAt': bestAt == null ? null : formatUtc(bestAt!),
    'runCount': runCount,
  };
}

class RunSummary {
  const RunSummary({
    required this.runId,
    required this.score,
    required this.playedAt,
  });

  final String runId;
  final int score;
  final DateTime playedAt;

  Map<String, Object?> toJson() => {
    'runId': runId,
    'score': score,
    'playedAt': formatUtc(playedAt),
  };
}

class BoardEntry {
  const BoardEntry({
    required this.rank,
    required this.playerName,
    required this.bestScore,
    required this.bestAt,
  });

  final int rank;
  final String playerName;
  final int bestScore;
  final DateTime bestAt;

  Map<String, Object?> toJson() => {
    'rank': rank,
    'playerName': playerName,
    'bestScore': bestScore,
    'bestAt': formatUtc(bestAt),
  };
}

String formatUtc(DateTime value) {
  final utc = value.toUtc();
  final iso = utc.toIso8601String();
  if (iso.endsWith('Z')) return iso;
  return '${iso}Z';
}
