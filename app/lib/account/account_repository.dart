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
  AccountRepository({NameStore? names, PaletteStore? palettes})
      : names = names ?? NameStore(),
        palettes = palettes ?? PaletteStore();

  final NameStore names;
  final PaletteStore palettes;

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
    final id = await requestFirebaseUserId();
    final next = current.copyWith(firebaseId: id);
    await save(next);
    return next;
  }

  Future<GizmoAccount> signOut(GizmoAccount current) async {
    final next = current.copyWith(clearFirebaseId: true);
    await save(next);
    return next;
  }
}
