import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gizmo/account/account_repository.dart';
import 'package:gizmo/account/firebase_auth.dart';
import 'package:gizmo/account/local_score.dart';
import 'package:gizmo/api/gizmo_client.dart';
import 'package:gizmo/game/session.dart';
import 'package:gizmo/widgets/gizmo_button.dart';
import 'package:gizmo/main.dart';
import 'package:gizmo/name_store.dart';
import 'package:gizmo/palette_store.dart';
import 'package:gizmo/screens/play_screen.dart';
import 'package:gizmo/screens/result_screen.dart';
import 'package:gizmo/theme.dart';
import 'package:gizmo/widgets/icon_view.dart';
import 'package:gizmo_rules/gizmo_rules.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('a new player names themselves and reaches home', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final client = _FakeClient();
    await tester.pumpWidget(GizmoApp(client: client, names: NameStore()));
    await tester.pumpAndSettle();

    expect(find.text('Continue'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '!!!');
    await tester.tap(find.text('Continue'));
    await tester.pump();
    expect(find.textContaining('1–20'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '  Paul  ');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('Paul'), findsOneWidget);
    expect(find.text('Play'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
    expect(client.bestCalls, 1);
  });

  testWidgets('profile holds themes and play uses the one you pick', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({NameStore.storageKey: 'Paul'});
    _usePhoneSurface(tester);
    await tester
        .pumpWidget(GizmoApp(client: _FakeClient(), names: NameStore()));
    await tester.pumpAndSettle();

    expect(find.text('Colors'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('open-profile')));
    await tester.pumpAndSettle();

    expect(find.text('Warm'), findsOneWidget);
    expect(find.text('Cold'), findsOneWidget);
    expect(find.text('Forest'), findsOneWidget);
    expect(find.text('Ink'), findsOneWidget);
    expect(_paletteBorder(tester, 'warm'), inkColor);

    await tester.tap(find.text('Cold'));
    await tester.pumpAndSettle();
    expect(_paletteBorder(tester, 'cold'), coldLook.ink);
    expect(_paletteBorder(tester, 'warm'), isNot(coldLook.ink));

    await tester.pumpWidget(
      GizmoApp(
        key: const ValueKey('reloaded'),
        client: _FakeClient(),
        accounts: AccountRepository(
          names: NameStore(),
          palettes: PaletteStore(),
          requestUserId: () async => 'paul-id',
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('open-profile')));
    await tester.pumpAndSettle();
    expect(_paletteBorder(tester, 'cold'), coldLook.ink);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Play'));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.byType(IconView), findsOneWidget);
    _expectPalette(tester, coldPalette);

    await tester.pump(const Duration(milliseconds: 3000));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(IconView), findsNWidgets(3));
    _expectPalette(tester, coldPalette);
  });

  testWidgets('look, gap, then three choices', (tester) async {
    final round = buildRound(scoreSoFar: 0, random: Random(0));
    await tester.pumpWidget(
      MaterialApp(
        home: PlayScreen(
          playerName: 'Paul',
          session: GameSession(random: Random(0)),
        ),
      ),
    );
    await _reachChoices(tester);
    expect(find.byType(IconView), findsNWidgets(3));

    await tester
        .tap(find.byKey(ValueKey(round.choices.indexOf(round.original))));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
    expect(find.byType(IconView), findsOneWidget);
  });

  testWidgets('a wrong pick slides the other decoys off', (tester) async {
    final round = buildRound(scoreSoFar: 0, random: Random(1));
    await tester.pumpWidget(
      MaterialApp(
        home: PlayScreen(
          playerName: 'Paul',
          session: GameSession(random: Random(1)),
        ),
      ),
    );
    await _reachChoices(tester);

    final original = round.choices.indexOf(round.original);
    final wrong =
        round.choices.indexWhere((choice) => choice != round.original);
    final leaver = round.choices.indexWhere(
      (choice) => choice != round.original && choice != round.choices[wrong],
    );
    final before = tester.getRect(find.byKey(ValueKey(original)));

    await tester.tap(find.byKey(ValueKey(wrong)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 420));

    final screen = tester.getRect(find.byType(Scaffold));
    expect(_peakScale(tester), closeTo(1, 0.01));
    expect(
        tester.getRect(find.byKey(ValueKey(leaver))).overlaps(screen), isFalse);
    expect(
      tester.getTopLeft(find.byKey(ValueKey(original))),
      offsetMoreOrLessEquals(before.topLeft, epsilon: 0.5),
    );
    expect(
        tester.getRect(find.byKey(ValueKey(wrong))).overlaps(screen), isTrue);
    expect(find.text('Continue'), findsNothing);

    await tester.pump(const Duration(milliseconds: 380));

    final kept = tester.getRect(find.byKey(ValueKey(original)));
    final picked = tester.getRect(find.byKey(ValueKey(wrong)));
    expect(
        tester.getRect(find.byKey(ValueKey(leaver))).overlaps(screen), isFalse);
    expect(kept.top, closeTo(picked.top, 0.5));
    expect(kept.left, lessThan(picked.left));
    expect(picked.left - kept.right, greaterThan(16));
    expect((kept.left + picked.right) / 2, closeTo(screen.width / 2, 1));
    expect((kept.top - before.top).abs(), greaterThan(20));
    expect(find.text('Continue'), findsOneWidget);
    expect(find.text('original'), findsNothing);
    expect(_solidMark(tester), isTrue);
    expect(
      kept.bottom,
      lessThan(tester.getRect(find.byType(GizmoButton)).top),
    );

    await tester.pump(const Duration(milliseconds: 450));
    expect(find.text('original'), findsOneWidget);
    expect(_solidMark(tester), isFalse);
    final label = tester.getRect(find.text('original'));
    final keptAfter = tester.getRect(find.byKey(ValueKey(original)));
    expect(label.top, greaterThan(keptAfter.bottom - 1));
    expect(
      (label.left + label.right) / 2,
      closeTo((keptAfter.left + keptAfter.right) / 2, 2),
    );
    expect(
        label.bottom, lessThan(tester.getRect(find.byType(GizmoButton)).top));

    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Continue'), findsOneWidget);
    expect(find.text('original'), findsOneWidget);
    expect(find.byType(IconView), findsNWidgets(3));

    await tester.tap(find.text('Continue'));
    await tester.pump();
    expect(find.byType(IconView), findsOneWidget);
  });

  testWidgets('the look icon slides in, rests, then leaves another way', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PlayScreen(
          playerName: 'Paul',
          session: GameSession(random: Random(2)),
        ),
      ),
    );
    await tester.pump();
    final screen = tester.getRect(find.byType(Scaffold));
    final enteredFrom = _outsideSide(
      tester.getRect(find.byType(IconView)),
      screen,
    );

    await tester.pump(const Duration(milliseconds: 1500));
    final resting = tester.getRect(find.byType(IconView));
    expect((resting.center.dx - screen.center.dx).abs(), lessThan(24));
    expect((resting.center.dy - screen.center.dy).abs(), lessThan(90));
    expect(resting.overlaps(screen), isTrue);

    await tester.pump(const Duration(milliseconds: 1490));
    expect(
      _outsideSide(tester.getRect(find.byType(IconView)), screen),
      isNot(enteredFrom),
    );
  });

  testWidgets('choices slide in from the edges', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PlayScreen(
          playerName: 'Paul',
          session: GameSession(random: Random(3)),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 2999));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump();
    expect(find.byType(IconView), findsNothing);

    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    final screen = tester.getRect(find.byType(Scaffold));
    final icons = find.byType(IconView);
    expect(icons, findsNWidgets(3));
    for (var index = 0; index < 3; index++) {
      expect(screen.contains(tester.getRect(icons.at(index)).center), isFalse);
    }

    await tester.pump(const Duration(milliseconds: 400));
    final centers = <Offset>[
      for (var index = 0; index < 3; index++)
        tester.getRect(icons.at(index)).center,
    ];
    for (final center in centers) {
      expect(screen.contains(center), isTrue);
    }
    expect((centers[0] - centers[1]).distance, greaterThan(40));
    expect((centers[1] - centers[2]).distance, greaterThan(40));
  });

  testWidgets('a correct pick celebrates, then the next look starts', (
    tester,
  ) async {
    final round = buildRound(scoreSoFar: 0, random: Random(0));
    await tester.pumpWidget(
      MaterialApp(
        home: PlayScreen(
          playerName: 'Paul',
          session: GameSession(random: Random(0)),
        ),
      ),
    );
    await _reachChoices(tester);
    await tester.tap(
      find.byKey(ValueKey(round.choices.indexOf(round.original))),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(_peakScale(tester), greaterThan(1.05));
    expect(find.byType(IconView), findsNWidgets(3));
    expect(find.text('Continue'), findsNothing);

    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byType(IconView), findsOneWidget);
    expect(find.text('Continue'), findsNothing);
  });

  testWidgets('the profile gear opens account settings', (tester) async {
    SharedPreferences.setMockInitialValues({NameStore.storageKey: 'Paul'});
    _usePhoneSurface(tester);
    await tester
        .pumpWidget(GizmoApp(client: _FakeClient(), names: NameStore()));
    await tester.pumpAndSettle();

    expect(find.text('Change name'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('open-profile')));
    await tester.pumpAndSettle();

    expect(find.text('Profile'), findsOneWidget);
    expect(find.text('No Firebase id yet'), findsOneWidget);
    expect(find.text('Sign out'), findsOneWidget);
    expect(
      tester
          .widget<SwitchListTile>(
              find.widgetWithText(SwitchListTile, 'Admin mode'))
          .onChanged,
      isNull,
    );

    await tester.tap(find.widgetWithText(SwitchListTile, 'Admin'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<SwitchListTile>(
              find.widgetWithText(SwitchListTile, 'Admin mode'))
          .onChanged,
      isNotNull,
    );

    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();
    expect(
        find.textContaining('Firebase has not been started'), findsOneWidget);
    expect(find.text('No Firebase id yet'), findsOneWidget);
  });

  testWidgets('a first launch cannot play while offline', (tester) async {
    SharedPreferences.setMockInitialValues({NameStore.storageKey: 'Paul'});
    await tester.pumpWidget(
      GizmoApp(
        client: _FakeClient(),
        accounts: AccountRepository(
          names: NameStore(),
          palettes: PaletteStore(),
          requestUserId: () async => throw const SignInOffline(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Play'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Sign in to play.'), findsOneWidget);
    expect(find.byType(PlayScreen), findsNothing);
  });

  testWidgets('offline play starts only for the saved account', (tester) async {
    SharedPreferences.setMockInitialValues({
      NameStore.storageKey: 'Paul',
      AccountRepository.firebaseIdKey: 'uid-a',
    });
    await tester.pumpWidget(
      GizmoApp(
        client: _FakeClient(),
        accounts: AccountRepository(
          names: NameStore(),
          palettes: PaletteStore(),
          requestUserId: () async => throw const SignInOffline(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Play'));
    await tester.pump();
    await tester.pump();

    expect(find.byType(PlayScreen), findsOneWidget);
    expect(find.text('Sign in to play.'), findsNothing);
  });

  testWidgets('an offline run stays on the device for that account', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final client = _FakeClient();
    final scores = LocalScoreStore();
    await tester.pumpWidget(
      MaterialApp(
        home: ResultScreen(
          playerName: 'Paul',
          userId: 'uid-a',
          localOnly: true,
          scores: scores,
          client: client,
          transcript: const SubmittedRun(
            playerName: 'Paul',
            score: 4,
            rounds: [],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(client.submitCalls, 0);
    expect(find.text('Saved on this device'), findsOneWidget);
    expect(find.text('Best 4'), findsOneWidget);
    expect(find.text('Rank 1'), findsNothing);
    expect((await scores.read('uid-a'))!.best, 4);
    expect(await scores.read('uid-b'), isNull);
  });

  testWidgets('home shows the saved score only for the signed-in account', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      NameStore.storageKey: 'Paul',
      AccountRepository.firebaseIdKey: 'uid-a',
      LocalScoreStore.bestKey('uid-a'): 9,
      LocalScoreStore.runsKey('uid-a'): 2,
      LocalScoreStore.bestKey('uid-b'): 40,
    });
    await tester.pumpWidget(
      GizmoApp(
        client: _DownClient(),
        accounts: AccountRepository(
          names: NameStore(),
          palettes: PaletteStore(),
          requestUserId: () async => throw const SignInOffline(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('9'), findsOneWidget);
    expect(find.text('40'), findsNothing);
    expect(find.text('Saved on this device'), findsOneWidget);
    expect(find.text('The scoreboard is unreachable.'), findsNothing);
  });

  test('a dealt round matches the score band', () {
    final session = GameSession();
    final round = session.deal();
    expect(round.choiceCount, 3);
    expect(round.choices, contains(round.original));
  });
}

void _expectPalette(WidgetTester tester, IconPalette palette) {
  final views = tester.widgetList<IconView>(find.byType(IconView));
  expect(views, isNotEmpty);
  for (final view in views) {
    final painter = tester
        .widget<CustomPaint>(
          find.descendant(
            of: find.byWidget(view),
            matching: find.byType(CustomPaint),
          ),
        )
        .painter! as IconPainter;
    expect(painter.palette, palette);
    expect(
      painter.palette.values[view.assembly.color],
      palette.values[view.assembly.color],
    );
    expect(
      painter.palette.values[view.assembly.color],
      isNot(colorValue[view.assembly.color]),
    );
  }
}

void _usePhoneSurface(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(480, 1000);
  addTearDown(tester.view.reset);
}

Color _paletteBorder(WidgetTester tester, String id) {
  final container = tester.widget<Container>(
    find.byKey(ValueKey('palette-$id')),
  );
  final border = (container.decoration! as BoxDecoration).border! as Border;
  return border.top.color;
}

bool _solidMark(WidgetTester tester) {
  for (final box
      in tester.widgetList<DecoratedBox>(find.byType(DecoratedBox))) {
    final decoration = box.decoration;
    if (decoration is! BoxDecoration) continue;
    final border = decoration.border;
    if (border is! Border) continue;
    if (border.top.width >= 3 && border.top.color.a > 0.85) return true;
  }
  return false;
}

Future<void> _reachChoices(WidgetTester tester) async {
  await tester.pump();
  expect(find.byType(IconView), findsOneWidget);

  await tester.pump(const Duration(milliseconds: 2999));
  expect(find.byType(IconView), findsOneWidget);

  await tester.pump(const Duration(milliseconds: 50));
  await tester.pump();
  expect(find.byType(IconView), findsNothing);

  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 400));
}

String _outsideSide(Rect icon, Rect screen) {
  final center = icon.center;
  if (center.dx < screen.left) return 'left';
  if (center.dx > screen.right) return 'right';
  if (center.dy < screen.top) return 'top';
  if (center.dy > screen.bottom) return 'bottom';
  fail('icon center ${icon.center} is still on screen');
}

double _peakScale(WidgetTester tester) {
  var peak = 1.0;
  for (final transform
      in tester.widgetList<Transform>(find.byType(Transform))) {
    final scale = transform.transform.getMaxScaleOnAxis();
    if (scale > peak) peak = scale;
  }
  return peak;
}

class _FakeClient extends GizmoClient {
  int bestCalls = 0;
  int submitCalls = 0;

  @override
  Future<PlayerSummary> fetchBest(String name) async {
    bestCalls += 1;
    return PlayerSummary(playerName: name, bestScore: 12, runCount: 4);
  }

  @override
  Future<SavedRun> submitRun(SubmittedRun run) async {
    submitCalls += 1;
    return SavedRun(
      runId: 'run',
      playerName: run.playerName,
      score: run.score,
      personalBest: run.score,
      isNewPersonalBest: true,
      rank: 1,
    );
  }

  @override
  Future<List<BoardEntry>> fetchLeaderboard({int limit = 20}) async {
    return const [];
  }
}

class _DownClient extends _FakeClient {
  @override
  Future<PlayerSummary> fetchBest(String name) async {
    throw GizmoClientException('unreachable');
  }
}
