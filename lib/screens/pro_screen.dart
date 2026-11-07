import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import '../services/plan_service.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/illustrations.dart';

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
    ['Meal photo to calories (uses AI requests)', 'Yes', 'Yes'],
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
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary, AppColors.primaryDeep],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Center(child: HeroArt(ArtKind.crown, size: 96)),
                const SizedBox(height: 10),
                const Text('Healthy Pro',
                    style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                const Text('More AI every day. Your core app stays free.',
                    style: TextStyle(color: Colors.white, fontSize: 14)),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _price('Monthly', 'Rs 99', 'per month', false)),
              const SizedBox(width: 12),
              Expanded(child: _price('Yearly', 'Rs 799', 'per year, save 33%', true)),
            ],
          ),
          const SizedBox(height: 4),
          Text('Preview prices, not final.',
              textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted, fontSize: 11)),
          const SizedBox(height: 14),
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
          Builder(builder: (context) {
            final s = context.watch<AppState>();
            final on = s.prefs['proNotify'] == true;
            return FilledButton.icon(
              onPressed: on
                  ? null
                  : () {
                      final next = Map<String, dynamic>.from(s.prefs)..['proNotify'] = true;
                      s.savePrefs(next);
                      ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Noted. Pro is not open for payment yet.')));
                    },
              icon: Icon(on ? Icons.check : Icons.notifications_active_outlined),
              label: Text(on ? 'We will tell you when Pro opens' : 'Notify me when Pro opens'),
            );
          }),
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

  Widget _price(String name, String price, String sub, bool best) => AppCard(
        borderColor: best ? AppColors.primary : null,
        child: Column(
          children: [
            Text(name, style: TextStyle(color: AppColors.muted, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(price, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
            Text(sub, textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted, fontSize: 11)),
          ],
        ),
      );
}
