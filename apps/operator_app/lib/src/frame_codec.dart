// SPDX-License-Identifier: Apache-2.0

import 'dart:convert';

import 'package:robot_protocol/robot_protocol.dart';

/// Encodes outbound client JSON frames (strict schema).
abstract final class ClientFrameCodec {
  static String hello() => jsonEncode({'v': 1, 'type': 'hello'});

  static String sessioned({
    required String session,
    required int seq,
    required CommandType type,
    List<Waypoint>? waypoints,
  }) {
    final Object body = switch (type) {
      CommandType.missionSet => {
        'waypoints': [
          for (final w in waypoints ?? const <Waypoint>[]) [w.$1, w.$2],
        ],
      },
      _ => <String, Object?>{},
    };
    return jsonEncode({
      'v': 1,
      'type': type.wireName,
      'session': session,
      'seq': seq,
      'body': body,
    });
  }
}
