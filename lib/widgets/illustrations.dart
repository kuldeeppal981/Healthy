import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

enum ArtKind { shield, heart, report, flame, crown }

/// Small hand-drawn header pictures (no image files). They follow the theme colour.
class HeroArt extends StatelessWidget {
  final ArtKind kind;
  final double size;
  const HeroArt(this.kind, {super.key, this.size = 120});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size * 1.5,
      height: size,
      child: CustomPaint(painter: _ArtPainter(kind, AppColors.primary, AppColors.primaryDeep, AppColors.chipBg)),
    );
  }
}

/// Picture, title, one line and an optional outlined button (empty states and screen headers).
class HeroHeader extends StatelessWidget {
  final ArtKind kind;
  final String title;
  final String subtitle;
  final String? buttonLabel;
  final VoidCallback? onPressed;
  const HeroHeader({
    super.key,
    required this.kind,
    required this.title,
    required this.subtitle,
    this.buttonLabel,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        HeroArt(kind),
        const SizedBox(height: 6),
        Text(title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: AppColors.muted, height: 1.35)),
        if (buttonLabel != null) ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 44),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            ),
            onPressed: onPressed,
            icon: const Icon(Icons.add, size: 20),
            label: Text(buttonLabel!),
          ),
        ],
        const SizedBox(height: 8),
      ],
    );
  }
}

class _ArtPainter extends CustomPainter {
  final ArtKind kind;
  final Color c;
  final Color deep;
  final Color soft;
  _ArtPainter(this.kind, this.c, this.deep, this.soft);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final mid = Offset(w / 2, h / 2);
    // soft blobs and dots behind every picture
    final blob = Paint()
      ..color = kind == ArtKind.crown ? Colors.white.withOpacity(0.14) : soft.withOpacity(0.9);
    canvas.drawCircle(Offset(mid.dx - h * 0.42, mid.dy + h * 0.08), h * 0.34, blob);
    canvas.drawCircle(Offset(mid.dx + h * 0.4, mid.dy - h * 0.02), h * 0.3, blob);
    final dot = Paint()
      ..color = kind == ArtKind.crown ? Colors.white.withOpacity(0.4) : c.withOpacity(0.35);
    canvas.drawCircle(Offset(mid.dx - h * 0.62, mid.dy - h * 0.2), 5, dot);
    canvas.drawCircle(Offset(mid.dx + h * 0.66, mid.dy - h * 0.3), 4, dot);
    canvas.drawCircle(Offset(mid.dx + h * 0.55, mid.dy + h * 0.34), 6, dot);

