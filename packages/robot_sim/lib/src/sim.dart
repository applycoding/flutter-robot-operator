// SPDX-License-Identifier: Apache-2.0

import 'dart:math' as math;

import 'config.dart';
import 'grid_map.dart';
import 'mission.dart';
import 'plant.dart';
import 'safety.dart';

/// Per-tick state exposed to protocol / tests.
class SimSnapshot {
  const SimSnapshot({
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
    required this.contact,
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
  final String fault;
  final int heartbeatAgeTicks;
  final double clearance;
  final bool contact;
}

class CommandResult {
  const CommandResult.ok() : ok = true, code = null, reason = null;
  const CommandResult.reject(this.code, [this.reason]) : ok = false;

  final bool ok;
  final String? code;
  final String? reason;
}

/// Main simulation façade.
class RobotSim {
  factory RobotSim({SimConfig? config, bool skipValidation = false}) {
    final cfg = config ?? SimConfig.standard;
    final sharedMap = GridMap(cfg);
    final sharedSafety = SafetyLayer(cfg, sharedMap);
    final sharedPlant = Plant(cfg, sharedMap, sharedSafety);
    return RobotSim._(
      cfg,
      sharedMap,
      sharedSafety,
      sharedPlant,
      skipValidation: skipValidation,
    );
  }

  RobotSim._(
    this.config,
    this.map,
    this.safety,
    this.plant, {
    this.skipValidation = false,
  });

  final bool skipValidation;

  factory RobotSim.forTest({bool skipValidation = true, SimConfig? config}) =>
      RobotSim(config: config, skipValidation: skipValidation);

  final SimConfig config;
  final GridMap map;
  final SafetyLayer safety;
  final Plant plant;

  CommandResult missionSet(List<List<double>> waypoints) {
    if (plant.mission == MissionState.running ||
        plant.mission == MissionState.paused) {
      return const CommandResult.reject(RejectCode.badState);
    }

    if (!skipValidation) {
      final vr = _validateMission(waypoints);
      if (vr != null) {
        return vr;
      }
    }

    plant.waypoints = waypoints
        .map((w) => [w[0], w[1]])
        .toList(growable: false);
    plant.wpIndex = 0;
    plant.faultCode = FaultCode.none;
    plant.deadman = false;
    if (plant.mission == MissionState.idle ||
        plant.mission == MissionState.succeeded ||
        plant.mission == MissionState.fault) {
      plant.mission = MissionState.ready;
    }
    return const CommandResult.ok();
  }

  CommandResult? _validateMission(List<List<double>> waypoints) {
    if (waypoints.isEmpty || waypoints.length > config.maxWaypoints) {
      return const CommandResult.reject(
        RejectCode.invalidMission,
        RejectCode.invalid,
      );
    }

    for (final w in waypoints) {
      if (w.length < 2) {
        return const CommandResult.reject(
          RejectCode.invalidMission,
          RejectCode.invalid,
        );
      }
      for (final c in w) {
        if (!c.isFinite) {
          return const CommandResult.reject(
            RejectCode.invalidMission,
            RejectCode.invalid,
          );
        }
      }
      final wx = w[0];
      final wy = w[1];
      if (!map.isInsideMap(wx, wy)) {
        return const CommandResult.reject(
          RejectCode.invalidMission,
          RejectCode.outOfMap,
        );
      }
      if (!map.inflatedClearAt(wx, wy)) {
        return const CommandResult.reject(
          RejectCode.invalidMission,
          RejectCode.waypointInObstacle,
        );
      }
    }

    var sx = plant.x;
    var sy = plant.y;
    for (final w in waypoints) {
      final wx = w[0];
      final wy = w[1];
      final blocked = _segmentBlocked(sx, sy, wx, wy);
      if (blocked) {
        return const CommandResult.reject(
          RejectCode.invalidMission,
          RejectCode.segmentBlocked,
        );
      }
      sx = wx;
      sy = wy;
    }
    return null;
  }

  bool _segmentBlocked(double x0, double y0, double x1, double y1) {
    final dx = x1 - x0;
    final dy = y1 - y0;
    final len = math.sqrt(dx * dx + dy * dy);
    if (len == 0) {
      return !map.inflatedClearAt(x0, y0);
    }
    final step = 0.05;
    final n = (len / step).ceil();
    for (var i = 0; i <= n; i++) {
      final t = i / n;
      final px = x0 + t * dx;
      final py = y0 + t * dy;
      if (!map.inflatedClearAt(px, py)) {
        return true;
      }
    }
    return false;
  }

  CommandResult missionStart() {
    if (plant.latched) {
      return const CommandResult.reject(RejectCode.estopLatched);
    }
    if (plant.mission != MissionState.ready) {
      return const CommandResult.reject(RejectCode.badState);
    }
    if (!plant.heartbeatFresh()) {
      return const CommandResult.reject(RejectCode.heartbeatStale);
    }
    plant.mission = MissionState.running;
    return const CommandResult.ok();
  }

  CommandResult missionPause() {
    if (plant.mission == MissionState.running) {
      plant.mission = MissionState.paused;
      return const CommandResult.ok();
    }
    return const CommandResult.reject(RejectCode.badState);
  }

  CommandResult missionResume() {
    if (plant.latched) {
      return const CommandResult.reject(RejectCode.estopLatched);
    }
    if (plant.deadman && !plant.heartbeatFresh()) {
      return const CommandResult.reject(RejectCode.deadman);
    }
    if (plant.mission != MissionState.paused) {
      return const CommandResult.reject(RejectCode.badState);
    }
    if (!plant.heartbeatFresh()) {
      return const CommandResult.reject(RejectCode.heartbeatStale);
    }
    if (!plant.fullyStopped()) {
      return const CommandResult.reject(RejectCode.notStopped);
    }
    plant.deadman = false;
    plant.mission = MissionState.running;
    return const CommandResult.ok();
  }

  CommandResult missionStop() {
    if (plant.mission == MissionState.running ||
        plant.mission == MissionState.paused ||
        plant.mission == MissionState.ready) {
      plant.mission = MissionState.idle;
      plant.waypoints = [];
      plant.wpIndex = 0;
      plant.deadman = false;
      plant.faultCode = FaultCode.none;
      return const CommandResult.ok();
    }
    return const CommandResult.reject(RejectCode.badState);
  }

  void estop() {
    plant.onEstop();
  }

  CommandResult estopReset() {
    if (!plant.latched) {
      return const CommandResult.ok();
    }
    if (plant.estopLatchedTick != null &&
        plant.tickCount <= plant.estopLatchedTick!) {
      return const CommandResult.reject(RejectCode.stillMoving);
    }
    // estop_reset_moving_guard
    if (!plant.fullyStopped()) {
      return const CommandResult.reject(RejectCode.stillMoving);
    }
    plant.latched = false;
    plant.estopLatchedTick = null;
    return const CommandResult.ok();
  }

  void heartbeat() {
    plant.onHeartbeat();
  }

  void tick() {
    plant.tickPlant();
  }

  SimSnapshot snapshot() => SimSnapshot(
    tick: plant.tickCount,
    x: plant.x,
    y: plant.y,
    theta: plant.theta,
    v: plant.v,
    w: plant.w,
    mission: plant.mission,
    wpIndex: plant.wpIndex,
    latched: plant.latched,
    deadman: plant.deadman,
    fault: plant.faultCode.code,
    heartbeatAgeTicks: plant.heartbeatAgeTicks(),
    clearance: plant.clearance,
    contact: plant.contact,
  );

  /// One trace line for golden comparison (12 significant digits).
  String traceLine() {
    final s = snapshot();
    return '${s.tick} ${fmt12(s.x)} ${fmt12(s.y)} ${fmt12(s.theta)} '
        '${fmt12(s.v)} ${fmt12(s.w)} ${s.mission.name} ${s.wpIndex} '
        '${s.latched} ${s.deadman} ${s.fault} ${fmt12(s.clearance)}';
  }

  static String fmt12(double v) {
    if (v == 0) {
      return '0';
    }
    return v.toStringAsPrecision(12);
  }
}
