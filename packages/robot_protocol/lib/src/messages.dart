// SPDX-License-Identifier: Apache-2.0

/// Inbound command types from operator to robot server.
enum CommandType {
  hello,
  heartbeat,
  estop,
  estopReset,
  missionSet,
  missionStart,
  missionPause,
  missionResume,
  missionStop,
}

extension CommandTypeJson on CommandType {
  String get wireName => switch (this) {
    CommandType.hello => 'hello',
    CommandType.heartbeat => 'heartbeat',
    CommandType.estop => 'estop',
    CommandType.estopReset => 'estop_reset',
    CommandType.missionSet => 'mission_set',
    CommandType.missionStart => 'mission_start',
    CommandType.missionPause => 'mission_pause',
    CommandType.missionResume => 'mission_resume',
    CommandType.missionStop => 'mission_stop',
  };

  static CommandType? parse(String value) => switch (value) {
    'hello' => CommandType.hello,
    'heartbeat' => CommandType.heartbeat,
    'estop' => CommandType.estop,
    'estop_reset' => CommandType.estopReset,
    'mission_set' => CommandType.missionSet,
    'mission_start' => CommandType.missionStart,
    'mission_pause' => CommandType.missionPause,
    'mission_resume' => CommandType.missionResume,
    'mission_stop' => CommandType.missionStop,
    _ => null,
  };

  static const sessioned = {
    CommandType.heartbeat,
    CommandType.estop,
    CommandType.estopReset,
    CommandType.missionSet,
    CommandType.missionStart,
    CommandType.missionPause,
    CommandType.missionResume,
    CommandType.missionStop,
  };
}

/// Waypoint as `[x, y]` in metres.
typedef Waypoint = (double x, double y);

/// Parsed client frame after strict validation.
sealed class ClientFrame {
  const ClientFrame();

  CommandType get commandType;
}

final class HelloFrame extends ClientFrame {
  const HelloFrame();

  @override
  CommandType get commandType => CommandType.hello;
}

final class SessionedFrame extends ClientFrame {
  const SessionedFrame({
    required this.session,
    required this.seq,
    required this.type,
    required this.waypoints,
  });

  final String session;
  final int seq;
  final CommandType type;

  /// Non-empty only for [CommandType.missionSet].
  final List<Waypoint> waypoints;

  @override
  CommandType get commandType => type;
}

/// Axis-aligned obstacle rectangle in world metres `[x0, y0, x1, y1]`.
typedef ObstacleRect = (double x0, double y0, double x1, double y1);

/// Map description sent in [WelcomeMessage].
final class MapInfo {
  const MapInfo({
    required this.widthM,
    required this.heightM,
    required this.cellM,
    required this.obstacles,
  });

  final double widthM;
  final double heightM;
  final double cellM;
  final List<ObstacleRect> obstacles;

  Map<String, Object?> toJson() => {
    'width_m': widthM,
    'height_m': heightM,
    'cell_m': cellM,
    'obstacles': [
      for (final o in obstacles) [o.$1, o.$2, o.$3, o.$4],
    ],
  };
}

/// Server outbound messages.
sealed class ServerMessage {
  const ServerMessage();

  Map<String, Object?> toJson();
}

final class WelcomeMessage extends ServerMessage {
  const WelcomeMessage({
    required this.session,
    required this.tickDtS,
    required this.map,
  });

  final String session;
  final double tickDtS;
  final MapInfo map;

  @override
  Map<String, Object?> toJson() => {
    'type': 'welcome',
    'session': session,
    'tick_dt_s': tickDtS,
    'map': map.toJson(),
  };
}

final class AckMessage extends ServerMessage {
  const AckMessage({required this.seq, this.note});

  final int seq;
  final String? note;

  @override
  Map<String, Object?> toJson() => {
    'type': 'ack',
    'seq': seq,
    'ok': true,
    if (note != null) 'note': note!,
  };
}

final class RejectMessage extends ServerMessage {
  const RejectMessage({required this.seq, required this.code});

  final int seq;
  final String code;

  @override
  Map<String, Object?> toJson() => {'type': 'reject', 'seq': seq, 'code': code};
}

final class ErrorMessage extends ServerMessage {
  const ErrorMessage({required this.code});

  final String code;

  @override
  Map<String, Object?> toJson() => {'type': 'error', 'code': code};
}

/// Mission state string in snapshots (matches simulation).
enum MissionState { idle, ready, running, paused, succeeded, fault }

extension MissionStateJson on MissionState {
  String get wireName => name;

  static MissionState parse(String value) => MissionState.values.firstWhere(
    (s) => s.name == value,
    orElse: () => throw ArgumentError('unknown mission state: $value'),
  );
}

final class SnapshotMessage extends ServerMessage {
  const SnapshotMessage({
    required this.tick,
    required this.x,
    required this.y,
    required this.theta,
    required this.v,
    required this.w,
    required this.mission,
    required this.wpIndex,
    required this.latched,
    required this.deadman,
    required this.fault,
    required this.heartbeatAgeTicks,
    required this.clearance,
  });

  final int tick;
  final double x;
  final double y;
  final double theta;
  final double v;
  final double w;
  final MissionState mission;
  final int wpIndex;
  final bool latched;
  final bool deadman;
  final String? fault;
  final int heartbeatAgeTicks;
  final double clearance;

  @override
  Map<String, Object?> toJson() => {
    'type': 'snapshot',
    'tick': tick,
    'x': x,
    'y': y,
    'theta': theta,
    'v': v,
    'w': w,
    'mission': mission.wireName,
    'wp_index': wpIndex,
    'latched': latched,
    'deadman': deadman,
    'fault': fault,
    'heartbeat_age_ticks': heartbeatAgeTicks,
    'clearance': clearance,
  };
}
