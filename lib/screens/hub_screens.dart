import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/add_food_sheet.dart';
import '../widgets/todays_plan_card.dart';
import 'badges_screen.dart';
import 'allergy_screen.dart';
import 'budget_plan_screen.dart';
import 'exercise_library_screen.dart';
import 'health_connect_screen.dart';
import 'health_screen.dart';
import 'medical_report_screen.dart';
import 'missions_screen.dart';
import 'muscle_screen.dart';
import 'privacy_dashboard_screen.dart';
import 'reminders_screen.dart';
import 'report_screen.dart';
import 'social_screen.dart';
import 'streak_card.dart';
import 'training_status_screen.dart';
import 'workout_data.dart';

/// One tab of a hub: a label and the list of widgets inside it.
class HubTab {
  final String label;
  final List<Widget> Function(BuildContext context) build;
  const HubTab(this.label, this.build);
}

/// A shortcut page opened from "Explore your fitness": a title and 2-3 tabs.
class HubScreen extends StatelessWidget {
  final String title;
  final List<HubTab> tabs;

  const HubScreen({super.key, required this.title, required this.tabs});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          title: Text(title),
          bottom: TabBar(
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.muted,
            indicatorColor: AppColors.primary,
            tabs: [for (final t in tabs) Tab(text: t.label)],
          ),
        ),
        body: AppBackground(
          child: TabBarView(
            children: [
              for (final t in tabs)
                ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                  children: t.build(context),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

void _open(BuildContext context, Widget page) =>
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));

MenuRow _row(BuildContext context, IconData icon, String title, String sub, Widget page) =>
    MenuRow(icon: icon, title: title, subtitle: sub, onTap: () => _open(context, page));

// ---- Nutrition ----

class _NutritionSummary extends StatelessWidget {
  final int days;
  const _NutritionSummary({required this.days});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final today = DateTime.now();
    final list = [
      for (var i = days - 1; i >= 0; i--) DateTime(today.year, today.month, today.day - i),
    ];
    final kcal = <double>[];
    double p = 0, c = 0, f = 0;
    var logged = 0;
    for (final d in list) {
      final es = s.entriesOn(d);
      final k = es.fold<double>(0, (a, e) => a + e.kcal);
      kcal.add(k);
      if (es.isNotEmpty) {
        logged++;
        p += es.fold<double>(0, (a, e) => a + e.protein);
        c += es.fold<double>(0, (a, e) => a + e.carbs);
        f += es.fold<double>(0, (a, e) => a + e.fat);
      }
    }
    final n = logged == 0 ? 1 : logged;
    final maxK = kcal.fold<double>(s.kcalTarget.toDouble(), (a, b) => b > a ? b : a);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(days == 1 ? 'Today' : 'Average per day logged ($logged of $days days)',
              style: TextStyle(color: AppColors.muted, fontSize: 13)),
          const SizedBox(height: 4),
          Text('${(kcal.fold<double>(0, (a, b) => a + b) / n).round()} kcal',
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(
              'Protein ${(p / n).round()} g   Carbs ${(c / n).round()} g   Fat ${(f / n).round()} g',
              style: TextStyle(color: AppColors.muted, fontSize: 13)),
          if (days > 1) ...[
            const SizedBox(height: 16),
            SizedBox(
              height: 90,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final k in kcal)
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: days > 14 ? 1 : 3),
                        child: Container(
                          height: (k / maxK * 90).clamp(2.0, 90.0).toDouble(),
                          decoration: BoxDecoration(
                            color: k <= 0
                                ? AppColors.track
                                : (k > s.kcalTarget ? AppColors.ring : AppColors.primary),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text('Orange bars are above your ${s.kcalTarget} kcal goal.',
                style: TextStyle(color: AppColors.muted, fontSize: 11)),
          ],
        ],
      ),
    );
  }
}

List<Widget> _nutritionActions(BuildContext context, void Function(int) goto) => [
      const SizedBox(height: 14),
      GradientButton(
        label: 'Add meal',
        icon: Icons.add,
        onPressed: () => showAddFoodSheet(context),
      ),
      const SizedBox(height: 14),
      MenuCard(rows: [
        MenuRow(
          icon: Icons.menu_book_outlined,
          title: 'Open diary',
          subtitle: 'Meals by day, add to past days',
          onTap: () {
            Navigator.of(context).popUntil((r) => r.isFirst);
            goto(1);
          },
        ),
        _row(context, Icons.savings_outlined, 'Budget diet plan',
            'A week of meals in your rupee budget', const BudgetPlanScreen()),
      ]),
    ];

HubScreen nutritionHub(void Function(int) goto) => HubScreen(
      title: 'Nutrition',
      tabs: [
        HubTab('Today', (c) => [const _NutritionSummary(days: 1), ..._nutritionActions(c, goto)]),
        HubTab('Week', (c) => [const _NutritionSummary(days: 7), ..._nutritionActions(c, goto)]),
        HubTab('Month', (c) => [const _NutritionSummary(days: 30), ..._nutritionActions(c, goto)]),
      ],
    );

// ---- Health ----

