// SPDX-License-Identifier: Apache-2.0

import 'package:robot_protocol/robot_protocol.dart';
import 'package:robot_sim/robot_sim.dart' as sim;

/// Synchronous local stack (codec + SessionGate + RobotSim) for integration tests.
final class SimStackHarness {
  SimStackHarness({sim.RobotSim? robot}) : _sim = robot ?? sim.RobotSim() {
    _gate = SessionGate(applyCommand: _applyCommand);
  }

  final sim.RobotSim _sim;
  late final SessionGate _gate;
  String? _session;
  int _seq = 0;

  void hello() {
    _gate.beginSession(tickDtS: _sim.config.dt, map: _mapInfo());
    _session = _gate.sessionId;
    _seq = 0;
  }

  void ingest(String rawUtf8) {
    final decoded = RobotCodec.decodeTextFrame(rawUtf8);
    if (decoded is DecodeError) {
      return;
    }
    final frame = (decoded as DecodeOk).frame;
    if (frame is HelloFrame) {
      hello();
      return;
    }
    final sessioned = frame as SessionedFrame;
    _gate.handle(sessioned, rawUtf8: rawUtf8);
  }

  void send(CommandType type, {List<List<double>>? waypoints}) {
    final raw = _rawFor(type, waypoints: waypoints);
    ingest(raw);
  }

  String _rawFor(CommandType type, {List<List<double>>? waypoints}) {
    if (type == CommandType.hello) {
      return '{"v":1,"type":"hello"}';
    }
    final session = _session ?? 'unset';
    _seq += 1;
    switch (type) {
      case CommandType.missionSet:
        final wps = waypoints!;
        final wpJson = wps.map((w) => '[${w[0]},${w[1]}]').join(',');
        return '{"v":1,"type":"mission_set","session":"$session","seq":$_seq,'
            '"body":{"waypoints":[$wpJson]}}';
      case CommandType.missionStart:
        return '{"v":1,"type":"mission_start","session":"$session","seq":$_seq,"body":{}}';
      case CommandType.missionPause:
        return '{"v":1,"type":"mission_pause","session":"$session","seq":$_seq,"body":{}}';
      case CommandType.missionResume:
        return '{"v":1,"type":"mission_resume","session":"$session","seq":$_seq,"body":{}}';
      case CommandType.missionStop:
        return '{"v":1,"type":"mission_stop","session":"$session","seq":$_seq,"body":{}}';
      case CommandType.heartbeat:
        return '{"v":1,"type":"heartbeat","session":"$session","seq":$_seq,"body":{}}';
      case CommandType.estop:
        return '{"v":1,"type":"estop","session":"$session","seq":$_seq,"body":{}}';
      case CommandType.estopReset:
        return '{"v":1,"type":"estop_reset","session":"$session","seq":$_seq,"body":{}}';
      case CommandType.hello:
        return '{"v":1,"type":"hello"}';
    }
  }

  void tick() => _sim.tick();

  String traceLine() => _sim.traceLine();

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
    return RejectMessage(
      seq: frame.seq,
      code: result.reason ?? result.code ?? ProtocolCodes.invalid,
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

const malformedFramesWhileMoving = <String>[
  '{"v":2,"type":"hello"}',
  '{"v":1,"type":"hello","extra":1}',
  '{"v":1,"type":"mission_set","session":"s","seq":1.0,"body":{"waypoints":[[2,2]]}}',
  '{"v":1,"type":"heartbeat","session":"s","seq":1,"body":{"bad":1}}',
  '{"v":1,"type":"unknown","session":"s","seq":1,"body":{}}',
  'not json at all',
  '{"v":1,"type":"mission_set","session":"s","seq":1,"body":{"waypoints":[[NaN,1.0]]}}',
  '{"v":1,"type":"heartbeat","session":"s","seq":0,"body":{}}',
  '{"v":1,"type":"estop","session":"s","seq":1.0,"body":{}}',
  '{"v":1,"type":"mission_start","session":"","seq":1,"body":{}}',
];

List<String> runDemoTrace({
  required SimStackHarness stack,
  required int ticks,
  bool injectMalformed = false,
}) {
  stack.ingest('{"v":1,"type":"hello"}');
  stack.send(CommandType.missionSet, waypoints: sim.SimConfig.demoWaypoints);
  stack.send(CommandType.heartbeat);
  stack.send(CommandType.missionStart);

  final lines = <String>[];
  for (var t = 1; t <= ticks; t++) {
    if (t % 2 == 0) {
      stack.send(CommandType.heartbeat);
    }
    if (injectMalformed) {
      stack.ingest(
        malformedFramesWhileMoving[(t - 1) % malformedFramesWhileMoving.length],
      );
    }
    stack.tick();
    lines.add(stack.traceLine());
  }
  return lines;
}
