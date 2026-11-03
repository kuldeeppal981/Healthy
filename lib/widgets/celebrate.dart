import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

/// Confetti burst over the whole screen for about 1.6 seconds.
/// Call `Celebrate.show(context)` after a win (check-in, workout done).
class Celebrate {
  static void show(BuildContext context) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => IgnorePointer(child: _Confetti(onDone: () => entry.remove())),
    );
    overlay.insert(entry);
  }
}

class _Confetti extends StatefulWidget {
  final VoidCallback onDone;
  const _Confetti({required this.onDone});

  @override
  State<_Confetti> createState() => _ConfettiState();
}

class _ConfettiState extends State<_Confetti> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final List<_Piece> _pieces;

  @override
  void initState() {
    super.initState();
    final r = math.Random();
    final colors = [
      AppColors.primary,
      const Color(0xFFF59E0B),
      const Color(0xFF2563EB),
      const Color(0xFFEC4899),
      const Color(0xFF22C55E),
    ];
    _pieces = List.generate(70, (i) {
      return _Piece(
        x: r.nextDouble(),
        vx: (r.nextDouble() - 0.5) * 0.5,
        vy: 0.5 + r.nextDouble() * 0.9,
        size: 5 + r.nextDouble() * 6,
        spin: r.nextDouble() * 8,
        color: colors[r.nextInt(colors.length)],
      );
    });
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))
      ..addStatusListener((st) {
        if (st == AnimationStatus.completed) widget.onDone();
      })
      ..forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => CustomPaint(
        size: Size.infinite,
        painter: _ConfettiPainter(_pieces, _c.value),
      ),
    );
  }
}

class _Piece {
  final double x, vx, vy, size, spin;
  final Color color;
  _Piece({
    required this.x,
    required this.vx,
    required this.vy,
    required this.size,
    required this.spin,
    required this.color,
  });
}

class _ConfettiPainter extends CustomPainter {
  final List<_Piece> pieces;
  final double t;
  _ConfettiPainter(this.pieces, this.t);

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in pieces) {
      final y = -20 + (size.height * 0.9) * p.vy * t * t * 1.2 + 120 * t;
      final x = size.width * (p.x + p.vx * t);
      final fade = t < 0.7 ? 1.0 : (1 - (t - 0.7) / 0.3).clamp(0.0, 1.0).toDouble();
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.spin * t * 3);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.55),
          const Radius.circular(2),
        ),
        Paint()..color = p.color.withOpacity(fade),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter old) => old.t != t;
}
