import 'dart:async';

import 'package:flutter/material.dart';

import '../services/levels.dart';
import '../state/app_state.dart';
import '../theme.dart';
import 'celebrate.dart';
import 'ui_kit.dart';

/// "You are checked in" popup with a bouncing flame, a counting streak number
/// and confetti. Closes by itself after a few seconds or on tap.
Future<void> showAutoCheckInPopup(BuildContext context, AppState s) {
  final streak = s.dailyStreak < 1 ? 1 : s.dailyStreak;
  final p = Progress.of(s);
  Haptic.win();
  Celebrate.show(context);
  Timer? closer;
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Checked in',
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 420),
    pageBuilder: (ctx, a1, a2) {
      closer ??= Timer(const Duration(milliseconds: 3200), () {
        if (ctx.mounted && Navigator.of(ctx).canPop()) Navigator.of(ctx).pop();
      });
      return _CheckInCard(streak: streak, levelTitle: p.title, level: p.level);
    },
    transitionBuilder: (ctx, a1, a2, child) {
      final t = CurvedAnimation(parent: a1, curve: Curves.elasticOut);
      return FadeTransition(
        opacity: CurvedAnimation(parent: a1, curve: Curves.easeOut),
        child: ScaleTransition(scale: Tween<double>(begin: 0.6, end: 1).animate(t), child: child),
      );
    },
  ).whenComplete(() => closer?.cancel());
}

class _CheckInCard extends StatelessWidget {
  final int streak;
  final String levelTitle;
  final int level;
  const _CheckInCard({required this.streak, required this.levelTitle, required this.level});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 290,
          padding: const EdgeInsets.fromLTRB(24, 26, 24, 22),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: 1),
                duration: const Duration(milliseconds: 900),
                curve: Curves.elasticOut,
                builder: (context, t, _) => Transform.scale(
                  scale: 0.4 + 0.6 * t,
                  child: Transform.rotate(
                    angle: (1 - t) * -0.5,
                    child: const Text('🔥', style: TextStyle(fontSize: 72)),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text('Checked in!',
                  style: TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.ink)),
              const SizedBox(height: 10),
              TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: streak.toDouble()),
                duration: const Duration(milliseconds: 1100),
                curve: Curves.easeOutCubic,
                builder: (context, v, _) => Text('${v.round()}',
                    style: TextStyle(
                        fontSize: 54, fontWeight: FontWeight.w900, color: AppColors.primary)),
              ),
              Text(streak == 1 ? 'day streak started' : 'day streak',
                  style: TextStyle(color: AppColors.muted, fontSize: 14)),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: AppColors.chipBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('+10 XP  |  Level $level $levelTitle',
                    style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.chipInk)),
              ),
              const SizedBox(height: 10),
              Text('Auto check-in for today. Keep going!',
                  style: TextStyle(color: AppColors.muted, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}
