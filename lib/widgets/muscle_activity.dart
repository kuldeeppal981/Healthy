import 'package:flutter/material.dart';

import '../data/exercise_library.dart';
import '../services/muscle_stats.dart';
import '../theme.dart';
import 'muscle_art.dart';
import 'ui_kit.dart';

/// How much a muscle was trained in the chosen period.
/// none | attention | trained | high
String muscleStatus(int sets, int total) {
  if (sets <= 0 || total <= 0) return 'none';
  final share = sets / total;
  if (share >= 0.25) return 'high';
  if (sets < 3 || share < 0.08) return 'attention';
  return 'trained';
}

const _statusColors = <String, Color>{
  'none': Color(0xFFD5DADF),
  'attention': Color(0xFFF59E0B),
  'trained': Color(0xFF22C55E),
  'high': Color(0xFF2563EB),
};

const _statusNames = <String, String>{
  'none': 'Not trained',
  'attention': 'Needs attention',
  'trained': 'Trained',
  'high': 'High volume',
};

const _statusAdvice = <String, String>{
  'none': 'Not trained in this period. Try adding one exercise for it.',
  'attention': 'Low volume so far. One more exercise would balance things out.',
  'trained': 'Good volume. Keep it going.',
  'high': 'High volume. Make sure you rest this muscle and keep your form clean.',
};

// ---------------------------------------------------------------------------
// Body drawing. Everything is painted in code on a 100 x 230 canvas, so it
// follows the theme and needs no picture files.
// ---------------------------------------------------------------------------

Path _smooth(List<Offset> p) {
  final path = Path();
  final n = p.length;
  Offset mid(Offset a, Offset b) => Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);
  final start = mid(p[n - 1], p[0]);
  path.moveTo(start.dx, start.dy);
  for (var i = 0; i < n; i++) {
    final c = p[i];
    final m = mid(c, p[(i + 1) % n]);
    path.quadraticBezierTo(c.dx, c.dy, m.dx, m.dy);
  }
  path.close();
  return path;
}

List<Offset> _pts(List<double> xy) =>
    [for (var i = 0; i + 1 < xy.length; i += 2) Offset(xy[i], xy[i + 1])];

Offset _mir(Offset o) => Offset(100 - o.dx, o.dy);

/// A left-side shape and its mirror image on the right.
List<Path> _pair(List<double> xy) {
  final a = _pts(xy);
  return [_smooth(a), _smooth([for (final o in a) _mir(o)])];
}

/// One centred shape. [xy] runs down the left edge, first and last point on x = 50.
Path _sym(List<double> xy) {
  final a = _pts(xy);
  final inner = a.sublist(1, a.length - 1);
  return _smooth([...a, for (final o in inner.reversed) _mir(o)]);
}

List<(String, Path)> _regions(bool front) {
  final r = <(String, Path)>[];
  final delts = _pair(const [30, 39, 21, 40, 14, 48, 14, 58, 21, 60, 27, 52]);
  final arm = _pair(const [22, 60, 15, 63, 11, 75, 13, 85, 19, 85, 22, 73]);
  final calves = _pair(const [34, 172, 45, 172, 44, 196, 41, 212, 36, 206, 34, 190]);
  if (front) {
    for (final p in _pair(const [35, 124, 48, 124, 48, 146, 46, 168, 36, 168, 34, 146])) {
      r.add(('Legs', p));
    }
    for (final p in calves) {
      r.add(('Legs', p));
    }
    r.add(('Core', _sym(const [50, 68, 43, 68, 40, 80, 40, 96, 44, 112, 50, 114])));
    for (final p in _pair(const [50, 41, 40, 40, 31, 43, 28, 52, 33, 62, 42, 66, 50, 64])) {
      r.add(('Chest', p));
    }
    for (final p in delts) {
      r.add(('Shoulders', p));
    }
    for (final p in arm) {
      r.add(('Biceps', p));
    }
  } else {
    for (final p in _pair(const [34, 112, 50, 110, 50, 130, 40, 136, 33, 126])) {
      r.add(('Legs', p));
    }
    for (final p in _pair(const [35, 140, 48, 140, 48, 150, 46, 168, 36, 168, 34, 152])) {
      r.add(('Legs', p));
    }
    for (final p in calves) {
      r.add(('Legs', p));
    }
    r.add(('Back', _sym(const [50, 36, 40, 38, 30, 43, 30, 60, 34, 82, 42, 98, 50, 102])));
    for (final p in delts) {
      r.add(('Shoulders', p));
    }
    for (final p in arm) {
      r.add(('Triceps', p));
    }
  }
  return r;
}

