import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/exercise_library.dart';
import '../theme.dart';

/// Home row that opens the exercise library.
class ExerciseLibraryCard extends StatelessWidget {
  const ExerciseLibraryCard({super.key});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      radius: 16,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: ListTile(
        leading: Icon(Icons.menu_book_outlined, color: AppColors.primary),
        title: const Text('Exercise library',
            style: TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text('${exerciseLibrary.length} exercises: muscles, form, mistakes'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const ExerciseLibraryScreen()),
        ),
      ),
    );
  }
}

IconData _groupIcon(String g) => switch (g) {
      'Chest' => Icons.fitness_center,
      'Back' => Icons.accessibility_new,
      'Shoulders' => Icons.sports_gymnastics,
      'Arms' => Icons.sports_martial_arts,
      'Legs' => Icons.directions_run,
      'Core' => Icons.self_improvement,
      _ => Icons.favorite_outline,
    };

Color _levelColor(String level) => switch (level) {
      'Beginner' => AppColors.safe,
      'Intermediate' => const Color(0xFFE08A00),
      _ => AppColors.danger,
    };

class ExerciseLibraryScreen extends StatefulWidget {
  const ExerciseLibraryScreen({super.key});

  @override
  State<ExerciseLibraryScreen> createState() => _ExerciseLibraryScreenState();
}

class _ExerciseLibraryScreenState extends State<ExerciseLibraryScreen> {
  String _query = '';
  String _group = 'All';
  String _level = 'All';
  String _equip = 'All';

  static const _equipOptions = ['All', 'No equipment', 'Dumbbells', 'Barbell', 'Machine or cable'];

  bool _equipMatch(ExerciseInfo e) {
    final q = e.equipment.toLowerCase();
    return switch (_equip) {
      'No equipment' => q.contains('bodyweight'),
      'Dumbbells' => q.contains('dumbbell') || q.contains('kettlebell'),
      'Barbell' => q.contains('barbell'),
      'Machine or cable' => q.contains('machine') || q.contains('cable'),
      _ => true,
    };
  }

  Widget _chips(List<String> options, String value, ValueChanged<String> onPick) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: options.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) => ChoiceChip(
          label: Text(options[i]),
          selected: value == options[i],
          onSelected: (_) => onPick(options[i]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();
    final list = [
      for (final e in exerciseLibrary)
        if ((_group == 'All' || e.group == _group) &&
            (_level == 'All' || e.level == _level) &&
            _equipMatch(e) &&
            (q.isEmpty ||
                e.name.toLowerCase().contains(q) ||
                e.primary.toLowerCase().contains(q) ||
                e.secondary.toLowerCase().contains(q)))
          e,
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Exercise library')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(
            onChanged: (v) => setState(() => _query = v),
            decoration: const InputDecoration(
              hintText: 'Search exercise or muscle',
              prefixIcon: Icon(Icons.search),
            ),
          ),
          const SizedBox(height: 12),
          _chips(['All', ...exerciseGroups], _group, (v) => setState(() => _group = v)),
          const SizedBox(height: 4),
          _chips(['All', 'Beginner', 'Intermediate', 'Advanced'], _level,
              (v) => setState(() => _level = v)),
          const SizedBox(height: 4),
          _chips(_equipOptions, _equip, (v) => setState(() => _equip = v)),
          const SizedBox(height: 12),
          if (list.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Text('No exercise matches. Try clearing a filter.',
                  textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted)),
            ),
          for (final e in list)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: AppCard(
                radius: 16,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                child: ListTile(
                  leading: Icon(_groupIcon(e.group), color: AppColors.primary),
                  title: Text(e.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text('${e.primary}  |  ${e.equipment}'),
                  trailing: Text(e.level,
                      style: TextStyle(
                          color: _levelColor(e.level),
                          fontSize: 12,
                          fontWeight: FontWeight.w700)),
                  onTap: () => openExercise(context, e),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

void openExercise(BuildContext context, ExerciseInfo e) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => ExerciseDetailScreen(info: e)),
  );
}

class ExerciseDetailScreen extends StatelessWidget {
  final ExerciseInfo info;

  const ExerciseDetailScreen({super.key, required this.info});

  Future<void> _demo(BuildContext context) async {
    final url = Uri.https(
        'www.youtube.com', '/results', {'search_query': '${info.name} proper form'});
    var ok = false;
    try {
      ok = await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (_) {}
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the video. Check your internet.')),
      );
    }
  }

  Widget _title(String t) => Padding(
        padding: const EdgeInsets.only(top: 22, bottom: 8),
        child: Text(t, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
      );

  Widget _variation(String level, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: AppCard(
          radius: 14,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(level,
                  style: TextStyle(
                      color: _levelColor(level), fontWeight: FontWeight.w800, fontSize: 13)),
              const SizedBox(height: 4),
              Text(text, style: const TextStyle(height: 1.4)),
            ],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(info.name)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          AppCard(
            radius: 18,
            child: Row(
              children: [
                Icon(_groupIcon(info.group), size: 40, color: AppColors.primary),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(info.group,
                          style: const TextStyle(color: AppColors.muted, fontSize: 12)),
                      Text(info.name,
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                      Text(info.level,
                          style: TextStyle(
                              color: _levelColor(info.level), fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => _demo(context),
            icon: const Icon(Icons.play_circle_outline),
            label: const Text('Watch a video demo'),
          ),
          _title('Muscles worked'),
          Text('Main: ${info.primary}', style: const TextStyle(height: 1.5)),
          Text('Also: ${info.secondary}',
              style: const TextStyle(height: 1.5, color: AppColors.muted)),
          _title('Equipment'),
          Text(info.equipment),
          _title('How to do it'),
          for (var i = 0; i < info.steps.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: AppColors.primary,
                    child: Text('${i + 1}',
                        style: const TextStyle(
                            color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(info.steps[i], style: const TextStyle(height: 1.4))),
                ],
              ),
            ),
          _title('Common mistakes'),
          for (final m in info.mistakes)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.close, size: 18, color: AppColors.danger),
                  const SizedBox(width: 8),
                  Expanded(child: Text(m, style: const TextStyle(height: 1.4))),
                ],
              ),
            ),
          _title('Make it easier or harder'),
          _variation('Beginner', info.beginner),
          _variation('Intermediate', info.intermediate),
          _variation('Advanced', info.advanced),
          const SizedBox(height: 16),
          const Text(
            'General fitness guidance, not medical advice. Start light, stop if something hurts, and ask a coach or doctor if you are unsure.',
            style: TextStyle(color: AppColors.muted, fontSize: 12, height: 1.4),
          ),
        ],
      ),
    );
  }
}
