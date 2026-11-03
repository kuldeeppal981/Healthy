import 'package:flutter/material.dart';

import '../theme.dart';

/// Small drawings used on the cards (shoe, water glass, dumbbell, shaker).
/// They are painted in code, so they follow the theme colour, stay sharp at
/// any size and look right in dark mode (no picture frames or white boxes).

class ShoeArt extends StatelessWidget {
  final double width;
  const ShoeArt({super.key, this.width = 76});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: width * 0.64,
      child: CustomPaint(painter: _ShoePainter()),
    );
  }
}

class _ShoePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 100, size.height / 64);
    final upper = Path()
      ..moveTo(6, 48)
      ..lineTo(6, 18)
      ..quadraticBezierTo(6, 10, 14, 10)
      ..lineTo(30, 10)
      ..quadraticBezierTo(37, 10, 39, 17)
      ..lineTo(42, 26)
      ..quadraticBezierTo(50, 35, 66, 37)
      ..quadraticBezierTo(94, 39, 94, 50)
      ..lineTo(6, 50)
      ..close();
    canvas.drawPath(
      upper,
      Paint()
        ..shader = LinearGradient(
          colors: [AppColors.primaryLight, AppColors.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(const Rect.fromLTWH(0, 0, 100, 64)),
    );
    // Sole
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTRB(3, 46, 97, 58), const Radius.circular(6)),
      Paint()..color = const Color(0xFFF1F5F2),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTRB(3, 46, 97, 58), const Radius.circular(6)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = const Color(0xFFCFE0D5),
    );
    // Laces and side stripe
    final lace = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(40, 21), const Offset(50, 26), lace);
    canvas.drawLine(const Offset(46, 27), const Offset(57, 31), lace);
    canvas.drawLine(const Offset(53, 33), const Offset(64, 35), lace);
    canvas.drawPath(
      Path()
        ..moveTo(14, 40)
        ..quadraticBezierTo(40, 38, 74, 44),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..color = Colors.white.withOpacity(0.7),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class GlassArt extends StatelessWidget {
  final double width;
  const GlassArt({super.key, this.width = 56});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: width * 1.1,
      child: CustomPaint(painter: _GlassPainter()),
    );
  }
}

class _GlassPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 60, size.height / 66);
    final glass = Path()
      ..moveTo(8, 6)
      ..lineTo(52, 6)
      ..lineTo(46, 60)
      ..quadraticBezierTo(45.5, 63, 42, 63)
      ..lineTo(18, 63)
      ..quadraticBezierTo(14.5, 63, 14, 60)
      ..close();
    canvas.drawPath(glass, Paint()..color = const Color(0xFFE0F2FE));
    // Water
    final water = Path()
      ..moveTo(10.3, 26)
      ..quadraticBezierTo(20, 21, 30, 26)
      ..quadraticBezierTo(40, 31, 49.7, 26)
      ..lineTo(46, 60)
      ..quadraticBezierTo(45.5, 63, 42, 63)
      ..lineTo(18, 63)
      ..quadraticBezierTo(14.5, 63, 14, 60)
      ..close();
    canvas.drawPath(
      water,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF7DD3FC), Color(0xFF0284C7)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(const Rect.fromLTWH(0, 20, 60, 46)),
    );
    // Shine and bubbles
    canvas.drawLine(
      const Offset(17, 12),
      const Offset(19.5, 50),
      Paint()
        ..color = Colors.white.withOpacity(0.7)
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
    final bubble = Paint()..color = Colors.white.withOpacity(0.65);
    canvas.drawCircle(const Offset(34, 44), 2.4, bubble);
    canvas.drawCircle(const Offset(40, 36), 1.8, bubble);
    canvas.drawCircle(const Offset(30, 52), 1.6, bubble);
    canvas.drawPath(
      glass,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round
        ..color = const Color(0xFF38BDF8),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Soft white dumbbell for gradient banners.
class DumbbellArt extends StatelessWidget {
  final double width;
  final double opacity;
  const DumbbellArt({super.key, this.width = 110, this.opacity = 0.28});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: width * 0.5,
      child: CustomPaint(painter: _DumbbellPainter(opacity)),
    );
  }
}

class _DumbbellPainter extends CustomPainter {
  final double opacity;
  const _DumbbellPainter(this.opacity);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 100, size.height / 50);
    final p = Paint()..color = Colors.white.withOpacity(opacity);
    canvas.drawRRect(
        RRect.fromRectAndRadius(const Rect.fromLTRB(24, 21, 76, 29), const Radius.circular(3)), p);
    for (final r in const [
      Rect.fromLTRB(4, 14, 12, 36),
      Rect.fromLTRB(12, 6, 24, 44),
      Rect.fromLTRB(76, 6, 88, 44),
      Rect.fromLTRB(88, 14, 96, 36),
    ]) {
      canvas.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(4)), p);
    }
  }

  @override
  bool shouldRepaint(covariant _DumbbellPainter old) => old.opacity != opacity;
}

/// Protein shaker bottle.
class ShakerArt extends StatelessWidget {
  final double height;
  const ShakerArt({super.key, this.height = 74});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: height * 0.6,
      height: height,
      child: CustomPaint(painter: _ShakerPainter()),
    );
  }
}

class _ShakerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 48, size.height / 80);
    // Lid
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTRB(10, 4, 38, 16), const Radius.circular(5)),
      Paint()..color = const Color(0xFF1F2937),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTRB(18, 0, 30, 6), const Radius.circular(3)),
      Paint()..color = const Color(0xFF374151),
    );
    // Body
    final body = RRect.fromRectAndCorners(
      const Rect.fromLTRB(6, 14, 42, 76),
      topLeft: const Radius.circular(6),
      topRight: const Radius.circular(6),
      bottomLeft: const Radius.circular(12),
      bottomRight: const Radius.circular(12),
    );
    canvas.drawRRect(
      body,
      Paint()
        ..shader = LinearGradient(
          colors: [AppColors.primaryLight, AppColors.primaryDeep],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(const Rect.fromLTWH(0, 0, 48, 80)),
    );
    // Label and shine
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTRB(12, 32, 36, 56), const Radius.circular(6)),
      Paint()..color = Colors.white.withOpacity(0.9),
    );
    final mark = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(24, 38), const Offset(24, 46), mark);
    canvas.drawCircle(const Offset(24, 51), 1.8, Paint()..color = AppColors.primary);
    canvas.drawLine(
      const Offset(11, 22),
      const Offset(11, 68),
      Paint()
        ..color = Colors.white.withOpacity(0.35)
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
