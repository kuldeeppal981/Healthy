import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../services/step_service.dart';
import '../state/app_state.dart';
import '../theme.dart';

/// Shows a progress card and lets the user share it as an image.
Future<void> showShareCard(BuildContext context) {
  final s = Provider.of<AppState>(context, listen: false);
  final now = DateTime.now();
  final monthStart = DateTime(now.year, now.month, 1);
  final monthWorkouts = s.workouts.where((w) => !w.at.isBefore(monthStart)).length;
  final steps = StepService.instance.steps;
  return _showStoryShare(
    context,
    fileName: 'healthy-progress.png',
    text: 'My progress on Healthy',
    card: _StoryCard(
      label: 'MY PROGRESS',
      big: '${s.foodStreak}',
      bigCaption: 'day logging streak',
      emoji: '🔥',
      stats: [
        ('$monthWorkouts', 'workouts this month'),
        ('$steps', 'steps today'),
        ('${s.workouts.length}', 'workouts in total'),
      ],
    ),
  );
}

/// Share card for one personal record, for example "Bench press 60 kg x 8".
Future<void> showPrShareCard(
    BuildContext context, String exercise, double kg, int reps) {
  final name = exercise.isEmpty ? exercise : '${exercise[0].toUpperCase()}${exercise.substring(1)}';
  final kgText = kg == kg.roundToDouble() ? '${kg.round()}' : '$kg';
  return _showStoryShare(
    context,
    fileName: 'healthy-pr.png',
    text: 'New personal record: $name $kgText kg x $reps. Tracked on Healthy',
    card: _StoryCard(
      label: 'PERSONAL RECORD',
      big: '$kgText kg',
      bigCaption: '$name  x  $reps reps',
      emoji: '🏆',
      stats: const [],
    ),
  );
}

Future<void> _showStoryShare(
  BuildContext context, {
  required String fileName,
  required String text,
  required Widget card,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _ShareDialog(fileName: fileName, text: text, card: card),
  );
}

/// 9:16 card, the size of an Instagram or WhatsApp story.
class _StoryCard extends StatelessWidget {
  final String label;
  final String big;
  final String bigCaption;
  final String emoji;
  final List<(String, String)> stats;

  const _StoryCard({
    required this.label,
    required this.big,
    required this.bigCaption,
    required this.emoji,
    required this.stats,
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 9 / 16,
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 36, 24, 28),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            colors: [Color(0xFF0F7A37), Color(0xFF16A34A), Color(0xFF4ADE80)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          children: [
            const Text('HEALTHY',
                style: TextStyle(
                    color: Colors.white70, letterSpacing: 4, fontWeight: FontWeight.w800)),
            const Spacer(),
            Text(emoji, style: const TextStyle(fontSize: 64)),
            const SizedBox(height: 12),
            Text(label,
                style: const TextStyle(
                    color: Colors.white70, letterSpacing: 2, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(big,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 72, fontWeight: FontWeight.w900)),
            ),
            const SizedBox(height: 4),
            Text(bigCaption,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 17)),
            const Spacer(),
            if (stats.isNotEmpty)
              Row(
                children: [
                  for (final st in stats)
                    Expanded(
                      child: Column(
                        children: [
                          Text(st.$1,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800)),
                          const SizedBox(height: 2),
                          Text(st.$2,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Color(0xFFD5F5E0), fontSize: 11)),
                        ],
                      ),
                    ),
                ],
              ),
            const SizedBox(height: 18),
            const Text('Tracked with Healthy',
                style: TextStyle(color: Colors.white60, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _ShareDialog extends StatefulWidget {
  final String fileName;
  final String text;
  final Widget card;
  const _ShareDialog({required this.fileName, required this.text, required this.card});

  @override
  State<_ShareDialog> createState() => _ShareDialogState();
}

class _ShareDialogState extends State<_ShareDialog> {
  final _key = GlobalKey();
  bool _busy = false;

  Future<void> _share() async {
    setState(() => _busy = true);
    try {
      final boundary = _key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 4);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/${widget.fileName}');
      await file.writeAsBytes(data!.buffer.asUint8List());
      await Share.shareXFiles([XFile(file.path)], text: widget.text);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not share the card. Try again.')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.of(context).size.height;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: h * 0.68),
            child: RepaintBoundary(key: _key, child: widget.card),
          ),
          const SizedBox(height: 12),
          const Text(
            'In the share list pick Instagram (Stories) or WhatsApp (Status)',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FilledButton.icon(
                onPressed: _busy ? null : _share,
                icon: const Icon(Icons.share),
                label: const Text('Share'),
                style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 44),
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.primary),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
