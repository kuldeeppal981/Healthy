import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../data/exercise_library.dart';
import '../data/indian_foods.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/add_food_sheet.dart';
import 'allergy_screen.dart';
import 'badges_screen.dart';
import 'budget_plan_screen.dart';
import 'coach_screen.dart';
import 'exercise_library_screen.dart';
import 'health_connect_screen.dart';
import 'health_screen.dart';
import 'medical_report_screen.dart';
import 'missions_screen.dart';
import 'muscle_screen.dart';
import 'privacy_dashboard_screen.dart';
import 'reminders_screen.dart';
import 'report_screen.dart';
import 'scan_screen.dart';
import 'settings_screen.dart';
import 'social_screen.dart';
import 'steps_screen.dart';
import 'training_status_screen.dart';

class _Dest {
  final String title;
  final String hint;
  final IconData icon;
  final String keys;
  final void Function(BuildContext context, void Function(int) goto) open;
  const _Dest(this.title, this.hint, this.icon, this.keys, this.open);
}

void _push(BuildContext c, Widget w) =>
    Navigator.of(c).push(MaterialPageRoute<void>(builder: (_) => w));

final _destinations = <_Dest>[
  _Dest('Food diary', 'Meals and calories', Icons.menu_book_outlined, 'diary meals log calories food',
      (c, g) {
    Navigator.of(c).pop();
    g(1);
  }),
  _Dest('Workout', 'Plan and log sets', Icons.fitness_center, 'workout gym plan sets exercise',
      (c, g) {
    Navigator.of(c).pop();
    g(2);
  }),
  _Dest('Analytics', 'Charts and trends', Icons.bar_chart_rounded, 'analytics chart trend progress',
      (c, g) {
    Navigator.of(c).pop();
    g(3);
  }),
  _Dest('Scan a product', 'Barcode and allergy check', Icons.qr_code_scanner, 'scan barcode label allergy product',
      (c, g) => _push(c, const ScanScreen())),
  _Dest('AI coach', 'Ask anything about food and training', Icons.smart_toy_outlined, 'coach ai chat ask',
      (c, g) => _push(c, const CoachScreen())),
  _Dest('Training status', 'Last trained, weekly sets, recovery', Icons.insights_outlined,
      'training status recovery sets muscle last trained', (c, g) => _push(c, const TrainingStatusScreen())),
  _Dest('Muscle volume', 'Sets per muscle group', Icons.pie_chart_outline, 'muscle volume sets',
      (c, g) => _push(c, const MuscleScreen())),
  _Dest('Exercise library', 'Muscles, form, mistakes', Icons.menu_book_outlined, 'exercise library form technique',
      (c, g) => _push(c, const ExerciseLibraryScreen())),
  _Dest('Steps', 'Daily steps and goal', Icons.directions_walk, 'steps walk goal',
      (c, g) => _push(c, const StepsScreen())),
  _Dest('Budget diet plan', 'A week of meals in your budget', Icons.savings_outlined, 'budget diet plan meals rupee cheap',
      (c, g) => _push(c, const BudgetPlanScreen())),
  _Dest('Monthly report', 'Workouts, calories, PDF', Icons.insights_outlined, 'report monthly pdf summary',
      (c, g) => _push(c, const ReportScreen())),
  _Dest('Medical report', 'Scan a report, foods to limit', Icons.medical_information_outlined,
      'medical report blood test doctor avoid', (c, g) => _push(c, const MedicalReportScreen())),
  _Dest('Allergies', 'Set allergens and severity', Icons.shield_outlined, 'allergy allergies allergen safety',
      (c, g) => _push(c, const AllergyPage())),
  _Dest('Health conditions', 'Diabetes, BP, cholesterol, PCOS', Icons.monitor_heart_outlined,
      'health conditions diabetes bp cholesterol pcos', (c, g) => _push(c, const HealthScreen())),
  _Dest('Reminders', 'Meals, water, workouts', Icons.notifications_active_outlined,
      'reminder notification alarm remind', (c, g) => _push(c, const RemindersScreen())),
  _Dest('Missions and challenges', 'Weekly missions, your own goals', Icons.flag_outlined,
      'mission challenge weekly goal', (c, g) => _push(c, const MissionsScreen())),
  _Dest('Streaks and badges', 'Your streak and awards', Icons.emoji_events_outlined, 'streak badge award xp level',
      (c, g) => _push(c, const BadgesScreen())),
  _Dest('Friends and challenges', 'Feed and leaderboards', Icons.groups_outlined, 'friends social challenge feed leaderboard',
      (c, g) => _push(c, const SocialScreen())),
  _Dest('Health Connect', 'Smartwatch data', Icons.watch_outlined, 'health connect watch heart sleep',
      (c, g) => _push(c, const HealthConnectScreen())),
  _Dest('Privacy dashboard', 'Stored, shared, export data', Icons.privacy_tip_outlined,
      'privacy data export delete share permission', (c, g) => _push(c, const PrivacyDashboardScreen())),
  _Dest('Settings', 'Dark mode, text size, high contrast', Icons.settings_outlined,
      'settings theme dark text size contrast accessibility sound', (c, g) => _push(c, const SettingsScreen())),
];

