import 'dart:io';

import 'package:gizmo_api/gizmo_api.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

Future<void> main() async {
  final server = await GizmoServer.open();
  final http = await shelf_io.serve(
    server.handler,
    InternetAddress.anyIPv4,
    8080,
  );
  stdout.writeln('Gizmo API on http://${http.address.host}:${http.port}');
}
