import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/theme_service.dart';
import '../theme.dart';

/// Same spacing everywhere: screens use [Space.page] around their content and
/// [Space.gap] between cards.
class Space {
  static const double page = 20;
  static const double gap = 14;
  static const pagePadding = EdgeInsets.fromLTRB(20, 8, 20, 28);
}

/// Light vibrations for small wins. Safe to call anywhere.
class Haptic {
  static void tap() => HapticFeedback.selectionClick();
  static void done() => HapticFeedback.lightImpact();
  static void win() => HapticFeedback.mediumImpact();
}

/// Friendly message for screens with nothing to show yet.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: const BoxDecoration(color: AppColors.chipBg, shape: BoxShape.circle),
              child: Icon(icon, size: 36, color: AppColors.primary),
            ),
            const SizedBox(height: 16),
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.muted)),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 18),
              GradientButton(label: actionLabel!, onPressed: onAction, expand: false),
            ],
          ],
        ),
      ),
    );
  }
}

/// One look for every error: what happened and a Try again button.
class ErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const ErrorCard({super.key, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: AppCard(
          color: AppColors.dangerBg,
          borderColor: AppColors.dangerBg,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: AppColors.danger, size: 34),
              const SizedBox(height: 10),
              Text(message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              if (onRetry != null) ...[
                const SizedBox(height: 14),
                GradientButton(label: 'Try again', onPressed: onRetry, expand: false, height: 44),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Grey pulsing block shown while content loads.
class Skeleton extends StatefulWidget {
  final double height;
  final double? width;
  final double radius;

  const Skeleton({super.key, this.height = 16, this.width, this.radius = 12});

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => Container(
        height: widget.height,
        width: widget.width,
        decoration: BoxDecoration(
          color: AppColors.track.withOpacity(0.5 + 0.5 * _c.value),
          borderRadius: BorderRadius.circular(widget.radius),
        ),
      ),
    );
  }
}

/// A few skeleton cards, used instead of a spinner on list screens.
class SkeletonList extends StatelessWidget {
  final int count;

  const SkeletonList({super.key, this.count = 4});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: Space.pagePadding,
      children: [
        for (var i = 0; i < count; i++) ...[
          const AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Skeleton(height: 18, width: 160),
                SizedBox(height: 10),
                Skeleton(height: 12),
                SizedBox(height: 6),
                Skeleton(height: 12, width: 220),
              ],
            ),
          ),
          const SizedBox(height: Space.gap),
        ],
      ],
    );
  }
}

/// Number that counts up to its value (used for calories, XP, streaks).
class CountUp extends StatelessWidget {
  final num value;
  final TextStyle? style;
  final String suffix;

  const CountUp({super.key, required this.value, this.style, this.suffix = ''});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: value.toDouble()),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => Text('${v.round()}$suffix', style: style),
    );
  }
}

/// Asset picture that keeps its real colours in dark mode.
class AppImage extends StatelessWidget {
  final String path;
  final double? width;
  final double? height;
  final BoxFit? fit;

  const AppImage(this.path, {super.key, this.width, this.height, this.fit});

  @override
  Widget build(BuildContext context) {
    return ThemeService.undoDark(
      context,
      Image.asset(path, width: width, height: height, fit: fit),
    );
  }
}
