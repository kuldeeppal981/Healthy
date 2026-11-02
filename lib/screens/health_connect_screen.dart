import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/health_service.dart';
import '../state/app_state.dart';
import '../theme.dart';

/// Home row for Health Connect and smartwatch data.
class HealthConnectCard extends StatelessWidget {
  const HealthConnectCard({super.key});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      radius: 16,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: ListTile(
        leading: Icon(Icons.watch_outlined, color: AppColors.primary),
        title: const Text('Smartwatch and Health Connect',
            style: TextStyle(fontWeight: FontWeight.w700)),
        subtitle: const Text('Steps, heart rate, sleep and workouts'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const HealthConnectScreen()),
        ),
      ),
    );
  }
}

class HealthConnectScreen extends StatelessWidget {
  const HealthConnectScreen({super.key});

  Widget _tile(String value, String label) => Expanded(
        child: AppCard(
          radius: 16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  style: TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.primary)),
              Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
            ],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final svc = HealthService.instance;
    return Scaffold(
      appBar: AppBar(title: const Text('Smartwatch and Health Connect')),
      body: ListenableBuilder(
        listenable: svc,
        builder: (context, _) {
          if (!svc.connected) {
            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text(
                  'Bring in the data your smartwatch or fitness app saves in Health Connect: steps, heart rate, sleep and exercise sessions.',
                  style: TextStyle(height: 1.4),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Healthy only reads this data, and keeps it on your phone. Your watch must sync to Health Connect first (for example through its own app, Google Fit or Samsung Health).',
                  style: TextStyle(color: AppColors.muted, height: 1.4, fontSize: 13),
                ),
                if (svc.error != null) ...[
                  const SizedBox(height: 12),
                  Text(svc.error!, style: const TextStyle(color: AppColors.danger)),
                ],
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: svc.busy ? null : () => svc.connect(state),
                  child: const Text('Connect Health Connect'),
                ),
              ],
            );
          }
          return RefreshIndicator(
            onRefresh: () => svc.refresh(state),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Row(
                  children: [
                    _tile(svc.steps == null ? '-' : '${svc.steps}', 'Steps today'),
                    const SizedBox(width: 10),
                    _tile(
                      svc.sleepHours == null ? '-' : '${svc.sleepHours!.toStringAsFixed(1)} h',
                      'Sleep (last night)',
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _tile(svc.avgHr == null ? '-' : '${svc.avgHr!.round()} bpm',
                        'Average heart rate today'),
                    const SizedBox(width: 10),
                    _tile(
                      svc.minHr == null ? '-' : '${svc.minHr} - ${svc.maxHr}',
                      'Lowest to highest bpm',
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Expanded(
                      child: Text('Exercise sessions',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                    ),
                    if (svc.busy)
                      const SizedBox(
                          width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                  ],
                ),
                const SizedBox(height: 4),
                const Text('New sessions from the last 14 days are added to your workout history.',
                    style: TextStyle(color: AppColors.muted, fontSize: 12)),
                const SizedBox(height: 8),
                if (svc.workouts.isEmpty)
                  const Text('No exercise sessions found.',
                      style: TextStyle(color: AppColors.muted)),
                for (final w in svc.workouts)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: AppCard(
                      radius: 14,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(w.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                                Text('${w.start.day}/${w.start.month}',
                                    style: const TextStyle(
                                        color: AppColors.muted, fontSize: 12)),
                              ],
                            ),
                          ),
                          Text('${w.minutes} min${w.kcal != null ? '  |  ${w.kcal} kcal' : ''}',
                              style: const TextStyle(color: AppColors.muted)),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: svc.busy ? null : () => svc.refresh(state),
                  child: const Text('Sync now'),
                ),
                TextButton(
                  onPressed: svc.disconnect,
                  child: const Text('Disconnect', style: TextStyle(color: AppColors.danger)),
                ),
                const Text(
                  'To remove Healthy\'s access completely, open Health Connect on your phone and change app permissions.',
                  style: TextStyle(color: AppColors.muted, fontSize: 11),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
