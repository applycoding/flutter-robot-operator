// SPDX-License-Identifier: Apache-2.0

import 'dart:io';

import 'package:robot_sim/robot_sim.dart';

void main() {
  final sim = RobotSim();
  sim.missionSet(SimConfig.demoWaypoints);
  sim.heartbeat();
  sim.missionStart();
  final buf = StringBuffer();
  for (var t = 1; t <= 700; t++) {
    if (t % 2 == 0) {
      sim.heartbeat();
    }
    sim.tick();
    buf.writeln(sim.traceLine());
  }
  final out = File('packages/robot_sim/test/golden/demo_mission_trace.txt');
  out.parent.createSync(recursive: true);
  out.writeAsStringSync(buf.toString());
  stdout.writeln('Wrote ${out.path} (${700} lines)');
}
