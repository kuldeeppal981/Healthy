import 'package:flutter/material.dart';

import '../theme.dart';

/// Stick figures for yoga poses, drawn with CustomPaint (no image files).
/// Points are on a 120 x 100 canvas; ground line at y = 90.
class _Pose {
  final Offset head;
  final List<List<Offset>> lines;
  const _Pose(this.head, this.lines);
}

Offset _o(double x, double y) => Offset(x, y);

final Map<String, _Pose> _poses = {
  'Mountain pose (Tadasana)': _Pose(_o(60, 17), [
    [_o(60, 25), _o(60, 56)], [_o(60, 30), _o(52, 56)], [_o(60, 30), _o(68, 56)],
    [_o(60, 56), _o(55, 88)], [_o(60, 56), _o(65, 88)],
  ]),
  'Tree pose (Vrikshasana)': _Pose(_o(60, 17), [
    [_o(60, 25), _o(60, 56)], [_o(60, 30), _o(52, 38), _o(60, 36)],
    [_o(60, 30), _o(68, 38), _o(60, 36)], [_o(60, 56), _o(58, 88)],
    [_o(60, 56), _o(80, 66), _o(62, 72)],
  ]),
  'Warrior II (Virabhadrasana II)': _Pose(_o(60, 19), [
    [_o(60, 27), _o(60, 58)], [_o(60, 32), _o(18, 32)], [_o(60, 32), _o(102, 32)],
    [_o(60, 58), _o(88, 64), _o(88, 88)], [_o(60, 58), _o(28, 88)],
  ]),
  'Chair pose (Utkatasana)': _Pose(_o(52, 20), [
    [_o(52, 28), _o(44, 60)], [_o(52, 32), _o(70, 10)], [_o(52, 32), _o(62, 8)],
    [_o(44, 60), _o(72, 64), _o(68, 88)],
  ]),
  'Cobra pose (Bhujangasana)': _Pose(_o(80, 50), [
    [_o(72, 64), _o(38, 86)], [_o(72, 64), _o(66, 88)], [_o(38, 86), _o(8, 88)],
  ]),
  'Child pose (Balasana)': _Pose(_o(86, 80), [
    [_o(30, 78), _o(78, 82)], [_o(78, 82), _o(106, 88)],
    [_o(30, 78), _o(46, 88), _o(18, 88)],
  ]),
  'Downward dog (Adho Mukha Svanasana)': _Pose(_o(82, 64), [
    [_o(72, 56), _o(52, 34)], [_o(72, 56), _o(92, 88)],
    [_o(52, 34), _o(24, 88)], [_o(52, 34), _o(18, 88)],
  ]),
  'Bridge pose (Setu Bandhasana)': _Pose(_o(14, 82), [
    [_o(22, 88), _o(50, 50)], [_o(50, 50), _o(72, 56), _o(86, 88)],
    [_o(22, 88), _o(8, 88)],
  ]),
  'Easy seat (Sukhasana)': _Pose(_o(60, 34), [
    [_o(60, 42), _o(60, 74)], [_o(60, 48), _o(40, 72)], [_o(60, 48), _o(80, 72)],
    [_o(60, 74), _o(28, 84), _o(52, 86)], [_o(60, 74), _o(92, 84), _o(68, 86)],
  ]),
  'Surya Namaskar (Sun salutation)': _Pose(_o(60, 17), [
    [_o(60, 25), _o(60, 56)], [_o(60, 30), _o(54, 12), _o(60, 3)],
    [_o(60, 30), _o(66, 12), _o(60, 3)], [_o(60, 56), _o(55, 88)],
    [_o(60, 56), _o(65, 88)],
  ]),
};

bool hasYogaFigure(String name) => _poses.containsKey(name);

class YogaFigure extends StatelessWidget {
  final String name;
  final bool woman;
  final double height;

  const YogaFigure({super.key, required this.name, required this.woman, this.height = 130});

  @override
  Widget build(BuildContext context) {
    final p = _poses[name];
    if (p == null) return const SizedBox.shrink();
    return SizedBox(
      height: height,
      width: height * 1.2,
      child: CustomPaint(painter: _FigurePainter(p, woman, AppColors.primary)),
    );
  }
}

class _FigurePainter extends CustomPainter {
  final _Pose pose;
  final bool woman;
  final Color color;

  _FigurePainter(this.pose, this.woman, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / 120;
    Offset s(Offset p) => Offset(p.dx * k, p.dy * k);
    final ground = Paint()
      ..color = color.withOpacity(0.3)
      ..strokeWidth = 2 * k
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(s(_o(0, 90)), s(_o(120, 90)), ground);
    final line = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5 * k
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (final l in pose.lines) {
      final path = Path()..moveTo(s(l.first).dx, s(l.first).dy);
      for (final p in l.skip(1)) {
        path.lineTo(s(p).dx, s(p).dy);
      }
      canvas.drawPath(path, line);
    }
    canvas.drawCircle(s(pose.head), 8 * k, Paint()..color = color);
    if (woman) {
      final h = pose.head;
      final tail = Path()
        ..moveTo(s(_o(h.dx + 6, h.dy - 5)).dx, s(_o(h.dx + 6, h.dy - 5)).dy)
        ..quadraticBezierTo(s(_o(h.dx - 8, h.dy - 5)).dx, s(_o(h.dx - 8, h.dy - 5)).dy,
            s(_o(h.dx - 6, h.dy + 9)).dx, s(_o(h.dx - 6, h.dy + 9)).dy);
      canvas.drawPath(tail, line..strokeWidth = 4 * k);
    }
  }

  @override
  bool shouldRepaint(covariant _FigurePainter old) =>
      old.pose != pose || old.woman != woman || old.color != color;
}
