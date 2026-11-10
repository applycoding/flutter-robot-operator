// SPDX-License-Identifier: Apache-2.0

import 'dart:async';
import 'dart:io';

import 'package:robot_protocol/robot_protocol.dart';
import 'package:robot_sim/robot_sim.dart' as sim;

/// Maximum client frames accepted per simulation tick (PLAN section 7).
const int kMaxFramesPerTick = 32;

/// WebSocket close code when a second operator connects.
const int kCloseSecondClient = 1008;

/// WebSocket close code when the per-tick frame limit is exceeded.
const int kCloseFrameOverflow = 1009;

/// Drives periodic simulation ticks (wall clock or manual for tests).
abstract class TickSource {
  void start(void Function() onTick);

  void stop();
}

/// [Timer.periodic] tick source for production `bin/robot_server.dart`.
final class WallClockTickSource implements TickSource {
  WallClockTickSource(this.periodMs);

  final int periodMs;
  Timer? _timer;

  @override
  void start(void Function() onTick) {
    stop();
    _timer = Timer.periodic(Duration(milliseconds: periodMs), (_) => onTick());
  }

  @override
  void stop() {
    _timer?.cancel();
    _timer = null;
  }
}

/// Manual tick source for integration tests (call [tick] explicitly).
final class ManualTickSource implements TickSource {
  void Function()? _onTick;

  @override
  void start(void Function() onTick) {
    _onTick = onTick;
  }

  void tick() {
    _onTick?.call();
  }

  @override
  void stop() {
    _onTick = null;
  }
}

/// Local WebSocket server owning one [sim.RobotSim] and one [SessionGate].
final class RobotWebSocketServer {
  RobotWebSocketServer({
    sim.RobotSim? robotSim,
    TickSource? tickSource,
    this.tickPeriodMs = 50,
  }) : _sim = robotSim ?? sim.RobotSim(),
       _tickSource = tickSource ?? WallClockTickSource(tickPeriodMs) {
    _gate = SessionGate(applyCommand: _applyCommand);
  }

  final sim.RobotSim _sim;
  final TickSource _tickSource;
  final int tickPeriodMs;

  late final SessionGate _gate;

  HttpServer? _httpServer;
  WebSocket? _socket;
  int _framesThisTick = 0;

  int get port => _httpServer?.port ?? 0;

  /// Starts listening on [address]:[port] (0 = ephemeral).
  Future<void> start({InternetAddress? address, int port = 0}) async {
    if (_httpServer != null) {
      throw StateError('server already started');
    }
    final bindAddress = address ?? InternetAddress.loopbackIPv4;
    _httpServer = await HttpServer.bind(bindAddress, port);
    _httpServer!.listen(_onHttpRequest);
    _tickSource.start(_onSimTick);
  }

  Future<void> stop() async {
    _tickSource.stop();
    await _socket?.close();
    _socket = null;
    await _httpServer?.close(force: true);
    _httpServer = null;
  }

  void _onHttpRequest(HttpRequest request) async {
    if (!WebSocketTransformer.isUpgradeRequest(request)) {
      request.response
        ..statusCode = HttpStatus.badRequest
        ..write('WebSocket upgrade required')
        ..close();
      return;
    }
    final ws = await WebSocketTransformer.upgrade(request);
    _acceptSocket(ws);
  }

  void _acceptSocket(WebSocket ws) {
    if (_socket != null) {
      ws.close(kCloseSecondClient, 'one operator at a time');
      return;
    }
    _socket = ws;
    _framesThisTick = 0;
    ws.listen(
      _onSocketData,
      onDone: _onSocketDone,
      onError: (_) => _onSocketDone(),
      cancelOnError: true,
    );
  }

  void _onSocketDone() {
    final active = _socket;
    _socket = null;
    _gate.endSession();
    _framesThisTick = 0;
    active?.close();
  }

  void _onSocketData(dynamic data) {
    _framesThisTick++;
    if (_framesThisTick > kMaxFramesPerTick) {
      final s = _socket;
      _socket = null;
      _gate.endSession();
      unawaited(s?.close(kCloseFrameOverflow, 'frame rate limit'));
      return;
    }

    if (data is! String) {
      _send(const ErrorMessage(code: ProtocolCodes.binaryNotSupported));
      return;
    }

    final decode = RobotCodec.decodeTextFrame(data);
    switch (decode) {
      case DecodeOk(:final frame):
        _handleFrame(frame, data);
      case DecodeError(:final code):
        _send(ErrorMessage(code: code));
    }
  }

  void _handleFrame(ClientFrame frame, String rawUtf8) {
    switch (frame) {
      case HelloFrame():
        final welcome = _gate.beginSession(
          tickDtS: _sim.config.dt,
          map: _mapInfo(),
        );
        _send(welcome);
        _sendSnapshot();
      case SessionedFrame():
        final reply = _gate.handle(frame, rawUtf8: rawUtf8);
        _send(reply);
    }
  }

  ServerMessage _applyCommand(SessionedFrame frame) {
    final seq = frame.seq;
    switch (frame.type) {
      case CommandType.heartbeat:
        _sim.heartbeat();
        return AckMessage(seq: seq);
      case CommandType.estop:
        _sim.estop();
        return AckMessage(seq: seq);
      case CommandType.estopReset:
        final r = _sim.estopReset();
        if (r.ok) {
          return AckMessage(seq: seq);
        }
        return RejectMessage(seq: seq, code: r.code!);
      case CommandType.missionSet:
        final wps = [
          for (final w in frame.waypoints) [w.$1, w.$2],
        ];
        final r = _sim.missionSet(wps);
        if (r.ok) {
          return AckMessage(seq: seq);
        }
        return RejectMessage(seq: seq, code: r.reason ?? r.code!);
      case CommandType.missionStart:
        return _commandResult(seq, _sim.missionStart());
      case CommandType.missionPause:
        return _commandResult(seq, _sim.missionPause());
      case CommandType.missionResume:
        return _commandResult(seq, _sim.missionResume());
      case CommandType.missionStop:
        return _commandResult(seq, _sim.missionStop());
      case CommandType.hello:
        return const ErrorMessage(code: ProtocolCodes.invalid);
    }
  }

  ServerMessage _commandResult(int seq, sim.CommandResult r) {
    if (r.ok) {
      return AckMessage(seq: seq);
    }
    return RejectMessage(seq: seq, code: r.code!);
  }

  void _onSimTick() {
    _sim.tick();
    _sendSnapshot();
    _framesThisTick = 0;
  }

  void _send(ServerMessage message) {
    final ws = _socket;
    if (ws == null) {
      return;
    }
    try {
      ws.add(RobotCodec.encodeServerMessage(message));
    } on Object {
      // Socket may have closed between check and send.
    }
  }

  void _sendSnapshot() {
    final s = _sim.snapshot();
    final fault = s.fault.isEmpty ? null : s.fault;
    _send(
      SnapshotMessage(
        tick: s.tick,
        x: s.x,
        y: s.y,
        theta: s.theta,
        v: s.v,
        w: s.w,
        mission: MissionState.values.byName(s.mission.name),
        wpIndex: s.wpIndex,
        latched: s.latched,
        deadman: s.deadman,
        fault: fault,
        heartbeatAgeTicks: s.heartbeatAgeTicks,
        clearance: s.clearance,
      ),
    );
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
}
