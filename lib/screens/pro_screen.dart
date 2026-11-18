import 'package:flutter/material.dart';

import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config.dart';

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

  Future<void> _interest(AppState s) async {
    String plan = 'yearly', price = 'fair', feature = 'AI coach';
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setM) {
        Widget group(String title, List<List<String>> opts, String cur, void Function(String) pick) =>
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 14),
                Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    for (final o in opts)
                      ChoiceChip(
                        label: Text(o[1]),
                        selected: cur == o[0],
                        onSelected: (_) => setM(() => pick(o[0])),
                      ),
                  ],
                ),
              ],
            );
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Tell us what you would like',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text('This is not a payment. It only helps us plan Pro.',
                    style: TextStyle(color: AppColors.muted, fontSize: 12)),
                group('Which plan?', [
                  ['monthly', 'Monthly Rs 99'],
                  ['yearly', 'Yearly Rs 799'],
                ], plan, (v) => plan = v),
                group('How does the price feel?', [
                  ['cheap', 'Cheap'],
                  ['fair', 'Fair'],
                  ['high', 'Too high'],
                ], price, (v) => price = v),
                group('What would you want most?', [
                  ['AI coach', 'More AI coach'],
                  ['Diet plan', 'AI diet plan'],
                  ['Meal photo', 'Meal photo calories'],
                  ['Reports', 'Reports and trends'],
                ], feature, (v) => feature = v),
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Send'),
                ),
              ],
            ),
          ),
        );
      }),
    );
    if (ok != true || !mounted) return;
    final next = Map<String, dynamic>.from(s.prefs)..['proNotify'] = true;
    s.savePrefs(next);
    var sent = false;
    if (cloudEnabled && s.signedIn) {
      try {
        final r = await Supabase.instance.client.rpc('set_pro_interest',
            params: {'p_plan': plan, 'p_price': price, 'p_feature': feature});
        sent = r == 'ok';
      } catch (_) {}
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(sent
            ? 'Thank you. Noted. Pro is not open for payment yet.'
            : 'Noted on this phone. Sign in and connect to the internet so we can count you.')));
  }

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
      appBar: AppBar(title: const Text('Smartfitly Pro')),
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
                const Text('Smartfitly Pro',
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
              onPressed: on ? null : () => _interest(s),
              icon: Icon(on ? Icons.check : Icons.notifications_active_outlined),
              label: Text(on ? 'We will tell you when Pro opens' : 'I am interested in Pro'),
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
