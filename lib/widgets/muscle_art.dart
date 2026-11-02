import 'package:flutter/material.dart';

/// Colour for each tracked muscle group (same colours as the Muscle volume chart).
Color muscleColor(String? muscle) {
  switch (muscle) {
    case 'Chest':
      return const Color(0xFF7C3AED);
    case 'Back':
      return const Color(0xFF2563EB);
    case 'Shoulders':
      return const Color(0xFF0EA5E9);
    case 'Biceps':
      return const Color(0xFF10B981);
    case 'Triceps':
      return const Color(0xFFF59E0B);
    case 'Legs':
      return const Color(0xFFEF4444);
    case 'Core':
      return const Color(0xFFEC4899);
    default:
      return const Color(0xFF64748B);
  }
}

/// Small tile for an exercise without a photo: coloured by muscle, with its name.
class MuscleTile extends StatelessWidget {
  final String? muscle;
  final IconData icon;
  final double width;
  final double height;

  const MuscleTile({
    super.key,
    required this.muscle,
    required this.icon,
    this.width = 72,
    this.height = 52,
  });

  @override
  Widget build(BuildContext context) {
    final c = muscleColor(muscle);
    return Container(
      width: width,
      height: height,
      color: c.withOpacity(0.14),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: c, size: 22),
          if (muscle != null)
            Text(muscle!,
                maxLines: 1,
                overflow: TextOverflow.clip,
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: c)),
        ],
      ),
    );
  }
}
