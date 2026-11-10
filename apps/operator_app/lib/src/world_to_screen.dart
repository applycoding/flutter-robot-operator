// SPDX-License-Identifier: Apache-2.0

import 'dart:math' as math;
import 'dart:ui';

/// Map viewport transform: world metres (origin bottom-left) to logical pixels.
final class MapViewport {
  const MapViewport({
    required this.mapWidthM,
    required this.mapHeightM,
    required this.canvasSize,
    this.padding = 8.0,
  });

  final double mapWidthM;
  final double mapHeightM;
  final Size canvasSize;
  final double padding;

  double get _drawWidth => canvasSize.width - 2 * padding;
  double get _drawHeight => canvasSize.height - 2 * padding;

  double get scale =>
      math.min(_drawWidth / mapWidthM, _drawHeight / mapHeightM);

  Offset get _origin => Offset(
    padding + (_drawWidth - mapWidthM * scale) / 2,
    padding + (_drawHeight - mapHeightM * scale) / 2,
  );

  Offset worldToScreen(double xM, double yM) {
    final px = _origin.dx + xM * scale;
    final py = _origin.dy + (mapHeightM - yM) * scale;
    return Offset(px, py);
  }

  Offset screenToWorld(Offset screen) {
    final xM = (screen.dx - _origin.dx) / scale;
    final yM = mapHeightM - (screen.dy - _origin.dy) / scale;
    return Offset(xM, yM);
  }

  double metresToPixels(double metres) => metres * scale;
}
