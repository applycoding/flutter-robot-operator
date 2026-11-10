// SPDX-License-Identifier: Apache-2.0

import 'package:robot_sim/robot_sim.dart';
import 'package:test/test.dart';

void main() {
  group('criterion 5 e-stop braking', () {
    test('bounded decel and rest timing', () {
      final sim = RobotSim();
      sim.missionSet(SimConfig.demoWaypoints);
      sim.heartbeat();
      sim.missionStart();

      var e = 0;
      for (var t = 1; t <= 500; t++) {
        if (t % 2 == 0) {
          sim.heartbeat();
        }
        sim.tick();
        if (sim.snapshot().v >= 0.6 - 1e-12) {
          e = t;
          sim.estop();
          break;
        }
      }
      expect(e, greaterThan(0), reason: 'never reached 0.6 m/s');

      expect(sim.snapshot().latched, isTrue);
      expect(sim.snapshot().mission, MissionState.paused);

      final xE = sim.snapshot().x;
      var prevV = sim.snapshot().v;

      var restTick = 0;
      for (var t = e + 1; t <= e + 107; t++) {
        if (t % 2 == 0) {
          sim.heartbeat();
        }
        sim.tick();
        final s = sim.snapshot();
        if (t >= e + 1 && prevV > 1e-12) {
          final drop = prevV - s.v;
          expect(drop, lessThanOrEqualTo(2.0 * 0.05 + 1e-12));
          if (s.v > 1e-12) {
            expect(drop, greaterThan(0));
          }
        }
        if (restTick == 0 && s.v.abs() <= 1e-12 && s.w.abs() <= 1e-12) {
          restTick = t;
        }
        if (t >= e + 7) {
          expect(s.v, closeTo(0, 1e-12));
          expect(s.w, closeTo(0, 1e-12));
        }
        prevV = s.v;
      }
      expect(restTick, greaterThan(0));

      final xE7 = sim.snapshot().x;
      expect((xE7 - xE).abs(), lessThanOrEqualTo(0.10));
    });
  });

  group('criterion 6 latch rules', () {
    test('same-tick reset, resume while latched, reset at E+7', () {
      final sim = RobotSim();
      sim.missionSet(SimConfig.demoWaypoints);
      sim.heartbeat();
      sim.missionStart();

      var e = 0;
      for (var t = 1; t <= 500; t++) {
        if (t % 2 == 0) {
          sim.heartbeat();
        }
        sim.tick();
        if (sim.snapshot().v >= 0.6 - 1e-12) {
          e = t;
          sim.estop();
          final sameTickReset = sim.estopReset();
          expect(sameTickReset.ok, isFalse);
          expect(sameTickReset.code, RejectCode.stillMoving);
          break;
        }
      }

      expect(sim.missionStart().code, RejectCode.estopLatched);
      expect(sim.missionResume().code, RejectCode.estopLatched);

      final moving = RobotSim();
      moving.missionSet(SimConfig.demoWaypoints);
      moving.heartbeat();
      moving.missionStart();
      for (var t = 1; t <= e; t++) {
        if (t % 2 == 0) {
          moving.heartbeat();
        }
        moving.tick();
      }
      moving.estop();
      moving.tick();
      expect(moving.snapshot().latched, isTrue);
      expect(moving.snapshot().v, greaterThan(0.05));
      final midReset = moving.estopReset();
      expect(midReset.ok, isFalse);
      expect(midReset.code, RejectCode.stillMoving);

      for (var t = e + 1; t <= e + 7; t++) {
        if (t % 2 == 0) {
          sim.heartbeat();
        }
        sim.tick();
      }
      expect(sim.estopReset().ok, isTrue);
      expect(sim.snapshot().mission, MissionState.paused);
      expect(sim.snapshot().v, closeTo(0, 1e-12));

      for (var t = e + 8; t <= e + 20; t++) {
        if (t % 2 == 0) {
          sim.heartbeat();
        }
        sim.tick();
        expect(sim.snapshot().mission, MissionState.paused);
        expect(sim.snapshot().v, closeTo(0, 1e-12));
      }
    });
  });

  group('negative config e-stop', () {
    test('weakened aEstop detected', () {
      final weak = SimConfig.standard.copyWith(estopUsesAMax: true);
      final sim = RobotSim(config: weak);
      sim.missionSet(SimConfig.demoWaypoints);
      sim.heartbeat();
      sim.missionStart();
      var e = 0;
      for (var t = 1; t <= 200; t++) {
        if (t % 2 == 0) {
          sim.heartbeat();
        }
        sim.tick();
        if (sim.snapshot().v >= 0.6 - 1e-12) {
          e = t;
          sim.estop();
          break;
        }
      }
      final x0 = sim.snapshot().x;
      for (var i = 0; i < 30; i++) {
        sim.tick();
      }
      final travelled = (sim.snapshot().x - x0).abs();
      final strong = RobotSim();
      strong.missionSet(SimConfig.demoWaypoints);
      strong.heartbeat();
      strong.missionStart();
      for (var t = 1; t <= e; t++) {
        if (t % 2 == 0) {
          strong.heartbeat();
        }
        strong.tick();
      }
      strong.estop();
      final x0s = strong.snapshot().x;
      for (var i = 0; i < 30; i++) {
        strong.tick();
      }
      final travelledStrong = (strong.snapshot().x - x0s).abs();
      expect(travelled > travelledStrong, isTrue);
    });

    test('instant snap detected', () {
      final snap = SimConfig.standard.copyWith(instantEstopSnap: true);
      final sim = RobotSim(config: snap);
      sim.missionSet(SimConfig.demoWaypoints);
      sim.heartbeat();
      sim.missionStart();
      for (var t = 1; t <= 200; t++) {
        if (t % 2 == 0) {
          sim.heartbeat();
        }
        sim.tick();
        if (sim.snapshot().v >= 0.6 - 1e-12) {
          final vBefore = sim.snapshot().v;
          sim.estop();
          sim.tick();
          final drop = vBefore - sim.snapshot().v;
          expect(drop > 2.0 * 0.05 + 1e-9, isTrue);
          return;
        }
      }
      fail('did not reach speed');
    });
  });
}
