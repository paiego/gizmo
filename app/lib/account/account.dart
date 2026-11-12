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

  /// How alike decoys should be, from 0 (wider) to 1 (one field).
  final double decoySimilarity;

  /// When true, higher levels use closer decoys and [decoySimilarity] is
  /// ignored. When false, only [decoySimilarity] sets closeness.
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
      levelBasedProximity: levelBasedProximity ?? this.levelBasedProximity,
    );
  }
}
