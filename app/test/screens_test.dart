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
import 'package:gizmo/screens/icon_gallery_screen.dart';
import 'package:gizmo/screens/play_screen.dart';
import 'package:gizmo/screens/result_screen.dart';
import 'package:gizmo/widgets/icon_shapes.dart';
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
    final round = buildRound(level: 1, random: Random(0));
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
    expect(find.text('Remember Me!'), findsNothing);
    expect(find.text('Find Me!'), findsNothing);
  });

  testWidgets('a wrong pick shows the original beside the pick',
      (tester) async {
    final round = buildRound(level: 1, random: Random(1));
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

    final screen = tester.getRect(find.byType(Scaffold));
    expect(_peakScale(tester), closeTo(1, 0.01));
    expect(
        tester.getRect(find.byKey(ValueKey(leaver))).overlaps(screen), isFalse);
    expect(
        tester.getRect(find.byKey(ValueKey(wrong))).overlaps(screen), isTrue);
    final kept = tester.getRect(find.byKey(ValueKey(original)));
    final picked = tester.getRect(find.byKey(ValueKey(wrong)));
    expect(kept.top, closeTo(picked.top, 0.5));
    expect(kept.left, lessThan(picked.left));
    expect(picked.left - kept.right, greaterThan(16));
    expect((kept.left + picked.right) / 2, closeTo(screen.width / 2, 1));
    expect((kept.top - before.top).abs(), greaterThan(10));
    expect(find.text('Continue'), findsOneWidget);
    expect(find.text('original'), findsOneWidget);
    expect(_solidMark(tester), isFalse);
    expect(
      kept.bottom,
      lessThan(tester.getRect(find.byType(GizmoButton)).top),
    );
    final label = tester.getRect(find.text('original'));
    expect(label.top, greaterThan(kept.bottom - 1));
    expect(
      (label.left + label.right) / 2,
      closeTo((kept.left + kept.right) / 2, 2),
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
    expect(find.text('Remember Me!'), findsNothing);
    expect(find.text('Find Me!'), findsNothing);
  });

  testWidgets('the look icon stays in place', (tester) async {
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
    final first = tester.getRect(find.byType(IconView));
    final remember = tester.getRect(find.text('Remember Me!'));
    expect(remember.bottom, lessThanOrEqualTo(first.top + 1));
    expect(screen.contains(first.center), isTrue);
    expect((first.center.dx - screen.center.dx).abs(), lessThan(24));
    expect((first.center.dy - screen.center.dy).abs(), lessThan(90));

    await tester.pump(const Duration(milliseconds: 1500));
    expect(
      tester.getRect(find.byType(IconView)).center,
      offsetMoreOrLessEquals(first.center, epsilon: 0.5),
    );

    await tester.pump(const Duration(milliseconds: 1490));
    final later = tester.getRect(find.byType(IconView));
    expect(later.center, offsetMoreOrLessEquals(first.center, epsilon: 0.5));
    expect(screen.contains(later.center), isTrue);
  });

  testWidgets('choices appear in place', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PlayScreen(
          playerName: 'Paul',
          session: GameSession(random: Random(3)),
        ),
      ),
    );
    await tester.pump();
    final look = tester.getSize(find.byType(IconView));
    await tester.pump(const Duration(milliseconds: 2999));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump();
    expect(find.byType(IconView), findsNothing);

    for (var step = 0; step < 40; step++) {
      await tester.pump(const Duration(milliseconds: 16));
      if (find.byType(IconView).evaluate().isNotEmpty) break;
    }
    final screen = tester.getRect(find.byType(Scaffold));
    final arriving = find.byType(IconView);
    expect(arriving, findsNWidgets(3));
    expect(
      List.generate(3, (index) => tester.getRect(arriving.at(index)))
          .any((rect) => !screen.contains(rect.center)),
      isTrue,
    );

    await tester.pump(const Duration(milliseconds: 400));
    final icons = find.byType(IconView);
    expect(icons, findsNWidgets(3));
    expect(find.text('Remember Me!'), findsNothing);
    final findMe = tester.getRect(find.text('Find Me!'));
    final iconTop = tester.getRect(icons.first).top;
    expect(findMe.bottom, lessThanOrEqualTo(iconTop + 1));
    for (var index = 0; index < 3; index++) {
      expect(tester.getSize(icons.at(index)), look);
    }
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
    final round = buildRound(level: 1, random: Random(0));
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
    expect(_peakScale(tester), closeTo(1, 0.01));
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

  test('the gallery is one thousand distinct icons', () {
    expect(galleryCount, 1000);
    expect(galleryAssemblies, hasLength(galleryCount));
    expect(iconShapes(galleryAssemblies.first), hasLength(3));
    final kinds = {
      for (final assembly in galleryAssemblies)
        for (final shape in iconShapes(assembly)) shape.kind,
    };
    expect(
      kinds,
      containsAll(const [
        IconShapeKind.heptagon,
        IconShapeKind.octagon,
        IconShapeKind.nonagon,
        IconShapeKind.decagon,
      ]),
    );
    for (var i = 0; i < galleryAssemblies.length; i++) {
      for (var j = i + 1; j < galleryAssemblies.length; j++) {
        expect(
          samePicture(galleryAssemblies[i], galleryAssemblies[j]),
          isFalse,
        );
      }
    }
  });

  testWidgets('the profile gallery scrolls two columns in the active theme', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({NameStore.storageKey: 'Paul'});
    _usePhoneSurface(tester);
    await tester
        .pumpWidget(GizmoApp(client: _FakeClient(), names: NameStore()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('open-profile')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cold'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('open-icon-gallery')));
    await tester.tap(find.byKey(const ValueKey('open-icon-gallery')));
    await tester.pumpAndSettle();

    expect(find.text('Icons'), findsOneWidget);
    final gallery = find.byKey(const ValueKey('icon-gallery'));
    expect(gallery, findsOneWidget);
    final viewport = tester.getRect(gallery);
    final visible = <Rect>[];
    for (final element in find.byType(IconView).evaluate()) {
      final rect = tester.getRect(find.byWidget(element.widget));
      if (!rect.overlaps(viewport)) continue;
      visible.add(rect);
      final icon = element.widget as IconView;
      expect(icon.palette, coldPalette);
    }
    final rows = <int, List<Rect>>{};
    for (final rect in visible) {
      final band = (rect.top / 8).round();
      rows.putIfAbsent(band, () => []).add(rect);
    }
    expect(rows.length, inInclusiveRange(3, 4));
    for (final row in rows.values) {
      expect(row, hasLength(2));
      expect((row[0].center.dx - row[1].center.dx).abs(), greaterThan(40));
    }

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('gallery-icon-99')),
      400,
    );
    expect(find.byKey(const ValueKey('gallery-icon-99')), findsOneWidget);
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
          pingReachable: () async => throw const SignInOffline(),
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
          pingReachable: () async => throw const SignInOffline(),
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
          pingReachable: () async => throw const SignInOffline(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('9'), findsOneWidget);
    expect(find.text('40'), findsNothing);
    expect(find.text('Saved on this device'), findsOneWidget);
    expect(find.text('The scoreboard is unreachable.'), findsNothing);
  });

  test('a dealt round starts at level 1', () {
    final session = GameSession();
    final round = session.deal();
    expect(session.level, 1);
    expect(round.choiceCount, 3);
    expect(round.choices, contains(round.original));
  });

  testWidgets('admin mode prints the similarity index while playing', (
    tester,
  ) async {
    final session = GameSession(
      random: Random(0),
      adminMode: true,
      decoySimilarity: 0.35,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: PlayScreen(
          playerName: 'Paul',
          session: session,
          adminMode: true,
          decoySimilarity: 0.35,
        ),
      ),
    );
    expect(find.text('Sim '), findsOneWidget);
    expect(find.byKey(const ValueKey('admin-similarity')), findsOneWidget);
    expect(find.text('0.35'), findsOneWidget);

    await tester.pumpWidget(
      const MaterialApp(
        home: PlayScreen(playerName: 'Paul'),
      ),
    );
    expect(find.text('Sim '), findsNothing);
    expect(find.byKey(const ValueKey('admin-similarity')), findsNothing);
  });

  testWidgets('admin mode sets the level for the next round', (tester) async {
    final session = GameSession(random: Random(0), adminMode: true);
    final round = buildRound(level: 1, random: Random(0));
    await tester.pumpWidget(
      MaterialApp(
        home: PlayScreen(
          playerName: 'Paul',
          session: session,
          adminMode: true,
        ),
      ),
    );
    expect(find.text('Level '), findsOneWidget);
    expect(find.byType(TextField), findsNothing);

    await _reachChoices(tester);
    expect(find.byType(TextField), findsOneWidget);
    await tester.enterText(find.byType(TextField), '12');
    await tester.pump();
    expect(session.level, 1);

    await tester.tap(
      find.byKey(ValueKey(round.choices.indexOf(round.original))),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(session.level, 12);
    expect(session.score, 1);
    expect(find.text('12'), findsOneWidget);

    for (var step = 0; step < 30; step++) {
      await tester.pump(const Duration(milliseconds: 200));
      if (find.byType(IconView).evaluate().length == 6) break;
    }
    expect(find.byType(IconView), findsNWidgets(6));
  });

  testWidgets('a high level shows the original for a quarter of the time', (
    tester,
  ) async {
    final session = GameSession(random: Random(4), adminMode: true);
    final round = buildRound(level: 1, random: Random(4));
    await tester.pumpWidget(
      MaterialApp(
        home: PlayScreen(
          playerName: 'Paul',
          session: session,
          adminMode: true,
        ),
      ),
    );
    await _reachChoices(tester);
    await tester.enterText(find.byType(TextField), '19');
    await tester.tap(
      find.byKey(ValueKey(round.choices.indexOf(round.original))),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(session.level, 19);
    expect(find.byType(IconView), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 700));
    expect(find.byType(IconView), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 80));
    await tester.pump();
    expect(find.byType(IconView), findsNothing);
  });

  testWidgets('eight choices scatter inside the margins', (tester) async {
    _usePhoneSurface(tester);
    final session = GameSession(random: Random(4), adminMode: true);
    final round = buildRound(level: 1, random: Random(4));
    await tester.pumpWidget(
      MaterialApp(
        home: PlayScreen(
          playerName: 'Paul',
          session: session,
          adminMode: true,
        ),
      ),
    );
    await _reachChoices(tester);
    final early = tester.getSize(find.byType(IconView).first);
    await tester.enterText(find.byType(TextField), '19');
    await tester.tap(
      find.byKey(ValueKey(round.choices.indexOf(round.original))),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    final look = tester.getSize(find.byType(IconView));

    for (var step = 0; step < 30; step++) {
      await tester.pump(const Duration(milliseconds: 200));
      if (find.byType(IconView).evaluate().length == 8) break;
    }
    await tester.pump(const Duration(milliseconds: 400));
    final icons = find.byType(IconView);
    expect(icons, findsNWidgets(8));
    final screen = tester.getRect(find.byType(Scaffold));
    final rects = [
      for (var index = 0; index < 8; index++) tester.getRect(icons.at(index)),
    ];
    final xs = <int>{};
    final ys = <int>{};
    final ink = early.width - 2;
    for (final rect in rects) {
      expect(rect.width, closeTo(early.width, 0.5));
      expect(rect.height, closeTo(early.height, 0.5));
      expect(rect.width, closeTo(look.width, 0.5));
      expect(rect.left, greaterThanOrEqualTo(screen.left + 14 - 1));
      expect(rect.right, lessThanOrEqualTo(screen.right - 14 + 1));
      expect(rect.bottom, lessThanOrEqualTo(screen.bottom - 14 + 1));
      xs.add((rect.left / 8).round());
      ys.add((rect.top / 8).round());
    }
    for (var i = 0; i < rects.length; i++) {
      for (var j = i + 1; j < rects.length; j++) {
        final dist = (rects[i].center - rects[j].center).distance;
        expect(dist, greaterThanOrEqualTo(ink + 12 - 0.5));
      }
    }
    expect(xs.length, greaterThan(1));
    expect(ys.length, greaterThan(1));
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