HubScreen healthHub() => HubScreen(
      title: 'Health and reports',
      tabs: [
        HubTab('Reports', (c) => [
              MenuCard(rows: [
                _row(c, Icons.insights_outlined, 'Monthly report',
                    'Workouts, calories, protein, PDF', const ReportScreen()),
                _row(c, Icons.medical_information_outlined, 'Medical report',
                    'Scan a report, foods to limit', const MedicalReportScreen()),
                _row(c, Icons.watch_outlined, 'Smartwatch and Health Connect',
                    'Steps, heart rate, sleep', const HealthConnectScreen()),
              ]),
              const SizedBox(height: 12),
              Text('General guidance only, not medical advice.',
                  style: TextStyle(color: AppColors.muted, fontSize: 12)),
            ]),
        HubTab('Conditions', (c) => [
              MenuCard(rows: [
                _row(c, Icons.monitor_heart_outlined, 'Health conditions',
                    'Diabetes, BP, cholesterol, PCOS', const HealthScreen()),
              ]),
            ]),
        HubTab('Allergies', (c) => [
              MenuCard(rows: [
                _row(c, Icons.shield_outlined, 'Allergies',
                    'Every scan is checked against them', const AllergyPage()),
              ]),
            ]),
      ],
    );

// ---- Library ----

HubScreen libraryHub() => HubScreen(
      title: 'Library',
      tabs: [
        HubTab('Exercises', (c) => [
              MenuCard(rows: [
                _row(c, Icons.menu_book_outlined, 'Exercise library',
                    'Muscles, form, mistakes', const ExerciseLibraryScreen()),
              ]),
              const SizedBox(height: 12),
              Text('Form check (photo and live camera) is on each exercise while you log a workout.',
                  style: TextStyle(color: AppColors.muted, fontSize: 12)),
            ]),
        HubTab('Training', (c) => [
              MenuCard(rows: [
                _row(c, Icons.insights_outlined, 'Training status',
                    'Last trained, weekly sets, recovery', const TrainingStatusScreen()),
                _row(c, Icons.pie_chart_outline, 'Muscle volume',
                    'Sets per muscle group', const MuscleScreen()),
              ]),
            ]),
      ],
    );

// ---- Community ----

HubScreen communityHub() => HubScreen(
      title: 'Community',
      tabs: [
        HubTab('Friends', (c) => [
              if (cloudEnabled)
                MenuCard(rows: [
                  _row(c, Icons.groups_outlined, 'Friends and challenges',
                      'Feed, leaderboard, 30-day challenge', const SocialScreen()),
                ])
              else
                AppCard(
                  child: Text('Friends need an account. Sign in to use them.',
                      style: TextStyle(color: AppColors.muted)),
                ),
            ]),
        HubTab('Privacy', (c) => [
              MenuCard(rows: [
                _row(c, Icons.privacy_tip_outlined, 'Privacy dashboard',
                    'What is stored and shared. Export data', const PrivacyDashboardScreen()),
              ]),
              const SizedBox(height: 12),
              Text('Block, mute, private profile and activity status are in Friends, at the bottom.',
                  style: TextStyle(color: AppColors.muted, fontSize: 12)),
            ]),
      ],
    );

// ---- Daily plan ----

HubScreen dailyPlanHub(void Function(int) goto) => HubScreen(
      title: 'Daily plan',
      tabs: [
        HubTab('Today', (c) => [
              TodaysPlanCard(onGoto: (i) {
                Navigator.of(c).popUntil((r) => r.isFirst);
                goto(i);
              }),
              const SizedBox(height: 14),
              MenuCard(rows: [
                _row(c, Icons.notifications_active_outlined, 'Reminders',
                    'Meals, water, workouts', const RemindersScreen()),
              ]),
            ]),
        HubTab('Week', (c) {
          final s = c.watch<AppState>();
          const names = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
          final todayWd = DateTime.now().weekday;
          return [
            for (var wd = 1; wd <= 7; wd++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: AppCard(
                  radius: 16,
                  color: wd == todayWd ? AppColors.chipBg : null,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: InkWell(
                    onTap: () {
                      Navigator.of(c).popUntil((r) => r.isFirst);
                      goto(2);
                    },
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(names[wd - 1],
                              style: const TextStyle(fontWeight: FontWeight.w700)),
                        ),
                        Text(_planText(s.planFor(wd)),
                            style: TextStyle(color: AppColors.muted)),
                      ],
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 6),
            Text('Tap a day to open the Workout tab and change the plan.',
                style: TextStyle(color: AppColors.muted, fontSize: 12)),
          ];
        }),
      ],
    );

String _planText(DayPlan p) => p.rest ? 'Rest day' : p.title;

// ---- Challenges ----

HubScreen challengesHub() => HubScreen(
      title: 'Challenges',
      tabs: [
        HubTab('Missions', (c) => [
              const WeeklyMissionsCard(),
              const SizedBox(height: 14),
              MenuCard(rows: [
                _row(c, Icons.flag_outlined, 'Missions and challenges',
                    'Weekly missions and your own goals', const MissionsScreen()),
              ]),
            ]),
        HubTab('Streaks', (c) => [
              const StreakCard(),
              const SizedBox(height: 14),
              MenuCard(rows: [
                _row(c, Icons.emoji_events_outlined, 'Streaks and badges',
                    'Milestones, freezes, badges', const BadgesScreen()),
              ]),
            ]),
      ],
    );

