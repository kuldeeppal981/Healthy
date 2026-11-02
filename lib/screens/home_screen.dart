import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../services/avatar_service.dart';
import '../services/step_service.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/add_food_sheet.dart';
import '../widgets/food_art.dart';
import '../widgets/ring.dart';
import '../widgets/ui_kit.dart';
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
        _header(context, now, s.displayName),
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
              onPressed: () => onGoto(1),
              style: TextButton.styleFrom(
                minimumSize: const Size(0, 36),
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: Row(
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
              Haptic.tap();
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
        _proteinTip(s, now),
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

  Widget _header(BuildContext context, DateTime now, String? name) {
    final first = (name ?? '').trim().split(' ').first;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_greeting(now.hour)}  \u00B7  ${_days[now.weekday - 1]}, ${now.day} ${_months[now.month - 1]}',
                style: const TextStyle(color: AppColors.muted, fontSize: 13),
              ),
              const SizedBox(height: 2),
              Text(first.isEmpty ? 'Welcome' : first,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
            ],
          ),
        ),
        InkWell(
          onTap: () => onGoto(4),
          borderRadius: BorderRadius.circular(40),
          child: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.card,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.border, width: 1.5),
            ),
            padding: const EdgeInsets.all(3),
            child: const AvatarCircle(size: 46),
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
    final pct = s.kcalTarget <= 0 ? 0 : (s.kcalToday / s.kcalTarget * 100).round();
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(over ? 'Calories over' : 'Calories left',
                        style: const TextStyle(fontSize: 13, color: AppColors.muted)),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(_num(over ? -remaining : remaining),
                          style: TextStyle(
                              fontSize: 42,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -1.5,
                              color: over ? AppColors.warnInk : AppColors.ink)),
                    ),
                    Text('of ${_num(s.kcalTarget)} kcal goal',
                        style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                  ],
                ),
              ),
              Ring(
                progress: s.kcalTarget <= 0 ? 0 : s.kcalToday / s.kcalTarget,
                color: over ? AppColors.ring : AppColors.primary,
                track: AppColors.track,
                size: 104,
                child: Text('$pct%',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _macroChip('Protein', s.proteinToday, s.proteinTarget),
              const SizedBox(width: 8),
              _macroChip('Carbs', s.carbsToday, s.carbsTarget),
              const SizedBox(width: 8),
              _macroChip('Fat', s.fatToday, s.fatTarget),
            ],
          ),
        ],
      ),
    );
  }

  Widget _macroChip(String label, double value, int target) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.chipBg.withOpacity(0.6),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 11, color: AppColors.muted)),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text.rich(
                TextSpan(children: [
                  TextSpan(
                      text: '${value.round()}',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                  TextSpan(
                      text: ' / $target g',
                      style: const TextStyle(fontSize: 11, color: AppColors.muted)),
                ]),
                maxLines: 1,
              ),
            ),
          ],
        ),
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
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.primaryLight, AppColors.primaryDeep],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.28),
                      blurRadius: 12,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 25),
              ),
              const SizedBox(height: 8),
              Text(label,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }

  /// Amber tip card with a drawn apple, only when protein is low in the afternoon.
  Widget _proteinTip(AppState s, DateTime now) {
    if (now.hour < 12 || s.proteinTarget <= 0 || s.proteinToday >= s.proteinTarget * 0.5) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFFFFF4D6), Color(0xFFFFE7B8)]),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          children: [
            const FoodArt(FoodKind.apple, size: 44),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Protein is a bit low',
                      style: TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF7A4A06))),
                  SizedBox(height: 2),
                  Text('Try paneer, sprouts, dal or a boiled egg',
                      style: TextStyle(fontSize: 12, color: Color(0xFF9A6A1F))),
                ],
              ),
            ),
          ],
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
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  right: -14,
                  top: -14,
                  child: IgnorePointer(
                    child: AppImage('assets/images/shoe.png', width: 76, fit: BoxFit.contain),
                  ),
                ),
                Column(
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
                  child: Row(
                    children: [
                      Icon(Icons.favorite, size: 16, color: AppColors.primary),
                      const SizedBox(width: 6),
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
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            right: -12,
            top: 22,
            child: IgnorePointer(
              child: AppImage('assets/images/glass.png', width: 62, fit: BoxFit.contain),
            ),
          ),
          Column(
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
                      style: TextStyle(
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
              onPressed: () {
                Haptic.tap();
                s.addWater(1);
              },
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add water'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 38),
                padding: const EdgeInsets.symmetric(horizontal: 6),
                foregroundColor: AppColors.primary,
                side: BorderSide(color: AppColors.primary, width: 1.2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
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
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: AppImage('assets/images/dumbbell.jpg',
                width: 104, height: 120, fit: BoxFit.cover),
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
                          style: TextStyle(
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
          Row(
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
                    style: TextStyle(
                        color: AppColors.link, fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                ),
                if (cloudEnabled)
                  Icon(Icons.arrow_forward, size: 16, color: AppColors.link),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
