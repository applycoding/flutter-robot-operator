// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:operator_app/src/frame_codec.dart';
import 'package:operator_app/src/local_sim_transport.dart';
import 'package:robot_protocol/robot_protocol.dart';
import 'package:robot_sim/robot_sim.dart' as sim;

void main() {
  test('local transport demo mission through codec reaches running', () async {
    final transport = LocalSimTransport();
    final rejects = <String>[];
    transport.events.listen((e) {
      if (e.kind == 'reject') {
        rejects.add(e.code ?? '');
      }
    });
    await transport.connect();
    await transport.handshake();
    final session = transport.sessionId;
    expect(session, isNotNull);

    var seq = 1;
    void send(CommandType type, {List<(double, double)>? waypoints}) {
      transport.ingestClientFrame(
        ClientFrameCodec.sessioned(
          session: session!,
          seq: seq++,
          type: type,
          waypoints: waypoints,
        ),
      );
    }

    final wps = sim.SimConfig.demoWaypoints
        .map<(double, double)>((w) => (w[0], w[1]))
        .toList();
    send(CommandType.missionSet, waypoints: wps);
    expect(rejects, isEmpty);
    send(CommandType.heartbeat);
    send(CommandType.missionStart);

    final runningFuture = transport.snapshots
        .firstWhere((s) => s.mission == MissionState.running)
        .timeout(const Duration(seconds: 2));

    for (var t = 0; t < 20; t++) {
      if (t.isEven) {
        send(CommandType.heartbeat);
      }
      transport.stepTick();
    }

    await runningFuture;
    expect(rejects, isEmpty);
    transport.dispose();
  });
}
