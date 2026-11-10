// SPDX-License-Identifier: Apache-2.0

import 'package:flutter_test/flutter_test.dart';
import 'package:operator_app/src/operator_controller.dart';
import 'package:robot_protocol/robot_protocol.dart';

import 'fake_transport.dart';

void main() {
  late FakeTransport transport;
  late OperatorController controller;

  setUp(() async {
    transport = FakeTransport();
    controller = OperatorController(transport);
    await controller.start();
  });

  tearDown(() {
    controller.dispose();
    transport.dispose();
  });

  SnapshotMessage snap({
    MissionState mission = MissionState.idle,
    bool latched = false,
    bool deadman = false,
    double v = 0,
    double w = 0,
    int hbAge = 0,
  }) {
    return SnapshotMessage(
      tick: 1,
      x: 1,
      y: 1,
      theta: 0,
      v: v,
      w: w,
      mission: mission,
      wpIndex: 0,
      latched: latched,
      deadman: deadman,
      fault: null,
      heartbeatAgeTicks: hbAge,
      clearance: 1,
    );
  }

  test('load demo sends mission_set', () async {
    transport.setSnapshot(snap(mission: MissionState.idle));
    expect(controller.canLoadDemoMission, isTrue);
    await controller.loadDemoMission();
    expect(transport.lastCommandType, CommandType.missionSet);
  });

  test('start enabled only when ready with fresh heartbeat', () async {
    controller.setLinkLossSimulated(true);
    transport.setSnapshot(snap(mission: MissionState.ready, hbAge: 2));
    expect(controller.snapshot?.mission, MissionState.ready);
    expect(controller.canStart, isTrue);
    transport.setSnapshot(snap(mission: MissionState.ready, hbAge: 11));
    expect(controller.canStart, isFalse);
    transport.setSnapshot(snap(mission: MissionState.ready, latched: true));
    expect(controller.canStart, isFalse);
  });

  test('estop sends exactly one frame', () async {
    controller.setLinkLossSimulated(true);
    await controller.estop();
    expect(transport.sentFrames.length, 1);
    expect(transport.lastCommandType, CommandType.estop);
    await controller.estop();
    expect(transport.sentFrames.length, 2);
    expect(transport.sentFrames.where((f) => f.contains('"estop"')).length, 2);
  });
}
