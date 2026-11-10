// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';

import 'operator_controller.dart';

class EstopPanel extends StatelessWidget {
  const EstopPanel({super.key, required this.controller});

  final OperatorController controller;

  @override
  Widget build(BuildContext context) {
    final latched = controller.snapshot?.latched == true;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red.shade800,
            foregroundColor: Colors.white,
            minimumSize: const Size(160, 72),
            textStyle: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          onPressed: () => controller.estop(),
          child: const Text('E-STOP'),
        ),
        if (latched) ...[
          const SizedBox(height: 8),
          Text(
            'LATCHED',
            style: TextStyle(
              color: Colors.red.shade900,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
        ],
        if (controller.showEstopReset) ...[
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () => controller.estopReset(),
            child: const Text('Reset'),
          ),
        ],
      ],
    );
  }
}
