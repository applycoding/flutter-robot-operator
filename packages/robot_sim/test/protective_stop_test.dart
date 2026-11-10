// SPDX-License-Identifier: Apache-2.0

import 'package:robot_sim/robot_sim.dart';
import 'package:test/test.dart';

void main() {
  group('criterion 8 protective stop', () {
    test('fault without contact', () {
      final sim = RobotSim.forTest();
      sim.missionSet([
        [2.9, 1.0],
      ]);
      sim.heartbeat();
      sim.missionStart();
      var contactTicks = 0;
      for (var t = 1; t <= 200; t++) {
        if (t % 2 == 0) {
          sim.heartbeat();
        }
        sim.tick();
        if (sim.snapshot().contact) {
          contactTicks++;
        }
      }
      final s = sim.snapshot();
      expect(s.mission, MissionState.fault);
      expect(s.fault, FaultCode.obstacleAhead.code);
      expect(contactTicks, 0);
      expect(s.v, closeTo(0, 1e-12));
    });

    test('disabled check allows contacts', () {
      final cfg = SimConfig.standard.copyWith(protectiveStopEnabled: false);
      final sim = RobotSim.forTest(config: cfg);
      sim.missionSet([
        [2.9, 1.0],
      ]);
      sim.heartbeat();
      sim.missionStart();
      var contactTicks = 0;
      for (var t = 1; t <= 200; t++) {
        if (t % 2 == 0) {
          sim.heartbeat();
        }
        sim.tick();
        if (sim.snapshot().contact) {
          contactTicks++;
        }
      }
      expect(contactTicks, greaterThan(0));
    });
  });
}
