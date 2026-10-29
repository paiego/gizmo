import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gizmo/account/account.dart';
import 'package:gizmo/account/account_repository.dart';
import 'package:gizmo/account/firebase_auth.dart';
import 'package:gizmo/account/local_score.dart';
import 'package:gizmo/name_store.dart';
import 'package:gizmo/palette_store.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('sign-in does not mint an id before Firebase is started', () async {
    expect(firebaseIsReady(), isFalse);
    await expectLater(
      requestFirebaseUserId(),
      throwsA(isA<FirebaseNotStarted>()),
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
      throwsA(isA<FirebaseNotStarted>()),
    );
    final after = await repository.read();
    expect(after.firebaseId, isNull);
    expect(after.username, 'Paul');
  });

  test('only a dropped network counts as an offline sign-in', () {
    expect(
      isOfflineSignInFailure(
        FirebaseException(
            plugin: 'firebase_auth', code: 'network-request-failed'),
      ),
      isTrue,
    );
    expect(isOfflineSignInFailure(const SocketException('offline')), isTrue);
    expect(
      isOfflineSignInFailure(TimeoutException('timed out')),
      isTrue,
    );
    expect(
      isOfflineSignInFailure(
          PlatformException(code: 'NSURLErrorDomain: -1009')),
      isTrue,
    );
    expect(isOfflineSignInFailure(const SignInOffline()), isTrue);
    expect(isOfflineSignInFailure(const FirebaseNotStarted()), isFalse);
    expect(isOfflineSignInFailure(const GoogleSignInCanceled()), isFalse);
    expect(
      isOfflineSignInFailure(
        FirebaseException(plugin: 'firebase_auth', code: 'invalid-credential'),
      ),
      isFalse,
    );
    expect(
      isOfflineSignInFailure(
        const GoogleSignInException(
            code: GoogleSignInExceptionCode.unknownError),
      ),
      isFalse,
    );
  });

  test('offline play uses only the cached user id and keeps that score',
      () async {
    SharedPreferences.setMockInitialValues({
      AccountRepository.firebaseIdKey: 'uid-a',
      NameStore.storageKey: 'Paul',
    });
    final repository = AccountRepository(
      names: NameStore(),
      palettes: PaletteStore(),
      requestUserId: () async => throw const SignInOffline(),
    );

    final ticket = await repository.preparePlay(await repository.read());

    expect(ticket.localOnly, isTrue);
    expect(ticket.userId, 'uid-a');
    expect(ticket.account.firebaseId, 'uid-a');
    expect((await repository.read()).firebaseId, 'uid-a');

    final scores = LocalScoreStore();
    final saved = await keepLocalScore(
      scores: scores,
      admittedUserId: ticket.userId,
      userId: ticket.userId,
      score: 4,
    );
    expect(saved.best, 4);
    expect(saved.isNewBest, isTrue);
    expect((await scores.read('uid-a'))!.best, 4);
    expect(await scores.read('uid-b'), isNull);

    await expectLater(
      keepLocalScore(
        scores: scores,
        admittedUserId: ticket.userId,
        userId: 'uid-b',
        score: 9,
      ),
      throwsA(isA<OfflineScoreRefused>()),
    );
    expect((await scores.read('uid-a'))!.best, 4);
    expect(await scores.read('uid-b'), isNull);
  });

  test('a first launch with nothing cached cannot play offline', () async {
    SharedPreferences.setMockInitialValues({});
    final repository = AccountRepository(
      names: NameStore(),
      palettes: PaletteStore(),
      requestUserId: () async => throw const SignInOffline(),
    );

    await expectLater(
      repository.preparePlay(const GizmoAccount(username: 'Paul')),
      throwsA(isA<PlayRequiresSignIn>()),
    );
    expect((await repository.read()).firebaseId, isNull);
    expect(await LocalScoreStore().read('uid-a'), isNull);
  });

  test('signing out blocks offline play for the next person', () async {
    SharedPreferences.setMockInitialValues({
      AccountRepository.firebaseIdKey: 'uid-a',
      NameStore.storageKey: 'Paul',
    });
    final repository = AccountRepository(
      names: NameStore(),
      palettes: PaletteStore(),
      requestUserId: () async => throw const SignInOffline(),
    );
    await LocalScoreStore().record('uid-a', 4);
    final signedOut = await repository.signOut(await repository.read());

    expect(signedOut.firebaseId, isNull);
    await expectLater(
      repository.preparePlay(signedOut),
      throwsA(isA<PlayRequiresSignIn>()),
    );
    expect((await LocalScoreStore().read('uid-a'))!.best, 4);
  });

  test('a different account plays only when sign-in returns their id',
      () async {
    SharedPreferences.setMockInitialValues({
      AccountRepository.firebaseIdKey: 'uid-a',
    });
    await LocalScoreStore().record('uid-a', 4);
    final repository = AccountRepository(
      names: NameStore(),
      palettes: PaletteStore(),
      requestUserId: () async => 'uid-b',
    );

    final ticket = await repository.preparePlay(await repository.read());

    expect(ticket.localOnly, isFalse);
    expect(ticket.userId, 'uid-b');
    expect((await repository.read()).firebaseId, 'uid-b');
    expect((await LocalScoreStore().read('uid-a'))!.best, 4);
    expect(await LocalScoreStore().read('uid-b'), isNull);
  });

  test('canceling sign-in does not start an offline game', () async {
    SharedPreferences.setMockInitialValues({
      AccountRepository.firebaseIdKey: 'uid-a',
    });
    final repository = AccountRepository(
      names: NameStore(),
      palettes: PaletteStore(),
      requestUserId: () async => throw const GoogleSignInCanceled(),
    );

    await expectLater(
      repository.preparePlay(await repository.read()),
      throwsA(isA<GoogleSignInCanceled>()),
    );
    expect((await repository.read()).firebaseId, 'uid-a');
  });
}
