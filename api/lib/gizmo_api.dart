import 'dart:io';

import 'package:shelf/shelf.dart';

import 'src/database.dart';
import 'src/http.dart';
import 'src/store.dart';

export 'src/database.dart' show Database, migrationFiles;
export 'src/http.dart' show buildHandler, jsonHeaders, parseLimit;
export 'src/models.dart';
export 'src/store.dart';

class GizmoServer {
  GizmoServer(this.store) : handler = buildHandler(store);

  final GizmoStore store;
  final Handler handler;

  static Future<GizmoServer> open({String? databasePath}) async {
    final path =
        databasePath ?? Platform.environment['GIZMO_DB'] ?? 'gizmo.sqlite';
    final database = await Database.open(path);
    return GizmoServer(database);
  }

  Future<void> close() => store.close();
}
