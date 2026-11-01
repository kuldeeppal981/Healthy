import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme.dart';
import 'allergy_screen.dart';
import 'home_screen.dart';
import 'onboarding_screen.dart';
import 'profile_screen.dart';
import 'scan_screen.dart';
import 'workout_screen.dart';

/// Bottom navigation: Home, Allergy | Scan | Workout, Profile.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  void _goto(int i) => setState(() => _index = i);

  Widget _navItem(int i, IconData icon, String label) {
    final selected = _index == i;
    final color = selected ? AppColors.link : AppColors.muted;
    return Expanded(
      child: InkWell(
        onTap: () => _goto(i),
        child: SizedBox(
          height: 60,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: color,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
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
    if (context.watch<AppState>().needsOnboarding) {
      return const OnboardingScreen();
    }

    final pages = <Widget>[
      HomeScreen(onGoto: _goto),
      const AllergyScreen(),
      const WorkoutScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      body: SafeArea(child: IndexedStack(index: _index, children: pages)),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Scan product',
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        shape: const CircleBorder(),
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const ScanScreen()),
        ),
        child: const Icon(Icons.qr_code_scanner, size: 28),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        color: AppColors.card,
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        padding: EdgeInsets.zero,
        height: 64,
        child: Row(
          children: [
            _navItem(0, Icons.home_outlined, 'Home'),
            _navItem(1, Icons.shield_outlined, 'Allergy'),
            const SizedBox(width: 72),
            _navItem(2, Icons.fitness_center, 'Workout'),
            _navItem(3, Icons.person_outline, 'Profile'),
          ],
        ),
      ),
    );
  }
}
