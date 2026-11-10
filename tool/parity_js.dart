// SPDX-License-Identifier: Apache-2.0

import 'package:robot_sim/robot_sim.dart';

/// Demo-mission trace for dart2js / Node parity (criterion 13).
void main() {
  final sim = RobotSim();
  sim.missionSet(SimConfig.demoWaypoints);
  sim.heartbeat();
  sim.missionStart();
  for (var t = 1; t <= 700; t++) {
    if (t % 2 == 0) {
      sim.heartbeat();
    }
    sim.tick();
    // ignore: avoid_print
    print(sim.traceLine());
  }
}
