// SPDX-License-Identifier: Apache-2.0

import 'dart:async';

import 'package:robot_protocol/robot_protocol.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'frame_codec.dart';
import 'snapshot_parse.dart';
import 'transport.dart';

/// WebSocket client for desktop / Android (`dart:io` builds only).
final class WsTransport implements RobotTransport {
  WsTransport(this.url);

  final String url;

  WebSocketChannel? _channel;
  StreamSubscription<Object?>? _sub;

  final _snapshotController = StreamController<SnapshotMessage>.broadcast();
  final _eventController = StreamController<TransportEvent>.broadcast();

  bool _connected = false;
  String? _sessionId;

  @override
  TransportKind get kind => TransportKind.ws;

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
    _channel = WebSocketChannel.connect(Uri.parse(url));
    _connected = true;
    _sub = _channel!.stream.listen(
      _onFrame,
      onError: (_) => disconnect(),
      onDone: () => disconnect(),
    );
  }

  @override
  Future<void> disconnect() async {
    _connected = false;
    _sessionId = null;
    await _sub?.cancel();
    _sub = null;
    await _channel?.sink.close();
    _channel = null;
  }

  @override
  Future<void> handshake() async {
    await _sendText(ClientFrameCodec.hello());
  }

  @override
  Future<void> sendCommand(
    SessionedFrame frame, {
    required String rawUtf8,
  }) async {
    await _sendText(rawUtf8);
  }

  @override
  Future<void> sendEstop(
    SessionedFrame frame, {
    required String rawUtf8,
  }) async {
    await _sendText(rawUtf8);
  }

  @override
  void setHeartbeatEnabled(bool enabled) {}

  Future<void> _sendText(String text) async {
    final ch = _channel;
    if (ch == null) {
      return;
    }
    ch.sink.add(text);
  }

  void _onFrame(Object? data) {
    if (data is! String) {
      final err = RobotCodec.decodeBinaryFrame();
      _eventController.add(TransportEvent.error(err.code));
      return;
    }
    final msg = SnapshotParse.tryParseServerMessage(data);
    if (msg == null) {
      return;
    }
    switch (msg) {
      case WelcomeMessage(:final session, :final map):
        _sessionId = session;
        _eventController.add(TransportEvent.welcome(session, mapInfo: map));
      case AckMessage(:final seq):
        _eventController.add(TransportEvent.ack(seq));
      case RejectMessage(:final seq, :final code):
        _eventController.add(TransportEvent.reject(seq, code));
      case ErrorMessage(:final code):
        _eventController.add(TransportEvent.error(code));
      case SnapshotMessage():
        _snapshotController.add(msg);
    }
  }

  void dispose() {
    disconnect();
    _snapshotController.close();
    _eventController.close();
  }
}
