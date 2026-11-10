// SPDX-License-Identifier: Apache-2.0

import 'dart:io';

import 'package:robot_sim/robot_sim.dart';
import 'package:test/test.dart';

import 'helpers.dart';

void main() {
  group('criterion 3 demo mission', () {
    test('fixed ticks and clearance', () {
      final s300 = _snapshotAtTick(RobotSim(), 300);
      expect(s300.mission, MissionState.running);

      final s600 = _snapshotAtTick(RobotSim(), 600);
      expect(s600.mission, MissionState.succeeded);

      final simClear = RobotSim();
      simClear.missionSet(SimConfig.demoWaypoints);
      simClear.heartbeat();
      simClear.missionStart();
      for (var t = 1; t <= 700; t++) {
        if (t % 2 == 0) {
          simClear.heartbeat();
        }
        simClear.tick();
        final s = simClear.snapshot();
        expect(s.contact, isFalse);
        expect(s.clearance, greaterThanOrEqualTo(0.35 - 1e-12));
      }
      final s700 = simClear.snapshot();
      expect(s700.mission, MissionState.succeeded);
      expect(s700.v, closeTo(0, 1e-12));
      expect(s700.wpIndex, 5);
      expect((s700.x - 9.2).abs(), lessThan(0.15));
      expect((s700.y - 2.4).abs(), lessThan(0.15));
    });
  });

  group('criterion 4 golden trace', () {
    test('lines 1-700 match golden file', () {
      final sim = RobotSim();
      final lines = collectTrace(sim, ticks: 700);
      final goldenPath = Directory.current.path.endsWith('robot_sim')
          ? 'test/golden/demo_mission_trace.txt'
          : 'packages/robot_sim/test/golden/demo_mission_trace.txt';
      final goldenFile = File(goldenPath);
      expect(
        goldenFile.existsSync(),
        isTrue,
        reason: 'Run dart run ../../tool/regen_golden.dart first',
      );
      final golden = goldenFile.readAsLinesSync();
      expect(lines.length, golden.length);
      for (var i = 0; i < lines.length; i++) {
        expect(lines[i], golden[i], reason: 'tick ${i + 1}');
      }
    });
  });
}

SimSnapshot _snapshotAtTick(RobotSim sim, int target) {
  sim.missionSet(SimConfig.demoWaypoints);
  sim.heartbeat();
  sim.missionStart();
  SimSnapshot? snap;
  for (var t = 1; t <= target; t++) {
    if (t % 2 == 0) {
      sim.heartbeat();
    }
    sim.tick();
    if (t == target) {
      snap = sim.snapshot();
    }
  }
  return snap!;
}
