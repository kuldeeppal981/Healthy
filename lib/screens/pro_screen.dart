import 'package:flutter/material.dart';

import '../services/plan_service.dart';
import '../theme.dart';

/// Free vs Pro. Buying is not open yet (needs Google Play Billing), so the
/// button says so honestly. Pro can already be granted by the server.
class ProScreen extends StatefulWidget {
  const ProScreen({super.key});

  @override
  State<ProScreen> createState() => _ProScreenState();
}

class _ProScreenState extends State<ProScreen> {
  late Future<PlanInfo> _plan = PlanService.load();

  static const _rows = <List<String>>[
    ['Calorie diary, water, steps, weight', 'Free', 'Pro'],
    ['Barcode scan and allergy alerts', 'Free', 'Pro'],
    ['Workouts, streaks, friends feed', 'Free', 'Pro'],
    ['AI requests per day (coach, voice, label scan)', '10', '60'],
    ['Weekly AI diet and workout plan', '-', 'Pro'],
    ['Meal photo to calories', '-', 'Pro'],
    ['Muscle and nutrition trends, PDF reports', 'Basic', 'Full'],
    ['Cloud backup of full history', '90 days', 'All'],
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Healthy Pro')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          FutureBuilder<PlanInfo>(
            future: _plan,
            builder: (context, snap) {
              final p = snap.data;
              final loading = snap.connectionState != ConnectionState.done;
              final pro = p?.pro ?? false;
              return AppCard(
                child: Row(
                  children: [
                    Icon(pro ? Icons.workspace_premium : Icons.person_outline,
                        color: AppColors.primary, size: 32),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            loading ? 'Checking your plan...' : (pro ? 'You are on Pro' : 'You are on the Free plan'),
                            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                          ),
                          if (pro && p?.expiresAt != null)
                            Text(
                              'Valid until ${p!.expiresAt!.day}/${p.expiresAt!.month}/${p.expiresAt!.year}',
                              style: TextStyle(color: AppColors.muted),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 14),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(child: SizedBox()),
                    SizedBox(width: 64, child: Text('Free', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w700))),
                    SizedBox(width: 64, child: Text('Pro', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.primary))),
                  ],
                ),
                for (final r in _rows)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Expanded(child: Text(r[0], style: const TextStyle(fontSize: 13))),
                        SizedBox(
                          width: 64,
                          child: Text(r[1] == 'Pro' ? 'Yes' : r[1], textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted, fontSize: 12)),
                        ),
                        SizedBox(
                          width: 64,
                          child: Text(r[2] == 'Pro' ? 'Yes' : r[2], textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const AppCard(
            child: Text(
              'Allergy alerts, barcode scan and the basic diary stay free, always. '
              'Pro is for the parts that cost us money to run, like AI.',
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: null,
            child: const Text('Upgrade (coming soon)'),
          ),
          const SizedBox(height: 8),
          Text(
            'Payments will open when the app is on Google Play. Plans and prices are not final.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
