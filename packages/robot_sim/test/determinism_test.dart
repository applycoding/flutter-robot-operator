// SPDX-License-Identifier: Apache-2.0

import 'package:robot_sim/robot_sim.dart';
import 'package:test/test.dart';

import 'helpers.dart';

void main() {
  group('criterion 13 determinism', () {
    test('two VM runs identical', () {
      final a = collectTrace(RobotSim(), ticks: 700);
      final b = collectTrace(RobotSim(), ticks: 700);
      expect(a, b);
    });
  });
}
