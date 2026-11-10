// SPDX-License-Identifier: Apache-2.0

import 'dart:convert';

import 'errors.dart';
import 'messages.dart';

/// Maximum UTF-8 byte length of a single text frame.
const int kMaxFrameUtf8Bytes = 4096;

/// Result of decoding a client text frame.
sealed class DecodeResult {
  const DecodeResult();
}

final class DecodeOk extends DecodeResult {
  const DecodeOk(this.frame);

  final ClientFrame frame;
}

final class DecodeError extends DecodeResult {
  const DecodeError(this.code);

  final String code;
}

/// Strict JSON codec for protocol version 1.
abstract final class RobotCodec {
  /// Rejects binary WebSocket payloads per PLAN section 7.
  static DecodeError decodeBinaryFrame() {
    return const DecodeError(ProtocolCodes.binaryNotSupported);
  }

  /// Decodes a UTF-8 text frame with byte-length and schema validation.
  static DecodeResult decodeTextFrame(String utf8Text) {
    final bytes = utf8.encode(utf8Text);
    if (bytes.length > kMaxFrameUtf8Bytes) {
      return const DecodeError(ProtocolCodes.frameTooLarge);
    }
    return decodeUtf8Bytes(bytes);
  }

  /// Decodes already-encoded UTF-8 bytes (enforces [kMaxFrameUtf8Bytes]).
  static DecodeResult decodeUtf8Bytes(List<int> utf8Bytes) {
    if (utf8Bytes.length > kMaxFrameUtf8Bytes) {
      return const DecodeError(ProtocolCodes.frameTooLarge);
    }
    final Object? parsed;
    try {
      parsed = jsonDecode(utf8.decode(utf8Bytes));
    } on Object {
      return const DecodeError(ProtocolCodes.invalid);
    }
    if (parsed is! Map) {
      return const DecodeError(ProtocolCodes.invalid);
    }
    return _decodeRootMap(parsed);
  }

  static String encodeServerMessage(ServerMessage message) {
    return jsonEncode(message.toJson());
  }
}

DecodeResult _decodeRootMap(Map<dynamic, dynamic> map) {
  if (!_exactKeys(map, const {'v', 'type'})) {
    return _maybeCommandFrame(map);
  }
  final v = _readInt(map['v']);
  if (v == null || v != 1) {
    return const DecodeError(ProtocolCodes.invalid);
  }
  final typeStr = map['type'];
  if (typeStr is! String) {
    return const DecodeError(ProtocolCodes.invalid);
  }
  if (typeStr != 'hello') {
    return const DecodeError(ProtocolCodes.invalid);
  }
  return const DecodeOk(HelloFrame());
}

DecodeResult _maybeCommandFrame(Map<dynamic, dynamic> map) {
  if (!_exactKeys(map, const {'v', 'type', 'session', 'seq', 'body'})) {
    return const DecodeError(ProtocolCodes.invalid);
  }
  final v = _readInt(map['v']);
  if (v == null || v != 1) {
    return const DecodeError(ProtocolCodes.invalid);
  }
  final typeStr = map['type'];
  if (typeStr is! String) {
    return const DecodeError(ProtocolCodes.invalid);
  }
  final type = CommandTypeJson.parse(typeStr);
  if (type == null || type == CommandType.hello) {
    return const DecodeError(ProtocolCodes.invalid);
  }
  final session = map['session'];
  if (session is! String || session.isEmpty) {
    return const DecodeError(ProtocolCodes.invalid);
  }
  final seq = _readInt(map['seq']);
  if (seq == null || seq < 1) {
    return const DecodeError(ProtocolCodes.invalid);
  }
  final body = map['body'];
  if (body is! Map) {
    return const DecodeError(ProtocolCodes.invalid);
  }
  final bodyResult = _decodeBody(type, body);
  if (bodyResult is DecodeError) {
    return bodyResult;
  }
  final waypoints = bodyResult is List<Waypoint>
      ? bodyResult
      : const <Waypoint>[];
  return DecodeOk(
    SessionedFrame(
      session: session,
      seq: seq,
      type: type,
      waypoints: waypoints,
    ),
  );
}

Object? _decodeBody(CommandType type, Map<dynamic, dynamic> body) {
  return switch (type) {
    CommandType.heartbeat ||
    CommandType.estop ||
    CommandType.estopReset ||
    CommandType.missionStart ||
    CommandType.missionPause ||
    CommandType.missionResume ||
    CommandType.missionStop => _emptyBodyOk(body),
    CommandType.missionSet => _decodeMissionSetBody(body),
    CommandType.hello => const DecodeError(ProtocolCodes.invalid),
  };
}

Object? _emptyBodyOk(Map<dynamic, dynamic> body) {
  if (body.isNotEmpty) {
    return const DecodeError(ProtocolCodes.invalid);
  }
  return null;
}

Object? _decodeMissionSetBody(Map<dynamic, dynamic> body) {
  if (!_exactKeys(body, const {'waypoints'})) {
    return const DecodeError(ProtocolCodes.invalid);
  }
  final raw = body['waypoints'];
  if (raw is! List) {
    return const DecodeError(ProtocolCodes.invalid);
  }
  final waypoints = <Waypoint>[];
  for (final item in raw) {
    if (item is! List || item.length != 2) {
      return const DecodeError(ProtocolCodes.invalid);
    }
    final x = _readFiniteNumber(item[0]);
    final y = _readFiniteNumber(item[1]);
    if (x == null || y == null) {
      return const DecodeError(ProtocolCodes.invalid);
    }
    waypoints.add((x, y));
  }
  return waypoints;
}

bool _exactKeys(Map<dynamic, dynamic> map, Set<String> expected) {
  if (map.length != expected.length) {
    return false;
  }
  for (final key in map.keys) {
    if (key is! String || !expected.contains(key)) {
      return false;
    }
  }
  return true;
}

int? _readInt(Object? value) {
  if (value is int) {
    return value;
  }
  return null;
}

double? _readFiniteNumber(Object? value) {
  if (value is int) {
    return value.toDouble();
  }
  if (value is double) {
    if (!value.isFinite) {
      return null;
    }
    return value;
  }
  return null;
}
