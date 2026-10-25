import 'dart:async';
import 'dart:io';

import 'package:gizmo_rules/gizmo_rules.dart';
import 'package:postgres/postgres.dart';

import 'models.dart';
import 'store.dart';

class Database implements GizmoStore {
  Database(this._connection);

  final Connection _connection;
  Future<void> _queue = Future<void>.value();

  static Future<Database> connect(String databaseUrl) async {
    final endpoint = endpointFromUrl(databaseUrl);
    final connection = await Connection.open(
      endpoint,
      settings: const ConnectionSettings(
        sslMode: SslMode.disable,
        applicationName: 'gizmo',
      ),
    );
    final database = Database(connection);
    await database.migrate();
    return database;
  }

  /// Applies `migrations/*.sql` in filename order. Safe to call again.
  Future<void> migrate() {
    return _serialized(() async {
      await _connection.execute('''
        create table if not exists schema_migrations (
          filename text primary key,
          applied_at timestamptz not null default now()
        )
      ''');
      final applied = await _connection.execute(
        'select filename from schema_migrations',
      );
      final done = {for (final row in applied) _text(row, 'filename')};
      final files = migrationFiles();
      for (final file in files) {
        final name = file.uri.pathSegments.last;
        if (done.contains(name)) continue;
        final statements = file
            .readAsStringSync()
            .split(';')
            .map((statement) => statement.trim())
            .where((statement) => statement.isNotEmpty);
        await _connection.runTx((session) async {
          for (final statement in statements) {
            await session.execute(statement);
          }
          await session.execute(
            Sql.named(
              'insert into schema_migrations (filename) values (@filename)',
            ),
            parameters: {'filename': name},
          );
        });
      }
    });
  }

  @override
  Future<SavedRun> insertRun(SubmittedRun run) {
    final name = parsePlayerName(run.playerName)!;
    return _serialized(() {
      return _connection.runTx((session) async {
        final player = await _lockPlayer(session, name);
        final previous = await session.execute(
          Sql.named(
            'select max(score) as best from runs where player_id = cast(@id as uuid)',
          ),
          parameters: {'id': player.id},
        );
        final previousBest = _intOrNull(_map(previous.first)['best']);
        final isNew = previousBest == null || run.score > previousBest;

        final inserted = await session.execute(
          Sql.named('''
            insert into runs (id, player_id, score, wrong_count)
            values (gen_random_uuid(), cast(@player as uuid), @score, 3)
            returning cast(id as text) as id
          '''),
          parameters: {'player': player.id, 'score': run.score},
        );
        final runId = _text(inserted.first, 'id');

        for (final round in run.rounds) {
          await session.execute(
            Sql.named('''
              insert into rounds (
                id, run_id, round_index, body, top_part, side_part,
                hole, color, pulse, choice_count, correct
              ) values (
                gen_random_uuid(), cast(@run as uuid), @index, @body, @top,
                @side, @hole, @color, @pulse, @choice, @correct
              )
            '''),
            parameters: {
              'run': runId,
              'index': round.index,
              'body': round.body,
              'top': round.topPart,
              'side': round.sidePart,
              'hole': round.hole,
              'color': round.color,
              'pulse': round.pulse,
              'choice': round.choiceCount,
              'correct': round.correct,
            },
          );
        }

        final personalBest = isNew ? run.score : previousBest;
        final rank = await _rankFor(session, name.key);
        return SavedRun(
          runId: runId,
          playerName: player.display,
          score: run.score,
          personalBest: personalBest,
          isNewPersonalBest: isNew,
          rank: rank,
        );
      });
    });
  }

