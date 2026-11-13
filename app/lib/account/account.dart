/// A player account.
///
/// [firebaseId] is the Firebase Auth user id. It stays null until sign-in
/// returns one. The app does not invent that id.
class GizmoAccount {
  const GizmoAccount({
    this.firebaseId,
    this.username,
    this.admin = false,
    this.adminMode = false,
    this.pictureId = defaultPictureId,
    this.themeId = 'warm',
    this.decoySimilarity = 0,
    this.decoySimilarityMax = 1,
    this.decoySimilarityRampSlope = 0.5,
    this.levelBasedProximity = false,
  });

  static const defaultPictureId = 'disc';

  final String? firebaseId;
  final String? username;
  final bool admin;

  /// Play continues after misses so high rounds can be inspected.
  /// Only meaningful while [admin] is on.
  final bool adminMode;
  final String pictureId;
  final String themeId;

  /// Start decoy similarity (0 wider, 1 tightest) for level 1 or fixed play.
  final double decoySimilarity;

  /// Target similarity at high levels when [levelBasedProximity] is on.
  final double decoySimilarityMax;

  /// Ramp steepness 0..1 when level-based proximity is on (1 = instant max).
  final double decoySimilarityRampSlope;

  /// When true, similarity ramps from [decoySimilarity] to [decoySimilarityMax]
  /// by level. When false, only [decoySimilarity] applies.
  final bool levelBasedProximity;

  bool get signedIn => firebaseId != null && firebaseId!.isNotEmpty;

  bool get playingAdmin => admin && adminMode;

  GizmoAccount copyWith({
    String? firebaseId,
    bool clearFirebaseId = false,
    String? username,
    bool clearUsername = false,
    bool? admin,
    bool? adminMode,
    String? pictureId,
    String? themeId,
    double? decoySimilarity,
    double? decoySimilarityMax,
    double? decoySimilarityRampSlope,
    bool? levelBasedProximity,
  }) {
    return GizmoAccount(
      firebaseId: clearFirebaseId ? null : (firebaseId ?? this.firebaseId),
      username: clearUsername ? null : (username ?? this.username),
      admin: admin ?? this.admin,
      adminMode: adminMode ?? this.adminMode,
      pictureId: pictureId ?? this.pictureId,
      themeId: themeId ?? this.themeId,
      decoySimilarity: decoySimilarity ?? this.decoySimilarity,
      decoySimilarityMax: decoySimilarityMax ?? this.decoySimilarityMax,
      decoySimilarityRampSlope:
          decoySimilarityRampSlope ?? this.decoySimilarityRampSlope,
      levelBasedProximity: levelBasedProximity ?? this.levelBasedProximity,
    );
  }
}
