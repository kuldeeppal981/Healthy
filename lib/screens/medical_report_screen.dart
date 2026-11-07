import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../services/health_conditions.dart';
import '../services/report_ai.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/illustrations.dart';
import '../widgets/ai_wait.dart';
import '../widgets/ui_kit.dart';

/// Scan a medical report. The AI reads the numbers and gives simple food
/// guidance (what to limit, what to eat more of). After the user checks it,
/// it is saved to the profile and used as a reminder when logging food.
/// General guidance only, never a diagnosis.
class MedicalReportScreen extends StatefulWidget {
  const MedicalReportScreen({super.key});

  @override
  State<MedicalReportScreen> createState() => _MedicalReportScreenState();
}

class _MedicalReportScreenState extends State<MedicalReportScreen> {
  final ImagePicker _picker = ImagePicker();
  bool _busy = false;
  int? _size;
  String? _error;
  Map<String, dynamic>? _draft; // read but not saved yet

  Future<void> _go(ImageSource source) async {
    setState(() => _error = null);
    try {
      final f = await _picker.pickImage(source: source, maxWidth: 1800, imageQuality: 85);
      if (f == null) return;
      setState(() => _busy = true);
      final bytes = await f.readAsBytes();
      setState(() => _size = bytes.length);
      final r = await ReportAi.read(bytes);
      if (!mounted) return;
      setState(() => _draft = r);
    } on ReportAiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not open the camera or photo. Allow permission and try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  List<String> _list(Object? v) =>
      v is List ? [for (final x in v) x.toString()] : const <String>[];

  void _save() {
    final d = _draft;
    if (d == null) return;
    final now = DateTime.now();
    final ids = _list(d['condition_ids']);
    context.read<AppState>().saveMedicalNotes({
      'date': '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
      'summary': d['summary'] ?? '',
      'markers': d['markers'] ?? const [],
      'concerns': d['other_concerns'] ?? const [],
      'avoid': d['avoid'] ?? const [],
      'prefer': d['prefer'] ?? const [],
      'note': d['note'] ?? '',
    }, ids);
    setState(() => _draft = null);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Saved to your profile. Food you log will be checked against it.')),
    );
  }

  Color _statusColor(String s) => switch (s) {
        'high' => AppColors.danger,
        'low' => const Color(0xFFF59E0B),
        'normal' => AppColors.safe,
        _ => AppColors.muted,
      };

  Widget _chips(List<String> items, Color color) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final a in items)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: color.withOpacity(0.14),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(a, style: TextStyle(fontSize: 13, color: AppColors.ink)),
            ),
        ],
      );

  Widget _notesView(Map<String, dynamic> n, {required bool saved}) {
    final markers = n['markers'] is List ? n['markers'] as List : const [];
    final concerns = _list(n['concerns'] ?? n['other_concerns']);
    final avoid = _list(n['avoid']);
    final prefer = _list(n['prefer']);
    final ids = _list(n['condition_ids']);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if ((n['summary'] ?? '').toString().isNotEmpty)
          AppCard(child: Text(n['summary'].toString(), style: const TextStyle(height: 1.4))),
        if (markers.isNotEmpty) ...[
          const SizedBox(height: 12),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Key numbers', style: TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                for (final m in markers)
                  if (m is Map)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Expanded(child: Text('${m['name']}')),
                          Text('${m['value']} ${m['unit'] ?? ''}',
                              style: const TextStyle(fontWeight: FontWeight.w700)),
                          const SizedBox(width: 8),
                          Text('${m['status']}'.toUpperCase(),
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: _statusColor('${m['status']}'))),
                        ],
                      ),
                    ),
              ],
            ),
          ),
        ],
        if (!saved && ids.isNotEmpty) ...[
          const SizedBox(height: 12),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Will switch on in Health conditions',
                    style: TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                _chips([
                  for (final id in ids) conditionById(id)?.label ?? id,
                ], AppColors.primary),
              ],
            ),
          ),
        ],
        if (concerns.isNotEmpty) ...[
          const SizedBox(height: 12),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Also noticed', style: TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                _chips(concerns, const Color(0xFFF59E0B)),
              ],
            ),
          ),
        ],
        if (avoid.isNotEmpty) ...[
          const SizedBox(height: 12),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Better to limit',
                    style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.danger)),
                const SizedBox(height: 8),
                _chips(avoid, AppColors.danger),
              ],
            ),
          ),
        ],
        if (prefer.isNotEmpty) ...[
          const SizedBox(height: 12),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Good to eat more',
                    style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.safe)),
                const SizedBox(height: 8),
                _chips(prefer, AppColors.safe),
              ],
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final saved = s.medicalNotes;
    return Scaffold(
      appBar: AppBar(title: const Text('Medical report')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          HeroHeader(
            kind: ArtKind.report,
            title: saved == null ? 'Your medical report' : 'Report saved',
            subtitle: 'Scan a lab report to see foods to limit and foods to eat more of.',
          ),
          const SizedBox(height: 8),
          AppCard(
            color: AppColors.warnBg,
            borderColor: AppColors.warnBg,
            radius: 14,
            child: Text(
              'General food guidance only, not medical advice or a diagnosis. The AI can misread numbers, so check them against your report. Always follow your doctor or dietitian. The photo is not stored; only the short result is saved to your profile.',
              style: TextStyle(color: AppColors.warnInk, fontSize: 13, height: 1.4),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _busy ? null : () => _go(ImageSource.camera),
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: const Text('Scan report'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : () => _go(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Gallery'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text('Tip: one page at a time, flat, good light, results table in view. Uses 1 daily AI request.',
              style: TextStyle(color: AppColors.muted, fontSize: 12)),
          if (_busy) ...[
            const SizedBox(height: 20),
            AiWaitCard(doing: 'Reading your report', sizeBytes: _size),
          ],
          if (_error != null) ...[
            const SizedBox(height: 14),
            Text(_error!, style: TextStyle(color: AppColors.danger)),
          ],
          if (_draft != null) ...[
            const SizedBox(height: 16),
            const Text('What I found', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            _notesView(_draft!, saved: false),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: FilledButton(onPressed: _save, child: const Text('Save to my profile')),
                ),
                const SizedBox(width: 10),
                TextButton(
                  onPressed: () => setState(() => _draft = null),
                  child: const Text('Discard'),
                ),
              ],
            ),
          ] else if (saved != null) ...[
            const SizedBox(height: 18),
            Row(
              children: [
                const Expanded(
                  child: Text('Saved in your profile',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                ),
                Text('${saved['date'] ?? ''}', style: TextStyle(color: AppColors.muted)),
              ],
            ),
            const SizedBox(height: 8),
            _notesView(saved, saved: true),
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: () {
                context.read<AppState>().clearMedicalNotes();
              },
              icon: Icon(Icons.delete_outline, color: AppColors.danger),
              label: Text('Remove report notes', style: TextStyle(color: AppColors.danger)),
            ),
          ],
        ],
      ),
    );
  }
}
