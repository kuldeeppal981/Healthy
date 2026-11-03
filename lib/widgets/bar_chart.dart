import 'package:flutter/material.dart';

import '../theme.dart';

/// A card with a title, a short summary and an animated bar chart.
/// Bars grow when the card appears, today (the last bar) is the strongest,
/// and a dashed line marks the goal.
class BarChartCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final String summary; // for example "Avg 1,820 kcal"
  final String? note; // small line under the chart
  final List<double> values;
  final List<String> labels;
  final double? target;
  final Color color;
  final bool showValues;

  const BarChartCard({
    super.key,
    required this.title,
    required this.icon,
    required this.summary,
    required this.values,
    required this.labels,
    required this.color,
    this.target,
    this.note,
    this.showValues = true,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(title,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(summary,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 150,
            width: double.infinity,
            child: TweenAnimationBuilder<double>(
              key: ValueKey('$title-${values.length}-${values.fold<double>(0, (a, b) => a + b).round()}'),
              tween: Tween<double>(begin: 0, end: 1),
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOutCubic,
              builder: (context, t, _) => CustomPaint(
                painter: _BarPainter(
                  values: values,
                  labels: labels,
                  target: target,
                  color: color,
                  t: t,
                  showValues: showValues && values.length <= 7,
                ),
              ),
            ),
          ),
          if (note != null) ...[
            const SizedBox(height: 8),
            Text(note!, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
          ],
        ],
      ),
    );
  }
}

class _BarPainter extends CustomPainter {
  final List<double> values;
  final List<String> labels;
  final double? target;
  final Color color;
  final double t;
  final bool showValues;

  _BarPainter({
    required this.values,
    required this.labels,
    required this.target,
    required this.color,
    required this.t,
    required this.showValues,
  });

  void _text(Canvas canvas, String s, Offset center, double size, Color c, FontWeight w) {
    final tp = TextPainter(
      text: TextSpan(text: s, style: TextStyle(fontSize: size, color: c, fontWeight: w)),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(center.dx - tp.width / 2, center.dy - tp.height / 2));
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    const labelH = 20.0;
    const topPad = 16.0;
    final chartH = size.height - labelH - topPad;
    final n = values.length;
    var maxV = 0.0;
    for (final v in values) {
      if (v > maxV) maxV = v;
    }
    if (target != null && target! > maxV) maxV = target!;
    if (maxV <= 0) maxV = 1;
    maxV *= 1.1;
    final slot = size.width / n;
    final barW = (slot * 0.58).clamp(4.0, 34.0).toDouble();
    final base = topPad + chartH;

    // Goal line
    if (target != null) {
      final y = base - chartH * (target! / maxV);
      final dash = Paint()
        ..color = AppColors.muted.withOpacity(0.55)
        ..strokeWidth = 1.2;
      for (var x = 0.0; x < size.width; x += 8) {
        canvas.drawLine(Offset(x, y), Offset(x + 4, y), dash);
      }
    }

    final labelEvery = n <= 8 ? 1 : (n / 6).ceil();
    for (var i = 0; i < n; i++) {
      final cx = slot * i + slot / 2;
      final v = values[i];
      final isLast = i == n - 1;
      // Track
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(cx - barW / 2, topPad, barW, chartH),
          const Radius.circular(8),
        ),
        Paint()..color = color.withOpacity(0.07),
      );
      if (v > 0) {
        final h = (chartH * v / maxV * t).clamp(4.0, chartH).toDouble();
        final rect = Rect.fromLTWH(cx - barW / 2, base - h, barW, h);
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(8)),
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                color.withOpacity(isLast ? 1.0 : 0.75),
                color.withOpacity(isLast ? 0.7 : 0.4),
              ],
            ).createShader(rect),
        );
        if (showValues && t > 0.9) {
          _text(canvas, v >= 1000 ? '${(v / 1000).toStringAsFixed(1)}k' : '${v.round()}',
              Offset(cx, base - h - 8), 9.5, AppColors.muted, FontWeight.w600);
        }
      }
      if (i % labelEvery == 0 || isLast) {
        _text(canvas, labels[i], Offset(cx, size.height - labelH / 2 + 2), 10.5,
            isLast ? AppColors.ink : AppColors.muted,
            isLast ? FontWeight.w800 : FontWeight.w500);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BarPainter old) => true;
}
