import 'package:flutter/material.dart';

enum FoodKind { bowl, thali, chai, apple }

/// Small flat food drawings (no image files needed). Drawn in a 48x48 box.
class FoodArt extends StatelessWidget {
  final FoodKind kind;
  final double size;

  const FoodArt(this.kind, {super.key, this.size = 34});

  /// Picks a drawing from the food name, or null when nothing fits.
  static FoodKind? kindFor(String name) {
    final n = name.toLowerCase();
    bool has(List<String> w) => w.any(n.contains);
    if (has(['chai', 'tea', 'coffee', 'milk', 'lassi'])) return FoodKind.chai;
    if (has(['apple', 'banana', 'fruit', 'orange', 'mango', 'papaya', 'guava'])) {
      return FoodKind.apple;
    }
    if (has(['poha', 'upma', 'rice', 'khichdi', 'oats', 'idli', 'dosa', 'curry', 'soup', 'biryani'])) {
      return FoodKind.bowl;
    }
    if (has(['roti', 'dal', 'chapati', 'paratha', 'thali', 'sabzi', 'paneer', 'egg'])) {
      return FoodKind.thali;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _FoodPainter(kind)),
    );
  }
}

class _FoodPainter extends CustomPainter {
  final FoodKind kind;
  _FoodPainter(this.kind);

  Paint _fill(int c) => Paint()..color = Color(c);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 48, size.height / 48);
    switch (kind) {
      case FoodKind.bowl:
        canvas.drawOval(const Rect.fromLTWH(10, 14, 28, 16), _fill(0xFFFCD34D));
        for (final o in const [Offset(18, 20), Offset(26, 18), Offset(30, 23)]) {
          canvas.drawCircle(o, 1.6, _fill(0xFFB45309));
        }
        canvas.drawCircle(const Offset(21, 25), 1.6, _fill(0xFF16A34A));
        final bowl = Path()
          ..moveTo(7, 25)
          ..lineTo(41, 25)
          ..arcToPoint(const Offset(7, 25),
              radius: const Radius.elliptical(17, 14), clockwise: true)
          ..close();
        canvas.drawPath(bowl, _fill(0xFFFB923C));
        break;
      case FoodKind.thali:
        canvas.drawCircle(const Offset(24, 24), 18, _fill(0xFFFFFFFF));
        canvas.drawCircle(
            const Offset(24, 24),
            18,
            Paint()
              ..color = const Color(0xFFD5D9E0)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2);
        canvas.drawCircle(const Offset(17, 20), 7, _fill(0xFFF59E0B));
        canvas.drawCircle(const Offset(17, 20), 3.5, _fill(0xFFFCD34D));
        canvas.drawCircle(const Offset(31, 19), 6.5, _fill(0xFFD6A05B));
        canvas.drawCircle(const Offset(31, 19), 4, _fill(0xFFE9BE80));
        canvas.drawCircle(const Offset(25, 32), 5.5, _fill(0xFF22C55E));
        break;
      case FoodKind.chai:
        final steam = Paint()
          ..color = const Color(0xFFF59E0B)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round;
        canvas.drawPath(
            Path()
              ..moveTo(15, 6)
              ..quadraticBezierTo(12, 9, 15, 13),
            steam);
        canvas.drawPath(
            Path()
              ..moveTo(22, 5)
              ..quadraticBezierTo(19, 9, 22, 13),
            steam);
        canvas.drawArc(const Rect.fromLTWH(31, 20, 9, 9), -1.57, 3.14, false,
            Paint()
              ..color = const Color(0xFFE5B88A)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2);
        final cup = Path()
          ..moveTo(9, 18)
          ..lineTo(35, 18)
          ..lineTo(35, 28)
          ..arcToPoint(const Offset(24, 39), radius: const Radius.circular(11))
          ..lineTo(20, 39)
          ..arcToPoint(const Offset(9, 28), radius: const Radius.circular(11))
          ..close();
        canvas.drawPath(cup, _fill(0xFFFFFFFF));
        canvas.drawPath(
            cup,
            Paint()
              ..color = const Color(0xFFE5B88A)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2);
        canvas.drawRRect(
            RRect.fromRectAndRadius(const Rect.fromLTWH(11, 21, 22, 6), const Radius.circular(3)),
            _fill(0xFFB45309));
        break;
      case FoodKind.apple:
        final apple = Path()
          ..moveTo(24, 12)
          ..cubicTo(18, 7, 8, 11, 10, 21)
          ..cubicTo(12, 31, 19, 39, 24, 39)
          ..cubicTo(29, 39, 36, 31, 38, 21)
          ..cubicTo(40, 11, 30, 7, 24, 12)
          ..close();
        canvas.drawPath(apple, _fill(0xFFEF4444));
        canvas.drawPath(
            Path()
              ..moveTo(24, 12)
              ..quadraticBezierTo(24, 6, 30, 4),
            Paint()
              ..color = const Color(0xFF16A34A)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3
              ..strokeCap = StrokeCap.round);
        canvas.drawOval(const Rect.fromLTWH(27, 5, 10, 6), _fill(0xFF22C55E));
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _FoodPainter old) => old.kind != kind;
}
