// SPDX-License-Identifier: Apache-2.0

import 'dart:math' as math;

import 'config.dart';
import 'grid_map.dart';
import 'mission.dart';
import 'safety.dart';

double wrapAngle(double a) {
  while (a <= -math.pi) {
    a += 2 * math.pi;
  }
  while (a > math.pi) {
    a -= 2 * math.pi;
  }
  return a;
}

double clamp(double v, double lo, double hi) => math.min(math.max(v, lo), hi);

/// Diff-drive plant: controller, limits, integration.
class Plant {
  Plant(this.config, this.map, this.safety)
    : x = SimConfig.startPose[0],
      y = SimConfig.startPose[1],
      theta = SimConfig.startPose[2],
      v = 0,
      w = 0,
      mission = MissionState.idle,
      wpIndex = 0,
      waypoints = <List<double>>[],
      latched = false,
      deadman = false,
      faultCode = FaultCode.none,
      clearance = 0,
      contact = false {
    clearance = map.clearanceAt(x, y);
  }

  final SimConfig config;
  final GridMap map;
  final SafetyLayer safety;

  double x;
  double y;
  double theta;
  double v;
  double w;

  MissionState mission;
  int wpIndex;
  List<List<double>> waypoints;

  bool latched;
  bool deadman;
  FaultCode faultCode;

  double clearance;
  bool contact;

  int tickCount = 0;
  int? lastHeartbeatTick;
  int? estopLatchedTick;

  double vCmd = 0;
  double wCmd = 0;

  bool heartbeatFresh() {
    if (lastHeartbeatTick == null) {
      return false;
    }
    return tickCount - lastHeartbeatTick! <= config.heartbeatTimeoutTicks;
  }

  int heartbeatAgeTicks() {
    if (lastHeartbeatTick == null) {
      return 1 << 30;
    }
    return tickCount - lastHeartbeatTick!;
  }

  bool fullyStopped() => v == 0 && w == 0;

  void onHeartbeat() {
    lastHeartbeatTick = tickCount;
  }

  void onEstop() {
    latched = true;
    estopLatchedTick = tickCount;
    if (mission == MissionState.running) {
      mission = MissionState.paused;
    }
  }

  /// One simulation tick: (a)–(g) per PLAN section 5.
  void tickPlant() {
    tickCount++;

    // (a) deadman check
    if (config.deadmanEnabled &&
        mission == MissionState.running &&
        !heartbeatFresh()) {
      mission = MissionState.paused;
      deadman = true;
    }

    vCmd = 0;
    wCmd = 0;

    // (b) controller — only while running
    if (mission == MissionState.running && waypoints.isNotEmpty) {
      _runController();
    }

    // (c) predictive protective stop
    if (config.protectiveStopEnabled &&
        mission == MissionState.running &&
        safety.obstacleAhead(x: x, y: y, theta: theta, vCmd: vCmd)) {
      mission = MissionState.fault;
      faultCode = FaultCode.obstacleAhead;
      vCmd = 0;
      wCmd = 0;
    }

    // (d) choose active limit
    final estopBraking = latched || faultCode == FaultCode.obstacleAhead;
    final double aLin;
    if (estopBraking) {
      aLin = config.aEstop;
    } else if (deadman) {
      aLin = config.aDeadman;
    } else {
      aLin = config.aMax;
    }

    if (config.instantEstopSnap && estopBraking) {
      v = 0;
      w = 0;
    } else {
      // (e) rate-limit v and w
      final spinToZero = estopBraking || deadman;
      if (spinToZero) {
        w = _rateLimit(w, 0, config.alphaEstop);
      } else if (mission == MissionState.running) {
        w = _rateLimit(w, wCmd, config.alphaMax);
      } else {
        w = _rateLimit(w, 0, config.alphaMax);
      }

      final targetV = mission == MissionState.running ? vCmd : 0.0;
      v = _rateLimit(v, targetV, aLin);
      if (v < 0) {
        v = 0;
      }
    }

    // (f) semi-implicit Euler
    x += v * math.cos(theta) * config.dt;
    y += v * math.sin(theta) * config.dt;
    theta = wrapAngle(theta + w * config.dt);

    // (g) clearance and contact
    clearance = map.clearanceAt(x, y);
    contact = clearance < config.footprintRadius;
  }

  void _runController() {
    if (wpIndex >= waypoints.length) {
      return;
    }
    final wp = waypoints[wpIndex];
    final dx = wp[0] - x;
    final dy = wp[1] - y;
    final dist = math.sqrt(dx * dx + dy * dy);

    if (dist < config.waypointTolerance) {
      wpIndex++;
      if (wpIndex >= waypoints.length) {
        mission = MissionState.succeeded;
        vCmd = 0;
        wCmd = 0;
        return;
      }
      return _runController();
    }

    final herr = wrapAngle(math.atan2(dy, dx) - theta);
    wCmd = clamp(config.headingGain * herr, -config.wMax, config.wMax);

    if (herr.abs() > config.vCmdHerrLimit) {
      vCmd = 0;
    } else {
      final slowdown = math.sqrt(
        2 * config.aMax * 0.8 * math.max(0, dist - config.vCmdDistOffset),
      );
      vCmd = math.min(config.vMax, slowdown) * math.max(0, math.cos(herr));
    }
  }

  double _rateLimit(double current, double target, double aMax) {
    final dv = aMax * config.dt;
    if (target > current) {
      return math.min(target, current + dv);
    }
    return math.max(target, current - dv);
  }
}
