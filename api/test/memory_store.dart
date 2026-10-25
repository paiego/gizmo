import 'package:gizmo_api/gizmo_api.dart';
import 'package:gizmo_rules/gizmo_rules.dart';

class MemoryStore implements GizmoStore {
  MemoryStore({DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;
  final Map<String, _Player> _players = {};
  var _ids = 0;

  @override
  Future<SavedRun> insertRun(SubmittedRun run) async {
    final name = parsePlayerName(run.playerName)!;
    final player = _players.putIfAbsent(name.key, () => _Player(name.display));
    final previous = player.bestScore;
    final isNew = previous == null || run.score > previous;
    final id = 'run-${_ids++}';
    player.runs.add(_StoredRun(id, run.score, _clock()));
    return SavedRun(
      runId: id,
      playerName: player.display,
      score: run.score,
      personalBest: player.bestScore!,
      isNewPersonalBest: isNew,
      rank: _rankOf(name.key),
    );
  }

  @override
  Future<PlayerBest> best(PlayerName name) async {
    final player = _players[name.key];
    if (player == null) {
      return PlayerBest(
        playerName: name.display,
        bestScore: null,
        bestAt: null,
        runCount: 0,
      );
    }
    return PlayerBest(
      playerName: player.display,
      bestScore: player.bestScore,
      bestAt: player.bestAt,
      runCount: player.runs.length,
    );
  }

  @override
  Future<List<RunSummary>> runs(PlayerName name, {required int limit}) async {
    final player = _players[name.key];
    if (player == null) return const [];
    final newest = [...player.runs]
      ..sort((a, b) => b.playedAt.compareTo(a.playedAt));
    return [
      for (final run in newest.take(limit))
        RunSummary(runId: run.id, score: run.score, playedAt: run.playedAt),
    ];
  }

  @override
  Future<List<BoardEntry>> leaderboard({required int limit}) async {
    final ranked = _ranked();
    return [
      for (var i = 0; i < ranked.length && i < limit; i++)
        BoardEntry(
          rank: i + 1,
          playerName: ranked[i].display,
          bestScore: ranked[i].bestScore!,
          bestAt: ranked[i].bestAt!,
        ),
    ];
  }

  @override
  Future<void> close() async {}

  int _rankOf(String key) {
    final ranked = _ranked();
    return ranked.indexWhere((player) => player.key == key) + 1;
  }

  List<_Player> _ranked() {
    final players = _players.values.toList()
      ..sort((a, b) {
        final byScore = b.bestScore!.compareTo(a.bestScore!);
        if (byScore != 0) return byScore;
        final byTime = a.bestAt!.compareTo(b.bestAt!);
        if (byTime != 0) return byTime;
        return a.display.compareTo(b.display);
      });
    return players;
  }
}

class _Player {
  _Player(this.display) : key = display.toLowerCase();

  final String key;
  final String display;
  final List<_StoredRun> runs = [];

  int? get bestScore {
    if (runs.isEmpty) return null;
    return runs.map((run) => run.score).reduce((a, b) => a > b ? a : b);
  }

  DateTime? get bestAt {
    final best = bestScore;
    if (best == null) return null;
    final times = [
      for (final run in runs)
        if (run.score == best) run.playedAt,
    ];
    return times.reduce((a, b) => a.isBefore(b) ? a : b);
  }
}

class _StoredRun {
  const _StoredRun(this.id, this.score, this.playedAt);
  final String id;
  final int score;
  final DateTime playedAt;
}
