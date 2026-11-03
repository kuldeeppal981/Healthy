import 'package:flutter/material.dart';

import '../theme.dart';

/// Smooth line chart with a soft fill, guide lines and min/max labels
/// (for example weight over time).
class Sparkline extends StatelessWidget {
  final List<double> values;
  final Color color;
  final double height;

  const Sparkline({
    super.key,
    required this.values,
    required this.color,
    this.height = 110,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: TweenAnimationBuilder<double>(
        key: ValueKey(values.length),
        tween: Tween<double>(begin: 0, end: 1),
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeOutCubic,
        builder: (context, t, _) =>
            CustomPaint(painter: _SparkPainter(values, color, t)),
      ),
    );
  }
}

class _SparkPainter extends CustomPainter {
  final List<double> values;
  final Color color;
  final double t;

  _SparkPainter(this.values, this.color, this.t);

  void _label(Canvas canvas, String text, Offset at, {bool right = false}) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(fontSize: 10, color: Color(0xFF8A94A0)),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, right ? Offset(at.dx - tp.width, at.dy) : at);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;

    var minV = values.first;
    var maxV = values.first;
    for (final v in values) {
      if (v < minV) minV = v;
      if (v > maxV) maxV = v;
    }
    final range = (maxV - minV) < 0.5 ? 0.5 : (maxV - minV);
    const padX = 10.0;
    const padTop = 16.0;
    const padBottom = 10.0;
    final w = size.width - padX * 2;
    final h = size.height - padTop - padBottom;

    Offset pointAt(int i) {
      final x = padX + w * i / (values.length - 1);
      final y = padTop + h * (1 - (values[i] - minV) / range);
      return Offset(x, y);
    }

    // Guide lines.
    final guide = Paint()
      ..color = color.withOpacity(0.10)
      ..strokeWidth = 1;
    for (var k = 0; k < 3; k++) {
      final y = padTop + h * k / 2;
      canvas.drawLine(Offset(padX, y), Offset(size.width - padX, y), guide);
    }

    // Smooth path.
    final pts = [for (var i = 0; i < values.length; i++) pointAt(i)];
    final line = Path()..moveTo(pts[0].dx, pts[0].dy);
    for (var i = 1; i < pts.length; i++) {
      final mid = (pts[i - 1].dx + pts[i].dx) / 2;
      line.cubicTo(mid, pts[i - 1].dy, mid, pts[i].dy, pts[i].dx, pts[i].dy);
    }

    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width * t, size.height));

    // Soft fill under the line.
    final fill = Path.from(line)
      ..lineTo(pts.last.dx, size.height)
      ..lineTo(pts.first.dx, size.height)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withOpacity(0.28), color.withOpacity(0.0)],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );

    canvas.drawPath(
      line,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.restore();

    // End dot with a white ring, and labels.
    if (t > 0.98) {
      final last = pts.last;
      canvas.drawCircle(last, 8, Paint()..color = AppColors.card);
      canvas.drawCircle(last, 5.5, Paint()..color = color);
    }
    _label(canvas, maxV.toStringAsFixed(1), const Offset(padX, 0));
    _label(canvas, minV.toStringAsFixed(1), Offset(padX, size.height - 12));
  }

  @override
  bool shouldRepaint(_SparkPainter old) =>
      old.values != values || old.color != color || old.t != t;
}
