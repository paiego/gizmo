import 'package:shared_preferences/shared_preferences.dart';

/// The best score kept on this device for one Firebase user id.
class LocalScore {
  const LocalScore({
    required this.userId,
    required this.best,
    required this.runs,
    this.isNewBest = false,
  });

  final String userId;
  final int best;
  final int runs;
  final bool isNewBest;
}

/// Refuses a score that is not for the account already saved on the device.
class OfflineScoreRefused implements Exception {
  const OfflineScoreRefused();

  @override
  String toString() =>
      'This score stays with the account already on this device.';
}

/// Scores for offline play. Each Firebase user id has its own record.
///
/// Nothing here is uploaded.
class LocalScoreStore {
  const LocalScoreStore();

  static String bestKey(String userId) => 'local_score.$userId.best';

  static String runsKey(String userId) => 'local_score.$userId.runs';

  Future<LocalScore?> read(String userId) async {
    if (userId.isEmpty) return null;
    final prefs = await SharedPreferences.getInstance();
    final best = prefs.getInt(bestKey(userId));
    if (best == null) return null;
    return LocalScore(
      userId: userId,
      best: best,
      runs: prefs.getInt(runsKey(userId)) ?? 0,
    );
  }

  Future<LocalScore> record(String userId, int score) async {
    if (userId.isEmpty) throw const OfflineScoreRefused();
    final prefs = await SharedPreferences.getInstance();
    final previous = prefs.getInt(bestKey(userId));
    final runs = (prefs.getInt(runsKey(userId)) ?? 0) + 1;
    final best = previous == null || score > previous ? score : previous;
    await prefs.setInt(bestKey(userId), best);
    await prefs.setInt(runsKey(userId), runs);
    return LocalScore(
      userId: userId,
      best: best,
      runs: runs,
      isNewBest: previous == null || score > previous,
    );
  }
}

/// Writes [score] only for [admittedUserId], the id the offline game was
/// allowed to use. A different id is refused and left untouched.
Future<LocalScore> keepLocalScore({
  required LocalScoreStore scores,
  required String admittedUserId,
  required String userId,
  required int score,
}) async {
  if (userId.isEmpty || userId != admittedUserId) {
    throw const OfflineScoreRefused();
  }
  return scores.record(userId, score);
}
