// SPDX-License-Identifier: Apache-2.0

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:async/async.dart';
import 'package:robot_protocol/robot_protocol.dart';
import 'package:robot_sim/robot_sim.dart';
import 'package:robot_server/robot_server.dart';
import 'package:test/test.dart';

const _frameTimeout = Duration(seconds: 5);

Future<Map<String, dynamic>> _nextJson(StreamQueue<String> q) async {
  final raw = await q.next.timeout(_frameTimeout);
  return jsonDecode(raw) as Map<String, dynamic>;
}

Future<Map<String, dynamic>> _waitForJson(
  List<String> inbound,
  bool Function(Map<String, dynamic>) match,
) async {
  final deadline = DateTime.now().add(_frameTimeout);
  while (DateTime.now().isBefore(deadline)) {
    for (final raw in inbound) {
      final m = jsonDecode(raw) as Map<String, dynamic>;
      if (match(m)) {
        return m;
      }
    }
    await Future<void>.delayed(const Duration(milliseconds: 2));
  }
  throw TimeoutException('no matching frame');
}

String _cmd({
  required String session,
  required int seq,
  required String type,
  Map<String, Object?> body = const {},
}) {
  return jsonEncode({
    'v': 1,
    'type': type,
    'session': session,
    'seq': seq,
    'body': body,
  });
}

