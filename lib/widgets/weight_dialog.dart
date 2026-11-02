import 'package:flutter/material.dart';

import '../state/app_state.dart';

/// Asks for today's weight and saves it.
Future<void> showLogWeight(BuildContext context, AppState s) async {
  final c = TextEditingController(
    text: s.weights.isEmpty ? '' : s.weights.last.kg.toString(),
  );
  final kg = await showDialog<double>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Log weight'),
      content: TextField(
        controller: c,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(labelText: 'Weight', suffixText: 'kg'),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(90, 44)),
          onPressed: () {
            final v = double.tryParse(c.text.trim());
            if (v != null && v >= 30 && v <= 250) Navigator.pop(ctx, v);
          },
          child: const Text('Save'),
        ),
      ],
    ),
  );
  c.dispose();
  if (kg != null) s.logWeight(kg);
}