/// Screens that need the online account are left out when it is not set up.
List<_Dest> get _dests => [
      for (final d in _destinations)
        if (cloudEnabled || (d.title != 'Friends and challenges' && d.title != 'AI coach')) d,
    ];

/// Search foods, exercises and app screens from one box.
class SearchScreen extends StatefulWidget {
  final void Function(int tab) onGoto;

  const SearchScreen({super.key, required this.onGoto});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _ctl = TextEditingController();
  String _q = '';

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  Widget _head(String t) => Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 6),
        child: Text(t, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
      );

  Widget _tile(IconData icon, String title, String sub, VoidCallback onTap) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      minVerticalPadding: 8,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.chipBg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: AppColors.primary, size: 22),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis),
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final q = _q.trim().toLowerCase();

    final foods = <Widget>[];
    final exercises = <Widget>[];
    final screens = <Widget>[];

    if (q.isEmpty) {
      for (final e in s.recentFoods(limit: 5)) {
        foods.add(_tile(Icons.history, e.name, '${e.kcal.round()} kcal  |  recent',
            () => showAddFoodSheet(context, initialQuery: e.name.split(' (').first)));
      }
      for (final d in _dests.take(6)) {
        screens.add(_tile(d.icon, d.title, d.hint, () => d.open(context, widget.onGoto)));
      }
    } else {
      final fl = indianFoods.where((f) => f.name.toLowerCase().contains(q)).take(8);
      for (final f in fl) {
        foods.add(_tile(Icons.restaurant, f.name, '${f.serving}  |  ${f.kcal.round()} kcal  |  ${f.protein.round()} g protein',
            () => showAddFoodSheet(context, initialQuery: f.name)));
      }
      final el = exerciseLibrary.where((e) =>
          e.name.toLowerCase().contains(q) ||
          e.group.toLowerCase().contains(q) ||
          e.primary.toLowerCase().contains(q));
      for (final e in el.take(8)) {
        exercises.add(_tile(Icons.fitness_center, e.name, '${e.primary}  |  ${e.equipment}',
            () => openExercise(context, e)));
      }
      final dl = _dests.where(
          (d) => d.title.toLowerCase().contains(q) || d.keys.contains(q));
      for (final d in dl.take(8)) {
        screens.add(_tile(d.icon, d.title, d.hint, () => d.open(context, widget.onGoto)));
      }
    }

    final empty = q.isNotEmpty && foods.isEmpty && exercises.isEmpty && screens.isEmpty;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: TextField(
          controller: _ctl,
          autofocus: true,
          onChanged: (v) => setState(() => _q = v),
          decoration: InputDecoration(
            hintText: 'Search food, exercise, settings',
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            filled: false,
            suffixIcon: _q.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear',
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      _ctl.clear();
                      setState(() => _q = '');
                    },
                  ),
          ),
        ),
      ),
      body: AppBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
          children: [
            if (empty)
              Padding(
                padding: const EdgeInsets.only(top: 40),
                child: Center(
                  child: Text('Nothing found for "$_q"',
                      style: TextStyle(color: AppColors.muted)),
                ),
              ),
            if (foods.isNotEmpty) ...[_head(q.isEmpty ? 'Recent foods' : 'Foods'), ...foods],
            if (exercises.isNotEmpty) ...[_head('Exercises'), ...exercises],
            if (screens.isNotEmpty) ...[_head(q.isEmpty ? 'Go to' : 'Screens'), ...screens],
          ],
        ),
      ),
    );
  }
}
