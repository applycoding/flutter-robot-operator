// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';

import 'operator_controller.dart';

class MissionBar extends StatelessWidget {
  const MissionBar({super.key, required this.controller});

  final OperatorController controller;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ElevatedButton(
          onPressed: controller.canLoadDemoMission
              ? () => controller.loadDemoMission()
              : null,
          child: const Text('Load demo mission'),
        ),
        ElevatedButton(
          onPressed: controller.canStart
              ? () => controller.missionStart()
              : null,
          child: const Text('Start'),
        ),
        ElevatedButton(
          onPressed: controller.canPause
              ? () => controller.missionPause()
              : null,
          child: const Text('Pause'),
        ),
        ElevatedButton(
          onPressed: controller.canResume
              ? () => controller.missionResume()
              : null,
          child: const Text('Resume'),
        ),
        ElevatedButton(
          onPressed: controller.canStop ? () => controller.missionStop() : null,
          child: const Text('Stop'),
        ),
      ],
    );
  }
}
