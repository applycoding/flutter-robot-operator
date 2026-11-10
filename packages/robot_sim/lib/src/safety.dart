// SPDX-License-Identifier: Apache-2.0

import 'dart:math' as math;

import 'config.dart';
import 'grid_map.dart';

/// Predictive protective-stop check along the current heading.
class SafetyLayer {
  SafetyLayer(this.config, this.map);

  final SimConfig config;
  final GridMap map;

  /// Returns true if an obstacle is hit along the lookahead corridor.
  bool obstacleAhead({
    required double x,
    required double y,
    required double theta,
    required double vCmd,
  }) {
    if (!config.protectiveStopEnabled) {
      return false;
    }
    if (vCmd <= 0) {
      return false;
    }

    final brakingDist = (vCmd * vCmd) / (2 * config.aEstop);
    final lookahead =
        brakingDist + vCmd * config.dt + config.protectiveLookaheadExtra;
    final n = config.protectiveSampleCount;
    final inflation = config.inflatedFootprintRadius;

    for (var i = 1; i <= n; i++) {
      final s = lookahead * i / n;
      final px = x + s * math.cos(theta);
      final py = y + s * math.sin(theta);
      if (!map.isInsideMap(px, py)) {
        return true;
      }
      if (map.clearanceAt(px, py) < inflation) {
        return true;
      }
    }
    return false;
  }
}
