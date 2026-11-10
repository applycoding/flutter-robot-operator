// SPDX-License-Identifier: Apache-2.0

import 'dart:convert';

import 'package:robot_protocol/robot_protocol.dart';
import 'package:test/test.dart';

const _map = MapInfo(widthM: 10, heightM: 6, cellM: 0.1, obstacles: []);

String _frameJson({
  required String session,
  required int seq,
  required CommandType type,
  List<List<double>>? waypoints,
}) {
  final body = switch (type) {
    CommandType.missionSet => {
      'waypoints':
          waypoints ??
          [
            [1.0, 1.0],
          ],
    },
    _ => <String, Object?>{},
  };
  return jsonEncode({
    'v': 1,
    'type': type.wireName,
    'session': session,
    'seq': seq,
    'body': body,
  });
}

SessionedFrame _decode(String raw) {
  final result = RobotCodec.decodeTextFrame(raw);
  expect(result, isA<DecodeOk>());
  final frame = (result as DecodeOk).frame;
  expect(frame, isA<SessionedFrame>());
  return frame as SessionedFrame;
}

void main() {
  late CountingApplier applier;
  late SessionGate gate;

  setUp(() {
    applier = CountingApplier();
    gate = SessionGate(
      applyCommand: applier.apply,
      generateSessionId: () => 'session-a',
    );
    gate.beginSession(tickDtS: 0.05, map: _map);
  });

  final commandTypes = CommandTypeJson.sessioned.toList();

  group('in-order seq advances and applies once', () {
    for (final type in commandTypes) {
      test(type.wireName, () {
        applier.reset();
        gate = SessionGate(
          applyCommand: applier.apply,
          generateSessionId: () => 'session-a',
        );
        gate.beginSession(tickDtS: 0.05, map: _map);
        final raw = _frameJson(session: 'session-a', seq: 1, type: type);
        final frame = _decode(raw);
        final msg = gate.handle(frame, rawUtf8: raw);
        expect(msg, isA<AckMessage>());
        expect(applier.count, 1);
        if (type == CommandType.estop) {
          expect(gate.lastSeq, 0);
        } else {
          expect(gate.lastSeq, 1);
        }
      });
    }
  });

  group('duplicate identical frame uses cache', () {
    for (final type in commandTypes) {
      test(type.wireName, () {
        applier.reset();
        gate = SessionGate(
          applyCommand: applier.apply,
          generateSessionId: () => 'session-a',
        );
        gate.beginSession(tickDtS: 0.05, map: _map);
        final raw = _frameJson(session: 'session-a', seq: 1, type: type);
        final frame = _decode(raw);
        gate.handle(frame, rawUtf8: raw);
        final again = gate.handle(frame, rawUtf8: raw);
        expect(again, isA<AckMessage>());
        if (type == CommandType.estop) {
          expect(applier.count, 2);
        } else {
          expect(applier.count, 1);
        }
      });
    }
  });

  group('reused seq with different payload', () {
    for (final type in commandTypes) {
      test(type.wireName, () {
        applier.reset();
        gate = SessionGate(
          applyCommand: applier.apply,
          generateSessionId: () => 'session-a',
        );
        gate.beginSession(tickDtS: 0.05, map: _map);
        final raw1 = _frameJson(session: 'session-a', seq: 1, type: type);
        gate.handle(_decode(raw1), rawUtf8: raw1);
        if (type == CommandType.estop) {
          final raw2 = raw1.replaceFirst('"body":{}', '"body": {}');
          final msg = gate.handle(_decode(raw2), rawUtf8: raw2);
          expect(msg, isA<AckMessage>());
          expect(applier.estopCount, 2);
          return;
        }
        final raw2 = type == CommandType.missionSet
            ? _frameJson(
                session: 'session-a',
                seq: 1,
                type: type,
                waypoints: [
                  [2.0, 2.0],
                ],
              )
            : _frameJson(
                session: 'session-a',
                seq: 1,
                type: type,
              ).replaceFirst('"body":{}', '"body": {}');
        final msg = gate.handle(_decode(raw2), rawUtf8: raw2);
        expect(msg, isA<RejectMessage>());
        expect((msg as RejectMessage).code, ProtocolCodes.seqReused);
        expect(applier.count, 1);
      });
    }
  });

  group('stale and gap', () {
    test('stale_seq after seq 1', () {
      final raw1 = _frameJson(
        session: 'session-a',
        seq: 1,
        type: CommandType.heartbeat,
      );
      gate.handle(_decode(raw1), rawUtf8: raw1);
      // Advance with seq 2 first.
      final raw2 = _frameJson(
        session: 'session-a',
        seq: 2,
        type: CommandType.heartbeat,
      );
      gate.handle(_decode(raw2), rawUtf8: raw2);
      final stale3 = _frameJson(
        session: 'session-a',
        seq: 1,
        type: CommandType.missionStart,
      );
      final msg = gate.handle(_decode(stale3), rawUtf8: stale3);
      expect(msg, isA<RejectMessage>());
      expect((msg as RejectMessage).code, ProtocolCodes.staleSeq);
    });

    test('seq_gap leaves last unchanged', () {
      final raw1 = _frameJson(
        session: 'session-a',
        seq: 1,
        type: CommandType.heartbeat,
      );
      gate.handle(_decode(raw1), rawUtf8: raw1);
      final gap = _frameJson(
        session: 'session-a',
        seq: 3,
        type: CommandType.heartbeat,
      );
      final msg = gate.handle(_decode(gap), rawUtf8: gap);
      expect(msg, isA<RejectMessage>());
      expect((msg as RejectMessage).code, ProtocolCodes.seqGap);
      expect(gate.lastSeq, 1);
      expect(applier.count, 1);
    });
  });

  group('wrong session and no session', () {
    test('wrong session rejects non-estop', () {
      final raw = _frameJson(
        session: 'other',
        seq: 1,
        type: CommandType.missionStart,
      );
      final msg = gate.handle(_decode(raw), rawUtf8: raw);
      expect(msg, isA<RejectMessage>());
      expect((msg as RejectMessage).code, ProtocolCodes.wrongSession);
      expect(applier.count, 0);
    });

    test('no hello yet rejects non-estop', () {
      final bare = SessionGate(
        applyCommand: applier.apply,
        generateSessionId: () => 'session-a',
      );
      final raw = _frameJson(
        session: 'session-a',
        seq: 1,
        type: CommandType.heartbeat,
      );
      final msg = bare.handle(_decode(raw), rawUtf8: raw);
      expect(msg, isA<RejectMessage>());
      expect((msg as RejectMessage).code, ProtocolCodes.wrongSession);
    });

    test('new hello replaces session', () {
      var index = 0;
      gate = SessionGate(
        applyCommand: applier.apply,
        generateSessionId: () => index++ == 0 ? 'session-a' : 'session-b',
      );
      gate.beginSession(tickDtS: 0.05, map: _map);
      final raw = _frameJson(
        session: 'session-a',
        seq: 1,
        type: CommandType.heartbeat,
      );
      gate.handle(_decode(raw), rawUtf8: raw);
      gate.beginSession(tickDtS: 0.05, map: _map);
      final old = gate.handle(_decode(raw), rawUtf8: raw);
      expect(old, isA<RejectMessage>());
      expect((old as RejectMessage).code, ProtocolCodes.wrongSession);
    });
  });

  group('e-stop exceptions', () {
    test('stale seq still applies with matching session', () {
      final hb = _frameJson(
        session: 'session-a',
        seq: 1,
        type: CommandType.heartbeat,
      );
      gate.handle(_decode(hb), rawUtf8: hb);
      final estop = _frameJson(
        session: 'session-a',
        seq: 1,
        type: CommandType.estop,
      );
      final msg = gate.handle(_decode(estop), rawUtf8: estop);
      expect(msg, isA<AckMessage>());
      expect(applier.estopCount, 1);
      expect(gate.lastSeq, 1);
    });

    test('gap seq still applies', () {
      final hb = _frameJson(
        session: 'session-a',
        seq: 1,
        type: CommandType.heartbeat,
      );
      gate.handle(_decode(hb), rawUtf8: hb);
      final estop = _frameJson(
        session: 'session-a',
        seq: 99,
        type: CommandType.estop,
      );
      gate.handle(_decode(estop), rawUtf8: estop);
      expect(applier.estopCount, 1);
      expect(gate.lastSeq, 1);
    });

    test('wrong session applies with note', () {
      final estop = _frameJson(
        session: 'wrong',
        seq: 5,
        type: CommandType.estop,
      );
      final msg = gate.handle(_decode(estop), rawUtf8: estop);
      expect(msg, isA<AckMessage>());
      expect((msg as AckMessage).note, kAppliedWithoutSessionNote);
      expect(applier.estopCount, 1);
    });

    test('before hello applies with note', () {
      final bare = SessionGate(
        applyCommand: applier.apply,
        generateSessionId: () => 'session-a',
      );
      applier.reset();
      final estop = _frameJson(session: 'any', seq: 1, type: CommandType.estop);
      final msg = bare.handle(_decode(estop), rawUtf8: estop);
      expect((msg as AckMessage).note, kAppliedWithoutSessionNote);
      expect(applier.estopCount, 1);
    });

    test('duplicate estop re-applies (not cached like other commands)', () {
      final estop = _frameJson(
        session: 'session-a',
        seq: 1,
        type: CommandType.estop,
      );
      gate.handle(_decode(estop), rawUtf8: estop);
      gate.handle(_decode(estop), rawUtf8: estop);
      expect(applier.estopCount, 2);
    });
  });

  group('response cache capacity', () {
    test('retains at most 64 entries', () {
      for (var seq = 1; seq <= 70; seq++) {
        final raw = _frameJson(
          session: 'session-a',
          seq: seq,
          type: CommandType.heartbeat,
        );
        gate.handle(_decode(raw), rawUtf8: raw);
      }
      expect(gate.lastSeq, 70);
      final first = _frameJson(
        session: 'session-a',
        seq: 1,
        type: CommandType.heartbeat,
      );
      final dup = gate.handle(_decode(first), rawUtf8: first);
      expect(dup, isA<RejectMessage>());
      expect((dup as RejectMessage).code, ProtocolCodes.staleSeq);
    });
  });

  test('sim reject still advances last', () {
    applier.nextReject = true;
    final raw = _frameJson(
      session: 'session-a',
      seq: 1,
      type: CommandType.missionStart,
    );
    final msg = gate.handle(_decode(raw), rawUtf8: raw);
    expect(msg, isA<RejectMessage>());
    expect(gate.lastSeq, 1);
  });
}

final class CountingApplier {
  int count = 0;
  int estopCount = 0;
  bool nextReject = false;

  void reset() {
    count = 0;
    estopCount = 0;
    nextReject = false;
  }

  ServerMessage apply(SessionedFrame frame) {
    count++;
    if (frame.type == CommandType.estop) {
      estopCount++;
    }
    if (nextReject) {
      return RejectMessage(seq: frame.seq, code: ProtocolCodes.estopLatched);
    }
    return AckMessage(seq: frame.seq);
  }
}
