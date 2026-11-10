// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:operator_app/src/estop_button.dart';
import 'package:operator_app/src/mission_bar.dart';
import 'package:operator_app/src/operator_controller.dart';
import 'package:robot_protocol/robot_protocol.dart';

import 'fake_transport.dart';

void main() {
  Widget wrap(OperatorController c, Widget child) {
    return MaterialApp(home: Scaffold(body: child));
  }

  late FakeTransport transport;
  late OperatorController controller;

  setUp(() async {
    transport = FakeTransport();
    controller = OperatorController(transport);
    await controller.start();
  });

  tearDown(() {
    controller.dispose();
    transport.dispose();
  });

  void setSnap({
    MissionState mission = MissionState.idle,
    bool latched = false,
    double v = 0,
    double w = 0,
    int hbAge = 0,
    bool deadman = false,
  }) {
    transport.setSnapshot(
      SnapshotMessage(
        tick: 1,
        x: 1,
        y: 1,
        theta: 0,
        v: v,
        w: w,
        mission: mission,
        wpIndex: 0,
        latched: latched,
        deadman: deadman,
        fault: null,
        heartbeatAgeTicks: hbAge,
        clearance: 1,
      ),
    );
  }

  testWidgets('e-stop press sends exactly one estop', (tester) async {
    await tester.pumpWidget(
      wrap(
        controller,
        ListenableBuilder(
          listenable: controller,
          builder: (context, _) => EstopPanel(controller: controller),
        ),
      ),
    );
    await tester.tap(find.text('E-STOP'));
    await tester.pump();
    expect(transport.sentFrames.where((f) => f.contains('estop')).length, 1);
  });

  testWidgets('mission buttons follow enable rules', (tester) async {
    setSnap(mission: MissionState.idle);
    await tester.pumpWidget(
      wrap(
        controller,
        ListenableBuilder(
          listenable: controller,
          builder: (context, _) => MissionBar(controller: controller),
        ),
      ),
    );

    final start = find.widgetWithText(ElevatedButton, 'Start');
    final load = find.widgetWithText(ElevatedButton, 'Load demo mission');
    expect(tester.widget<ElevatedButton>(load).onPressed, isNotNull);
    expect(tester.widget<ElevatedButton>(start).onPressed, isNull);

    setSnap(mission: MissionState.ready, hbAge: 1);
    await tester.pumpWidget(
      wrap(
        controller,
        ListenableBuilder(
          listenable: controller,
          builder: (context, _) => MissionBar(controller: controller),
        ),
      ),
    );
    expect(tester.widget<ElevatedButton>(start).onPressed, isNotNull);

    setSnap(mission: MissionState.running);
    await tester.pumpWidget(
      wrap(
        controller,
        ListenableBuilder(
          listenable: controller,
          builder: (context, _) => MissionBar(controller: controller),
        ),
      ),
    );
    final pause = find.widgetWithText(ElevatedButton, 'Pause');
    expect(tester.widget<ElevatedButton>(pause).onPressed, isNotNull);
  });

  testWidgets('resume and stop enable rules', (tester) async {
    Future<void> pumpBar() async {
      await tester.pumpWidget(
        wrap(
          controller,
          ListenableBuilder(
            listenable: controller,
            builder: (context, _) => MissionBar(controller: controller),
          ),
        ),
      );
    }

    final resume = find.widgetWithText(ElevatedButton, 'Resume');
    final stop = find.widgetWithText(ElevatedButton, 'Stop');

    setSnap(mission: MissionState.running);
    await pumpBar();
    expect(tester.widget<ElevatedButton>(resume).onPressed, isNull);
    expect(tester.widget<ElevatedButton>(stop).onPressed, isNotNull);

    setSnap(mission: MissionState.paused, v: 0, w: 0, hbAge: 2);
    await pumpBar();
    expect(tester.widget<ElevatedButton>(resume).onPressed, isNotNull);
    expect(tester.widget<ElevatedButton>(stop).onPressed, isNotNull);

    setSnap(mission: MissionState.paused, latched: true, v: 0, w: 0, hbAge: 1);
    await pumpBar();
    expect(tester.widget<ElevatedButton>(resume).onPressed, isNull);

    setSnap(mission: MissionState.paused, deadman: true, v: 0, w: 0, hbAge: 11);
    await pumpBar();
    expect(tester.widget<ElevatedButton>(resume).onPressed, isNull);

    setSnap(mission: MissionState.paused, deadman: true, v: 0, w: 0, hbAge: 1);
    await pumpBar();
    expect(tester.widget<ElevatedButton>(resume).onPressed, isNotNull);

    setSnap(mission: MissionState.idle);
    await pumpBar();
    expect(tester.widget<ElevatedButton>(stop).onPressed, isNull);

    setSnap(mission: MissionState.succeeded);
    await pumpBar();
    expect(tester.widget<ElevatedButton>(stop).onPressed, isNull);
  });
}
