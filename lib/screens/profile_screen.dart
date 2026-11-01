import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../services/nutrition_calc.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/sparkline.dart';
import 'onboarding_screen.dart';
import 'reminders_screen.dart';

/// Body stats, weight tracking and daily targets.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _logWeight(BuildContext context, AppState s) async {
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

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final p = s.profile;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      children: [
        const Text('Profile',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
        const SizedBox(height: 16),
        if (cloudEnabled) ...[
          _accountCard(s),
          const SizedBox(height: 16),
        ],
        if (p == null)
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Set up your profile to get calorie and protein targets worked out for you.'),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const OnboardingScreen(editing: true),
                    ),
                  ),
                  child: const Text('Set up profile'),
                ),
              ],
            ),
          )
        else
          _bodyCard(context, s),
        const SizedBox(height: 12),
        AppCard(
          radius: 16,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          child: ListTile(
            leading: const Icon(Icons.notifications_active_outlined, color: AppColors.primary),
            title: const Text('Reminders', style: TextStyle(fontWeight: FontWeight.w700)),
            subtitle: const Text('Meals, water and workouts'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const RemindersScreen()),
            ),
          ),
        ),
        const SizedBox(height: 20),
        const Text('Daily targets',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        _stepper(context, 'Calories', '${s.kcalTarget} kcal', 50,
            (d) => s.setTargets(kcal: (s.kcalTarget + d).clamp(1000, 5000))),
        _stepper(context, 'Protein', '${s.proteinTarget} g', 5,
            (d) => s.setTargets(protein: (s.proteinTarget + d).clamp(20, 300))),
        _stepper(context, 'Carbs', '${s.carbsTarget} g', 10,
            (d) => s.setTargets(carbs: (s.carbsTarget + d).clamp(20, 600))),
        _stepper(context, 'Fat', '${s.fatTarget} g', 5,
            (d) => s.setTargets(fat: (s.fatTarget + d).clamp(10, 200))),
        if (p != null)
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
        const SizedBox(height: 12),
        OutlinedButton(
          style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
          onPressed: () async {
            final ok = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Delete all data?'),
                content: const Text('Your profile, allergies, diary and workouts will be removed from this phone.'),
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
            if (ok == true) await s.clearAll(deleteCloud: true);
          },
          child: const Text('Delete all data'),
        ),
      ],
    );
  }

  Widget _accountCard(AppState s) {
    if (!s.signedIn) {
      return AppCard(
        radius: 18,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Your data is only on this phone.',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            const Text('Sign in to back it up to your account.',
                style: TextStyle(color: AppColors.muted)),
            const SizedBox(height: 12),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              onPressed: s.leaveGuest,
              child: const Text('Sign in or create account'),
            ),
          ],
        ),
      );
    }

    final status = s.syncing
        ? 'Syncing...'
        : (s.syncError ?? 'Backed up to your account');

    return AppCard(
      radius: 18,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s.accountEmail ?? 'Signed in',
              style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(
            status,
            style: TextStyle(
              fontSize: 13,
              color: s.syncError == null ? AppColors.muted : AppColors.danger,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            onPressed: s.signOut,
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
  }

  Widget _bodyCard(BuildContext context, AppState s) {
    final p = s.profile!;
    final bmi = bmiOf(p);
    final start = s.weights.isEmpty ? p.weightKg : s.weights.first.kg;
    final change = p.weightKg - start;
    final values = s.weights.map((w) => w.kg).toList();
    final recent = values.length > 12 ? values.sublist(values.length - 12) : values;

    return AppCard(
      radius: 22,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Current weight',
                        style: TextStyle(fontSize: 13, color: AppColors.muted)),
                    Text('${p.weightKg.toStringAsFixed(1)} kg',
                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700)),
                    Text(
                      change == 0
                          ? 'No change yet'
                          : '${change > 0 ? '+' : ''}${change.toStringAsFixed(1)} kg since start',
                      style: const TextStyle(fontSize: 13, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('BMI',
                      style: TextStyle(fontSize: 13, color: AppColors.muted)),
                  Text(bmi.toStringAsFixed(1),
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
                  Text(bmiLabel(bmi),
                      style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                ],
              ),
            ],
          ),
          if (recent.length >= 2) ...[
            const SizedBox(height: 12),
            Sparkline(values: recent, color: AppColors.primary),
          ],
          const SizedBox(height: 12),
          Text(
            '${p.heightCm.round()} cm  |  ${p.age} yrs  |  ${goalLabels[p.goal] ?? ''}',
            style: const TextStyle(fontSize: 13, color: AppColors.muted),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                  onPressed: () => _logWeight(context, s),
                  child: const Text('Log weight'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => OnboardingScreen(initial: p, editing: true),
                    ),
                  ),
                  child: const Text('Edit profile'),
                ),
              ),
            ],
          ),
        ],
      ),
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
