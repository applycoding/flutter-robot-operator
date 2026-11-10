// SPDX-License-Identifier: Apache-2.0

import 'dart:math';

import 'errors.dart';
import 'messages.dart';

/// Note on [AckMessage] when e-stop is applied without a matching session.
const String kAppliedWithoutSessionNote = 'applied_without_session';

/// Applies a validated, sessioned client command and returns the robot reply.
typedef CommandApplier = ServerMessage Function(SessionedFrame frame);

/// Enforces session and sequence rules from PLAN section 7 (shared by server and
/// local transport).
final class SessionGate {
  SessionGate({
    required this.applyCommand,
    String Function()? generateSessionId,
    Random? random,
  }) : _random = random ?? Random(),
       _generateSessionId = generateSessionId ?? _unsetSessionIdGenerator;

  final CommandApplier applyCommand;
  final String Function() _generateSessionId;
  final Random _random;

  static String _unsetSessionIdGenerator() =>
      throw StateError('generateSessionId required');

  String? _sessionId;
  int _lastSeq = 0;
  final _ResponseCache _cache = _ResponseCache();

  String? get sessionId => _sessionId;
  int get lastSeq => _lastSeq;

  /// Starts a new session (after `hello`), replacing any previous session.
  WelcomeMessage beginSession({required double tickDtS, required MapInfo map}) {
    _sessionId = _newSessionId();
    _lastSeq = 0;
    _cache.clear();
    return WelcomeMessage(session: _sessionId!, tickDtS: tickDtS, map: map);
  }

  /// Clears session bookkeeping on disconnect (plant state is unchanged elsewhere).
  void endSession() {
    _sessionId = null;
    _lastSeq = 0;
    _cache.clear();
  }

  /// Handles a validated client frame (not `hello`).
  ServerMessage handle(ClientFrame frame, {required String rawUtf8}) {
    if (frame is HelloFrame) {
      throw StateError('hello must use beginSession');
    }
    final sessioned = frame as SessionedFrame;
    if (sessioned.type == CommandType.estop) {
      return _handleEstop(sessioned);
    }
    return _handleSequenced(sessioned, rawUtf8);
  }

  ServerMessage _handleEstop(SessionedFrame frame) {
    final matchesSession = _sessionId != null && frame.session == _sessionId;
    final response = applyCommand(frame);
    if (!matchesSession) {
      return AckMessage(seq: frame.seq, note: kAppliedWithoutSessionNote);
    }
    return response;
  }

  ServerMessage _handleSequenced(SessionedFrame frame, String rawUtf8) {
    if (_sessionId == null || frame.session != _sessionId) {
      return RejectMessage(seq: frame.seq, code: ProtocolCodes.wrongSession);
    }

    if (frame.seq == _lastSeq + 1) {
      final response = applyCommand(frame);
      _lastSeq = frame.seq;
      _cache.put(frame.seq, rawUtf8, response);
      return response;
    }

    if (frame.seq == _lastSeq) {
      final cached = _cache.identicalResponse(frame.seq, rawUtf8);
      if (cached != null) {
        return cached;
      }
      return RejectMessage(seq: frame.seq, code: ProtocolCodes.seqReused);
    }

    if (frame.seq < _lastSeq) {
      return RejectMessage(seq: frame.seq, code: ProtocolCodes.staleSeq);
    }

    return RejectMessage(seq: frame.seq, code: ProtocolCodes.seqGap);
  }

  String _newSessionId() {
    if (!identical(_generateSessionId, _unsetSessionIdGenerator)) {
      return _generateSessionId();
    }
    return _defaultSessionId(_random);
  }
}

String _defaultSessionId(Random random) {
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return hex;
}

final class _ResponseCache {
  static const int maxEntries = 64;

  final Map<int, _CacheEntry> _entries = {};
  final List<int> _order = [];

  void clear() {
    _entries.clear();
    _order.clear();
  }

  void put(int seq, String rawUtf8, ServerMessage response) {
    if (_entries.containsKey(seq)) {
      _order.remove(seq);
    }
    _entries[seq] = _CacheEntry(rawUtf8, response);
    _order.add(seq);
    while (_order.length > maxEntries) {
      final evict = _order.removeAt(0);
      _entries.remove(evict);
    }
  }

  ServerMessage? identicalResponse(int seq, String rawUtf8) {
    final entry = _entries[seq];
    if (entry == null) {
      return null;
    }
    if (entry.rawUtf8 == rawUtf8) {
      return entry.response;
    }
    return null;
  }
}

final class _CacheEntry {
  const _CacheEntry(this.rawUtf8, this.response);

  final String rawUtf8;
  final ServerMessage response;
}
