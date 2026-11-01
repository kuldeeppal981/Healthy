import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/step_service.dart';
import '../state/app_state.dart';
import '../theme.dart';

/// Home card with today's steps.
class StepsCard extends StatelessWidget {
  const StepsCard({super.key});

  @override
  Widget build(BuildContext context) {
    final svc = StepService.instance;
    final weight = context.watch<AppState>().profile?.weightKg ?? 65;
    return ListenableBuilder(
      listenable: svc,
      builder: (context, _) {
        final pct = (svc.steps / svc.goal).clamp(0.0, 1.0);
        return AppCard(
          radius: 16,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const StepsScreen()),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.directions_walk, color: AppColors.primary),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text('Steps',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                    ),
                    const Icon(Icons.chevron_right),
                  ],
                ),
                const SizedBox(height: 8),
                if (!svc.granted)
                  Row(
                    children: [
                      const Expanded(
                        child: Text('Count your steps automatically with your phone sensor.',
                            style: TextStyle(color: AppColors.muted, height: 1.3)),
                      ),
                      FilledButton(
                        onPressed: svc.requestPermission,
                        child: const Text('Allow'),
                      ),
                    ],
                  )
                else ...[
                  Text('${svc.steps} / ${svc.goal}',
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: pct,
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(8),
                    color: AppColors.primary,
                    backgroundColor: AppColors.chipBg,
                  ),
                  const SizedBox(height: 6),
                  Text('About ${StepService.kcalFor(svc.steps, weight)} kcal burned walking',
                      style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class StepsScreen extends StatelessWidget {
  const StepsScreen({super.key});

  static const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  Future<void> _editGoal(BuildContext context, StepService svc) async {
    final c = TextEditingController(text: '${svc.goal}');
    final v = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Daily step goal'),
        content: TextField(
          controller: c,
          keyboardType: TextInputType.number,
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, int.tryParse(c.text.trim())),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    c.dispose();
    if (v != null) svc.setGoal(v);
  }

  @override
  Widget build(BuildContext context) {
    final svc = StepService.instance;
    final weight = context.watch<AppState>().profile?.weightKg ?? 65;
    return Scaffold(
      appBar: AppBar(title: const Text('Steps')),
      body: ListenableBuilder(
        listenable: svc,
        builder: (context, _) {
          final week = svc.lastDays(7);
          final top = [svc.goal, ...week.map((e) => e.value)].reduce((a, b) => a > b ? a : b);
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              if (!svc.granted) ...[
                const Text(
                  'Allow "Physical activity" so the app can read your phone\'s step sensor. Steps stay on your phone.',
                  style: TextStyle(height: 1.4),
                ),
                const SizedBox(height: 12),
                FilledButton(
                    onPressed: svc.requestPermission, child: const Text('Allow step counting')),
              ] else ...[
                Text('${svc.steps}',
                    style: const TextStyle(fontSize: 44, fontWeight: FontWeight.w800)),
                Text('of ${svc.goal} steps today',
                    style: const TextStyle(color: AppColors.muted)),
                const SizedBox(height: 4),
                Text('About ${StepService.kcalFor(svc.steps, weight)} kcal burned walking',
                    style: const TextStyle(color: AppColors.muted)),
                TextButton(
                  onPressed: () => _editGoal(context, svc),
                  child: const Align(
                      alignment: Alignment.centerLeft, child: Text('Change goal')),
                ),
                if (svc.unavailable)
                  const Text('This phone does not have a step sensor.',
                      style: TextStyle(color: AppColors.danger)),
                const SizedBox(height: 16),
                const Text('Last 7 days',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                SizedBox(
                  height: 150,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (final e in week)
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text('${e.value}', style: const TextStyle(fontSize: 10)),
                              const SizedBox(height: 4),
                              Container(
                                height: 100 * (e.value / top),
                                margin: const EdgeInsets.symmetric(horizontal: 6),
                                decoration: BoxDecoration(
                                  color: e.value >= svc.goal
                                      ? AppColors.safe
                                      : AppColors.primary,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(_days[e.key.weekday - 1],
                                  style: const TextStyle(
                                      fontSize: 11, color: AppColors.muted)),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Steps come from your phone sensor and are counted from the first time the app sees the sensor each day, so open the app in the morning for the most accurate total. Calories are an estimate.',
                  style: TextStyle(color: AppColors.muted, fontSize: 12, height: 1.4),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
