import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/reminder_service.dart';
import '../state/app_state.dart';
import '../theme.dart';

class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key});

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
  final _svc = ReminderService.instance;

  Future<void> _apply() async {
    await _svc.apply(context.read<AppState>());
    if (mounted) setState(() {});
  }

  Future<void> _toggle(bool on, void Function(bool) set) async {
    if (on) {
      final ok = await _svc.askPermission();
      if (!ok) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Allow notifications for Healthy in your phone settings.'),
        ));
        return;
      }
    }
    set(on);
    await _apply();
  }

  Future<void> _pick(Reminder r) async {
    final t = await showTimePicker(context: context, initialTime: r.time);
    if (t == null) return;
    r.time = t;
    await _apply();
  }

  Widget _row(String title, String subtitle, Reminder r) {
    return AppCard(
      radius: 16,
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                Text(subtitle,
                    style: const TextStyle(color: AppColors.muted, fontSize: 13)),
              ],
            ),
          ),
          if (r.enabled)
            TextButton(
              onPressed: () => _pick(r),
              child: Text(r.time.format(context)),
            ),
          Switch(
            value: r.enabled,
            activeColor: AppColors.primary,
            onChanged: (v) => _toggle(v, (x) => r.enabled = x),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reminders')),
      body: !_svc.available
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('Reminders are not available on this device.'),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _row('Breakfast', 'Daily', _svc.breakfast),
                const SizedBox(height: 10),
                _row('Lunch', 'Daily', _svc.lunch),
                const SizedBox(height: 10),
                _row('Dinner', 'Daily', _svc.dinner),
                const SizedBox(height: 10),
                _row('Workout', 'Gym alarm on days that are not rest days', _svc.workout),
                const SizedBox(height: 10),
                AppCard(
                  radius: 16,
                  padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Drink water',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w700, fontSize: 16)),
                                Text('Between 9 am and 9 pm',
                                    style: TextStyle(color: AppColors.muted, fontSize: 13)),
                              ],
                            ),
                          ),
                          Switch(
                            value: _svc.water,
                            activeColor: AppColors.primary,
                            onChanged: (v) => _toggle(v, (x) => _svc.water = x),
                          ),
                        ],
                      ),
                      if (_svc.water)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Wrap(
                            spacing: 8,
                            children: [
                              for (final h in const [1, 2, 3])
                                ChoiceChip(
                                  label: Text('Every $h h'),
                                  selected: _svc.waterEveryHours == h,
                                  onSelected: (_) {
                                    _svc.waterEveryHours = h;
                                    _apply();
                                  },
                                ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Reminders are saved on this phone. Android may deliver them a few minutes late to save battery.',
                  style: TextStyle(color: AppColors.muted, fontSize: 12, height: 1.4),
                ),
              ],
            ),
    );
  }
}
