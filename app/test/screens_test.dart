import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gizmo/api/gizmo_client.dart';
import 'package:gizmo/game/session.dart';
import 'package:gizmo/main.dart';
import 'package:gizmo/name_store.dart';
import 'package:gizmo/screens/play_screen.dart';
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

  testWidgets('look, gap, then three choices', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: PlayScreen(playerName: 'Paul', session: null)),
    );
    await tester.pump();
    expect(find.byType(IconView), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 2999));
    expect(find.byType(IconView), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump();
    expect(find.byType(IconView), findsNothing);

    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(IconView), findsNWidgets(3));

    await tester.tap(find.byType(IconView).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
    expect(find.byType(IconView), findsOneWidget);
  });

  test('a dealt round matches the score band', () {
    final session = GameSession();
    final round = session.deal();
    expect(round.choiceCount, 3);
    expect(round.choices, contains(round.original));
  });
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
