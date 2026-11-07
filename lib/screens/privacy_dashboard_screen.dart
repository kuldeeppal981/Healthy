import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../config.dart';
import '../services/health_service.dart';
import '../services/social_service.dart';
import '../state/app_state.dart';
import '../theme.dart';
import 'health_connect_screen.dart';
import 'privacy_screen.dart';
import 'delete_data_screen.dart';

/// One place to see what Healthy stores, what is shared, what the AI sees,
/// and to export or delete your data.
class PrivacyDashboardScreen extends StatelessWidget {
  const PrivacyDashboardScreen({super.key});

  void _open(BuildContext context, Widget page) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));

  Widget _title(String text) => Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 8),
        child: Text(text, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
      );

  Widget _line(IconData icon, String text, {Color? color}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: color ?? AppColors.primary),
            const SizedBox(width: 10),
            Expanded(child: Text(text, style: const TextStyle(fontSize: 14, height: 1.35))),
          ],
        ),
      );

  Future<void> _exportJson(BuildContext context, AppState s) async {
    try {
      final dir = await getTemporaryDirectory();
      final f = File('${dir.path}/healthy_my_data.json');
      await f.writeAsString(const JsonEncoder.withIndent('  ').convert(s.toSnapshot()));
      await Share.shareXFiles([XFile(f.path)], text: 'My Healthy data (JSON)');
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not create the file. Try again.')),
      );
    }
  }

  String _csv(String v) => '"${v.replaceAll('"', '""')}"';

  Future<void> _exportCsv(BuildContext context, AppState s) async {
    try {
      final b = StringBuffer('date,meal,food,kcal,protein_g,carbs_g,fat_g\n');
      final list = [...s.entries]..sort((a, c) => a.at.compareTo(c.at));
      for (final e in list) {
        b.writeln([
          AppState.dayKey(e.at),
          e.meal,
          _csv(e.name),
          e.kcal.round(),
          e.protein.toStringAsFixed(1),
          e.carbs.toStringAsFixed(1),
          e.fat.toStringAsFixed(1),
        ].join(','));
      }
      final dir = await getTemporaryDirectory();
      final f = File('${dir.path}/healthy_food_diary.csv');
      await f.writeAsString(b.toString());
      await Share.shareXFiles([XFile(f.path)], text: 'My food diary (CSV)');
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not create the file. Try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(backgroundColor: Colors.transparent, title: const Text('Privacy dashboard')),
      body: AppBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
          children: [
            _title('What is stored'),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _line(Icons.restaurant_outlined, '${s.entries.length} food entries'),
                  _line(Icons.fitness_center, '${s.workouts.length} workouts'),
                  _line(Icons.monitor_weight_outlined, '${s.weights.length} weight entries'),
                  _line(Icons.water_drop_outlined, '${s.water.length} days of water'),
                  _line(
                    Icons.medical_information_outlined,
                    s.medicalNotes == null
                        ? 'No medical report notes'
                        : 'Medical report notes saved (the photo itself is not kept)',
                  ),
                  _line(
                    s.signedIn ? Icons.cloud_done_outlined : Icons.phone_android,
                    s.signedIn
                        ? 'Saved on this phone and in your private account (only you can read it).'
                        : 'Saved on this phone only. Sign in to back it up.',
                  ),
                ],
              ),
            ),
            _title('Health permissions'),
            AppCard(
              child: ListenableBuilder(
                listenable: HealthService.instance,
                builder: (context, _) {
                  final h = HealthService.instance;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _line(
                        h.connected ? Icons.check_circle_outline : Icons.link_off,
                        h.unavailable
                            ? 'Health Connect is not available on this phone.'
                            : h.connected
                                ? 'Health Connect is connected. Healthy only reads steps, heart rate, sleep and exercise. It never writes to it.'
                                : 'Health Connect is not connected. No watch or phone health data is read.',
                      ),
                      const SizedBox(height: 6),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
                          onPressed: () => _open(context, const HealthConnectScreen()),
                          child: const Text('Manage Health Connect'),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            _title('AI and your data'),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _line(Icons.smart_toy_outlined,
                      'AI is used only when you tap it: coach chat, voice logging, photo scan, form check and report scan.'),
                  _line(Icons.send_outlined,
                      'Only the text or photo you send for that request goes to Google Gemini to get your answer.'),
                  _line(Icons.image_not_supported_outlined,
                      'Photos and videos are not saved in your account. Only the result (for example your report notes) is kept.'),
                  _line(Icons.block,
                      'Your data is not sold and is not used for advertising.'),
                  _line(Icons.warning_amber_outlined,
                      'AI answers can be wrong. Numbers from photos or voice are estimates. Always check labels for allergies.',
                      color: AppColors.warnInk),
                  if (s.medicalNotes != null) ...[
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
                        onPressed: () {
                          s.clearMedicalNotes();
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Medical report notes removed')));
                        },
                        child: const Text('Remove my medical report notes'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            _title('Who can see what'),
            AppCard(
              child: !cloudEnabled
                  ? _line(Icons.lock_outline, 'Friends are not part of this build. Nothing is shared.')
                  : ListenableBuilder(
                      listenable: SocialService.instance,
                      builder: (context, _) {
                        final soc = SocialService.instance;
                        if (!soc.enabled) {
                          return _line(Icons.lock_outline,
                              'Friends are off. Nothing is shared with anyone.');
                        }
                        return Column(
                          children: [
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Others can find me',
                                  style: TextStyle(fontWeight: FontWeight.w700)),
                              subtitle: const Text('Shows your name and friend code in search',
                                  style: TextStyle(fontSize: 12)),
                              value: soc.discoverable,
                              activeColor: AppColors.primary,
                              onChanged: soc.setDiscoverable,
                            ),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Share my achievements',
                                  style: TextStyle(fontWeight: FontWeight.w700)),
                              subtitle: const Text(
                                  'Streaks, levels and records appear in friends\' feed',
                                  style: TextStyle(fontSize: 12)),
                              value: soc.shareAchievements,
                              activeColor: AppColors.primary,
                              onChanged: soc.setShareAchievements,
                            ),
                            _line(Icons.visibility_off_outlined,
                                'Friends never see your food diary, weight, allergies or medical notes.'),
                          ],
                        );
                      },
                    ),
            ),
            _title('Your data'),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
                        onPressed: () => _exportJson(context, s),
                        icon: const Icon(Icons.download_outlined),
                        label: const Text('Export all data'),
                      ),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(minimumSize: const Size(0, 44)),
                        onPressed: () => _exportCsv(context, s),
                        icon: const Icon(Icons.table_chart_outlined),
                        label: const Text('Food diary (CSV)'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'The file opens in the share sheet, so you choose where it goes. It is not uploaded by Healthy.',
                    style: TextStyle(fontSize: 12, color: AppColors.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            MenuCard(rows: [
              MenuRow(
                icon: Icons.delete_outline,
                title: 'Delete data or account',
                subtitle: 'Cannot be undone',
                onTap: () => _open(context, const DeleteDataScreen()),
              ),
              MenuRow(
                icon: Icons.policy_outlined,
                title: 'Privacy policy',
                subtitle: 'Plain language',
                onTap: () => _open(context, const PrivacyScreen()),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}
