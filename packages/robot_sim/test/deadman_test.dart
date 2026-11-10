// SPDX-License-Identifier: Apache-2.0

import 'package:robot_sim/robot_sim.dart';
import 'package:test/test.dart';

void main() {
  group('criterion 7 deadman', () {
    test('trip, decel, resume rules', () {
      final sim = RobotSim();
      sim.missionSet(SimConfig.demoWaypoints);
      sim.heartbeat();
      sim.missionStart();

      var h = 0;
      for (var t = 1; t <= 500; t++) {
        if (h == 0) {
          if (t % 2 == 0) {
            sim.heartbeat();
          }
        }
        sim.tick();
        if (h == 0 && sim.snapshot().v >= 0.6 - 1e-12) {
          h = t;
          sim.heartbeat();
          break;
        }
      }
      expect(h, greaterThan(0));

      for (var t = h + 1; t <= h + 10; t++) {
        sim.tick();
      }
      expect(sim.snapshot().mission, MissionState.running);

      sim.tick();
      expect(sim.snapshot().mission, MissionState.paused);
      expect(sim.snapshot().deadman, isTrue);

      var prevV = sim.snapshot().v;
      for (var t = h + 12; t <= h + 23; t++) {
        sim.tick();
        final s = sim.snapshot();
        expect(prevV - s.v, lessThanOrEqualTo(1.0 * 0.05 + 1e-12));
        prevV = s.v;
      }
      expect(sim.snapshot().v, closeTo(0, 1e-12));

      expect(sim.missionResume().code, RejectCode.deadman);
      sim.heartbeat();
      expect(sim.missionResume().ok, isTrue);
    });
  });

  group('negative config deadman disabled', () {
    test('never trips', () {
      final cfg = SimConfig.standard.copyWith(deadmanEnabled: false);
      final sim = RobotSim(config: cfg);
      sim.missionSet(SimConfig.demoWaypoints);
      sim.heartbeat();
      sim.missionStart();
      var h = 0;
      for (var t = 1; t <= 500; t++) {
        if (t == 1) {
          sim.heartbeat();
        }
        sim.tick();
        if (sim.snapshot().v >= 0.6 - 1e-12) {
          h = t;
          break;
        }
      }
      for (var t = h + 1; t <= h + 50; t++) {
        sim.tick();
      }
      expect(sim.snapshot().mission, MissionState.running);
      expect(sim.snapshot().deadman, isFalse);
    });
  });
}
