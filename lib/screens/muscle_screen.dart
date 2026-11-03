import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/muscle_stats.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/muscle_activity.dart';

/// Muscle volume on its own page (the same section also sits in the
/// Analytics tab).
class MuscleScreen extends StatefulWidget {
  const MuscleScreen({super.key});

  @override
  State<MuscleScreen> createState() => _MuscleScreenState();
}

class _MuscleScreenState extends State<MuscleScreen> {
  int _days = 7;

  @override
  Widget build(BuildContext context) {
    final a = context.watch<AppState>();
    final st = MuscleStats.compute(a, _days);
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(backgroundColor: Colors.transparent, title: const Text('Muscle volume')),
      body: AppBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
          children: [
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 7, label: Text('Last 7 days')),
                ButtonSegment(value: 30, label: Text('Last 30 days')),
              ],
              selected: {_days},
              onSelectionChanged: (s) => setState(() => _days = s.first),
            ),
            const SizedBox(height: 14),
            MuscleStatTiles(stats: st),
            const SizedBox(height: 12),
            MuscleActivitySection(sets: st.sets),
            if (st.oldSets > 0) ...[
              const SizedBox(height: 8),
              Text(
                '${st.oldSets} sets from older workouts are not counted, because muscle data was not saved for them. '
                'Custom exercises that are not in the library are not counted either.',
                style: TextStyle(color: AppColors.muted, fontSize: 12),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              'General guide: many people train each muscle about 10 sets a week. Not medical advice.',
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
