import 'dart:convert';
import 'dart:io';

import 'package:gizmo_api/gizmo_api.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import 'script.dart';

void main() {
  GizmoServer? server;

  setUpAll(() async {
    try {
      server = await GizmoServer.open().timeout(const Duration(seconds: 4));
      await (server!.store as Database).migrate();
    } catch (error) {
      server = null;
      stderr.writeln('Postgres is not available, skipping API checks: $error');
    }
  });

  tearDownAll(() async {
    await server?.close();
  });

  test('migrations and POST /v1/runs', () async {
    final api = server;
    if (api == null) {
      markTestSkipped('Postgres is not available.');
      return;
    }

    final suffix = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final ada = 'Ada$suffix';
    final bea = 'Bea$suffix';

    final health = await _get(api, '/v1/health');
    expect(health.status, 200);
    expect(health.body['ok'], isTrue);

    final created = await _post(
      api,
      scriptedRun(ada, [true, true, false, false, false]),
    );
    expect(created.status, 200, reason: '${created.body}');
    expect(created.body['playerName'], ada);
    expect(created.body['score'], 2);
    expect(created.body['personalBest'], 2);
    expect(created.body['isNewPersonalBest'], isTrue);
    expect(created.body['rank'], isA<int>());
    expect(created.body['rank'] as int, greaterThan(0));

    final again = await _post(
      api,
      scriptedRun(ada.toLowerCase(), [
        true,
        true,
        true,
        false,
        false,
        false,
      ], seed: 4),
    );
    expect(again.status, 200, reason: '${again.body}');
    expect(again.body['playerName'], ada);
    expect(again.body['score'], 3);
    expect(again.body['personalBest'], 3);
    expect(again.body['isNewPersonalBest'], isTrue);

    final lower = await _post(
      api,
      scriptedRun(ada.toUpperCase(), [false, false, false], seed: 5),
    );
    expect(lower.body['playerName'], ada);
    expect(lower.body['isNewPersonalBest'], isFalse);
    expect(lower.body['personalBest'], 3);

    final best = await _get(
      api,
      '/v1/players/${Uri.encodeComponent(ada)}/best',
    );
    expect(best.status, 200);
    expect(best.body['playerName'], ada);
    expect(best.body['bestScore'], 3);
    expect(best.body['runCount'], 3);
    expect(best.body['bestAt'], isA<String>());
    expect((best.body['bestAt'] as String).endsWith('Z'), isTrue);

    final runs = await _get(
      api,
      '/v1/players/${Uri.encodeComponent(ada)}/runs',
    );
    expect(runs.body['runs'], hasLength(3));
    final played = [
      for (final run in runs.body['runs'] as List)
        DateTime.parse((run as Map)['playedAt'] as String),
    ];
    expect(played[0].isBefore(played[1]), isFalse);
    expect(played[1].isBefore(played[2]), isFalse);

    await _post(api, scriptedRun(bea, [true, false, false, false], seed: 6));
    final board = await _get(api, '/v1/leaderboard?limit=50');
    expect(board.status, 200);
    final entries = [
      for (final entry in board.body['entries'] as List)
        Map<String, dynamic>.from(entry as Map),
    ];
    expect(entries.length, lessThanOrEqualTo(50));
    final adaEntry = entries.firstWhere((entry) => entry['playerName'] == ada);
    final beaEntry = entries.firstWhere((entry) => entry['playerName'] == bea);
    expect(adaEntry['bestScore'], 3);
    expect(beaEntry['bestScore'], 1);
    expect(adaEntry['rank'] as int, lessThan(beaEntry['rank'] as int));

    final rejected = await _post(api, {
      'playerName': ada,
      'score': 0,
      'rounds': [
        {
          'index': 0,
          'body': 'disc',
          'topPart': 'none',
          'sidePart': 'none',
          'hole': 'none',
          'color': 'red',
          'choiceCount': 3,
          'correct': false,
        },
      ],
    });
    expect(rejected.status, 400);
    expect(rejected.body['error'], isNotEmpty);

    final unknown = await _get(api, '/v1/players/Nobody$suffix/best');
    expect(unknown.status, 200);
    expect(unknown.body['bestScore'], isNull);
    expect(unknown.body['runCount'], 0);

    final missing = await _get(api, '/nope');
    expect(missing.status, 404);
    expect(missing.body['error'], 'not_found');
  });
}

Future<_Body> _get(GizmoServer server, String path) async {
  final response = await server.handler(
    Request('GET', Uri.parse('http://localhost$path')),
  );
  return _Body(response.statusCode, jsonDecode(await response.readAsString()));
}

Future<_Body> _post(GizmoServer server, Object body) async {
  final response = await server.handler(
    Request(
      'POST',
      Uri.parse('http://localhost/v1/runs'),
      body: jsonEncode(body),
      headers: {'content-type': 'application/json'},
    ),
  );
  return _Body(response.statusCode, jsonDecode(await response.readAsString()));
}

class _Body {
  _Body(this.status, this.body);
  final int status;
  final dynamic body;
}
