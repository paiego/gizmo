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
  }) {
    return GizmoAccount(
      firebaseId: clearFirebaseId ? null : (firebaseId ?? this.firebaseId),
      username: clearUsername ? null : (username ?? this.username),
      admin: admin ?? this.admin,
      adminMode: adminMode ?? this.adminMode,
      pictureId: pictureId ?? this.pictureId,
      themeId: themeId ?? this.themeId,
    );
  }
}
