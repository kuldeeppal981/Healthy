import 'package:flutter/material.dart';

import '../services/social_service.dart';
import '../theme.dart';
import 'ui_kit.dart';

/// "New personal best" celebration after a finished workout.
Future<void> showPrPopup(BuildContext context, List<NewPr> prs) {
  if (prs.isEmpty) return Future<void>.value();
  Haptic.win();
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'New personal best',
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 420),
    pageBuilder: (ctx, a1, a2) => Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 300,
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
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
                  child: const Text('🏆', style: TextStyle(fontSize: 64)),
                ),
              ),
              const SizedBox(height: 6),
              Text(prs.length == 1 ? 'New personal best!' : '${prs.length} new personal bests!',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
              const SizedBox(height: 12),
              for (final p in prs.take(4))
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text('${p.exercise}: ${p.text}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.primary)),
                ),
              const SizedBox(height: 4),
              Text('Hard work shows. Rest well and eat enough protein.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.muted, fontSize: 12)),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Nice'),
              ),
            ],
          ),
        ),
      ),
    ),
    transitionBuilder: (ctx, a1, a2, child) {
      final t = CurvedAnimation(parent: a1, curve: Curves.elasticOut);
      return FadeTransition(
        opacity: CurvedAnimation(parent: a1, curve: Curves.easeOut),
        child: ScaleTransition(scale: Tween<double>(begin: 0.6, end: 1).animate(t), child: child),
      );
    },
  );
}
