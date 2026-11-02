import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:gizmo_rules/gizmo_rules.dart';
import 'package:sqlite3/sqlite3.dart' as sql;

import 'models.dart';
import 'store.dart';

class Database implements GizmoStore {
  Database(this._db);

  final sql.Database _db;
  Future<void> _queue = Future<void>.value();

  static Future<Database> open(String databasePath) async {
    final database = Database(sql.sqlite3.open(databasePath));
    database._db.execute('PRAGMA foreign_keys = ON');
    database._db.execute('PRAGMA journal_mode = WAL');
    await database.migrate();
    return database;
  }

  /// Applies `migrations/*.sql` in filename order. Safe to call again.
  Future<void> migrate() {
    return _serialized(() async {
      _db.execute('''
        create table if not exists schema_migrations (
          filename text primary key,
          applied_at text not null
        )
      ''');
      final applied = _db.select('select filename from schema_migrations');
      final done = {for (final row in applied) row['filename'] as String};
      for (final file in migrationFiles()) {
        final name = file.uri.pathSegments.last;
        if (done.contains(name)) continue;
        final statements = file
            .readAsStringSync()
            .split(';')
            .map((statement) => statement.trim())
            .where((statement) => statement.isNotEmpty);
        _tx(() {
          for (final statement in statements) {
            _db.execute(statement);
          }
          _db.execute(
            '''
            insert into schema_migrations (filename, applied_at)
            values (?, strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
            ''',
            [name],
          );
        });
      }
    });
  }

  @override
  Future<SavedRun> insertRun(SubmittedRun run) {
    final name = parsePlayerName(run.playerName)!;
    return _serialized(() async {
      late SavedRun saved;
      _tx(() {
        final player = _lockPlayer(name);
        final previous = _db.select(
          'select max(score) as best from runs where player_id = ?',
          [player.id],
        );
        final previousBest = _intOrNull(previous.first['best']);
        final isNew = previousBest == null || run.score > previousBest;
        final runId = _uuid();
        _db.execute(
          '''
          insert into runs (id, player_id, score, wrong_count, played_at)
          values (?, ?, ?, 3, strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
          ''',
          [runId, player.id, run.score],
        );
        for (final round in run.rounds) {
          _db.execute(
            '''
            insert into rounds (
              id, run_id, round_index, body, top_part, side_part,
              hole, color, pulse, choice_count, correct
            ) values (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ''',
            [
              _uuid(),
              runId,
              round.index,
              round.body,
              round.topPart,
              round.sidePart,
              round.hole,
              round.color,
              round.pulse,
              round.choiceCount,
              round.correct ? 1 : 0,
            ],
          );
        }
        saved = SavedRun(
          runId: runId,
          playerName: player.display,
          score: run.score,
          personalBest: isNew ? run.score : previousBest!,
          isNewPersonalBest: isNew,
          rank: _rankFor(name.key),
        );
      });
      return saved;
    });
  }

  @override
  Future<PlayerBest> best(PlayerName name) {
    return _serialized(() async {
      final result = _db.select(
        '''
        select
          p.display_name,
          (select max(score) from runs where player_id = p.id) as best_score,
          (select count(*) from runs where player_id = p.id) as run_count,
          (
            select min(played_at) from runs
            where player_id = p.id
              and score = (select max(score) from runs where player_id = p.id)
          ) as best_at
        from players p
        where p.name_key = ?
        ''',
        [name.key],
      );
      if (result.isEmpty) {
        return PlayerBest(
          playerName: name.display,
          bestScore: null,
          bestAt: null,
          runCount: 0,
        );
      }
      final row = result.first;
      return PlayerBest(
        playerName: row['display_name'] as String,
        bestScore: _intOrNull(row['best_score']),
        bestAt: _timeOrNull(row['best_at']),
        runCount: _int(row['run_count']),
      );
    });
  }

  @override
  Future<List<RunSummary>> runs(PlayerName name, {required int limit}) {
    return _serialized(() async {
      final result = _db.select(
        '''
        select r.id, r.score, r.played_at
        from runs r
        join players p on p.id = r.player_id
        where p.name_key = ?
        order by r.played_at desc, r.id desc
        limit ?
        ''',
        [name.key, limit],
      );
      return [
        for (final row in result)
          RunSummary(
            runId: row['id'] as String,
            score: _int(row['score']),
            playedAt: _time(row['played_at']),
          ),
      ];
    });
  }

