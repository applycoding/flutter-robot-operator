// SPDX-License-Identifier: Apache-2.0

import 'package:flutter/material.dart';

import 'operator_controller.dart';

class EventLogView extends StatelessWidget {
  const EventLogView({super.key, required this.controller});

  final OperatorController controller;

  @override
  Widget build(BuildContext context) {
    final entries = controller.eventLog;
    return Card(
      child: SizedBox(
        height: 120,
        child: ListView.builder(
          itemCount: entries.length,
          itemBuilder: (context, index) {
            return Text(
              entries[index].toString(),
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            );
          },
        ),
      ),
    );
  }
}
