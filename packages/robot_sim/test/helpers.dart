// SPDX-License-Identifier: Apache-2.0

import 'package:robot_sim/robot_sim.dart';

void runDemoMission(
  RobotSim sim, {
  required int ticks,
  int heartbeatEvery = 2,
}) {
  sim.missionSet(SimConfig.demoWaypoints);
  sim.heartbeat();
  sim.missionStart();
  for (var t = 1; t <= ticks; t++) {
    if (t % heartbeatEvery == 0) {
      sim.heartbeat();
    }
    sim.tick();
  }
}

List<String> collectTrace(
  RobotSim sim, {
  required int ticks,
  int heartbeatEvery = 2,
}) {
  sim.missionSet(SimConfig.demoWaypoints);
  sim.heartbeat();
  sim.missionStart();
  final lines = <String>[];
  for (var t = 1; t <= ticks; t++) {
    if (t % heartbeatEvery == 0) {
      sim.heartbeat();
    }
    sim.tick();
    lines.add(sim.traceLine());
  }
  return lines;
}

double straightLineOracleX(int k, {double x0 = 1.0, double dt = 0.05}) {
  var sum = 0.0;
  for (var i = 1; i <= k; i++) {
    final vi = (0.04 * i) < 0.6 ? 0.04 * i : 0.6;
    sum += vi;
  }
  return x0 + dt * sum;
}

double straightLineOracleV(int k) {
  final v = 0.04 * k;
  return v < 0.6 ? v : 0.6;
}
