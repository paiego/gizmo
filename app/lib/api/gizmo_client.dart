import 'dart:convert';

import 'package:gizmo_rules/gizmo_rules.dart';
import 'package:http/http.dart' as http;

const apiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'http://localhost:8080',
);

class GizmoClientException implements Exception {
  GizmoClientException(this.reason, {this.statusCode});

  final String reason;
  final int? statusCode;

  @override
  String toString() => reason;
}

class PlayerSummary {
  const PlayerSummary({
    required this.playerName,
    required this.bestScore,
    required this.runCount,
  });

  final String playerName;
  final int? bestScore;
  final int runCount;
}

class SavedRun {
  const SavedRun({
    required this.runId,
    required this.playerName,
    required this.score,
    required this.personalBest,
    required this.isNewPersonalBest,
    required this.rank,
  });

  final String runId;
  final String playerName;
  final int score;
  final int personalBest;
  final bool isNewPersonalBest;
  final int rank;
}

class BoardEntry {
  const BoardEntry({
    required this.rank,
    required this.playerName,
    required this.bestScore,
  });

  final int rank;
  final String playerName;
  final int bestScore;
}

class GizmoClient {
  GizmoClient({http.Client? httpClient, this.baseUrl = apiBaseUrl})
    : _http = httpClient ?? http.Client();

  final http.Client _http;
  final String baseUrl;

  Future<PlayerSummary> fetchBest(String name) async {
    final body = await _send(
      'GET',
      '/v1/players/${Uri.encodeComponent(name)}/best',
    );
    return PlayerSummary(
      playerName: _string(body, 'playerName'),
      bestScore: _intOrNull(body['bestScore']),
      runCount: _int(body, 'runCount'),
    );
  }

  Future<SavedRun> submitRun(SubmittedRun run) async {
    final body = await _send('POST', '/v1/runs', run.toJson());
    return SavedRun(
      runId: _string(body, 'runId'),
      playerName: _string(body, 'playerName'),
      score: _int(body, 'score'),
      personalBest: _int(body, 'personalBest'),
      isNewPersonalBest: body['isNewPersonalBest'] == true,
      rank: _int(body, 'rank'),
    );
  }

  Future<List<BoardEntry>> fetchLeaderboard({int limit = 20}) async {
    final body = await _send('GET', '/v1/leaderboard', null, {
      'limit': '$limit',
    });
    final entries = body['entries'];
    if (entries is! List) {
      throw GizmoClientException('invalid_response');
    }
    return [
      for (final entry in entries)
        if (entry is Map<String, dynamic>)
          BoardEntry(
            rank: _int(entry, 'rank'),
            playerName: _string(entry, 'playerName'),
            bestScore: _int(entry, 'bestScore'),
          )
        else
          throw GizmoClientException('invalid_response'),
    ];
  }

  Future<Map<String, dynamic>> _send(
    String method,
    String path, [
    Object? jsonBody,
    Map<String, String>? query,
  ]) async {
    final uri = _uri(path, query);
    late final http.Response response;
    try {
      if (method == 'POST') {
        response = await _http
            .post(
              uri,
              headers: {'content-type': 'application/json'},
              body: jsonEncode(jsonBody),
            )
            .timeout(const Duration(seconds: 8));
      } else {
        response = await _http.get(uri).timeout(const Duration(seconds: 8));
      }
    } catch (error) {
      if (error is GizmoClientException) rethrow;
      throw GizmoClientException('unreachable');
    }
    Object? decoded;
    try {
      decoded = jsonDecode(response.body);
    } catch (_) {
      throw GizmoClientException(
        'invalid_response',
        statusCode: response.statusCode,
      );
    }
    if (decoded is! Map) {
      throw GizmoClientException(
        'invalid_response',
        statusCode: response.statusCode,
      );
    }
    final body = Map<String, dynamic>.from(decoded);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final reason = body['error'];
      throw GizmoClientException(
        reason is String ? reason : 'request_failed',
        statusCode: response.statusCode,
      );
    }
    return body;
  }

  Uri _uri(String path, Map<String, String>? query) {
    final base = Uri.parse(baseUrl);
    final prefix = base.path.endsWith('/')
        ? base.path.substring(0, base.path.length - 1)
        : base.path;
    return base.replace(path: '$prefix$path', queryParameters: query);
  }

  String _string(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! String) throw GizmoClientException('invalid_response');
    return value;
  }

  int _int(Map<String, dynamic> json, String key) {
    final value = _intOrNull(json[key]);
    if (value == null) throw GizmoClientException('invalid_response');
    return value;
  }

  int? _intOrNull(Object? value) {
    if (value == null) return null;
    if (value is int) return value;
    throw GizmoClientException('invalid_response');
  }
}
