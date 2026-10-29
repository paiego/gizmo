import 'package:flutter_test/flutter_test.dart';
import 'package:gizmo/account/account.dart';
import 'package:gizmo/account/account_repository.dart';
import 'package:gizmo/account/firebase_auth.dart';
import 'package:gizmo/name_store.dart';
import 'package:gizmo/palette_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('sign-in reports missing Firebase config and does not mint an id',
      () async {
    expect(firebaseEnvironmentReady, isFalse);
    expect(firebaseConfigGaps(), isNotEmpty);
    expect(
      firebaseConfigGaps().join('\n'),
      isNot(contains('google-services.json')),
    );
    await expectLater(
      requestFirebaseUserId(),
      throwsA(
        isA<FirebaseConfigMissing>().having(
          (error) => error.missing.join('\n'),
          'missing',
          contains('GoogleService-Info.plist'),
        ),
      ),
    );
  });

  test('the repository keeps the username and theme without a Firebase id',
      () async {
    SharedPreferences.setMockInitialValues({});
    final repository = AccountRepository(
      names: NameStore(),
      palettes: PaletteStore(),
    );
    await repository.save(
      const GizmoAccount(username: 'Paul', themeId: 'cold', admin: true),
    );

    final loaded = await repository.read();
    expect(loaded.username, 'Paul');
    expect(loaded.themeId, 'cold');
    expect(loaded.admin, isTrue);
    expect(loaded.firebaseId, isNull);
    expect(loaded.signedIn, isFalse);

    await expectLater(
      repository.signIn(loaded),
      throwsA(isA<FirebaseConfigMissing>()),
    );
    final after = await repository.read();
    expect(after.firebaseId, isNull);
    expect(after.username, 'Paul');
  });
}
