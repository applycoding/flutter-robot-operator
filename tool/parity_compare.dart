// SPDX-License-Identifier: Apache-2.0

import 'dart:io';
import 'dart:math' as math;

import 'package:robot_sim/robot_sim.dart';

class _TracePoint {
  const _TracePoint({
    required this.tick,
    required this.x,
    required this.y,
    required this.mission,
  });

  final int tick;
  final double x;
  final double y;
  final String mission;
}

_TracePoint _parseTraceLine(String line) {
  final parts = line.split(' ');
  if (parts.length < 7) {
    throw FormatException('bad trace line: $line');
  }
  return _TracePoint(
    tick: int.parse(parts[0]),
    x: double.parse(parts[1]),
    y: double.parse(parts[2]),
    mission: parts[6],
  );
}

/// Compares VM demo trace with a Node dart2js trace (criterion 13).
Future<void> main(List<String> args) async {
  final vmOut = File(args.isNotEmpty ? args[0] : 'parity_vm.txt');
  final jsOut = File(args.length > 1 ? args[1] : 'parity_js.txt');

  if (!jsOut.existsSync()) {
    stderr.writeln('parity_js.txt missing (dart2js / Node trace required)');
    exit(1);
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

  int? vmFirstSuccess;
  int? jsFirstSuccess;
  var maxPose = 0.0;

  for (var i = 0; i < vmLines.length; i++) {
    final vp = _parseTraceLine(vmLines[i]);
    final jp = _parseTraceLine(jsLines[i]);

    if (vp.mission != jp.mission) {
      stderr.writeln(
        'mission mismatch tick ${vp.tick}: vm=${vp.mission} js=${jp.mission}',
      );
      exit(1);
    }

    if (vp.mission == 'succeeded' && vmFirstSuccess == null) {
      vmFirstSuccess = vp.tick;
    }
    if (jp.mission == 'succeeded' && jsFirstSuccess == null) {
      jsFirstSuccess = jp.tick;
    }

    final dx = (vp.x - jp.x).abs();
    final dy = (vp.y - jp.y).abs();
    maxPose = math.max(maxPose, math.max(dx, dy));
    if (dx > 1e-9 || dy > 1e-9) {
      stderr.writeln('pose mismatch tick ${vp.tick}: Δx=$dx Δy=$dy');
      exit(1);
    }
  }

  if (vmFirstSuccess != jsFirstSuccess) {
    stderr.writeln(
      'first success tick mismatch: vm=$vmFirstSuccess js=$jsFirstSuccess',
    );
    exit(1);
  }

  stdout.writeln(
    'parity ok (first success tick $vmFirstSuccess, max pose Δ $maxPose m, '
    '${vmLines.length} lines).',
  );
}
