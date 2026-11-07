import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../services/units.dart';

/// Asks for today's weight and saves it.
Future<void> showLogWeight(BuildContext context, AppState s) async {
  final c = TextEditingController(
    text: s.weights.isEmpty
        ? ''
        : Units.instance.weightValue(s.weights.last.kg).toStringAsFixed(1),
  );
  final kg = await showDialog<double>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Log weight'),
      content: TextField(
        controller: c,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(labelText: 'Weight', suffixText: Units.instance.weightUnit),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(90, 44)),
          onPressed: () {
            final v = double.tryParse(c.text.trim());
            if (v == null) return;
            final kg = Units.instance.kgFromInput(v);
            if (kg >= 30 && kg <= 250) Navigator.pop(ctx, kg);
          },
          child: const Text('Save'),
        ),
      ],
    ),
  );
  c.dispose();
  if (kg != null) s.logWeight(kg);
}
