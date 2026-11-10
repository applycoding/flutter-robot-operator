// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import 'src/estop_button.dart';
import 'src/event_log.dart';
import 'src/local_sim_transport.dart';
import 'src/map_painter.dart';
import 'src/mission_bar.dart';
import 'src/operator_controller.dart';
import 'src/status_panel.dart';
import 'src/ws_transport.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SemanticsBinding.instance.ensureSemantics();
  final wsUrl = const String.fromEnvironment('ROBOT_WS', defaultValue: '');
  final transport = (!kIsWeb && wsUrl.isNotEmpty)
      ? WsTransport(wsUrl)
      : LocalSimTransport();
  final controller = OperatorController(transport);
  await controller.start();
  runApp(OperatorApp(controller: controller));
}

class OperatorApp extends StatelessWidget {
  const OperatorApp({super.key, required this.controller});

  final OperatorController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        return MaterialApp(
          title: controller.pageTitle,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueGrey),
            useMaterial3: true,
          ),
          home: OperatorHome(controller: controller),
        );
      },
    );
  }
}

class OperatorHome extends StatelessWidget {
  const OperatorHome({super.key, required this.controller});

  final OperatorController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(title: Text(controller.pageTitle)),
          body: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        flex: 3,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade400),
                          ),
                          child: MapView(controller: controller),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              StatusPanel(controller: controller),
                              const SizedBox(height: 12),
                              MissionBar(controller: controller),
                              const SizedBox(height: 12),
                              EstopPanel(controller: controller),
                              const SizedBox(height: 12),
                              LinkLossSwitch(controller: controller),
                              const SizedBox(height: 12),
                              EventLogView(controller: controller),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
