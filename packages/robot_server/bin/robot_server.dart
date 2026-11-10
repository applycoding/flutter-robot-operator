// SPDX-License-Identifier: Apache-2.0

import 'dart:io';

import 'package:robot_server/robot_server.dart';

Future<void> main(List<String> args) async {
  var port = 8765;
  var tickMs = 50;

  for (var i = 0; i < args.length; i++) {
    final a = args[i];
    if (a == '--port' && i + 1 < args.length) {
      port = int.parse(args[++i]);
    } else if (a.startsWith('--port=')) {
      port = int.parse(a.substring('--port='.length));
    } else if (a == '--tick-ms' && i + 1 < args.length) {
      tickMs = int.parse(args[++i]);
    } else if (a.startsWith('--tick-ms=')) {
      tickMs = int.parse(a.substring('--tick-ms='.length));
    }
  }

  final server = RobotWebSocketServer(tickPeriodMs: tickMs);
  await server.start(address: InternetAddress.anyIPv4, port: port);
  stderr.writeln(
    'robot_server listening on ws://0.0.0.0:${server.port} (tick ${tickMs}ms)',
  );

  ProcessSignal.sigint.watch().listen((_) async {
    await server.stop();
    exit(0);
  });
}
