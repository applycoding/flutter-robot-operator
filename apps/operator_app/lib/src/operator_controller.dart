// SPDX-License-Identifier: Apache-2.0

import 'dart:async';
import 'dart:ui' show Offset;

import 'package:flutter/foundation.dart';
import 'package:robot_protocol/robot_protocol.dart';
import 'package:robot_sim/robot_sim.dart' as sim;

import 'frame_codec.dart';
import 'page_title.dart';
import 'transport.dart';

/// UI-facing snapshot and mission model.
final class OperatorController extends ChangeNotifier {
  OperatorController(this.transport) {
    _snapshotSub = transport.snapshots.listen(_onSnapshot);
    _eventSub = transport.events.listen(_onEvent);
  }

  final RobotTransport transport;

  static const int _heartbeatFreshMaxAge = 10;

  StreamSubscription<SnapshotMessage>? _snapshotSub;
  StreamSubscription<TransportEvent>? _eventSub;
  Timer? _heartbeatTimer;

  SnapshotMessage? snapshot;
  MapInfo? map;
  final List<TransportEvent> eventLog = [];
  final List<Offset> travelledPath = [];
  List<Waypoint> missionWaypoints = [];

  bool linkLossSimulated = false;
  int _nextSeq = 1;

  @override
  void dispose() {
    _heartbeatTimer?.cancel();
    _snapshotSub?.cancel();
    _eventSub?.cancel();
    super.dispose();
  }

  Future<void> start() async {
    await transport.connect();
    await transport.handshake();
    _startHeartbeatTimer();
    notifyListeners();
  }

  Future<void> stop() async {
    _heartbeatTimer?.cancel();
    await transport.disconnect();
    notifyListeners();
  }

  void setLinkLossSimulated(bool value) {
    linkLossSimulated = value;
    transport.setHeartbeatEnabled(!value);
    if (value) {
      _heartbeatTimer?.cancel();
      _heartbeatTimer = null;
    } else {
      _startHeartbeatTimer();
    }
    notifyListeners();
  }

  void _startHeartbeatTimer() {
    _heartbeatTimer?.cancel();
    if (linkLossSimulated || transport.sessionId == null) {
      return;
    }
    _heartbeatTimer = Timer.periodic(
      const Duration(milliseconds: 100),
      (_) => unawaited(sendHeartbeat()),
    );
  }

  Future<void> sendHeartbeat() async {
    final session = transport.sessionId;
    if (session == null) {
      return;
    }
    await _send(CommandType.heartbeat);
  }

  Future<void> loadDemoMission() async {
    final wps = sim.SimConfig.demoWaypoints
        .map<Waypoint>((w) => (w[0], w[1]))
        .toList();
    missionWaypoints = wps;
    await _send(CommandType.missionSet, waypoints: wps);
  }

  Future<void> missionStart() => _send(CommandType.missionStart);
  Future<void> missionPause() => _send(CommandType.missionPause);
  Future<void> missionResume() => _send(CommandType.missionResume);
  Future<void> missionStop() => _send(CommandType.missionStop);
  Future<void> estopReset() => _send(CommandType.estopReset);

  Future<void> estop() async {
    final session = transport.sessionId;
    if (session == null) {
      return;
    }
    // E-stop is applied server-side without advancing `last`; do not bump seq.
    final seq = _nextSeq;
    final raw = ClientFrameCodec.sessioned(
      session: session,
      seq: seq,
      type: CommandType.estop,
    );
    final decoded = RobotCodec.decodeTextFrame(raw);
    if (decoded is! DecodeOk) {
      return;
    }
    final frame = decoded.frame as SessionedFrame;
    await transport.sendEstop(frame, rawUtf8: raw);
  }

  Future<void> _send(CommandType type, {List<Waypoint>? waypoints}) async {
    final session = transport.sessionId;
    if (session == null) {
      return;
    }
    final seq = _nextSeq++;
    final raw = ClientFrameCodec.sessioned(
      session: session,
      seq: seq,
      type: type,
      waypoints: waypoints,
    );
    final decoded = RobotCodec.decodeTextFrame(raw);
    if (decoded is! DecodeOk) {
      return;
    }
    final frame = decoded.frame as SessionedFrame;
    await transport.sendCommand(frame, rawUtf8: raw);
  }

  bool get canLoadDemoMission {
    final s = snapshot?.mission;
    if (s == null) {
      return false;
    }
    return s == MissionState.idle ||
        s == MissionState.succeeded ||
        s == MissionState.fault;
  }

  bool get canStart {
    final snap = snapshot;
    if (snap == null) {
      return false;
    }
    return snap.mission == MissionState.ready &&
        !snap.latched &&
        _heartbeatFresh(snap);
  }

  bool get canPause {
    return snapshot?.mission == MissionState.running;
  }

  bool get canResume {
    final snap = snapshot;
    if (snap == null) {
      return false;
    }
    if (snap.mission != MissionState.paused) {
      return false;
    }
    if (snap.latched) {
      return false;
    }
    if (!_heartbeatFresh(snap)) {
      return false;
    }
    if (!snap.deadman && (snap.v.abs() > 1e-9 || snap.w.abs() > 1e-9)) {
      return false;
    }
    if (snap.deadman && !_heartbeatFresh(snap)) {
      return false;
    }
    return snap.v.abs() <= 1e-9 && snap.w.abs() <= 1e-9;
  }

  bool get canStop {
    final s = snapshot?.mission;
    if (s == null) {
      return false;
    }
    return s == MissionState.running ||
        s == MissionState.paused ||
        s == MissionState.ready;
  }

  bool get showEstopReset {
    final snap = snapshot;
    if (snap == null || !snap.latched) {
      return false;
    }
    return snap.v.abs() <= 1e-9 && snap.w.abs() <= 1e-9;
  }

  String get transportBadge =>
      transport.kind == TransportKind.local ? 'SIM · local' : 'SIM · ws';

  String get pageTitle {
    final mission = snapshot?.mission.name ?? 'idle';
    final latch = snapshot?.latched == true ? 'latched' : 'clear';
    return 'Robot operator (simulation only) - $mission - $latch';
  }

  void _onSnapshot(SnapshotMessage snap) {
    snapshot = snap;
    if (travelledPath.isEmpty) {
      travelledPath.add(Offset(snap.x, snap.y));
    } else {
      final last = travelledPath.last;
      final dx = snap.x - last.dx;
      final dy = snap.y - last.dy;
      if (dx * dx + dy * dy > 1e-6) {
        travelledPath.add(Offset(snap.x, snap.y));
      }
    }
    setDocumentTitle(pageTitle);
    notifyListeners();
  }

  void _onEvent(TransportEvent event) {
    eventLog.insert(0, event);
    if (eventLog.length > 200) {
      eventLog.removeRange(200, eventLog.length);
    }
    if (event.kind == 'welcome') {
      _nextSeq = 1;
      if (event.mapInfo != null) {
        map = event.mapInfo;
      }
      _startHeartbeatTimer();
    }
    notifyListeners();
  }

  bool _heartbeatFresh(SnapshotMessage snap) =>
      snap.heartbeatAgeTicks <= _heartbeatFreshMaxAge;
}
