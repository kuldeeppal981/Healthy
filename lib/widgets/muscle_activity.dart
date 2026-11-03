import 'package:flutter/material.dart';

import '../data/body_paths.dart';
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
// Body figure. The shapes live in lib/data/body_paths.dart (open-source
// artwork, MIT licence) and are drawn here with the colour of each muscle's
// training status. Front view uses x 0..724, back view x 724..1448, y 0..1448.
// ---------------------------------------------------------------------------

const _slugGroup = <String, String>{
  'chest': 'Chest',
  'deltoids': 'Shoulders',
  'biceps': 'Biceps',
  'triceps': 'Triceps',
  'abs': 'Core',
  'obliques': 'Core',
  'trapezius': 'Back',
  'upper-back': 'Back',
  'lower-back': 'Back',
  'quadriceps': 'Legs',
  'hamstring': 'Legs',
  'gluteal': 'Legs',
  'calves': 'Legs',
  'adductors': 'Legs',
  'tibialis': 'Legs',
};

Path _buildPath(List<double> d) {
  final p = Path();
  var i = 0;
  while (i < d.length) {
    final op = d[i].toInt();
    i++;
    if (op == 0) {
      p.moveTo(d[i], d[i + 1]);
      i += 2;
    } else if (op == 1) {
      p.lineTo(d[i], d[i + 1]);
      i += 2;
    } else if (op == 2) {
      p.cubicTo(d[i], d[i + 1], d[i + 2], d[i + 3], d[i + 4], d[i + 5]);
      i += 6;
    } else {
      p.close();
    }
  }
  return p;
}

class _Shape {
  final String slug;
  final String? group; // one of our tracked muscle groups, or null
  final Path path;

  _Shape(this.slug, this.group, this.path);
}

List<_Shape> _shapesOf(List<BodyPart> parts) => [
      for (final b in parts) _Shape(b.slug, _slugGroup[b.slug], _buildPath(b.d)),
    ];

final List<_Shape> _frontShapes = _shapesOf(bodyFrontParts);
final List<_Shape> _backShapes = _shapesOf(bodyBackParts);

class _BodyPainter extends CustomPainter {
  final bool front;
  final Map<String, Color> colors;
  final String? selected;

  _BodyPainter(this.front, this.colors, this.selected);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 724, size.height / 1448);
    if (!front) canvas.translate(-724, 0);
    final shapes = front ? _frontShapes : _backShapes;
    const base = Color(0xFFE3E8EC);
    const hair = Color(0xFFCBD2D9);
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeJoin = StrokeJoin.round
      ..color = Colors.white;
    for (final sh in shapes) {
      final color = sh.group != null
          ? (colors[sh.group] ?? _statusColors['none']!)
          : (sh.slug == 'hair' ? hair : base);
      canvas.drawPath(sh.path, Paint()..color = color);
      canvas.drawPath(sh.path, edge);
    }
    if (selected != null) {
      final hi = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeJoin = StrokeJoin.round
        ..color = AppColors.ink;
      for (final sh in shapes) {
        if (sh.group == selected) canvas.drawPath(sh.path, hi);
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
        final h = w * 2;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (d) {
            final p = Offset(
              d.localPosition.dx * 724 / w + (front ? 0 : 724),
              d.localPosition.dy * 1448 / h,
            );
            final shapes = front ? _frontShapes : _backShapes;
            for (final sh in shapes.reversed) {
              if (sh.group != null && sh.path.contains(p)) {
                onPick(sh.group!);
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