    final fill = Paint()
      ..shader = LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [c, deep])
          .createShader(Rect.fromCenter(center: mid, width: h * 0.7, height: h * 0.8));
    final white = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = h * 0.05
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    switch (kind) {
      case ArtKind.shield:
        final r = h * 0.38;
        final p = Path()
          ..moveTo(mid.dx, mid.dy - r)
          ..quadraticBezierTo(mid.dx + r * 0.2, mid.dy - r * 0.8, mid.dx + r * 0.85, mid.dy - r * 0.8)
          ..quadraticBezierTo(mid.dx + r * 0.95, mid.dy + r * 0.45, mid.dx, mid.dy + r)
          ..quadraticBezierTo(mid.dx - r * 0.95, mid.dy + r * 0.45, mid.dx - r * 0.85, mid.dy - r * 0.8)
          ..quadraticBezierTo(mid.dx - r * 0.2, mid.dy - r * 0.8, mid.dx, mid.dy - r)
          ..close();
        canvas.drawPath(p, fill);
        // leaf
        final lf = Path()
          ..moveTo(mid.dx - r * 0.32, mid.dy + r * 0.3)
          ..quadraticBezierTo(mid.dx - r * 0.5, mid.dy - r * 0.35, mid.dx + r * 0.3, mid.dy - r * 0.38)
          ..quadraticBezierTo(mid.dx + r * 0.35, mid.dy + r * 0.3, mid.dx - r * 0.32, mid.dy + r * 0.3)
          ..close();
        canvas.drawPath(lf, white);
        canvas.drawLine(Offset(mid.dx - r * 0.32, mid.dy + r * 0.3),
            Offset(mid.dx + r * 0.05, mid.dy - r * 0.05), white);
        break;
      case ArtKind.heart:
        final r = h * 0.36;
        final p = Path()
          ..moveTo(mid.dx, mid.dy + r)
          ..cubicTo(mid.dx - r * 1.7, mid.dy - r * 0.2, mid.dx - r * 0.9, mid.dy - r * 1.3, mid.dx, mid.dy - r * 0.45)
          ..cubicTo(mid.dx + r * 0.9, mid.dy - r * 1.3, mid.dx + r * 1.7, mid.dy - r * 0.2, mid.dx, mid.dy + r)
          ..close();
        canvas.drawPath(p, fill);
        final pulse = Path()
          ..moveTo(mid.dx - r * 0.95, mid.dy + r * 0.05)
          ..lineTo(mid.dx - r * 0.4, mid.dy + r * 0.05)
          ..lineTo(mid.dx - r * 0.2, mid.dy - r * 0.35)
          ..lineTo(mid.dx + r * 0.1, mid.dy + r * 0.5)
          ..lineTo(mid.dx + r * 0.3, mid.dy + r * 0.05)
          ..lineTo(mid.dx + r * 0.95, mid.dy + r * 0.05);
        canvas.drawPath(pulse, white);
        break;
      case ArtKind.report:
        final rect = RRect.fromRectAndRadius(
            Rect.fromCenter(center: mid, width: h * 0.62, height: h * 0.8), Radius.circular(h * 0.08));
        canvas.drawRRect(rect, Paint()..color = Colors.white);
        canvas.drawRRect(
            rect,
            Paint()
              ..color = c
              ..style = PaintingStyle.stroke
              ..strokeWidth = h * 0.035);
        final plus = Paint()
          ..color = c
          ..strokeWidth = h * 0.07
          ..strokeCap = StrokeCap.round;
        final pc = Offset(mid.dx, mid.dy - h * 0.2);
        canvas.drawLine(pc.translate(-h * 0.1, 0), pc.translate(h * 0.1, 0), plus);
        canvas.drawLine(pc.translate(0, -h * 0.1), pc.translate(0, h * 0.1), plus);
        final line = Paint()
          ..color = c.withOpacity(0.35)
          ..strokeWidth = h * 0.035
          ..strokeCap = StrokeCap.round;
        for (var i = 0; i < 3; i++) {
          final y = mid.dy + h * 0.02 + i * h * 0.1;
          canvas.drawLine(Offset(mid.dx - h * 0.2, y), Offset(mid.dx + h * (i == 2 ? 0.05 : 0.2), y), line);
        }
        canvas.drawCircle(Offset(mid.dx + h * 0.27, mid.dy + h * 0.3), h * 0.1, fill);
        final tick = Path()
          ..moveTo(mid.dx + h * 0.22, mid.dy + h * 0.3)
          ..lineTo(mid.dx + h * 0.26, mid.dy + h * 0.34)
          ..lineTo(mid.dx + h * 0.33, mid.dy + h * 0.25);
        canvas.drawPath(tick, white..strokeWidth = h * 0.025);
        break;
      case ArtKind.flame:
        final r = h * 0.4;
        final flame = Path()
          ..moveTo(mid.dx, mid.dy - r)
          ..cubicTo(mid.dx + r * 0.2, mid.dy - r * 0.5, mid.dx + r * 0.95, mid.dy - r * 0.1, mid.dx + r * 0.7, mid.dy + r * 0.55)
          ..cubicTo(mid.dx + r * 0.5, mid.dy + r * 1.05, mid.dx - r * 0.5, mid.dy + r * 1.05, mid.dx - r * 0.7, mid.dy + r * 0.55)
          ..cubicTo(mid.dx - r * 0.95, mid.dy - r * 0.05, mid.dx - r * 0.3, mid.dy - r * 0.35, mid.dx, mid.dy - r)
          ..close();
        canvas.drawPath(
            flame,
            Paint()
              ..shader = const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFFFFB300), Color(0xFFF4511E)])
                  .createShader(Rect.fromCenter(center: mid, width: h * 0.7, height: h * 0.9)));
        final inner = Path()
          ..moveTo(mid.dx, mid.dy + r * 0.1)
          ..cubicTo(mid.dx + r * 0.45, mid.dy + r * 0.35, mid.dx + r * 0.4, mid.dy + r * 0.85, mid.dx, mid.dy + r * 0.85)
          ..cubicTo(mid.dx - r * 0.4, mid.dy + r * 0.85, mid.dx - r * 0.45, mid.dy + r * 0.35, mid.dx, mid.dy + r * 0.1)
          ..close();
        canvas.drawPath(inner, Paint()..color = const Color(0xFFFFE082));
        break;
      case ArtKind.crown:
        final r = h * 0.4;
        final gold = Paint()
          ..shader = const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFFFD54F), Color(0xFFFFA000)])
              .createShader(Rect.fromCenter(center: mid, width: h * 0.9, height: h * 0.7));
        final p = Path()
          ..moveTo(mid.dx - r, mid.dy + r * 0.55)
          ..lineTo(mid.dx - r * 1.05, mid.dy - r * 0.5)
          ..lineTo(mid.dx - r * 0.45, mid.dy)
          ..lineTo(mid.dx, mid.dy - r * 0.75)
          ..lineTo(mid.dx + r * 0.45, mid.dy)
          ..lineTo(mid.dx + r * 1.05, mid.dy - r * 0.5)
          ..lineTo(mid.dx + r, mid.dy + r * 0.55)
          ..close();
        canvas.drawPath(p, gold);
        final gem = Paint()..color = Colors.white.withOpacity(0.85);
        canvas.drawCircle(Offset(mid.dx, mid.dy + r * 0.2), r * 0.1, gem);
        canvas.drawCircle(Offset(mid.dx - r * 0.5, mid.dy + r * 0.25), r * 0.07, gem);
        canvas.drawCircle(Offset(mid.dx + r * 0.5, mid.dy + r * 0.25), r * 0.07, gem);
        break;
    }
    // tiny sparkle
    final sp = Paint()
      ..color = c.withOpacity(0.5)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final sc = Offset(mid.dx + h * 0.48, mid.dy - h * 0.38);
    for (var i = 0; i < 2; i++) {
      final a = i * math.pi / 2;
      canvas.drawLine(sc + Offset(math.cos(a), math.sin(a)) * 7, sc - Offset(math.cos(a), math.sin(a)) * 7, sp);
    }
  }

  @override
  bool shouldRepaint(covariant _ArtPainter old) =>
      old.kind != kind || old.c != c || old.deep != deep || old.soft != soft;
}
