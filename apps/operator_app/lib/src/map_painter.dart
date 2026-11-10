// SPDX-License-Identifier: Apache-2.0

import 'dart:math' as math;
import 'dart:ui' show Canvas, Offset, Paint, Path, PointMode, Size;

import 'package:flutter/material.dart';
import 'package:robot_sim/robot_sim.dart' as sim;

import 'operator_controller.dart';
import 'world_to_screen.dart';

/// Occupancy map, mission polyline, travelled path, robot disc and heading.
class RobotMapPainter extends CustomPainter {
  RobotMapPainter({required this.controller, required this.viewport});

  final OperatorController controller;
  final MapViewport viewport;

  @override
  void paint(Canvas canvas, Size size) {
    final mapInfo = controller.map;
    final snap = controller.snapshot;
    if (mapInfo == null) {
      return;
    }

    final obstaclePaint = Paint()..color = const Color(0xFF424242);
    final gridPaint = Paint()
      ..color = const Color(0x1A000000)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    for (var x = 0.0; x <= mapInfo.widthM; x += mapInfo.cellM) {
      final a = viewport.worldToScreen(x, 0);
      final b = viewport.worldToScreen(x, mapInfo.heightM);
      canvas.drawLine(a, b, gridPaint);
    }
    for (var y = 0.0; y <= mapInfo.heightM; y += mapInfo.cellM) {
      final a = viewport.worldToScreen(0, y);
      final b = viewport.worldToScreen(mapInfo.widthM, y);
      canvas.drawLine(a, b, gridPaint);
    }

    final inflated = sim.SimConfig.standard.inflatedFootprintRadius;
    final inflatedPaint = Paint()
      ..color = const Color(0x33FF9800)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (final o in mapInfo.obstacles) {
      final topLeft = viewport.worldToScreen(o.$1, o.$4);
      final bottomRight = viewport.worldToScreen(o.$3, o.$2);
      final rect = Rect.fromPoints(topLeft, bottomRight);
      canvas.drawRect(rect, obstaclePaint);
      final centre = viewport.worldToScreen(
        (o.$1 + o.$3) / 2,
        (o.$2 + o.$4) / 2,
      );
      canvas.drawCircle(
        centre,
        viewport.metresToPixels(inflated),
        inflatedPaint,
      );
    }

    if (controller.missionWaypoints.isNotEmpty) {
      final missionPaint = Paint()
        ..color = Colors.blueAccent
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;
      final points = <Offset>[
        if (snap != null) viewport.worldToScreen(snap.x, snap.y),
        for (final w in controller.missionWaypoints)
          viewport.worldToScreen(w.$1, w.$2),
      ];
      if (points.length >= 2) {
        canvas.drawPoints(PointMode.polygon, points, missionPaint);
      }
      final wpPaint = Paint()..color = Colors.blue;
      for (final w in controller.missionWaypoints) {
        final p = viewport.worldToScreen(w.$1, w.$2);
        canvas.drawCircle(p, 4, wpPaint);
      }
    }

    if (controller.travelledPath.length >= 2) {
      final pathPaint = Paint()
        ..color = Colors.teal
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke;
      final path = Path();
      final first = viewport.worldToScreen(
        controller.travelledPath.first.dx,
        controller.travelledPath.first.dy,
      );
      path.moveTo(first.dx, first.dy);
      for (var i = 1; i < controller.travelledPath.length; i++) {
        final p = controller.travelledPath[i];
        final s = viewport.worldToScreen(p.dx, p.dy);
        path.lineTo(s.dx, s.dy);
      }
      canvas.drawPath(path, pathPaint);
    }

    if (snap != null) {
      final centre = viewport.worldToScreen(snap.x, snap.y);
      final radius = viewport.metresToPixels(
        sim.SimConfig.standard.footprintRadius,
      );
      final bodyPaint = Paint()..color = Colors.green.shade700;
      canvas.drawCircle(centre, radius, bodyPaint);
      final tip = viewport.worldToScreen(
        snap.x + math.cos(snap.theta) * sim.SimConfig.standard.footprintRadius,
        snap.y + math.sin(snap.theta) * sim.SimConfig.standard.footprintRadius,
      );
      final headingPaint = Paint()
        ..color = Colors.white
        ..strokeWidth = 2;
      canvas.drawLine(centre, tip, headingPaint);
    }
  }

  @override
  bool shouldRepaint(covariant RobotMapPainter oldDelegate) => true;
}

class MapView extends StatelessWidget {
  const MapView({super.key, required this.controller});

  final OperatorController controller;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final map = controller.map;
        final viewport = MapViewport(
          mapWidthM: map?.widthM ?? sim.SimConfig.standard.mapWidth,
          mapHeightM: map?.heightM ?? sim.SimConfig.standard.mapHeight,
          canvasSize: size,
        );
        return CustomPaint(
          painter: RobotMapPainter(controller: controller, viewport: viewport),
          size: size,
        );
      },
    );
  }
}
