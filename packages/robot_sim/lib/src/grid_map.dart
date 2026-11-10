// SPDX-License-Identifier: Apache-2.0

import 'dart:math' as math;

import 'config.dart';

/// Axis-aligned obstacle rectangle in world metres.
class ObstacleRect {
  const ObstacleRect({
    required this.xMin,
    required this.xMax,
    required this.yMin,
    required this.yMax,
  });

  final double xMin;
  final double xMax;
  final double yMin;
  final double yMax;
}

/// 10 x 6 m occupancy map with exact clearance queries.
class GridMap {
  GridMap(this.config)
    : obstacles = const [
        ObstacleRect(xMin: 3.0, xMax: 3.4, yMin: 0.0, yMax: 3.5),
        ObstacleRect(xMin: 6.0, xMax: 6.4, yMin: 2.5, yMax: 6.0),
        ObstacleRect(xMin: 8.0, xMax: 8.6, yMin: 1.0, yMax: 1.6),
      ];

  final SimConfig config;
  final List<ObstacleRect> obstacles;

  bool isInsideMap(double x, double y) =>
      x >= 0 && x <= config.mapWidth && y >= 0 && y <= config.mapHeight;

  /// Exact Euclidean clearance from centre to nearest obstacle or map edge.
  double clearanceAt(double x, double y) {
    var best = double.infinity;

    final toLeft = x;
    final toRight = config.mapWidth - x;
    final toBottom = y;
    final toTop = config.mapHeight - y;
    best = math.min(best, math.min(toLeft, toRight));
    best = math.min(best, math.min(toBottom, toTop));

    if (x < 0 || x > config.mapWidth || y < 0 || y > config.mapHeight) {
      return 0;
    }

    for (final o in obstacles) {
      final d = _distancePointToRect(x, y, o);
      best = math.min(best, d);
    }
    return best;
  }

  bool contactAt(double x, double y) =>
      clearanceAt(x, y) < config.footprintRadius;

  /// True when the inflated footprint is clear at (x, y).
  bool inflatedClearAt(double x, double y) {
    if (!isInsideMap(x, y)) {
      return false;
    }
    return clearanceAt(x, y) >= config.inflatedFootprintRadius;
  }

  static double _distancePointToRect(double px, double py, ObstacleRect r) {
    final cx = px.clamp(r.xMin, r.xMax);
    final cy = py.clamp(r.yMin, r.yMax);
    final dx = px - cx;
    final dy = py - cy;
    if (px >= r.xMin && px <= r.xMax && py >= r.yMin && py <= r.yMax) {
      return 0;
    }
    return math.sqrt(dx * dx + dy * dy);
  }
}
