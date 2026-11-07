import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../services/plan_service.dart';
import '../services/weekly_review.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/ai_wait.dart';

/// Weekly AI diet review. Free: once a week. Pro: make it again any time.
class WeeklyReviewScreen extends StatefulWidget {
  const WeeklyReviewScreen({super.key});

  @override
  State<WeeklyReviewScreen> createState() => _WeeklyReviewScreenState();
}

class _WeeklyReviewScreenState extends State<WeeklyReviewScreen> {
  bool _busy = false;
  String? _error;
  bool _pro = false;

  @override
  void initState() {
    super.initState();
    if (cloudEnabled) {
      PlanService.load().then((p) {
        if (mounted) setState(() => _pro = p.pro);
      });
    }
  }

  /// Monday of this week, as yyyy-mm-dd. Free users get one review per week.
  String get _weekKey {
    final n = DateTime.now();
    final d = DateTime(n.year, n.month, n.day).subtract(Duration(days: n.weekday - 1));
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  WeeklyReviewData? _saved(AppState s) {
    final w = s.prefs['weeklyReview'];
    if (w is Map && w['week'] == _weekKey) return WeeklyReviewData.fromJson(w['data']);
    return null;
  }

  Future<void> _make() async {
    final s = context.read<AppState>();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final w = await WeeklyReviewService.make(s);
      s.savePrefs({
        ...s.prefs,
        'weeklyReview': {'week': _weekKey, 'data': w.toJson()},
      });
    } on WeeklyException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final stats = WeekStats.of(s);
    final saved = _saved(s);
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(backgroundColor: Colors.transparent, title: const Text('Weekly review')),
      body: AppBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            Text('LAST 7 DAYS',
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.6, color: AppColors.muted)),
            const SizedBox(height: 8),
            _numbers(stats, s),
            const SizedBox(height: 14),
            if (saved != null) ..._review(saved),
            if (_busy) const AiWaitCard(doing: 'Writing your review', expectedSeconds: 12),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_error!, style: TextStyle(color: AppColors.danger)),
              ),
            const SizedBox(height: 12),
            if (!cloudEnabled || !s.signedIn)
              Text('Sign in to get your AI review.', style: TextStyle(color: AppColors.muted))
            else if (saved == null)
              GradientButton(
                label: 'Make my weekly review',
                icon: Icons.auto_awesome,
                onPressed: _busy ? null : _make,
              )
            else if (_pro)
              OutlinedButton.icon(
                onPressed: _busy ? null : _make,
                icon: const Icon(Icons.refresh),
                label: const Text('Make it again'),
              )
            else
              Text('You get one free review each week. Pro can make it again any time.',
                  style: TextStyle(fontSize: 12, color: AppColors.muted)),
            const SizedBox(height: 14),
            Text(
                'General guidance only, not medical advice. Written by AI from your own food log, so it is only as good as what you logged.',
                style: TextStyle(fontSize: 11, color: AppColors.muted, height: 1.4)),
          ],
        ),
      ),
    );
  }

  Widget _numbers(WeekStats st, AppState s) {
    final top = [s.kcalTarget * 1.2, ...st.perDay].reduce((a, b) => a > b ? a : b);
    return AppCard(
      radius: 22,
      child: Column(
        children: [
          Row(
            children: [
              _n('${st.daysLogged}/7', 'Days logged'),
              _n('${st.avgKcal.round()}', 'Avg kcal'),
              _n('${st.avgProtein.round()} g', 'Avg protein'),
              _n('${st.goalDays}', 'In goal'),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 60,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < st.perDay.length; i++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Container(
                        height: top <= 0 ? 0 : (st.perDay[i] / top * 60).clamp(0.0, 60.0),
                        decoration: BoxDecoration(
                          color: i == st.perDay.length - 1 ? AppColors.primary : AppColors.primaryLight,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _n(String v, String l) => Expanded(
        child: Column(
          children: [
            Text(v, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            Text(l, style: TextStyle(fontSize: 10, color: AppColors.muted)),
          ],
        ),
      );

  List<Widget> _review(WeeklyReviewData w) {
    Widget box(String title, List<String> items, Color bg, Color ink) {
      if (items.isEmpty) return const SizedBox.shrink();
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(fontWeight: FontWeight.w800, color: ink)),
            const SizedBox(height: 4),
            for (final t in items)
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(t, style: TextStyle(fontSize: 13, height: 1.35, color: ink)),
              ),
          ],
        ),
      );
    }

    return [
      if (w.headline.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(w.headline, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        ),
      box('Went well', w.wentWell, AppColors.chipBg, AppColors.chipInk),
      box('To improve', w.improve, AppColors.warnBg, AppColors.warnInk),
      AppCard(
        radius: 22,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Next week: 3 small steps',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            for (var i = 0; i < w.steps.length; i++)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('${i + 1}. ${w.steps[i]}', style: const TextStyle(fontSize: 14, height: 1.4)),
              ),
          ],
        ),
      ),
    ];
  }
}
