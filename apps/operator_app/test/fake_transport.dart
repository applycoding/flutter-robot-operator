// SPDX-License-Identifier: Apache-2.0

import 'dart:async';

import 'package:robot_protocol/robot_protocol.dart';

import 'package:operator_app/src/transport.dart';

class FakeTransport implements RobotTransport {
  final List<String> sentFrames = [];
  CommandType? lastCommandType;

  final _snapshotController = StreamController<SnapshotMessage>.broadcast(
    sync: true,
  );
  final _eventController = StreamController<TransportEvent>.broadcast(
    sync: true,
  );

  String session = 'test-session';
  SnapshotMessage snapshot = SnapshotMessage(
    tick: 0,
    x: 1,
    y: 1,
    theta: 0,
    v: 0,
    w: 0,
    mission: MissionState.idle,
    wpIndex: 0,
    latched: false,
    deadman: false,
    fault: null,
    heartbeatAgeTicks: 0,
    clearance: 1,
  );

  @override
  TransportKind get kind => TransportKind.local;

  @override
  Stream<SnapshotMessage> get snapshots => _snapshotController.stream;

  @override
  Stream<TransportEvent> get events => _eventController.stream;

  @override
  bool get isConnected => true;

  @override
  String? get sessionId => session;

  @override
  Future<void> connect() async {}

  @override
  Future<void> disconnect() async {}

  @override
  Future<void> handshake() async {
    _eventController.add(
      TransportEvent.welcome(
        session,
        mapInfo: const MapInfo(
          widthM: 10,
          heightM: 6,
          cellM: 0.1,
          obstacles: [],
        ),
      ),
    );
    emitSnapshot();
  }

  void emitSnapshot() {
    _snapshotController.add(snapshot);
  }

  void setSnapshot(SnapshotMessage value) {
    snapshot = value;
    emitSnapshot();
  }

  @override
  Future<void> sendCommand(
    SessionedFrame frame, {
    required String rawUtf8,
  }) async {
    sentFrames.add(rawUtf8);
    lastCommandType = frame.type;
    _eventController.add(TransportEvent.ack(frame.seq));
  }

  @override
  Future<void> sendEstop(
    SessionedFrame frame, {
    required String rawUtf8,
  }) async {
    sentFrames.add(rawUtf8);
    lastCommandType = CommandType.estop;
    _eventController.add(TransportEvent.ack(frame.seq));
  }

  @override
  void setHeartbeatEnabled(bool enabled) {}

  void dispose() {
    _snapshotController.close();
    _eventController.close();
  }
}
