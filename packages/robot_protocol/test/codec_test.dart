// SPDX-License-Identifier: Apache-2.0

import 'dart:convert';
import 'dart:io';

import 'package:robot_protocol/robot_protocol.dart';
import 'package:robot_sim/robot_sim.dart' as sim;
import 'package:test/test.dart';

void main() {
  final testDir = Directory.current.path.endsWith('robot_protocol')
      ? 'test'
      : 'packages/robot_protocol/test';
  final acceptDir = Directory('$testDir/fixtures/accept');
  final rejectDir = Directory('$testDir/fixtures/reject');

  group('accept fixtures', () {
    for (final entity in acceptDir.listSync().whereType<File>()) {
      final name = entity.uri.pathSegments.last;
      test(name, () {
        final text = entity.readAsStringSync();
        final result = RobotCodec.decodeTextFrame(text);
        expect(result, isA<DecodeOk>(), reason: text);
      });
    }
  });

  group('reject fixtures', () {
    for (final entity in rejectDir.listSync().whereType<File>()) {
      final name = entity.uri.pathSegments.last;
      test(name, () {
        final text = entity.readAsStringSync();
        final result = RobotCodec.decodeTextFrame(text);
        expect(result, isA<DecodeError>());
        final err = result as DecodeError;
        expect(err.code, ProtocolCodes.invalid);
      });
    }

    test('at least twenty reject fixtures on disk', () {
      final count = rejectDir.listSync().whereType<File>().length;
      expect(count, greaterThanOrEqualTo(20));
    });
  });

  group('codec edge cases', () {
    test('binary frame returns binary_not_supported', () {
      final result = RobotCodec.decodeBinaryFrame();
      expect(result.code, ProtocolCodes.binaryNotSupported);
    });

    test('4097 UTF-8 bytes returns frame_too_large', () {
      // Valid minimal prefix padded to 4097 bytes.
      final pad = 'a' * 4080;
      final text = '{"v":1,"type":"hello"}$pad';
      final bytes = utf8.encode(text);
      expect(bytes.length, greaterThan(kMaxFrameUtf8Bytes));
      final result = RobotCodec.decodeUtf8Bytes(bytes);
      expect(result, isA<DecodeError>());
      expect((result as DecodeError).code, ProtocolCodes.frameTooLarge);
    });

    test('exactly 4096 bytes can still parse if valid JSON', () {
      final text = '{"v":1,"type":"hello"}';
      final bytes = utf8.encode(text);
      final padLen = kMaxFrameUtf8Bytes - bytes.length;
      final padded = '$text${' ' * padLen}';
      expect(utf8.encode(padded).length, kMaxFrameUtf8Bytes);
      final result = RobotCodec.decodeTextFrame(padded);
      expect(result, isA<DecodeOk>());
    });

    test('NaN waypoint is invalid', () {
      const text =
          '{"v":1,"type":"mission_set","session":"abc","seq":1,'
          '"body":{"waypoints":[[NaN,1.0]]}}';
      final result = RobotCodec.decodeTextFrame(text);
      expect(result, isA<DecodeError>());
    });

    test('root array is invalid', () {
      final result = RobotCodec.decodeTextFrame('[1,2]');
      expect(result, isA<DecodeError>());
    });

    test('malformed JSON is invalid', () {
      expect(RobotCodec.decodeTextFrame('{'), isA<DecodeError>());
    });
  });

  group('encode server messages', () {
    test('snapshot round-trips expected keys', () {
      const snap = SnapshotMessage(
        tick: 1,
        x: 1.0,
        y: 2.0,
        theta: 0.0,
        v: 0.1,
        w: 0.0,
        mission: MissionState.running,
        wpIndex: 0,
        latched: false,
        deadman: false,
        fault: null,
        heartbeatAgeTicks: 0,
        clearance: 0.5,
      );
      final json = jsonDecode(RobotCodec.encodeServerMessage(snap));
      expect(json['type'], 'snapshot');
      expect(json['tick'], 1);
      expect(json['mission'], 'running');
      expect(json.containsKey('fault'), isTrue);
    });
  });

  test('moving robot trajectory unchanged under malformed frames', () {
    // criterion 11 (codec): malformed protocol frames must not disturb the plant.
    final simClean = sim.RobotSim();
    final simNoisy = sim.RobotSim();
    final demo = sim.SimConfig.demoWaypoints;
    for (final sim in [simClean, simNoisy]) {
      sim.missionSet(demo);
      sim.heartbeat();
      sim.missionStart();
    }

    const badFrames = <String>[
      '{"v":2,"type":"hello"}',
      '{"v":1,"type":"hello","extra":1}',
      '{"v":1,"type":"mission_set","session":"x","seq":1.0,"body":{"waypoints":[[2,2]]}}',
      '{"v":1,"type":"heartbeat","session":"x","seq":1,"body":{"bad":1}}',
      '{"v":1,"type":"unknown","session":"x","seq":1,"body":{}}',
      'not json',
      '{"v":1,"type":"mission_set","session":"x","seq":1,"body":{"waypoints":[[NaN,1.0]]}}',
    ];

    for (var t = 1; t <= 50; t++) {
      if (t % 2 == 0) {
        simClean.heartbeat();
        simNoisy.heartbeat();
      }
      for (final frame in badFrames) {
        RobotCodec.decodeTextFrame(frame);
      }
      simClean.tick();
      simNoisy.tick();
      expect(simClean.traceLine(), simNoisy.traceLine(), reason: 'tick $t');
    }
  });
}