class _BodyPainter extends CustomPainter {
  final bool front;
  final Map<String, Color> colors;
  final String? selected;

  _BodyPainter(this.front, this.colors, this.selected);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 100, size.height / 230);
    const fillColor = Color(0xFFE3E8EC);
    const lineColor = Color(0xFFC3CBD3);

    // Limbs: (from, to, width), left side, mirrored for the right side.
    const limbs = <(Offset, Offset, double)>[
      (Offset(22, 46), Offset(15, 82), 12),
      (Offset(15, 84), Offset(11, 116), 9),
      (Offset(42, 124), Offset(40, 168), 17),
      (Offset(40, 172), Offset(39, 212), 12),
    ];
    final torso = _sym(const [50, 38, 36, 38, 26, 41, 28, 60, 34, 84, 35, 104, 33, 120, 50, 124]);
    final shapes = <Path>[
      torso,
      Path()..addOval(Rect.fromCircle(center: const Offset(50, 16), radius: 11)),
      Path()..addRect(const Rect.fromLTRB(45, 24, 55, 38)),
      Path()..addOval(Rect.fromCircle(center: const Offset(10, 122), radius: 5)),
      Path()..addOval(Rect.fromCircle(center: const Offset(90, 122), radius: 5)),
      Path()..addOval(const Rect.fromLTRB(29, 216, 47, 225)),
      Path()..addOval(const Rect.fromLTRB(53, 216, 71, 225)),
    ];

    for (final pass in [0, 1]) {
      final lineP = Paint()
        ..color = pass == 0 ? lineColor : fillColor
        ..strokeCap = StrokeCap.round;
      for (final l in limbs) {
        lineP.strokeWidth = l.$3 + (pass == 0 ? 2 : 0);
        canvas.drawLine(l.$1, l.$2, lineP);
        canvas.drawLine(_mir(l.$1), _mir(l.$2), lineP);
      }
      for (final s in shapes) {
        if (pass == 0) {
          canvas.drawPath(
              s,
              Paint()
                ..style = PaintingStyle.stroke
                ..strokeWidth = 2
                ..color = lineColor);
        } else {
          canvas.drawPath(s, Paint()..color = fillColor);
        }
      }
    }

    for (final reg in _regions(front)) {
      final color = colors[reg.$1] ?? _statusColors['none']!;
      canvas.drawPath(reg.$2, Paint()..color = color);
      canvas.drawPath(
        reg.$2,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.9
          ..color = Colors.white.withOpacity(0.85),
      );
      if (reg.$1 == selected) {
        canvas.drawPath(
          reg.$2,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.8
            ..color = AppColors.ink,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BodyPainter old) => true;
}

class _Figure extends StatelessWidget {
  final bool front;
  final Map<String, Color> colors;
  final String? selected;
  final ValueChanged<String> onPick;

  const _Figure({
    required this.front,
    required this.colors,
    required this.selected,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final h = w * 2.3;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (d) {
            final p = Offset(d.localPosition.dx * 100 / w, d.localPosition.dy * 230 / h);
            for (final reg in _regions(front).reversed) {
              if (reg.$2.contains(p)) {
                onPick(reg.$1);
                return;
              }
            }
          },
          child: SizedBox(
            width: w,
            height: h,
            child: CustomPaint(painter: _BodyPainter(front, colors, selected)),
          ),
        );
      },
    );
  }
}

/// Front and back body figure coloured by training volume, the selected
/// muscle's details, the list of muscles and a balance tip.
class MuscleActivitySection extends StatefulWidget {
  /// Completed sets per tracked muscle in the chosen period.
  final Map<String, int> sets;

  const MuscleActivitySection({super.key, required this.sets});

  @override
  State<MuscleActivitySection> createState() => _MuscleActivitySectionState();
}

class _MuscleActivitySectionState extends State<MuscleActivitySection> {
  String? _sel;

