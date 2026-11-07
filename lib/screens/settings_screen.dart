import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../services/l10n.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/edit_identity.dart';
import 'appearance_screen.dart';
import 'delete_data_screen.dart';
import 'health_connect_screen.dart';
import 'help_feedback_screen.dart';
import 'notification_settings_screen.dart';
import 'units_language_screen.dart';
import 'privacy_dashboard_screen.dart';
import 'privacy_screen.dart';

/// Settings: account on top, then categories. Each category opens its own screen.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  void _open(BuildContext context, Widget page) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));

  Widget _title(String text, {Color? color}) => Padding(
        padding: const EdgeInsets.only(top: 20, bottom: 8, left: 4),
        child: Text(text,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color)),
      );

  Future<void> _changePassword(BuildContext context, AppState s) async {
    final c = TextEditingController();
    final pw = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('Change password')),
        content: TextField(
          controller: c,
          obscureText: true,
          decoration: const InputDecoration(hintText: 'New password (6+ characters)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, c.text), child: const Text('Save')),
        ],
      ),
    );
    if (pw == null || !context.mounted) return;
    String msg;
    if (pw.length < 6) {
      msg = 'Password must be at least 6 characters.';
    } else {
      final err = await s.cloud?.updatePassword(pw);
      msg = err ?? 'Password changed.';
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final name = (s.displayName ?? '').trim();
    final signedIn = s.signedIn;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(backgroundColor: Colors.transparent, title: Text(tr('Settings'))),
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
            if (cloudEnabled) ...[
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () {
                  if (signedIn) {
                    s.signOut();
                  } else {
                    s.leaveGuest();
                  }
                  Navigator.of(context).popUntil((r) => r.isFirst);
                },
                icon: Icon(signedIn ? Icons.logout : Icons.login),
                label: Text(signedIn ? tr('Sign out') : 'Sign in'),
              ),
            ],
            _title(tr('Account')),
            MenuCard(rows: [
              if (signedIn)
                MenuRow(
                  icon: Icons.lock_outline,
                  title: tr('Change password'),
                  subtitle: 'Email login',
                  onTap: () => _changePassword(context, s),
                ),
              MenuRow(
                icon: Icons.person_outline,
                title: 'Name and photo',
                subtitle: 'How friends see you',
                onTap: () => showEditIdentity(context, s),
              ),
            ]),
            _title(tr('Preferences')),
            MenuCard(rows: [
              MenuRow(
                icon: Icons.palette_outlined,
                title: 'Appearance',
                subtitle: 'Theme, colours, text size, sounds',
                onTap: () => _open(context, const AppearanceScreen()),
              ),
              MenuRow(
                icon: Icons.notifications_active_outlined,
                title: tr('Notifications'),
                subtitle: 'Reminders, friends, cheers, quiet hours',
                onTap: () => _open(context, const NotificationSettingsScreen()),
              ),
              MenuRow(
                icon: Icons.translate,
                title: '${tr('Units')} / ${tr('Language')}',
                subtitle: 'kg or lb, cm or ft, English or Hindi',
                onTap: () => _open(context, const UnitsLanguageScreen()),
              ),
            ]),
            _title(tr('Connected apps')),
            MenuCard(rows: [
              MenuRow(
                icon: Icons.favorite_border,
                title: 'Health Connect',
                subtitle: 'Steps and workouts from your phone',
                onTap: () => _open(context, const HealthConnectScreen()),
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
                icon: Icons.group_outlined,
                title: 'Friends privacy',
                subtitle: 'Be found, share achievements',
                onTap: () => _open(context, const PrivacyDashboardScreen()),
              ),
              MenuRow(
                icon: Icons.policy_outlined,
                title: 'Privacy policy',
                subtitle: 'In plain language',
                onTap: () => _open(context, const PrivacyScreen()),
              ),
            ]),
            _title(tr('Support')),
            MenuCard(rows: [
              MenuRow(
                icon: Icons.support_agent,
                title: tr('Help and feedback'),
                subtitle: 'Questions, ideas, problems',
                onTap: () => _open(context, const HelpFeedbackScreen()),
              ),
              MenuRow(
                icon: Icons.info_outline,
                title: 'About and licences',
                subtitle: 'Healthy $appVersion, open source licences',
                onTap: () => showLicensePage(
                    context: context,
                    applicationName: 'Healthy',
                    applicationVersion: appVersion),
              ),
            ]),
            _title(tr('Danger zone'), color: AppColors.danger),
            MenuCard(rows: [
              MenuRow(
                icon: Icons.delete_outline,
                title: 'Delete data or account',
                subtitle: 'Cannot be undone',
                onTap: () => _open(context, const DeleteDataScreen()),
              ),
            ]),
            const SizedBox(height: 18),
            Center(
              child: Text('Healthy $appVersion',
                  style: TextStyle(fontSize: 12, color: AppColors.muted)),
            ),
          ],
        ),
      ),
    );
  }
}
