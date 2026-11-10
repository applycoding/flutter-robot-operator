// SPDX-License-Identifier: Apache-2.0

import 'dart:async';

import 'package:robot_protocol/robot_protocol.dart';
import 'package:robot_sim/robot_sim.dart' as sim;

import 'frame_codec.dart';
import 'snapshot_parse.dart';
import 'transport.dart';

/// In-process simulation with real codec and [SessionGate].
final class LocalSimTransport implements RobotTransport {
  LocalSimTransport({sim.RobotSim? robot}) : _sim = robot ?? sim.RobotSim() {
    _gate = SessionGate(applyCommand: _applyCommand);
  }

  final sim.RobotSim _sim;
  late final SessionGate _gate;

  final _snapshotController = StreamController<SnapshotMessage>.broadcast();
  final _eventController = StreamController<TransportEvent>.broadcast();

  Timer? _tickTimer;
  bool _connected = false;
  String? _sessionId;

  @override
  TransportKind get kind => TransportKind.local;

  @override
  Stream<SnapshotMessage> get snapshots => _snapshotController.stream;

  @override
  Stream<TransportEvent> get events => _eventController.stream;

  @override
  bool get isConnected => _connected;

  @override
  String? get sessionId => _sessionId;

  @override
  Future<void> connect() async {
    if (_connected) {
      return;
    }
    _connected = true;
    final dtMs = (_sim.config.dt * 1000).round();
    _tickTimer = Timer.periodic(Duration(milliseconds: dtMs), (_) => _onTick());
  }

  @override
  Future<void> disconnect() async {
    _tickTimer?.cancel();
    _tickTimer = null;
    _gate.endSession();
    _connected = false;
    _sessionId = null;
  }

  @override
  Future<void> handshake() async {
    final raw = ClientFrameCodec.hello();
    _handleInbound(raw);
  }

  @override
  Future<void> sendCommand(
    SessionedFrame frame, {
    required String rawUtf8,
  }) async {
    _handleInbound(rawUtf8);
  }

  @override
  Future<void> sendEstop(
    SessionedFrame frame, {
    required String rawUtf8,
  }) async {
    _handleInbound(rawUtf8);
  }

  @override
  void setHeartbeatEnabled(bool _) {}

  void _onTick() {
    _sim.tick();
    _emitSnapshot();
  }

  void _emitSnapshot() {
    final snap = _sim.snapshot();
    final msg = SnapshotMessage(
      tick: snap.tick,
      x: snap.x,
      y: snap.y,
      theta: snap.theta,
      v: snap.v,
      w: snap.w,
      mission: _toProtocolMission(snap.mission),
      wpIndex: snap.wpIndex,
      latched: snap.latched,
      deadman: snap.deadman,
      fault: snap.fault.isEmpty ? null : snap.fault,
      heartbeatAgeTicks: snap.heartbeatAgeTicks,
      clearance: snap.clearance,
    );
    _snapshotController.add(msg);
  }

  MissionState _toProtocolMission(sim.MissionState state) {
    return MissionState.values.byName(state.name);
  }

  void _handleInbound(String rawUtf8) {
    final decoded = RobotCodec.decodeTextFrame(rawUtf8);
    if (decoded is DecodeError) {
      _eventController.add(TransportEvent.error(decoded.code));
      return;
    }
    final frame = (decoded as DecodeOk).frame;
    if (frame is HelloFrame) {
      final welcome = _gate.beginSession(
        tickDtS: _sim.config.dt,
        map: _mapInfo(),
      );
      _sessionId = welcome.session;
      _eventController.add(
        TransportEvent.welcome(welcome.session, mapInfo: welcome.map),
      );
      final out = RobotCodec.encodeServerMessage(welcome);
      _processServerJson(out);
      _emitSnapshot();
      return;
    }
    final sessioned = frame as SessionedFrame;
    final response = _gate.handle(sessioned, rawUtf8: rawUtf8);
    _dispatchServerMessage(response);
  }

  MapInfo _mapInfo() {
    final cfg = _sim.config;
    return MapInfo(
      widthM: cfg.mapWidth,
      heightM: cfg.mapHeight,
      cellM: cfg.cellSize,
      obstacles: [
        for (final o in _sim.map.obstacles) (o.xMin, o.yMin, o.xMax, o.yMax),
      ],
    );
  }

  ServerMessage _applyCommand(SessionedFrame frame) {
    final result = switch (frame.type) {
      CommandType.heartbeat => () {
        _sim.heartbeat();
        return const sim.CommandResult.ok();
      }(),
      CommandType.estop => () {
        _sim.estop();
        return const sim.CommandResult.ok();
      }(),
      CommandType.estopReset => _sim.estopReset(),
      CommandType.missionSet => _sim.missionSet(
        frame.waypoints.map((w) => [w.$1, w.$2]).toList(),
      ),
      CommandType.missionStart => _sim.missionStart(),
      CommandType.missionPause => _sim.missionPause(),
      CommandType.missionResume => _sim.missionResume(),
      CommandType.missionStop => _sim.missionStop(),
      CommandType.hello => const sim.CommandResult.reject(
        sim.RejectCode.badState,
      ),
    };

    if (result.ok) {
      return AckMessage(seq: frame.seq);
    }
    final code = result.reason ?? result.code ?? ProtocolCodes.invalid;
    return RejectMessage(seq: frame.seq, code: code);
  }

  void _dispatchServerMessage(ServerMessage message) {
    final encoded = RobotCodec.encodeServerMessage(message);
    _processServerJson(encoded);
  }

  void _processServerJson(String json) {
    final msg = SnapshotParse.tryParseServerMessage(json);
    if (msg == null) {
      return;
    }
    switch (msg) {
      case AckMessage(:final seq):
        _eventController.add(TransportEvent.ack(seq));
      case RejectMessage(:final seq, :final code):
        _eventController.add(TransportEvent.reject(seq, code));
      case ErrorMessage(:final code):
        _eventController.add(TransportEvent.error(code));
      case WelcomeMessage(:final session, :final map):
        _eventController.add(TransportEvent.welcome(session, mapInfo: map));
      case SnapshotMessage():
        _snapshotController.add(msg);
    }
  }

  /// Visible for tests: process a client JSON line through codec + gate.
  void ingestClientFrame(String rawUtf8) => _handleInbound(rawUtf8);

  /// Visible for tests: advance one physics tick.
  void stepTick() => _onTick();

  void dispose() {
    disconnect();
    _snapshotController.close();
    _eventController.close();
  }
}
