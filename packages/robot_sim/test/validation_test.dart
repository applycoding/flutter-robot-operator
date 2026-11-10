// SPDX-License-Identifier: Apache-2.0

import 'package:robot_sim/robot_sim.dart';
import 'package:test/test.dart';

void main() {
  group('criterion 9 validation', () {
    late RobotSim sim;

    setUp(() {
      sim = RobotSim();
    });

    test('waypoint in obstacle', () {
      final r = sim.missionSet([
        [3.2, 1.0],
      ]);
      expect(r.ok, isFalse);
      expect(r.code, RejectCode.invalidMission);
      expect(r.reason, RejectCode.waypointInObstacle);
    });

    test('segment blocked', () {
      final r = sim.missionSet([
        [5.0, 1.0],
      ]);
      expect(r.ok, isFalse);
      expect(r.reason, RejectCode.segmentBlocked);
    });

    test('out of map', () {
      final r = sim.missionSet([
        [10.5, 1.0],
      ]);
      expect(r.ok, isFalse);
      expect(r.reason, RejectCode.outOfMap);
    });

    test('33 waypoints invalid', () {
      final wps = List<List<double>>.generate(33, (i) => [1.0 + i * 0.1, 1.0]);
      final r = sim.missionSet(wps);
      expect(r.ok, isFalse);
      expect(r.reason, RejectCode.invalid);
    });

    test('NaN invalid', () {
      final r = sim.missionSet([
        [double.nan, 1.0],
      ]);
      expect(r.ok, isFalse);
      expect(r.reason, RejectCode.invalid);
    });

    test('demo mission accepted', () {
      final r = sim.missionSet(SimConfig.demoWaypoints);
      expect(r.ok, isTrue);
    });
  });
}
