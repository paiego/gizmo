import 'dart:convert';
import 'dart:io';

import 'package:gizmo_rules/gizmo_rules.dart';
import 'package:shelf/shelf.dart';

import 'store.dart';

const jsonHeaders = {
  'content-type': 'application/json; charset=utf-8',
  'access-control-allow-origin': '*',
  'access-control-allow-methods': 'GET, POST, OPTIONS',
  'access-control-allow-headers': 'content-type',
  'cache-control': 'no-store',
};

/// `limit` defaults to 20 and caps at 50. Null means the value is not usable.
int? parseLimit(String? raw) {
  if (raw == null || raw.isEmpty) return 20;
  final value = int.tryParse(raw);
  if (value == null || value < 1) return null;
  if (value > 50) return 50;
  return value;
}

Handler buildHandler(GizmoStore store) {
  return (Request request) async {
    if (request.method == 'OPTIONS') {
      return Response(204, headers: jsonHeaders);
    }
    try {
      return await _route(store, request);
    } catch (error, stack) {
      stderr.writeln('Gizmo API error: $error\n$stack');
      return _error(500, 'server_error');
    }
  };
}

Future<Response> _route(GizmoStore store, Request request) async {
  final segments = _segments(request);
  if (segments.isEmpty || segments.first != 'v1') {
    return _error(404, 'not_found');
  }

  if (segments.length == 2 && segments[1] == 'health') {
    if (request.method != 'GET') return _error(400, 'method_not_allowed');
    return _ok({'ok': true});
  }

  if (segments.length == 2 && segments[1] == 'runs') {
    if (request.method != 'POST') return _error(400, 'method_not_allowed');
    return _postRun(store, request);
  }

  if (segments.length == 2 && segments[1] == 'leaderboard') {
    if (request.method != 'GET') return _error(400, 'method_not_allowed');
    final limit = parseLimit(request.url.queryParameters['limit']);
    if (limit == null) return _error(400, 'invalid_limit');
    final entries = await store.leaderboard(limit: limit);
    return _ok({
      'entries': [for (final entry in entries) entry.toJson()],
    });
  }

  if (segments.length == 4 && segments[1] == 'players') {
    final name = parsePlayerName(segments[2]);
    if (name == null) return _error(400, 'invalid_name');
    if (segments[3] == 'best') {
      if (request.method != 'GET') return _error(400, 'method_not_allowed');
      final best = await store.best(name);
      return _ok(best.toJson());
    }
    if (segments[3] == 'runs') {
      if (request.method != 'GET') return _error(400, 'method_not_allowed');
      final limit = parseLimit(request.url.queryParameters['limit']);
      if (limit == null) return _error(400, 'invalid_limit');
      final runs = await store.runs(name, limit: limit);
      return _ok({
        'runs': [for (final run in runs) run.toJson()],
      });
    }
  }

  return _error(404, 'not_found');
}

Future<Response> _postRun(GizmoStore store, Request request) async {
  final raw = await request.readAsString();
  Object? decoded;
  try {
    decoded = jsonDecode(raw);
  } catch (_) {
    return _error(400, 'invalid_json');
  }
  final parsed = _parseRun(decoded);
  if (parsed.error != null) return _error(400, parsed.error!);
  final reason = validateSubmittedRun(parsed.run!);
  if (reason != null) return _error(400, reason);
  final saved = await store.insertRun(parsed.run!);
  return _ok(saved.toJson());
}

class _ParsedRun {
  const _ParsedRun.ok(this.run) : error = null;
  const _ParsedRun.err(this.error) : run = null;
  final SubmittedRun? run;
  final String? error;
}

_ParsedRun _parseRun(Object? decoded) {
  if (decoded is! Map) return const _ParsedRun.err('invalid_json');
  final body = Map<String, dynamic>.from(decoded);
  final playerName = body['playerName'];
  if (playerName is! String) return const _ParsedRun.err('invalid_name');
  final score = body['score'];
  if (score is! int) return const _ParsedRun.err('invalid_score');
  final roundsRaw = body['rounds'];
  if (roundsRaw is! List) return const _ParsedRun.err('invalid_rounds');

  final rounds = <SubmittedRound>[];
  for (final item in roundsRaw) {
    if (item is! Map) return const _ParsedRun.err('invalid_round');
    final round = Map<String, dynamic>.from(item);
    final index = round['index'];
    if (index is! int) return const _ParsedRun.err('invalid_index');
    final shape = round['body'];
    if (shape is! String) return const _ParsedRun.err('invalid_body');
    final top = round['topPart'];
    if (top is! String) return const _ParsedRun.err('invalid_top');
    final side = round['sidePart'];
    if (side is! String) return const _ParsedRun.err('invalid_side');
    final hole = round['hole'];
    if (hole is! String) return const _ParsedRun.err('invalid_hole');
    final color = round['color'];
    if (color is! String) return const _ParsedRun.err('invalid_color');
    final pulse = round['pulse'];
    if (pulse is! String) return const _ParsedRun.err('invalid_pulse');
    final choiceCount = round['choiceCount'];
    if (choiceCount is! int) {
      return const _ParsedRun.err('invalid_choice_count');
    }
    final correct = round['correct'];
    if (correct is! bool) return const _ParsedRun.err('invalid_round');
    rounds.add(
      SubmittedRound(
        index: index,
        body: shape,
        topPart: top,
        sidePart: side,
        hole: hole,
        color: color,
        pulse: pulse,
        choiceCount: choiceCount,
        correct: correct,
      ),
    );
  }

  return _ParsedRun.ok(
    SubmittedRun(playerName: playerName, score: score, rounds: rounds),
  );
}

List<String> _segments(Request request) {
  final requested = request.requestedUri.pathSegments
      .where((part) => part.isNotEmpty)
      .toList();
  if (requested.isNotEmpty) return requested;
  return request.url.pathSegments.where((part) => part.isNotEmpty).toList();
}

Response _ok(Object? body) =>
    Response.ok(jsonEncode(body), headers: jsonHeaders);

Response _error(int status, String reason) {
  return Response(
    status,
    body: jsonEncode({'error': reason}),
    headers: jsonHeaders,
  );
}
