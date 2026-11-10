// SPDX-License-Identifier: Apache-2.0

import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:operator_app/src/world_to_screen.dart';

void main() {
  test('worldToScreen round-trips within 0.5 logical px', () {
    const viewport = MapViewport(
      mapWidthM: 10,
      mapHeightM: 6,
      canvasSize: Size(640, 384),
      padding: 8,
    );
    final samples = <(double, double)>[
      (0, 0),
      (10, 6),
      (1.0, 1.0),
      (4.7, 4.6),
      (9.2, 2.4),
      (5.5, 3.3),
    ];
    for (final (x, y) in samples) {
      final screen = viewport.worldToScreen(x, y);
      final back = viewport.screenToWorld(screen);
      final err = math.sqrt(
        math.pow(back.dx - x, 2) + math.pow(back.dy - y, 2),
      );
      final errPx = err * viewport.scale;
      expect(errPx, lessThanOrEqualTo(0.5));
    }
  });
}