  @override
  Future<List<BoardEntry>> leaderboard({required int limit}) {
    return _serialized(() async {
      final result = _db.select(
        '''
        $_rankedSql
        select display_name, best_score, best_at, board_rank
        from ranked
        order by board_rank
        limit ?
        ''',
        [limit],
      );
      return [
        for (final row in result)
          BoardEntry(
            rank: _int(row['board_rank']),
            playerName: row['display_name'] as String,
            bestScore: _int(row['best_score']),
            bestAt: _time(row['best_at']),
          ),
      ];
    });
  }

  @override
  Future<void> close() async {
    _db.dispose();
  }

  Future<T> _serialized<T>(Future<T> Function() action) {
    final previous = _queue;
    final done = Completer<void>();
    _queue = done.future;
    return previous.then((_) async {
      try {
        return await action();
      } finally {
        if (!done.isCompleted) done.complete();
      }
    });
  }

  void _tx(void Function() body) {
    _db.execute('BEGIN IMMEDIATE');
    try {
      body();
      _db.execute('COMMIT');
    } catch (error) {
      _db.execute('ROLLBACK');
      rethrow;
    }
  }

  _PlayerRow _lockPlayer(PlayerName name) {
    List<sql.Row> load() {
      return _db.select(
        'select id, display_name from players where name_key = ?',
        [name.key],
      );
    }

    var rows = load();
    if (rows.isEmpty) {
      _db.execute(
        '''
        insert into players (id, name_key, display_name, created_at)
        values (?, ?, ?, strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
        on conflict (name_key) do nothing
        ''',
        [_uuid(), name.key, name.display],
      );
      rows = load();
    }
    final row = rows.first;
    return _PlayerRow(row['id'] as String, row['display_name'] as String);
  }

  int _rankFor(String key) {
    final result = _db.select(
      '''
      $_rankedSql
      select board_rank from ranked where name_key = ?
      ''',
      [key],
    );
    return _int(result.first['board_rank']);
  }
}

class _PlayerRow {
  const _PlayerRow(this.id, this.display);
  final String id;
  final String display;
}

const _rankedSql = '''
  with maxes as (
    select player_id, max(score) as best_score
    from runs
    group by player_id
  ),
  bests as (
    select m.player_id, m.best_score, min(r.played_at) as best_at
    from maxes m
    join runs r
      on r.player_id = m.player_id
     and r.score = m.best_score
    group by m.player_id, m.best_score
  ),
  ranked as (
    select
      p.name_key,
      p.display_name,
      b.best_score,
      b.best_at,
      row_number() over (
        order by b.best_score desc, b.best_at asc, p.display_name asc
      ) as board_rank
    from bests b
    join players p on p.id = b.player_id
  )
''';

List<File> migrationFiles() {
  final candidates = <Directory>[
    Directory('migrations'),
    Directory('api/migrations'),
  ];
  final script = Platform.script.toFilePath();
  if (script.isNotEmpty) {
    final parent = File(script).parent.path;
    candidates.add(Directory('$parent/../migrations'));
    candidates.add(Directory('$parent/migrations'));
  }
  for (final directory in candidates) {
    if (!directory.existsSync()) continue;
    final files = directory
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('.sql'))
        .toList()
      ..sort(
        (a, b) => a.uri.pathSegments.last.compareTo(b.uri.pathSegments.last),
      );
    if (files.isNotEmpty) return files;
  }
  throw StateError('Could not find api/migrations.');
}

int _int(Object? value) {
  if (value is int) return value;
  throw StateError('Expected an integer, got $value.');
}

int? _intOrNull(Object? value) => value == null ? null : _int(value);

DateTime _time(Object? value) {
  if (value is String) return DateTime.parse(value).toUtc();
  throw StateError('Expected a timestamp, got $value.');
}

DateTime? _timeOrNull(Object? value) => value == null ? null : _time(value);

String _uuid() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}
