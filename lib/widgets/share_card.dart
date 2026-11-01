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
  return showDialog<void>(
    context: context,
    builder: (_) => const _ShareDialog(),
  );
}

class _ShareDialog extends StatefulWidget {
  const _ShareDialog();

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
      final image = await boundary.toImage(pixelRatio: 3);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/healthy-progress.png');
      await file.writeAsBytes(data!.buffer.asUint8List());
      await Share.shareXFiles([XFile(file.path)], text: 'My progress on Healthy');
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
    final s = context.watch<AppState>();
    final steps = StepService.instance.steps;
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final monthWorkouts = s.workouts.where((w) => !w.at.isBefore(monthStart)).length;

    Widget stat(String v, String l) => Expanded(
          child: Column(
            children: [
              Text(v,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800)),
              Text(l,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFFD9CCFF), fontSize: 12)),
            ],
          ),
        );

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          RepaintBoundary(
            key: _key,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: const LinearGradient(
                  colors: [Color(0xFF6C3CE9), Color(0xFF9B6BFF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('HEALTHY',
                      style: TextStyle(
                          color: Colors.white70, letterSpacing: 3, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 14),
                  Text('${s.foodStreak}',
                      style: const TextStyle(
                          color: Colors.white, fontSize: 64, fontWeight: FontWeight.w900)),
                  const Text('day logging streak',
                      style: TextStyle(color: Colors.white, fontSize: 16)),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      stat('$monthWorkouts', 'workouts this month'),
                      stat('$steps', 'steps today'),
                      stat('${s.workouts.length}', 'workouts in total'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FilledButton.icon(
                onPressed: _busy ? null : _share,
                icon: const Icon(Icons.share),
                label: const Text('Share'),
                style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: AppColors.primary),
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
