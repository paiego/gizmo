import 'package:gizmo_rules/gizmo_rules.dart';

import 'models.dart';

abstract class GizmoStore {
  Future<SavedRun> insertRun(SubmittedRun run);

  Future<PlayerBest> best(PlayerName name);

  Future<List<RunSummary>> runs(PlayerName name, {required int limit});

  Future<List<BoardEntry>> leaderboard({required int limit});

  Future<void> close();
}