  @override
  Future<PlayerBest> best(PlayerName name) {
    return _serialized(() async {
      final result = await _connection.execute(
        Sql.named('''
          select
            p.display_name,
            max(r.score) as best_score,
            count(r.id) as run_count,
            min(r.played_at) filter (
              where r.score = (select max(score) from runs where player_id = p.id)
            ) as best_at
          from players p
          left join runs r on r.player_id = p.id
          where p.name_key = @key
          group by p.id, p.display_name
        '''),
        parameters: {'key': name.key},
      );
      if (result.isEmpty) {
        return PlayerBest(
          playerName: name.display,
          bestScore: null,
          bestAt: null,
          runCount: 0,
        );
      }
      final row = _map(result.first);
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
      final result = await _connection.execute(
        Sql.named('''
          select cast(r.id as text) as id, r.score, r.played_at
          from runs r
          join players p on p.id = r.player_id
          where p.name_key = @key
          order by r.played_at desc, r.id desc
          limit @limit
        '''),
        parameters: {'key': name.key, 'limit': limit},
      );
      return [
        for (final row in result)
          RunSummary(
            runId: _text(row, 'id'),
            score: _int(_map(row)['score']),
            playedAt: _time(_map(row)['played_at']),
          ),
      ];
    });
  }

  @override
  Future<List<BoardEntry>> leaderboard({required int limit}) {
    return _serialized(() async {
      final result = await _connection.execute(
        Sql.named('''
          $_rankedSql
          select display_name, best_score, best_at, board_rank
          from ranked
          order by board_rank
          limit @limit
        '''),
        parameters: {'limit': limit},
      );
      return [
        for (final row in result)
          BoardEntry(
            rank: _int(_map(row)['board_rank']),
            playerName: _map(row)['display_name'] as String,
            bestScore: _int(_map(row)['best_score']),
            bestAt: _time(_map(row)['best_at']),
          ),
      ];
    });
  }

  @override
  Future<void> close() => _connection.close();

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
}

class _PlayerRow {
  const _PlayerRow(this.id, this.display);
  final String id;
  final String display;
}

Future<_PlayerRow> _lockPlayer(Session session, PlayerName name) async {
  Future<Result> load() {
    return session.execute(
      Sql.named('''
        select cast(id as text) as id, display_name
        from players
        where name_key = @key
        for update
      '''),
      parameters: {'key': name.key},
    );
  }

  var rows = await load();
  if (rows.isEmpty) {
    final inserted = await session.execute(
      Sql.named('''
        insert into players (id, name_key, display_name)
        values (gen_random_uuid(), @key, @display)
        on conflict (name_key) do nothing
        returning cast(id as text) as id, display_name
      '''),
      parameters: {'key': name.key, 'display': name.display},
    );
    if (inserted.isNotEmpty) {
      return _PlayerRow(
        _text(inserted.first, 'id'),
        _map(inserted.first)['display_name'] as String,
      );
    }
    rows = await load();
  }
  final row = _map(rows.first);
  return _PlayerRow(row['id'] as String, row['display_name'] as String);
}

Future<int> _rankFor(Session session, String key) async {
  final result = await session.execute(
    Sql.named('''
      $_rankedSql
      select board_rank from ranked where name_key = @key
    '''),
    parameters: {'key': key},
  );
  return _int(_map(result.first)['board_rank']);
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

Endpoint endpointFromUrl(String raw) {
  final uri = Uri.parse(raw);
  final pieces = uri.userInfo.split(':');
  final username = pieces.isEmpty ? '' : Uri.decodeComponent(pieces.first);
  final password =
      pieces.length < 2 ? '' : Uri.decodeComponent(pieces.sublist(1).join(':'));
  final database = uri.pathSegments.isEmpty ? 'gizmo' : uri.pathSegments.first;
  return Endpoint(
    host: uri.host.isEmpty ? 'localhost' : uri.host,
    port: uri.hasPort ? uri.port : 5432,
    database: database,
    username: username,
    password: password,
  );
}

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

Map<String, dynamic> _map(ResultRow row) => row.toColumnMap();

String _text(ResultRow row, String column) => _map(row)[column] as String;

int _int(Object? value) {
  if (value is int) return value;
  if (value is BigInt) return value.toInt();
  throw StateError('Expected an integer, got $value.');
}

int? _intOrNull(Object? value) => value == null ? null : _int(value);

DateTime _time(Object? value) {
  if (value is DateTime) return value.toUtc();
  if (value is String) return DateTime.parse(value).toUtc();
  throw StateError('Expected a timestamp, got $value.');
}

DateTime? _timeOrNull(Object? value) => value == null ? null : _time(value);