  @override
  Widget build(BuildContext context) {
    final sets = widget.sets;
    final total = sets.values.fold<int>(0, (a, b) => a + b);
    var top = trackedMuscles.first;
    for (final m in trackedMuscles) {
      if ((sets[m] ?? 0) > (sets[top] ?? 0)) top = m;
    }
    final sel = (_sel != null && sets.containsKey(_sel)) ? _sel! : top;
    final status = {for (final m in trackedMuscles) m: muscleStatus(sets[m] ?? 0, total)};
    final colors = {for (final m in trackedMuscles) m: _statusColors[status[m]!]!};
    final missing = [for (final m in trackedMuscles) if ((sets[m] ?? 0) == 0) m];

    return Column(
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.chipBg,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(Icons.accessibility_new, color: AppColors.primary),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Muscle activity',
                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                        Text('Tap any muscle to see details',
                            style: TextStyle(fontSize: 12, color: AppColors.muted)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        _Figure(
                          front: true,
                          colors: colors,
                          selected: sel,
                          onPick: (m) => setState(() => _sel = m),
                        ),
                        const Text('Front',
                            style: TextStyle(fontSize: 12, color: AppColors.muted)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      children: [
                        _Figure(
                          front: false,
                          colors: colors,
                          selected: sel,
                          onPick: (m) => setState(() => _sel = m),
                        ),
                        const Text('Back',
                            style: TextStyle(fontSize: 12, color: AppColors.muted)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 14,
                runSpacing: 6,
                children: [
                  for (final k in const ['high', 'trained', 'attention', 'none'])
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration:
                              BoxDecoration(color: _statusColors[k], shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 6),
                        Text(_statusNames[k]!,
                            style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                      ],
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _detail(sel, sets[sel] ?? 0, total, status[sel]!),
        const SizedBox(height: 12),
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            children: [
              for (final m in trackedMuscles)
                _row(m, sets[m] ?? 0, total, status[m]!, m == sel),
            ],
          ),
        ),
        const SizedBox(height: 12),
        AppCard(
          color: AppColors.chipBg,
          borderColor: AppColors.chipBg,
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                child: Icon(Icons.lightbulb_outline, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Improve your muscle balance',
                        style: TextStyle(
                            fontSize: 14.5, fontWeight: FontWeight.w800, color: AppColors.chipInk)),
                    const SizedBox(height: 2),
                    Text(
                      total == 0
                          ? 'No muscle data yet. Finish a workout and your sets will show here.'
                          : missing.isEmpty
                              ? 'Nice, you trained every muscle group in this period.'
                              : '${missing.join(', ')} ${missing.length == 1 ? 'has' : 'have'} no recorded sets. Consider adding ${missing.length == 1 ? 'it' : 'them'} to your next workout.',
                      style: TextStyle(fontSize: 12.5, height: 1.35, color: AppColors.chipInk),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _detail(String m, int v, int total, String status) {
    final pct = total == 0 ? 0 : (v * 100 / total).round();
    final color = _statusColors[status]!;
    return AppCard(
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: MuscleTile(
                muscle: m, icon: Icons.fitness_center, width: 64, height: 64),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(m, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(_statusNames[status]!,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
                Text('$v sets',
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: status == 'none' ? AppColors.muted : AppColors.primary)),
                Text('$pct% of total sets',
                    style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                const SizedBox(height: 6),
                GradientBar(
                  value: total == 0 ? 0.0 : v / total,
                  height: 8,
                  colors: [color.withOpacity(0.6), color],
                ),
                const SizedBox(height: 6),
                Text(_statusAdvice[status]!,
                    style: const TextStyle(fontSize: 12, color: AppColors.muted, height: 1.3)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String m, int v, int total, String status, bool selected) {
    final pct = total == 0 ? 0 : (v * 100 / total).round();
    final color = _statusColors[status]!;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => setState(() => _sel = m),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              width: 11,
              height: 11,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 80,
              child: Text(m,
                  style: TextStyle(
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600)),
            ),
            Expanded(
              child: GradientBar(
                value: total == 0 ? 0.0 : v / total,
                height: 9,
                colors: [color.withOpacity(0.55), color],
              ),
            ),
            SizedBox(
              width: 82,
              child: Text('$v sets  $pct%',
                  textAlign: TextAlign.right,
                  style: const TextStyle(color: AppColors.muted, fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Three summary tiles: sets, muscles hit, total volume.
class MuscleStatTiles extends StatelessWidget {
  final MuscleStats stats;

  const MuscleStatTiles({super.key, required this.stats});

  Widget _tile(IconData icon, String value, String label) {
    return Expanded(
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        radius: 20,
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(color: AppColors.chipBg, shape: BoxShape.circle),
              child: Icon(icon, size: 18, color: AppColors.primary),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(value,
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                  ),
                  Text(label, style: const TextStyle(fontSize: 11, color: AppColors.muted)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _tile(Icons.fitness_center, '${stats.total}', 'Sets'),
        const SizedBox(width: 8),
        _tile(Icons.track_changes, '${stats.musclesHit} / ${trackedMuscles.length}', 'Muscles hit'),
        const SizedBox(width: 8),
        _tile(Icons.scale_outlined, '${stats.volume.round()} kg', 'Volume'),
      ],
    );
  }
}
