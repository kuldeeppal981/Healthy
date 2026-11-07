import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/l10n.dart';
import '../services/notify_prefs.dart';
import '../services/reminder_service.dart';
import '../state/app_state.dart';
import '../theme.dart';
import 'reminders_screen.dart';

/// What you get notified about, and quiet hours.
class NotificationSettingsScreen extends StatelessWidget {
  const NotificationSettingsScreen({super.key});

  String _fmt(BuildContext context, int minutes) =>
      TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60).format(context);

  Future<void> _pick(BuildContext context, bool from) async {
    final np = NotifyPrefs.instance;
    final cur = from ? np.quietFrom : np.quietTo;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: cur ~/ 60, minute: cur % 60),
    );
    if (t == null || !context.mounted) return;
    final m = t.hour * 60 + t.minute;
    await np.setQuiet(from ? m : np.quietFrom, from ? np.quietTo : m);
    if (context.mounted) await ReminderService.instance.apply(context.read<AppState>());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(backgroundColor: Colors.transparent, title: Text(tr('Notifications'))),
      body: AppBackground(
        child: ListenableBuilder(
          listenable: NotifyPrefs.instance,
          builder: (context, _) {
            final np = NotifyPrefs.instance;
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
              children: [
                MenuCard(rows: [
                  MenuRow(
                    icon: Icons.notifications_active_outlined,
                    title: 'Reminders',
                    subtitle: 'Meals, water, workouts, gym alarm',
                    onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(builder: (_) => const RemindersScreen())),
                  ),
                ]),
                const SizedBox(height: 14),
                AppCard(
                  radius: 22,
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                  child: Column(
                    children: [
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(tr('Friend requests and nudges'),
                            style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: const Text('New requests, accepted requests, nudges',
                            style: TextStyle(fontSize: 12)),
                        value: np.friends,
                        activeColor: AppColors.primary,
                        onChanged: np.setFriends,
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(tr('Cheers on your posts'),
                            style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: const Text('When a friend cheers your record or workout',
                            style: TextStyle(fontSize: 12)),
                        value: np.cheers,
                        activeColor: AppColors.primary,
                        onChanged: np.setCheers,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                AppCard(
                  radius: 22,
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(tr('Quiet hours'),
                            style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: const Text('No reminders or alerts in this time',
                            style: TextStyle(fontSize: 12)),
                        value: np.quietOn,
                        activeColor: AppColors.primary,
                        onChanged: (v) async {
                          await np.setQuietOn(v);
                          if (context.mounted) {
                            await ReminderService.instance.apply(context.read<AppState>());
                          }
                        },
                      ),
                      if (np.quietOn)
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
                                onPressed: () => _pick(context, true),
                                child: Text('${tr('From')} ${_fmt(context, np.quietFrom)}'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
                                onPressed: () => _pick(context, false),
                                child: Text('${tr('To')} ${_fmt(context, np.quietTo)}'),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                    'Quiet hours skip meal, water and workout reminders and friend alerts. Your gym alarm still rings, because you set it yourself. Turn it off in Reminders if you do not want it.',
                    style: TextStyle(fontSize: 12, color: AppColors.muted, height: 1.4)),
              ],
            );
          },
        ),
      ),
    );
  }
}
