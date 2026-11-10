// SPDX-License-Identifier: Apache-2.0

import 'package:robot_protocol/robot_protocol.dart';

import 'transport.dart';

/// WebSocket transport is unavailable on web (local sim is used instead).
final class WsTransport implements RobotTransport {
  WsTransport(String url);

  @override
  TransportKind get kind => TransportKind.ws;

  @override
  Stream<SnapshotMessage> get snapshots =>
      throw UnsupportedError('WsTransport is not available on this platform');

  @override
  Stream<TransportEvent> get events =>
      throw UnsupportedError('WsTransport is not available on this platform');

  @override
  bool get isConnected => false;

  @override
  String? get sessionId => null;

  @override
  Future<void> connect() async {
    throw UnsupportedError('WsTransport is not available on this platform');
  }

  @override
  Future<void> disconnect() async {}

  @override
  Future<void> handshake() async {
    throw UnsupportedError('WsTransport is not available on this platform');
  }

  @override
  Future<void> sendCommand(
    SessionedFrame frame, {
    required String rawUtf8,
  }) async {
    throw UnsupportedError('WsTransport is not available on this platform');
  }

  @override
  Future<void> sendEstop(
    SessionedFrame frame, {
    required String rawUtf8,
  }) async {
    throw UnsupportedError('WsTransport is not available on this platform');
  }

  @override
  void setHeartbeatEnabled(bool enabled) {}
}
