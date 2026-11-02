import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme.dart';
import 'privacy_screen.dart';

/// Daily targets and the delete-everything button.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(backgroundColor: Colors.transparent, title: const Text('Settings')),
      body: AppBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            const Text('Daily targets',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            _stepper('Calories', '${s.kcalTarget} kcal', 50,
                (d) => s.setTargets(kcal: (s.kcalTarget + d).clamp(1000, 5000))),
            _stepper('Protein', '${s.proteinTarget} g', 5,
                (d) => s.setTargets(protein: (s.proteinTarget + d).clamp(20, 300))),
            _stepper('Carbs', '${s.carbsTarget} g', 10,
                (d) => s.setTargets(carbs: (s.carbsTarget + d).clamp(20, 600))),
            _stepper('Fat', '${s.fatTarget} g', 5,
                (d) => s.setTargets(fat: (s.fatTarget + d).clamp(10, 200))),
            if (s.profile != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: OutlinedButton(
                  onPressed: () {
                    s.recalculateTargets();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Targets recalculated from your profile')),
                    );
                  },
                  child: const Text('Recalculate targets from profile'),
                ),
              ),
            const SizedBox(height: 24),
            OutlinedButton(
              style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Delete all data?'),
                    content: const Text(
                        'Your profile, allergies, diary and workouts will be removed from this phone and your account.'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancel')),
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Delete')),
                    ],
                  ),
                );
                if (ok == true) {
                  await s.clearAll(deleteCloud: true);
                  if (context.mounted) Navigator.of(context).pop();
                }
              },
              child: const Text('Delete all data'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const PrivacyScreen()),
              ),
              child: const Text('Privacy policy'),
            ),
            if (s.signedIn) ...[
              const SizedBox(height: 12),
              OutlinedButton(
                style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
                onPressed: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Delete your account?'),
                      content: const Text(
                          'This permanently deletes your account, friends, posts and all saved data. It cannot be undone.'),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancel')),
                        TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Delete account')),
                      ],
                    ),
                  );
                  if (ok != true) return;
                  final done = await s.deleteAccount();
                  if (!context.mounted) return;
                  if (done) {
                    Navigator.of(context).pop();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Could not delete the account. Try again later.')),
                    );
                  }
                },
                child: const Text('Delete account'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _stepper(String label, String value, int step, void Function(int delta) onChange) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        radius: 20,
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontSize: 13, color: AppColors.muted)),
                  Text(value,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            IconButton.outlined(
              tooltip: 'Decrease $label',
              onPressed: () => onChange(-step),
              icon: const Icon(Icons.remove),
            ),
            const SizedBox(width: 4),
            IconButton.outlined(
              tooltip: 'Increase $label',
              onPressed: () => onChange(step),
              icon: const Icon(Icons.add),
            ),
          ],
        ),
      ),
    );
  }
}
