// SPDX-License-Identifier: Apache-2.0

import 'dart:convert';

import 'package:robot_protocol/robot_protocol.dart';

/// Parses server JSON into typed messages.
abstract final class SnapshotParse {
  static ServerMessage? tryParseServerMessage(String utf8Text) {
    final Object? parsed;
    try {
      parsed = jsonDecode(utf8Text);
    } on Object {
      return null;
    }
    if (parsed is! Map) {
      return null;
    }
    final type = parsed['type'];
    if (type is! String) {
      return null;
    }
    return switch (type) {
      'welcome' => _parseWelcome(parsed),
      'ack' => _parseAck(parsed),
      'reject' => _parseReject(parsed),
      'error' => _parseError(parsed),
      'snapshot' => _parseSnapshot(parsed),
      _ => null,
    };
  }

  static WelcomeMessage? _parseWelcome(Map<dynamic, dynamic> m) {
    final session = m['session'];
    final tickDt = m['tick_dt_s'];
    final mapRaw = m['map'];
    if (session is! String || tickDt is! num || mapRaw is! Map) {
      return null;
    }
    final width = mapRaw['width_m'];
    final height = mapRaw['height_m'];
    final cell = mapRaw['cell_m'];
    final obs = mapRaw['obstacles'];
    if (width is! num || height is! num || cell is! num || obs is! List) {
      return null;
    }
    final obstacles = <ObstacleRect>[];
    for (final item in obs) {
      if (item is! List || item.length != 4) {
        continue;
      }
      final a = item[0];
      final b = item[1];
      final c = item[2];
      final d = item[3];
      if (a is num && b is num && c is num && d is num) {
        obstacles.add((a.toDouble(), b.toDouble(), c.toDouble(), d.toDouble()));
      }
    }
    return WelcomeMessage(
      session: session,
      tickDtS: tickDt.toDouble(),
      map: MapInfo(
        widthM: width.toDouble(),
        heightM: height.toDouble(),
        cellM: cell.toDouble(),
        obstacles: obstacles,
      ),
    );
  }

  static AckMessage? _parseAck(Map<dynamic, dynamic> m) {
    final seq = m['seq'];
    final ok = m['ok'];
    if (seq is! int || ok != true) {
      return null;
    }
    final note = m['note'];
    return AckMessage(seq: seq, note: note is String ? note : null);
  }

  static RejectMessage? _parseReject(Map<dynamic, dynamic> m) {
    final seq = m['seq'];
    final code = m['code'];
    if (seq is! int || code is! String) {
      return null;
    }
    return RejectMessage(seq: seq, code: code);
  }

  static ErrorMessage? _parseError(Map<dynamic, dynamic> m) {
    final code = m['code'];
    if (code is! String) {
      return null;
    }
    return ErrorMessage(code: code);
  }

  static SnapshotMessage? _parseSnapshot(Map<dynamic, dynamic> m) {
    int? readInt(Object? v) => v is int ? v : null;
    double? readNum(Object? v) {
      if (v is int) {
        return v.toDouble();
      }
      if (v is double && v.isFinite) {
        return v;
      }
      return null;
    }

    final tick = readInt(m['tick']);
    final x = readNum(m['x']);
    final y = readNum(m['y']);
    final theta = readNum(m['theta']);
    final v = readNum(m['v']);
    final w = readNum(m['w']);
    final missionStr = m['mission'];
    final wpIndex = readInt(m['wp_index']);
    final latched = m['latched'];
    final deadman = m['deadman'];
    final fault = m['fault'];
    final hbAge = readInt(m['heartbeat_age_ticks']);
    final clearance = readNum(m['clearance']);
    if (tick == null ||
        x == null ||
        y == null ||
        theta == null ||
        v == null ||
        w == null ||
        missionStr is! String ||
        wpIndex == null ||
        latched is! bool ||
        deadman is! bool ||
        hbAge == null ||
        clearance == null) {
      return null;
    }
    MissionState mission;
    try {
      mission = MissionStateJson.parse(missionStr);
    } on Object {
      return null;
    }
    final faultCode = fault is String && fault.isNotEmpty ? fault : null;
    return SnapshotMessage(
      tick: tick,
      x: x,
      y: y,
      theta: theta,
      v: v,
      w: w,
      mission: mission,
      wpIndex: wpIndex,
      latched: latched,
      deadman: deadman,
      fault: faultCode,
      heartbeatAgeTicks: hbAge,
      clearance: clearance,
    );
  }
}
