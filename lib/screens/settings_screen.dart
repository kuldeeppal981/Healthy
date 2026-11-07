import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/edit_identity.dart';
import 'appearance_screen.dart';
import 'delete_data_screen.dart';
import 'privacy_dashboard_screen.dart';
import 'privacy_screen.dart';
import 'reminders_screen.dart';
import 'tour_screen.dart';

/// Settings: account on top, then categories. Each category opens its own screen.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  void _open(BuildContext context, Widget page) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));

  Widget _title(String text) => Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 8, left: 4),
        child: Text(text, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
      );

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final name = (s.displayName ?? '').trim();
    final signedIn = s.signedIn;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(backgroundColor: Colors.transparent, title: const Text('Settings')),
      body: AppBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(22),
              onTap: () => showEditIdentity(context, s),
              child: AppCard(
                radius: 22,
                child: Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(colors: [AppColors.primaryLight, AppColors.primaryDeep]),
                      ),
                      child: Text(name.isEmpty ? '?' : name.characters.first.toUpperCase(),
                          style: const TextStyle(
                              color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name.isEmpty ? 'Add your name' : name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                          Text(
                              signedIn
                                  ? (s.accountEmail ?? 'Signed in')
                                  : 'Data is only on this phone',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: AppColors.muted, fontSize: 13)),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: AppColors.muted),
                  ],
                ),
              ),
            ),
            _title('Preferences'),
            MenuCard(rows: [
              MenuRow(
                icon: Icons.palette_outlined,
                title: 'Appearance',
                subtitle: 'Theme, colours, text size, sounds',
                onTap: () => _open(context, const AppearanceScreen()),
              ),
              MenuRow(
                icon: Icons.notifications_active_outlined,
                title: 'Notifications',
                subtitle: 'Meals, water, workouts, gym alarm',
                onTap: () => _open(context, const RemindersScreen()),
              ),
            ]),
            _title('Privacy and security'),
            MenuCard(rows: [
              MenuRow(
                icon: Icons.privacy_tip_outlined,
                title: 'Privacy and data',
                subtitle: 'What is stored, who sees it, export',
                onTap: () => _open(context, const PrivacyDashboardScreen()),
              ),
              MenuRow(
                icon: Icons.policy_outlined,
                title: 'Privacy policy',
                subtitle: 'In plain language',
                onTap: () => _open(context, const PrivacyScreen()),
              ),
              MenuRow(
                icon: Icons.delete_outline,
                title: 'Delete data or account',
                subtitle: 'Cannot be undone',
                onTap: () => _open(context, const DeleteDataScreen()),
              ),
            ]),
            _title('Support'),
            MenuCard(rows: [
              MenuRow(
                icon: Icons.help_outline,
                title: 'App tour',
                subtitle: 'See the quick intro again',
                onTap: () => _open(context, const TourScreen()),
              ),
              MenuRow(
                icon: Icons.info_outline,
                title: 'About and licences',
                subtitle: 'Healthy, open source licences',
                onTap: () => showLicensePage(context: context, applicationName: 'Healthy'),
              ),
            ]),
            if (cloudEnabled) ...[
              const SizedBox(height: 20),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.danger,
                  side: BorderSide(color: AppColors.danger.withOpacity(0.5)),
                ),
                onPressed: () {
                  if (signedIn) {
                    s.signOut();
                  } else {
                    s.leaveGuest();
                  }
                  Navigator.of(context).popUntil((r) => r.isFirst);
                },
                icon: Icon(signedIn ? Icons.logout : Icons.login),
                label: Text(signedIn ? 'Sign out' : 'Sign in'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
