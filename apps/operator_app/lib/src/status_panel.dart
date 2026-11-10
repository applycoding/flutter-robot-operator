// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';

import 'operator_controller.dart';

class StatusPanel extends StatelessWidget {
  const StatusPanel({super.key, required this.controller});

  final OperatorController controller;

  @override
  Widget build(BuildContext context) {
    final snap = controller.snapshot;
    final fault = snap?.fault;
    final protective = fault == 'obstacle_ahead';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Simulation only. Not connected to a robot. Not a certified safety system.',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.deepOrange,
          ),
        ),
        const SizedBox(height: 8),
        Text('Transport: ${controller.transportBadge}'),
        Text('Mission: ${snap?.mission.name ?? '—'}'),
        Text('Latch: ${snap?.latched == true ? 'latched' : 'clear'}'),
        Text('Deadman: ${snap?.deadman == true ? 'true' : 'false'}'),
        Text('Protective stop: ${protective ? 'obstacle_ahead' : 'clear'}'),
        Text('Heartbeat age (ticks): ${snap?.heartbeatAgeTicks ?? '—'}'),
        Text('Speed (m/s): ${snap?.v.toStringAsFixed(2) ?? '—'}'),
        Text('Clearance (m): ${snap?.clearance.toStringAsFixed(2) ?? '—'}'),
      ],
    );
  }
}

class LinkLossSwitch extends StatelessWidget {
  const LinkLossSwitch({super.key, required this.controller});

  final OperatorController controller;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      title: const Text('Simulate operator link loss'),
      value: controller.linkLossSimulated,
      onChanged: controller.setLinkLossSimulated,
    );
  }
}
