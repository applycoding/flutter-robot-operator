// SPDX-License-Identifier: Apache-2.0

import 'package:robot_sim/robot_sim.dart';
import 'package:test/test.dart';

import 'helpers.dart';

void main() {
  group('criterion 1 straight-line oracle', () {
    test('ticks 1-20 and v_15', () {
      final sim = RobotSim();
      sim.missionSet([
        [2.6, 1.0],
      ]);
      sim.heartbeat();
      sim.missionStart();
      for (var k = 1; k <= 20; k++) {
        sim.heartbeat();
        sim.tick();
        final s = sim.snapshot();
        final expectedX = straightLineOracleX(k);
        expect((s.x - expectedX).abs(), lessThan(1e-12));
        if (k == 15) {
          expect((s.v - 0.6).abs(), lessThan(1e-12));
        }
      }
    });
  });

  group('criterion 2 limits on demo mission', () {
    test('every tick', () {
      final sim = RobotSim();
      sim.missionSet(SimConfig.demoWaypoints);
      sim.heartbeat();
      sim.missionStart();
      var prevV = 0.0;
      const dt = 0.05;
      const aMax = 0.8;
      for (var t = 1; t <= 700; t++) {
        if (t % 2 == 0) {
          sim.heartbeat();
        }
        sim.tick();
        final s = sim.snapshot();
        expect(s.v, greaterThanOrEqualTo(-1e-12));
        expect(s.v, lessThanOrEqualTo(0.6 + 1e-12));
        expect(s.w.abs(), lessThanOrEqualTo(1.5 + 1e-12));
        expect((s.v - prevV).abs(), lessThanOrEqualTo(aMax * dt + 1e-12));
        prevV = s.v;
      }
    });
  });
}
