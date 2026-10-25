import 'dart:convert';

import 'package:gizmo_api/gizmo_api.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import 'memory_store.dart';
import 'script.dart';

void main() {
  late MemoryStore store;
  late GizmoServer server;
  var clock = DateTime.utc(2026, 10, 25, 12);

  setUp(() {
    clock = DateTime.utc(2026, 10, 25, 12);
    store = MemoryStore(
      clock: () {
        final now = clock;
        clock = clock.add(const Duration(seconds: 1));
        return now;
      },
    );
    server = GizmoServer(store);
  });

  test('health, limits, and unknown paths', () async {
    final health = await _json(server, 'GET', '/v1/health');
    expect(health.status, 200);
    expect(health.body, {'ok': true});

    final missing = await _json(server, 'GET', '/v1/missing');
    expect(missing.status, 404);
    expect(missing.body, {'error': 'not_found'});

    final method = await _json(server, 'GET', '/v1/runs');
    expect(method.status, 400);
    expect(method.body, {'error': 'method_not_allowed'});

    final limit = await _json(server, 'GET', '/v1/leaderboard?limit=0');
    expect(limit.status, 400);
    expect(limit.body, {'error': 'invalid_limit'});

    final capped = await _json(server, 'GET', '/v1/leaderboard?limit=99');
    expect(capped.status, 200);
    expect(capped.body['entries'], isEmpty);
  });

  test('posting a run updates the best, the list, and the board', () async {
    final created = await _send(
      server,
      scriptedRun('Paul', [true, true, false, false, false]),
    );
    expect(created.status, 200);
    expect(created.body['playerName'], 'Paul');
    expect(created.body['score'], 2);
    expect(created.body['personalBest'], 2);
    expect(created.body['isNewPersonalBest'], isTrue);
    expect(created.body['rank'], 1);

    final lower = await _send(
      server,
      scriptedRun('paul', [false, false, false], seed: 2),
    );
    expect(lower.body['playerName'], 'Paul');
    expect(lower.body['score'], 0);
    expect(lower.body['personalBest'], 2);
    expect(lower.body['isNewPersonalBest'], isFalse);

    final best = await _json(server, 'GET', '/v1/players/Paul/best');
    expect(best.body['playerName'], 'Paul');
    expect(best.body['bestScore'], 2);
    expect(best.body['runCount'], 2);
    expect(best.body['bestAt'], '2026-10-25T12:00:00.000Z');

    final runs = await _json(server, 'GET', '/v1/players/paul/runs');
    expect(runs.body['runs'], hasLength(2));
    expect(runs.body['runs'][0]['score'], 0);
    expect(runs.body['runs'][1]['score'], 2);

    final unknown = await _json(server, 'GET', '/v1/players/Ada/best');
    expect(unknown.status, 200);
    expect(unknown.body['bestScore'], isNull);
    expect(unknown.body['bestAt'], isNull);
    expect(unknown.body['runCount'], 0);
    expect(unknown.body['playerName'], 'Ada');

    final broken = scriptedRun('Paul', [false, false, false]).toJson();
    final rounds = broken['rounds'] as List<Map<String, Object?>>;
    rounds.first['topPart'] = 'none';
    rounds.first['sidePart'] = 'none';
    final bad = await _send(server, broken);
    expect(bad.status, 400);
    expect(bad.body['error'], 'invalid_parts');

    final board = await _json(server, 'GET', '/v1/leaderboard');
    expect(board.body['entries'], hasLength(1));
    expect(board.body['entries'][0]['playerName'], 'Paul');
    expect(board.body['entries'][0]['bestScore'], 2);
  });

  test('leaderboard orders by best, then earliest best, then name', () async {
    await _send(server, scriptedRun('Bea', [true, false, false, false]));
    await _send(
      server,
      scriptedRun('Ada', [true, false, false, false], seed: 3),
    );
    await _send(
      server,
      scriptedRun('Cara', [true, true, false, false, false], seed: 4),
    );

    final board = await _json(server, 'GET', '/v1/leaderboard?limit=20');
    final names = [
      for (final entry in board.body['entries'] as List)
        (entry as Map)['playerName'],
    ];
    expect(names, ['Cara', 'Bea', 'Ada']);
    expect(board.body['entries'][0]['rank'], 1);
    expect(board.body['entries'][1]['rank'], 2);
  });

  test('a bad body is rejected before it is stored', () async {
    final response = await _json(server, 'POST', '/v1/runs', {
      'playerName': 'Paul',
    });
    expect(response.status, 400);
    expect(response.body['error'], 'invalid_score');
    expect(await store.leaderboard(limit: 20), isEmpty);
  });
}

Future<_Json> _send(GizmoServer server, Object? body) {
  return _json(server, 'POST', '/v1/runs', body);
}

Future<_Json> _json(
  GizmoServer server,
  String method,
  String path, [
  Object? body,
]) async {
  final response = await server.handler(
    Request(
      method,
      Uri.parse('http://localhost$path'),
      body: body == null ? null : jsonEncode(body),
      headers: {'content-type': 'application/json'},
    ),
  );
  final raw = await response.readAsString();
  return _Json(response.statusCode, raw.isEmpty ? null : jsonDecode(raw));
}

class _Json {
  _Json(this.status, this.body);
  final int status;
  final dynamic body;
}
