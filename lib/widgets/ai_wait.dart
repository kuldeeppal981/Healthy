import 'dart:async';

import 'package:flutter/material.dart';

import '../theme.dart';

/// Shown while a photo goes to the AI and the answer is awaited.
/// The server does not report real upload bytes, so the bar is an estimate
/// based on time. It says so honestly: steps + seconds, never a fake "100%".
class AiWaitCard extends StatefulWidget {
  final String doing; // e.g. "Reading your report"
  final int? sizeBytes;
  final int expectedSeconds;

  const AiWaitCard({
    super.key,
    required this.doing,
    this.sizeBytes,
    this.expectedSeconds = 20,
  });

  @override
  State<AiWaitCard> createState() => _AiWaitCardState();
}

class _AiWaitCardState extends State<AiWaitCard> {
  final _sw = Stopwatch()..start();
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sec = _sw.elapsed.inMilliseconds / 1000;
    final exp = widget.expectedSeconds.toDouble();
    // Eases towards 95% and never reaches 100 until the answer arrives.
    final p = (0.95 * (1 - 1 / (1 + sec / (exp / 3)))).clamp(0.02, 0.95).toDouble();
    final step = sec < 3 ? 1 : (sec < exp ? 2 : 3);
    final kb = widget.sizeBytes == null ? null : (widget.sizeBytes! / 1024).round();
    final late = sec > exp;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('${widget.doing}...',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
              ),
              Text('${sec.floor()} s', style: TextStyle(color: AppColors.muted)),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: p,
              minHeight: 8,
              color: AppColors.primary,
              backgroundColor: AppColors.track,
            ),
          ),
          const SizedBox(height: 10),
          _step(1, step, kb == null ? 'Sending photo' : 'Sending photo ($kb KB)'),
          _step(2, step, 'AI is reading it'),
          _step(3, step, late ? 'Taking longer than usual, please wait' : 'Almost done'),
          const SizedBox(height: 6),
          Text('Usually 10 to 30 seconds. Please keep the app open.',
              style: TextStyle(color: AppColors.muted, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _step(int n, int now, String text) {
    final done = n < now;
    final active = n == now;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            done ? Icons.check_circle : (active ? Icons.timelapse : Icons.radio_button_unchecked),
            size: 16,
            color: done || active ? AppColors.primary : AppColors.muted,
          ),
          const SizedBox(width: 8),
          Text(text,
              style: TextStyle(
                  fontSize: 13,
                  color: active ? null : AppColors.muted,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w400)),
        ],
      ),
    );
  }
}