void main() {
  late ManualTickSource tickSource;
  late RobotWebSocketServer server;
  late int port;

  setUp(() async {
    tickSource = ManualTickSource();
    server = RobotWebSocketServer(tickSource: tickSource);
    await server.start(port: 0);
    port = server.port;
  });

  tearDown(() async {
    await server.stop();
  });

  group('criterion 12 server integration', () {
    test('hello, mission, motion, e-stop', () async {
      final ws = await WebSocket.connect('ws://127.0.0.1:$port')
          .timeout(_frameTimeout);
      final inbound = StreamQueue(ws.cast<String>());

      ws.add(jsonEncode({'v': 1, 'type': 'hello'}));
      final welcome = await _nextJson(inbound);
      expect(welcome['type'], 'welcome');
      final session = welcome['session'] as String;
      expect(session, isNotEmpty);

      final snap0 = await _nextJson(inbound);
      expect(snap0['type'], 'snapshot');
      expect(snap0['tick'], 0);

      ws.add(_cmd(session: session, seq: 1, type: 'heartbeat'));
      await _nextJson(inbound); // ack

      ws.add(
        _cmd(
          session: session,
          seq: 2,
          type: 'mission_set',
          body: {
            'waypoints': [
              [2.6, 1.0],
            ],
          },
        ),
      );
      await _nextJson(inbound);

      ws.add(_cmd(session: session, seq: 3, type: 'mission_start'));
      await _nextJson(inbound);

      for (var t = 0; t < 30; t++) {
        if (t.isOdd) {
          ws.add(_cmd(session: session, seq: 4 + t, type: 'heartbeat'));
          await _nextJson(inbound);
        }
        tickSource.tick();
        final snap = await _nextJson(inbound);
        expect(snap['type'], 'snapshot');
        if ((snap['v'] as num).toDouble() >= 0.6 - 1e-9) {
          break;
        }
      }

      ws.add(_cmd(session: session, seq: 100, type: 'estop'));
      final estopAck = await _nextJson(inbound);
      expect(estopAck['type'], 'ack');

      tickSource.tick();
      final latched = await _nextJson(inbound);
      expect(latched['latched'], isTrue);
      expect(latched['mission'], 'paused');

      await ws.close();
    });

    test('reconnect keeps latch, tick and pose', () async {
      final ws1 = await WebSocket.connect('ws://127.0.0.1:$port')
          .timeout(_frameTimeout);
      final q1 = StreamQueue(ws1.cast<String>());

      ws1.add(jsonEncode({'v': 1, 'type': 'hello'}));
      final w1 = await _nextJson(q1);
      final oldSession = w1['session'] as String;
      await _nextJson(q1);

      ws1.add(_cmd(session: oldSession, seq: 1, type: 'heartbeat'));
      await _nextJson(q1);
      ws1.add(
        _cmd(
          session: oldSession,
          seq: 2,
          type: 'mission_set',
          body: {
            'waypoints': [
              [2.6, 1.0],
            ],
          },
        ),
      );
      await _nextJson(q1);
      ws1.add(_cmd(session: oldSession, seq: 3, type: 'mission_start'));
      await _nextJson(q1);

      for (var i = 0; i < 40; i++) {
        ws1.add(_cmd(session: oldSession, seq: 4 + i, type: 'heartbeat'));
        await _nextJson(q1);
        tickSource.tick();
        final s = await _nextJson(q1);
        if ((s['v'] as num) >= 0.6 - 1e-9) {
          break;
        }
      }

      ws1.add(_cmd(session: oldSession, seq: 200, type: 'estop'));
      await _nextJson(q1);
      tickSource.tick();
      final beforeDisc = await _nextJson(q1);
      expect(beforeDisc['latched'], isTrue);
      final tick = beforeDisc['tick'];
      final x = (beforeDisc['x'] as num).toDouble();
      final y = (beforeDisc['y'] as num).toDouble();

      await ws1.close();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final ws2 = await WebSocket.connect('ws://127.0.0.1:$port')
          .timeout(_frameTimeout);
      final q2 = StreamQueue(ws2.cast<String>());
      ws2.add(jsonEncode({'v': 1, 'type': 'hello'}));
      await _nextJson(q2);
      final reconnectSnap = await _nextJson(q2);
      expect(reconnectSnap['latched'], isTrue);
      expect(reconnectSnap['tick'], tick);
      expect((reconnectSnap['x'] as num).toDouble(), closeTo(x, 1e-12));
      expect((reconnectSnap['y'] as num).toDouble(), closeTo(y, 1e-12));

      await ws2.close();
    });

    test('old session frames get wrong_session', () async {
      final ws1 = await WebSocket.connect('ws://127.0.0.1:$port')
          .timeout(_frameTimeout);
      final q1 = StreamQueue(ws1.cast<String>());
      ws1.add(jsonEncode({'v': 1, 'type': 'hello'}));
      final w1 = await _nextJson(q1);
      final oldSession = w1['session'] as String;
      await _nextJson(q1);
      await ws1.close();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final ws2 = await WebSocket.connect('ws://127.0.0.1:$port')
          .timeout(_frameTimeout);
      final q2 = StreamQueue(ws2.cast<String>());
      ws2.add(jsonEncode({'v': 1, 'type': 'hello'}));
      await _nextJson(q2);
      await _nextJson(q2);

      ws2.add(_cmd(session: oldSession, seq: 1, type: 'heartbeat'));
      final reject = await _nextJson(q2);
      expect(reject['type'], 'reject');
      expect(reject['code'], ProtocolCodes.wrongSession);

      await ws2.close();
    });

    test('second client closed with 1008', () async {
      final ws1 = await WebSocket.connect('ws://127.0.0.1:$port')
          .timeout(_frameTimeout);
      ws1.add(jsonEncode({'v': 1, 'type': 'hello'}));

      final ws2 = await WebSocket.connect('ws://127.0.0.1:$port')
          .timeout(_frameTimeout);
      final closed = Completer<void>();
      ws2.listen(
        null,
        onDone: closed.complete,
        onError: (_) => closed.complete(),
      );
      await closed.future.timeout(_frameTimeout);
      expect(ws2.closeCode, kCloseSecondClient);

      await ws1.close();
    });

    test('binary frame yields binary_not_supported', () async {
      final ws = await WebSocket.connect('ws://127.0.0.1:$port')
          .timeout(_frameTimeout);
      final q = StreamQueue(ws.cast<String>());
      ws.add(jsonEncode({'v': 1, 'type': 'hello'}));
      await _nextJson(q);
      await _nextJson(q);

      ws.add(Uint8List.fromList([1, 2, 3]));
      final err = await _nextJson(q);
      expect(err['type'], 'error');
      expect(err['code'], ProtocolCodes.binaryNotSupported);

      tickSource.tick();
      final snap = await _nextJson(q);
      expect(snap['type'], 'snapshot');
      expect(snap['tick'], 1);

      await ws.close();
    });

    test('oversize frame yields frame_too_large', () async {
      final ws = await WebSocket.connect('ws://127.0.0.1:$port')
          .timeout(_frameTimeout);
      final q = StreamQueue(ws.cast<String>());
      ws.add(jsonEncode({'v': 1, 'type': 'hello'}));
      await _nextJson(q);
      await _nextJson(q);

      final pad = 'x' * 4097;
      ws.add(pad);
      final err = await _nextJson(q);
      expect(err['type'], 'error');
      expect(err['code'], ProtocolCodes.frameTooLarge);

      await ws.close();
    });

    test('frame overflow closes with 1009', () async {
      final ws = await WebSocket.connect('ws://127.0.0.1:$port')
          .timeout(_frameTimeout);
      final closed = Completer<void>();
      ws.done.then((_) => closed.complete());
      final inbound = <String>[];
      final sub = ws.listen((event) => inbound.add(event as String));
      ws.add(jsonEncode({'v': 1, 'type': 'hello'}));
      final welcome = await _waitForJson(
        inbound,
        (m) => m['type'] == 'welcome',
      );
      final session = welcome['session'] as String;
      await _waitForJson(inbound, (m) => m['type'] == 'snapshot');

      for (var i = 1; i < 32; i++) {
        ws.add(_cmd(session: session, seq: i, type: 'heartbeat'));
        await _waitForJson(inbound, (m) => m['type'] == 'ack' && m['seq'] == i);
      }
      ws.add(_cmd(session: session, seq: 32, type: 'heartbeat'));
      await closed.future.timeout(_frameTimeout);
      expect(ws.closeCode, kCloseFrameOverflow);
      await sub.cancel();
    });

    test('disconnect while running trips deadman at H+11', () async {
      final ws = await WebSocket.connect('ws://127.0.0.1:$port')
          .timeout(_frameTimeout);
      final q = StreamQueue(ws.cast<String>());
      ws.add(jsonEncode({'v': 1, 'type': 'hello'}));
      final w = await _nextJson(q);
      final session = w['session'] as String;
      await _nextJson(q);

      var seq = 1;
      ws.add(_cmd(session: session, seq: seq++, type: 'heartbeat'));
      await _nextJson(q);
      ws.add(
        _cmd(
          session: session,
          seq: seq++,
          type: 'mission_set',
          body: {'waypoints': SimConfig.demoWaypoints},
        ),
      );
      await _nextJson(q);
      ws.add(_cmd(session: session, seq: seq++, type: 'mission_start'));
      await _nextJson(q);

      var h = 0;
      for (var t = 0; t < 500; t++) {
        if (h == 0 && t.isEven) {
          ws.add(_cmd(session: session, seq: seq++, type: 'heartbeat'));
          await _nextJson(q);
        }
        tickSource.tick();
        final snap = await _nextJson(q);
        if (h == 0 && (snap['v'] as num).toDouble() >= 0.6 - 1e-12) {
          h = snap['tick'] as int;
          ws.add(_cmd(session: session, seq: seq++, type: 'heartbeat'));
          await _nextJson(q);
          break;
        }
      }
      expect(h, greaterThan(0), reason: 'never reached cruise speed');

      await ws.close();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      for (var t = h + 1; t <= h + 10; t++) {
        tickSource.tick();
      }
      tickSource.tick();
      // Poll via reconnect for deadman state.
      final ws2 = await WebSocket.connect('ws://127.0.0.1:$port')
          .timeout(_frameTimeout);
      final q2 = StreamQueue(ws2.cast<String>());
      ws2.add(jsonEncode({'v': 1, 'type': 'hello'}));
      await _nextJson(q2);
      final deadSnap = await _nextJson(q2);
      expect(deadSnap['deadman'], isTrue);
      expect(deadSnap['mission'], 'paused');
      expect(deadSnap['tick'], h + 11);

      await ws2.close();
    });
  });
}
