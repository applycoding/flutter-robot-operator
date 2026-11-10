// SPDX-License-Identifier: Apache-2.0

import 'package:robot_protocol/robot_protocol.dart';

/// How the operator reaches the robot simulation.
enum TransportKind { local, ws }

/// Log line from ack / reject / error traffic.
final class TransportEvent {
  const TransportEvent.ack(this.seq)
    : session = null,
      mapInfo = null,
      code = null,
      note = null,
      kind = 'ack';

  const TransportEvent.reject(this.seq, this.code)
    : session = null,
      mapInfo = null,
      note = null,
      kind = 'reject';

  const TransportEvent.error(this.code)
    : seq = null,
      session = null,
      mapInfo = null,
      note = null,
      kind = 'error';

  const TransportEvent.welcome(this.session, {this.mapInfo})
    : seq = null,
      code = null,
      note = null,
      kind = 'welcome';

  final String kind;
  final int? seq;
  final String? code;
  final String? note;
  final String? session;
  final MapInfo? mapInfo;

  @override
  String toString() {
    return switch (kind) {
      'ack' => 'ack seq=$seq',
      'reject' => 'reject seq=$seq code=$code',
      'error' => 'error code=$code',
      'welcome' => 'welcome session=$session',
      _ => kind,
    };
  }
}

/// Shared contract for in-process and WebSocket transports.
abstract class RobotTransport {
  TransportKind get kind;

  Stream<SnapshotMessage> get snapshots;

  Stream<TransportEvent> get events;

  bool get isConnected;

  String? get sessionId;

  Future<void> connect();

  Future<void> disconnect();

  /// Sends `hello` and completes when welcome (and first snapshot) is processed.
  Future<void> handshake();

  Future<void> sendCommand(SessionedFrame frame, {required String rawUtf8});

  /// E-stop uses the next operator seq but gate rules are server-side.
  Future<void> sendEstop(SessionedFrame frame, {required String rawUtf8});

  void setHeartbeatEnabled(bool enabled);
}
