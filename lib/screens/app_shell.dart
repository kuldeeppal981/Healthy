import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme.dart';
import 'allergy_screen.dart';
import 'diary_screen.dart';
import 'auth_screen.dart';
import 'home_screen.dart';
import 'onboarding_screen.dart';
import 'profile_screen.dart';
import 'workout_screen.dart';

/// Bottom navigation: Home, Allergy | Scan | Workout, Profile.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;
  StreamSubscription<void>? _recoverySub;

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
    });
  }

  @override
  void dispose() {
    _recoverySub?.cancel();
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
                  child: Text(error!, style: const TextStyle(color: AppColors.danger)),
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
      child: InkWell(
        onTap: () => _goto(i),
        child: SizedBox(
          height: 64,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(selected ? activeIcon : icon, color: color, size: 26),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: color,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    if (app.needsAuth) return const AuthScreen();
    if (app.needsOnboarding) return const OnboardingScreen();

    final pages = <Widget>[
      HomeScreen(onGoto: _goto),
      const DiaryScreen(),
      const WorkoutScreen(),
      const AllergyScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: AppBackground(
        child: SafeArea(child: IndexedStack(index: _index, children: pages)),
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
              _navItem(2, Icons.fitness_center, Icons.fitness_center, 'Workout'),
              _navItem(3, Icons.shield_outlined, Icons.shield, 'Allergy'),
              _navItem(4, Icons.person_outline, Icons.person, 'Profile'),
            ],
          ),
        ),
      ),
    );
  }
}
