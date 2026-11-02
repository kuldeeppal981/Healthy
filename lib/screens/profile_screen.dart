import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../data/exercise_library.dart';
import '../services/badges.dart' as b;
import '../services/nutrition_calc.dart';
import '../services/social_service.dart';
import '../services/theme_service.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../services/avatar_service.dart';
import '../widgets/edit_identity.dart';
import '../widgets/sparkline.dart';
import 'badges_screen.dart';
import 'coach_screen.dart';
import 'exercise_library_screen.dart';
import 'health_connect_screen.dart';
import 'health_screen.dart';
import 'onboarding_screen.dart';
import 'reminders_screen.dart';
import 'report_screen.dart';
import 'settings_screen.dart';
import 'social_screen.dart';

/// Account, body stats and the menu for everything else.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  void _open(BuildContext context, Widget page) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final p = s.profile;
    final a = b.Achievements.of(s);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      children: [
        Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Profile',
                      style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800)),
                  Text('Manage your account & preferences',
                      style: TextStyle(color: AppColors.muted, fontSize: 15)),
                ],
              ),
            ),
            IconButton.filledTonal(
              tooltip: 'Settings',
              onPressed: () => _open(context, const SettingsScreen()),
              icon: const Icon(Icons.settings_outlined, color: AppColors.primary),
              style: IconButton.styleFrom(
                backgroundColor: AppColors.chipBg,
                minimumSize: const Size(48, 48),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _headerCard(context, s, p != null),
        const SizedBox(height: 14),
        if (p == null)
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                    'Set up your profile to get calorie and protein targets worked out for you.'),
                const SizedBox(height: 12),
                GradientButton(
                  label: 'Set up profile',
                  onPressed: () => _open(context, const OnboardingScreen(editing: true)),
                ),
              ],
            ),
          )
        else
          _bodyCard(context, s),
        const SizedBox(height: 14),
        ListenableBuilder(
          listenable: ThemeService.instance,
          builder: (context, _) => AppCard(
            radius: 22,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.dark_mode_outlined, color: AppColors.primary),
                    SizedBox(width: 12),
                    Text('Appearance',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<ThemeMode>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(value: ThemeMode.system, label: Text('Auto')),
                      ButtonSegment(value: ThemeMode.light, label: Text('Light')),
                      ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
                    ],
                    selected: {ThemeService.instance.mode},
                    onSelectionChanged: (v) => ThemeService.instance.set(v.first),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        MenuCard(rows: [
          MenuRow(
            icon: Icons.monitor_heart_outlined,
            title: 'Health conditions',
            subtitle: s.conditions.isEmpty
                ? 'Diabetes, BP, cholesterol, PCOS'
                : '${s.conditions.length} switched on',
            onTap: () => _open(context, const HealthScreen()),
          ),
          MenuRow(
            icon: Icons.notifications_active_outlined,
            title: 'Reminders',
            subtitle: 'Meals, water and workouts',
            onTap: () => _open(context, const RemindersScreen()),
          ),
        ]),
        const SizedBox(height: 14),
        MenuCard(rows: [
          MenuRow(
            icon: Icons.emoji_events_outlined,
            title: 'Streaks and badges',
            subtitle:
                '${a.currentStreak} day food streak  |  ${a.earnedCount} of ${a.badges.length} badges',
            onTap: () => _open(context, const BadgesScreen()),
          ),
          MenuRow(
            icon: Icons.insights_outlined,
            title: 'Monthly report',
            subtitle: 'Workouts, calories, protein, records, PDF',
            onTap: () => _open(context, const ReportScreen()),
          ),
          MenuRow(
            icon: Icons.menu_book_outlined,
            title: 'Exercise library',
            subtitle: '${exerciseLibrary.length} exercises: muscles, form, mistakes',
            onTap: () => _open(context, const ExerciseLibraryScreen()),
          ),
          MenuRow(
            icon: Icons.watch_outlined,
            title: 'Smartwatch and Health Connect',
            subtitle: 'Steps, heart rate, sleep and workouts',
            onTap: () => _open(context, const HealthConnectScreen()),
          ),
          if (cloudEnabled)
            MenuRow(
              icon: Icons.groups_outlined,
              title: 'Friends and challenges',
              subtitle: 'Feed, leaderboards, 30-day challenge',
              onTap: () => _open(context, const SocialScreen()),
              trailing: ListenableBuilder(
                listenable: SocialService.instance,
                builder: (context, _) {
                  final n = SocialService.instance.unreadCheers;
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (n > 0)
                        Badge(label: Text('$n'), child: const SizedBox(width: 8, height: 8)),
                      const SizedBox(width: 8),
                      const Icon(Icons.chevron_right, color: AppColors.muted),
                    ],
                  );
                },
              ),
            ),
          if (cloudEnabled)
            MenuRow(
              icon: Icons.auto_awesome,
              title: 'Ask the coach',
              subtitle: 'Food, protein and workout questions',
              onTap: () => _open(context, const CoachScreen()),
            ),
        ]),
      ],
    );
  }

  Widget _headerCard(BuildContext context, AppState s, bool hasProfile) {
    final signedIn = cloudEnabled && s.signedIn;
    final name = s.displayName ?? '';
    final hasName = name.isNotEmpty;
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primaryLight, AppColors.primaryDeep],
        ),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.28),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: Stack(
          children: [
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              child: Opacity(
                opacity: 0.5,
                child: Image.asset('assets/images/hero.png', fit: BoxFit.fitHeight),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
        children: [
          InkWell(
            onTap: () => showEditIdentity(context, s),
            borderRadius: BorderRadius.circular(60),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                const AvatarCircle(size: 78),
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(Icons.edit, size: 15, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  onTap: () => showEditIdentity(context, s),
                  child: Text(
                    hasName ? name : 'Add your name',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        decoration: hasName ? null : TextDecoration.underline,
                        decorationColor: Colors.white70),
                  ),
                ),
                if (signedIn)
                  Text(
                    s.accountEmail ?? 'Signed in',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.verified_user, size: 16, color: Colors.white70),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        !signedIn
                            ? 'Data is only on this phone'
                            : s.syncing
                                ? 'Syncing...'
                                : (s.syncError ?? 'Backed up to your account'),
                        maxLines: 2,
                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ),
                  ],
                ),
                if (cloudEnabled) ...[
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: signedIn ? s.signOut : s.leaveGuest,
                    icon: Icon(signedIn ? Icons.logout : Icons.login, size: 18),
                    label: Text(signedIn ? 'Sign out' : 'Sign in'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 40),
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white70, width: 1.4),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
            ),
          ],
        ),
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
      radius: 24,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: const BoxDecoration(
                    color: AppColors.chipBg, shape: BoxShape.circle),
                child: const Icon(Icons.monitor_weight_outlined, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Current weight',
                        style: TextStyle(fontSize: 13, color: AppColors.muted)),
                    Text('${p.weightKg.toStringAsFixed(1)} kg',
                        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
                    Text(
                      change == 0
                          ? 'No change yet'
                          : '${change > 0 ? '+' : ''}${change.toStringAsFixed(1)} kg since start',
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              Container(width: 1, height: 64, color: AppColors.border),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('BMI',
                      style: TextStyle(fontSize: 13, color: AppColors.muted)),
                  Text(bmi.toStringAsFixed(1),
                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.safeBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(bmiLabel(bmi),
                        style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.safe,
                            fontWeight: FontWeight.w700)),
                  ),
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
            style: const TextStyle(fontSize: 14, color: AppColors.muted),
          ),
          const SizedBox(height: 14),
          GradientButton(
            label: 'Edit profile',
            icon: Icons.edit,
            onPressed: () => _open(
              context,
              OnboardingScreen(initial: p, editing: true),
            ),
          ),
        ],
      ),
    );
  }
}
