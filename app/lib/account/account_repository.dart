import 'package:shared_preferences/shared_preferences.dart';

import '../name_store.dart';
import '../palette_store.dart';
import 'account.dart';
import 'firebase_auth.dart';

/// Local record of the account, plus the Firebase Auth sign-in call.
///
/// Username, admin, picture, and theme are stored on the device so the
/// profile works before a Firebase project is attached. The user id only
/// changes when [signIn] returns one.
class AccountRepository {
  AccountRepository({
    NameStore? names,
    PaletteStore? palettes,
    this.requestUserId = requestFirebaseUserId,
  })  : names = names ?? NameStore(),
        palettes = palettes ?? PaletteStore();

  final NameStore names;
  final PaletteStore palettes;

  /// Google sign-in. Tests pass a stand-in; the app uses Firebase.
  final Future<String> Function() requestUserId;

  static const firebaseIdKey = 'account_firebase_id';
  static const adminKey = 'account_admin';
  static const adminModeKey = 'account_admin_mode';
  static const pictureKey = 'account_picture';

  Future<GizmoAccount> read() async {
    final prefs = await SharedPreferences.getInstance();
    final username = await names.read();
    final themeId = await palettes.read();
    final firebaseId = prefs.getString(firebaseIdKey);
    return GizmoAccount(
      firebaseId: firebaseId == null || firebaseId.isEmpty ? null : firebaseId,
      username: username,
      admin: prefs.getBool(adminKey) ?? false,
      adminMode: prefs.getBool(adminModeKey) ?? false,
      pictureId: prefs.getString(pictureKey) ?? GizmoAccount.defaultPictureId,
      themeId: themeId ?? 'warm',
    );
  }

  Future<void> save(GizmoAccount account) async {
    final prefs = await SharedPreferences.getInstance();
    if (account.username == null) {
      await prefs.remove(NameStore.storageKey);
    } else {
      await names.write(account.username!);
    }
    await palettes.write(account.themeId);
    if (account.firebaseId == null) {
      await prefs.remove(firebaseIdKey);
    } else {
      await prefs.setString(firebaseIdKey, account.firebaseId!);
    }
    await prefs.setBool(adminKey, account.admin);
    await prefs.setBool(adminModeKey, account.admin && account.adminMode);
    await prefs.setString(pictureKey, account.pictureId);
  }

  /// Asks Firebase Auth for the account id. See [requestFirebaseUserId].
  Future<GizmoAccount> signIn(GizmoAccount current) async {
    final id = await requestUserId();
    final next = current.copyWith(firebaseId: id);
    await save(next);
    return next;
  }

  /// Decides whether a game may start.
  ///
  /// A successful sign-in starts an online game as the id it returned.
  /// An offline or network failure starts a game only when a user id is
  /// already saved, and only as that id. The score then stays on the device.
  /// A first launch with nothing saved still has to sign in.
  Future<PlayTicket> preparePlay(GizmoAccount current) async {
    try {
      final id = await requestUserId();
      if (id.isEmpty) {
        throw StateError('Firebase did not return a user id.');
      }
      final next = current.copyWith(firebaseId: id);
      await save(next);
      return PlayTicket(userId: id, localOnly: false, account: next);
    } on SignInOffline {
      if (!current.signedIn) throw const PlayRequiresSignIn();
      return PlayTicket(
        userId: current.firebaseId!,
        localOnly: true,
        account: current,
      );
    }
  }

  Future<GizmoAccount> signOut(GizmoAccount current) async {
    await signOutFirebase();
    final next = current.copyWith(clearFirebaseId: true);
    await save(next);
    return next;
  }
}

/// Permission to start one game.
class PlayTicket {
  const PlayTicket({
    required this.userId,
    required this.localOnly,
    required this.account,
  });

  /// The only Firebase user id this game may score.
  final String userId;

  /// The score stays on the device and is not submitted.
  final bool localOnly;
  final GizmoAccount account;
}

/// Sign-in failed offline and this device has no saved user id.
class PlayRequiresSignIn implements Exception {
  const PlayRequiresSignIn();

  @override
  String toString() => 'Sign in to play.';
}
