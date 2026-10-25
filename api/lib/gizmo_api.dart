import 'dart:io';

import 'package:shelf/shelf.dart';

import 'src/database.dart';
import 'src/http.dart';
import 'src/store.dart';

export 'src/database.dart' show Database, endpointFromUrl, migrationFiles;
export 'src/http.dart' show buildHandler, jsonHeaders, parseLimit;
export 'src/models.dart';
export 'src/store.dart';

class GizmoServer {
  GizmoServer(this.store) : handler = buildHandler(store);

  final GizmoStore store;
  final Handler handler;

  static Future<GizmoServer> open({String? databaseUrl}) async {
    final url =
        databaseUrl ??
        Platform.environment['DATABASE_URL'] ??
        'postgres://gizmo:gizmo@localhost:5432/gizmo';
    final database = await Database.connect(url);
    return GizmoServer(database);
  }

  Future<void> close() => store.close();
}
