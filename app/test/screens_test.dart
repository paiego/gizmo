import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gizmo/api/gizmo_client.dart';
import 'package:gizmo/game/session.dart';
import 'package:gizmo/widgets/gizmo_button.dart';
import 'package:gizmo/main.dart';
import 'package:gizmo/name_store.dart';
import 'package:gizmo/screens/play_screen.dart';
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

  testWidgets('home offers palettes and play uses the one you pick', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({NameStore.storageKey: 'Paul'});
    await tester
        .pumpWidget(GizmoApp(client: _FakeClient(), names: NameStore()));
    await tester.pumpAndSettle();

    expect(find.text('Warm'), findsOneWidget);
    expect(find.text('Cold'), findsOneWidget);
    expect(find.text('Forest'), findsOneWidget);
    expect(find.text('Ink'), findsOneWidget);
    expect(_paletteBorder(tester, 'warm'), inkColor);

    await tester.tap(find.text('Cold'));
    await tester.pumpAndSettle();
    expect(_paletteBorder(tester, 'cold'), inkColor);
    expect(_paletteBorder(tester, 'warm'), isNot(inkColor));

    await tester
        .pumpWidget(GizmoApp(client: _FakeClient(), names: NameStore()));
    await tester.pumpAndSettle();
    expect(_paletteBorder(tester, 'cold'), inkColor);

    await tester.tap(find.text('Play'));
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
}

class _FakeClient extends GizmoClient {
  int bestCalls = 0;

  @override
  Future<PlayerSummary> fetchBest(String name) async {
    bestCalls += 1;
    return PlayerSummary(playerName: name, bestScore: 12, runCount: 4);
  }

  @override
  Future<SavedRun> submitRun(SubmittedRun run) async {
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
