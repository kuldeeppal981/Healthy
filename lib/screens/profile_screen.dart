import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme.dart';

/// Daily targets. (Onboarding with BMR/TDEE auto-calculation comes next.)
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      children: [
        const Text('Profile',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        const Text('Apne daily targets set karo.',
            style: TextStyle(color: AppColors.muted)),
        const SizedBox(height: 16),
        _stepper(context, 'Calories', '${s.kcalTarget} kcal', 50,
            (d) => s.setTargets(kcal: (s.kcalTarget + d).clamp(1000, 5000))),
        _stepper(context, 'Protein', '${s.proteinTarget} g', 5,
            (d) => s.setTargets(protein: (s.proteinTarget + d).clamp(20, 300))),
        _stepper(context, 'Carbs', '${s.carbsTarget} g', 10,
            (d) => s.setTargets(carbs: (s.carbsTarget + d).clamp(20, 600))),
        _stepper(context, 'Fat', '${s.fatTarget} g', 5,
            (d) => s.setTargets(fat: (s.fatTarget + d).clamp(10, 200))),
        const SizedBox(height: 16),
        OutlinedButton(
          onPressed: () async {
            final ok = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Saara data delete karein?'),
                content: const Text('Allergies, diary aur targets sab hat jayenge.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Nahi')),
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Haan, delete karo')),
                ],
              ),
            );
            if (ok == true) await s.clearAll();
          },
          child: const Text('Saara data delete karo'),
        ),
      ],
    );
  }

  Widget _stepper(BuildContext context, String label, String value, int step,
      void Function(int delta) onChange) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        radius: 16,
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(fontSize: 13, color: AppColors.muted)),
                  Text(value,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            IconButton.outlined(
              tooltip: '$label kam karo',
              onPressed: () => onChange(-step),
              icon: const Icon(Icons.remove),
            ),
            const SizedBox(width: 4),
            IconButton.outlined(
              tooltip: '$label badhao',
              onPressed: () => onChange(step),
              icon: const Icon(Icons.add),
            ),
          ],
        ),
      ),
    );
  }
}
