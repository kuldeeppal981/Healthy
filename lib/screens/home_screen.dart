import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../services/step_service.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/add_food_sheet.dart';
import '../widgets/ring.dart';
import '../widgets/voice_review.dart';
import '../widgets/weight_dialog.dart';
import 'coach_screen.dart';
import 'diary_screen.dart';
import 'health_connect_screen.dart';
import 'scan_screen.dart';
import 'social_screen.dart';
import 'steps_screen.dart';
import 'streak_card.dart';
import 'workout_data.dart';

class HomeScreen extends StatelessWidget {
  final void Function(int tab) onGoto;

  const HomeScreen({super.key, required this.onGoto});

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  static const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  String _greeting(int hour) {
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  static String _num(num n) {
    final s = n.round().toString();
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
      b.write(s[i]);
    }
    return b.toString();
  }

  void _open(BuildContext context, Widget page) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final now = DateTime.now();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      children: [
        _header(context, now),
        const SizedBox(height: 18),
        _nutritionCard(context, s),
        const SizedBox(height: 22),
        Row(
          children: [
            const Expanded(
              child: Text('Quick actions',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            ),
            TextButton(
              onPressed: () => _open(context, const DiaryScreen()),
              style: TextButton.styleFrom(
                minimumSize: const Size(0, 36),
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Track your day',
                      style: TextStyle(
                          color: AppColors.link, fontWeight: FontWeight.w700)),
                  SizedBox(width: 4),
                  Icon(Icons.arrow_forward, size: 18, color: AppColors.link),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _quick(Icons.qr_code_scanner, 'Scan', () => _open(context, const ScanScreen())),
            const SizedBox(width: 10),
            _quick(Icons.mic, 'Voice', () => logByVoice(context)),
            const SizedBox(width: 10),
            _quick(Icons.water_drop, 'Water', () {
              s.addWater(1);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Water: ${s.waterToday} of ${s.waterTarget} glasses')),
              );
            }),
            const SizedBox(width: 10),
            _quick(Icons.monitor_weight_outlined, 'Weight', () => showLogWeight(context, s)),
          ],
        ),
        const SizedBox(height: 16),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _stepsCard(context, s)),
              const SizedBox(width: 12),
              Expanded(child: _waterCard(s)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _workoutCard(context, s, now),
        const SizedBox(height: 16),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _insightCard(context, s)),
              const SizedBox(width: 12),
              const Expanded(child: StreakCard()),
            ],
          ),
        ),
        if (cloudEnabled) ...[
          const SizedBox(height: 16),
          const SocialCard(),
        ],
      ],
    );
  }

  Widget _header(BuildContext context, DateTime now) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_days[now.weekday - 1]}, ${now.day} ${_months[now.month - 1]}',
                style: const TextStyle(color: AppColors.muted, fontSize: 15),
              ),
              const SizedBox(height: 2),
              Text('${_greeting(now.hour)} \u{1F44B}',
                  style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
              const Text("Let's make today count.",
                  style: TextStyle(color: AppColors.muted, fontSize: 16)),
            ],
          ),
        ),
        InkWell(
          onTap: () => onGoto(3),
          borderRadius: BorderRadius.circular(40),
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.border, width: 2),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.10),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(Icons.person, color: AppColors.primaryDeep, size: 30),
          ),
        ),
      ],
    );
  }

  Widget _pill(String text, Color bg, Color fg, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: fg),
            const SizedBox(width: 5),
          ],
          Text(text,
              style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _nutritionCard(BuildContext context, AppState s) {
    final remaining = (s.kcalTarget - s.kcalToday).round();
    final over = remaining < 0;
    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.restaurant, color: AppColors.primary, size: 24),
              const SizedBox(width: 10),
              const Expanded(
                child: Text('Daily nutrition',
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
              ),
              over
                  ? _pill('Over goal', AppColors.warnBg, AppColors.warnInk,
                      icon: Icons.warning_amber_rounded)
                  : _pill('On track', AppColors.safeBg, AppColors.safe,
                      icon: Icons.check_circle),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Ring(
                progress: s.kcalToday / s.kcalTarget,
                color: AppColors.primary,
                track: AppColors.track,
                size: 128,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_num(s.kcalToday),
                        style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800)),
                    const Text('kcal eaten',
                        style: TextStyle(fontSize: 13, color: AppColors.muted)),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Container(width: 1, height: 96, color: AppColors.border),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(_num(s.kcalTarget),
                          style: const TextStyle(
                              fontSize: 38, fontWeight: FontWeight.w800, height: 1.1)),
                    ),
                    const Text('Daily calorie goal',
                        style: TextStyle(fontSize: 15, color: AppColors.muted)),
                    const SizedBox(height: 10),
                    _pill(
                      over ? '${_num(-remaining)} over' : '${_num(remaining)} left',
                      over ? AppColors.warnBg : AppColors.safeBg,
                      over ? AppColors.warnInk : AppColors.safe,
                      icon: Icons.local_fire_department,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          IntrinsicHeight(
            child: Row(
              children: [
                _macro(Icons.fitness_center, 'Protein', s.proteinToday, s.proteinTarget,
                    AppColors.primary),
                const VerticalDivider(width: 18, color: AppColors.border),
                _macro(Icons.grass, 'Carbs', s.carbsToday, s.carbsTarget,
                    const Color(0xFFF0A020)),
                const VerticalDivider(width: 18, color: AppColors.border),
                _macro(Icons.water_drop, 'Fat', s.fatToday, s.fatTarget,
                    const Color(0xFF22A66A)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          GradientButton(
            label: 'Log food',
            icon: Icons.add,
            onPressed: () => showAddFoodSheet(context),
          ),
        ],
      ),
    );
  }

  Widget _macro(IconData icon, String label, double value, int target, Color color) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text('${value.round()} / $target g',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, color: AppColors.muted)),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: (value / target).clamp(0.0, 1.0).toDouble(),
              minHeight: 6,
              color: color,
              backgroundColor: AppColors.track,
            ),
          ),
        ],
      ),
    );
  }

  Widget _quick(IconData icon, String label, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          height: 88,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.65),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: AppColors.primary, size: 30),
              const SizedBox(height: 8),
              Text(label,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stepsCard(BuildContext context, AppState s) {
    final svc = StepService.instance;
    return ListenableBuilder(
      listenable: svc,
      builder: (context, _) {
        final pct = (svc.steps / svc.goal).clamp(0.0, 1.0).toDouble();
        return InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () {
            if (svc.granted) {
              _open(context, const StepsScreen());
            } else {
              svc.requestPermission();
            }
          },
          child: AppCard(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Text('\u{1F463}', style: TextStyle(fontSize: 22)),
                    SizedBox(width: 8),
                    Text('Steps',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                  ],
                ),
                const SizedBox(height: 10),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text('${_num(svc.steps)} / ${_num(svc.goal)}',
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: pct,
                    minHeight: 8,
                    color: AppColors.primary,
                    backgroundColor: AppColors.track,
                  ),
                ),
                const Spacer(),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () => _open(context, const HealthConnectScreen()),
                  child: const Row(
                    children: [
                      Icon(Icons.favorite, size: 16, color: AppColors.primary),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                            svc.granted ? 'Sync with Health Connect' : 'Tap to allow step counting',
                            maxLines: 2,
                            style: TextStyle(fontSize: 12, color: AppColors.muted)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _waterCard(AppState s) {
    const glassMl = 250;
    final shown = s.waterTarget.clamp(1, 10);
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.water_drop, color: AppColors.blue, size: 22),
              const SizedBox(width: 6),
              const Text('Water',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              const Spacer(),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.chipBg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('${s.waterToday}/${s.waterTarget}',
                      maxLines: 1,
                      style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text('${_num(s.waterToday * glassMl)} ml',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
          Text('Goal: ${_num(s.waterTarget * glassMl)} ml',
              style: const TextStyle(fontSize: 12, color: AppColors.muted)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 3,
            runSpacing: 3,
            children: [
              for (var i = 0; i < shown; i++)
                Icon(Icons.local_drink,
                    size: 17,
                    color: i < s.waterToday ? AppColors.blue : AppColors.track),
            ],
          ),
          const Spacer(),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => s.addWater(1),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add water'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 38),
                padding: const EdgeInsets.symmetric(horizontal: 6),
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary, width: 1.2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _workoutCard(BuildContext context, AppState s, DateTime now) {
    final plan = s.planFor(now.weekday);
    final mins = estimateMinutes(plan);
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 104,
            height: 120,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.primaryLight, AppColors.primaryDeep],
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(Icons.fitness_center, color: Colors.white, size: 48),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text("Today's workout",
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.chipBg,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(plan.title,
                          style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  plan.rest
                      ? 'Rest day'
                      : '${plan.exercises.length} exercises • $mins min',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
                Text(plan.rest ? 'Recover, stretch, walk' : 'Your scheduled workout',
                    style: const TextStyle(color: AppColors.muted, fontSize: 13)),
                const SizedBox(height: 10),
                GradientButton(
                  label: plan.rest ? 'View plan' : 'Start workout',
                  icon: plan.rest ? null : Icons.play_arrow,
                  height: 44,
                  onPressed: () => onGoto(2),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _insightCard(BuildContext context, AppState s) {
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.auto_awesome, color: AppColors.primary, size: 20),
              SizedBox(width: 6),
              Expanded(
                child: Text('AI daily insight',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(dailyTip(s),
              style: const TextStyle(fontSize: 13, color: AppColors.muted, height: 1.35)),
          const Spacer(),
          const SizedBox(height: 8),
          InkWell(
            onTap: cloudEnabled ? () => _open(context, const CoachScreen()) : null,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    cloudEnabled ? 'Ask the coach' : 'Personalized tips',
                    style: const TextStyle(
                        color: AppColors.link, fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                ),
                if (cloudEnabled)
                  const Icon(Icons.arrow_forward, size: 16, color: AppColors.link),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
