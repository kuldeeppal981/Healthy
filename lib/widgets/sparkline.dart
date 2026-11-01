import 'package:flutter/material.dart';

/// Small line chart for a list of values (for example weight over time).
class Sparkline extends StatelessWidget {
  final List<double> values;
  final Color color;
  final double height;

  const Sparkline({
    super.key,
    required this.values,
    required this.color,
    this.height = 80,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(painter: _SparkPainter(values, color)),
    );
  }
}

class _SparkPainter extends CustomPainter {
  final List<double> values;
  final Color color;

  _SparkPainter(this.values, this.color);

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
    const pad = 8.0;
    final w = size.width - pad * 2;
    final h = size.height - pad * 2;

    Offset pointAt(int i) {
      final x = pad + w * i / (values.length - 1);
      final y = pad + h * (1 - (values[i] - minV) / range);
      return Offset(x, y);
    }

    final line = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path()..moveTo(pointAt(0).dx, pointAt(0).dy);
    for (var i = 1; i < values.length; i++) {
      final p = pointAt(i);
      path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(path, line);

    final dot = Paint()..color = color;
    canvas.drawCircle(pointAt(values.length - 1), 5, dot);
  }

  @override
  bool shouldRepaint(_SparkPainter old) => old.values != values || old.color != color;
}
