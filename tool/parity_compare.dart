// SPDX-License-Identifier: Apache-2.0

import 'dart:io';

import 'package:robot_sim/robot_sim.dart';

/// Compares VM demo trace with a Node dart2js trace file (stub-friendly).
Future<void> main(List<String> args) async {
  final vmOut = File(args.isNotEmpty ? args[0] : 'parity_vm.txt');
  final jsOut = File(args.length > 1 ? args[1] : 'parity_js.txt');

  if (!jsOut.existsSync()) {
    stdout.writeln(
      'parity_js.txt missing — run: dart run tool/parity_js.dart > parity_vm.txt '
      '&& dart compile js -O2 tool/parity_js.dart -o parity_js.mjs '
      '&& node parity_js.mjs > parity_js.txt',
    );
    exit(0);
  }

  final sim = RobotSim();
  sim.missionSet(SimConfig.demoWaypoints);
  sim.heartbeat();
  sim.missionStart();
  final vm = StringBuffer();
  for (var t = 1; t <= 700; t++) {
    if (t % 2 == 0) {
      sim.heartbeat();
    }
    sim.tick();
    vm.writeln(sim.traceLine());
  }
  vmOut.writeAsStringSync(vm.toString());

  final jsLines = jsOut.readAsLinesSync();
  final vmLines = vmOut.readAsLinesSync();
  if (jsLines.length != vmLines.length) {
    stderr.writeln(
      'line count mismatch: vm=${vmLines.length} js=${jsLines.length}',
    );
    exit(1);
  }
  var maxPose = 0.0;
  for (var i = 0; i < vmLines.length; i++) {
    if (vmLines[i] != jsLines[i]) {
      final vp = vmLines[i].split(' ');
      final jp = jsLines[i].split(' ');
      if (vp.length >= 3 && jp.length >= 3) {
        final dx = (double.parse(vp[1]) - double.parse(jp[1])).abs();
        final dy = (double.parse(vp[2]) - double.parse(jp[2])).abs();
        maxPose = [maxPose, dx, dy].reduce((a, b) => a > b ? a : b);
      }
      if (maxPose > 1e-9) {
        stderr.writeln(
          'divergence at line ${i + 1}: ${vmLines[i]} vs ${jsLines[i]}',
        );
        exit(1);
      }
    }
  }
  stdout.writeln(
    'parity ok (max pose delta $maxPose m, ${vmLines.length} lines).',
  );
}
