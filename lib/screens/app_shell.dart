import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../widgets/checkin_popup.dart';
import '../widgets/offline_banner.dart';
import '../widgets/quick_add_sheet.dart';
import '../theme.dart';
import '../widgets/ui_kit.dart';
import 'analytics_screen.dart';
import 'diary_screen.dart';
import 'auth_screen.dart';
import 'home_screen.dart';
import 'onboarding_screen.dart';
import 'form_check_screen.dart';
import 'tour_screen.dart';
import 'streak_card.dart';
import 'workout_screen.dart';
import '../services/l10n.dart';

/// Bottom navigation: Home, Diary, Workout, Analytics, Profile.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;
  bool _tourChecked = false;
  StreamSubscription<void>? _recoverySub;
  StreamSubscription<void>? _checkInSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _recoverySub = context
          .read<AppState>()
          .cloud
          ?.passwordRecoveryEvents
          .listen((_) => _askNewPassword());
      streakStartupChecks(context);
      unawaited(FormCheckRecovery.check(context));
      _checkInSub = context.read<AppState>().autoCheckInEvents.listen((_) {
        // Wait a moment so a closing sheet (add food) is gone first.
        Future<void>.delayed(const Duration(milliseconds: 700), () {
          if (!mounted) return;
          showAutoCheckInPopup(context, context.read<AppState>());
        });
      });
    });
  }

  @override
  void dispose() {
    _recoverySub?.cancel();
    _checkInSub?.cancel();
    super.dispose();
  }

  Future<void> _askNewPassword() async {
    if (!mounted) return;
    final cloud = context.read<AppState>().cloud;
    final ctl = TextEditingController();
    String? error;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('Set a new password'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: ctl,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'New password (6+ characters)'),
              ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(error!, style: TextStyle(color: AppColors.danger)),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Later'),
            ),
            TextButton(
              onPressed: () async {
                if (ctl.text.length < 6) {
                  setD(() => error = 'Use at least 6 characters.');
                  return;
                }
                final e = await cloud?.updatePassword(ctl.text);
                if (e != null) {
                  setD(() => error = e);
                } else if (ctx.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Password changed')),
                  );
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    ctl.dispose();
  }

  void _goto(int i) => setState(() => _index = i);

  Widget _navItem(int i, IconData icon, IconData activeIcon, String label) {
    final selected = _index == i;
    final color = selected ? AppColors.link : AppColors.muted;
    return Expanded(
      child: Semantics(
       button: true,
       selected: selected,
       label: tr(label),
       excludeSemantics: true,
       child: InkWell(
        onTap: () => _goto(i),
        child: SizedBox(
          height: 64,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(selected ? activeIcon : icon, color: color, size: 26),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  tr(label),
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 12,
                    color: color,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 3),
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                height: 3,
                width: selected ? 28 : 0,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ],
          ),
        ),
       ),
      ),
    );
  }

  /// The big "+" in the middle: log food, water, workout, weight... from anywhere.
  Widget _addButton() {
    return SizedBox(
      width: 64,
      height: 64,
      child: Center(
        child: Semantics(
          button: true,
          label: 'Quick add',
          child: InkWell(
            borderRadius: BorderRadius.circular(28),
            onTap: () {
              Haptic.tap();
              showQuickAdd(context, context.read<AppState>(), onGoto: _goto);
            },
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.primaryLight, AppColors.primaryDeep],
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(Icons.add, color: Colors.white, size: 30),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    if (app.needsAuth) return const AuthScreen();
    if (app.needsOnboarding) return const OnboardingScreen();
    if (!_tourChecked && app.prefs['tourDone'] != true) {
      _tourChecked = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.of(context).push(MaterialPageRoute<void>(
            fullscreenDialog: true, builder: (_) => const TourScreen()));
      });
    }

    final pages = <Widget>[
      HomeScreen(onGoto: _goto),
      const DiaryScreen(),
      const WorkoutScreen(),
      const AnalyticsScreen(),
    ];

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: AppBackground(
        child: SafeArea(
          child: Column(
            children: [
              const OfflineBanner(),
              Expanded(child: IndexedStack(index: _index, children: pages)),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: SafeArea(
          top: false,
          child: Row(
            children: [
              _navItem(0, Icons.home_outlined, Icons.home_rounded, 'Home'),
              _navItem(1, Icons.menu_book_outlined, Icons.menu_book, 'Diary'),
              _addButton(),
              _navItem(2, Icons.fitness_center, Icons.fitness_center, 'Workout'),
              _navItem(3, Icons.bar_chart_outlined, Icons.bar_chart_rounded, 'Analytics'),
            ],
          ),
        ),
      ),
    );
  }
}
