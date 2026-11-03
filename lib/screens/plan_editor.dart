import 'package:flutter/material.dart';

import '../theme.dart';
import 'workout_data.dart';

class _Row {
  final TextEditingController name;
  final TextEditingController sets;
  final TextEditingController reps;
  String unit;

  _Row(Exercise e)
      : name = TextEditingController(text: e.name),
        sets = TextEditingController(text: '${e.sets}'),
        reps = TextEditingController(text: '${e.reps}'),
        unit = e.unit;

  void dispose() {
    name.dispose();
    sets.dispose();
    reps.dispose();
  }
}

/// Bottom sheet where the user builds their own plan for one weekday.
/// Returns the new [DayPlan] on save, or null when closed.
class PlanEditor extends StatefulWidget {
  final String dayName;
  final DayPlan plan;
  final bool isCustom;
  final VoidCallback onReset;

  const PlanEditor({
    super.key,
    required this.dayName,
    required this.plan,
    required this.isCustom,
    required this.onReset,
  });

  @override
  State<PlanEditor> createState() => _PlanEditorState();
}

class _PlanEditorState extends State<PlanEditor> {
  late final TextEditingController _title;
  late bool _rest;
  late final List<_Row> _rows;
  String? _error;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.plan.title);
    _rest = widget.plan.rest;
    _rows = widget.plan.exercises.map(_Row.new).toList();
  }

  @override
  void dispose() {
    _title.dispose();
    for (final r in _rows) {
      r.dispose();
    }
    super.dispose();
  }

  void _save() {
    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Give this day a name, like "Chest + Triceps".');
      return;
    }
    final exercises = <Exercise>[];
    if (!_rest) {
      for (final r in _rows) {
        final name = r.name.text.trim();
        if (name.isEmpty) continue;
        exercises.add(Exercise(
          name,
          (int.tryParse(r.sets.text.trim()) ?? 3).clamp(1, 12),
          (int.tryParse(r.reps.text.trim()) ?? 10).clamp(1, 3600),
          unit: r.unit,
        ));
      }
      if (exercises.isEmpty) {
        setState(() => _error = 'Add at least one exercise, or mark this as a rest day.');
        return;
      }
    }
    Navigator.pop(context, DayPlan(title, exercises, rest: _rest));
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scroll) => Padding(
        padding: EdgeInsets.only(bottom: bottom),
        child: Column(
          children: [
            Expanded(
              child: ListView(
                controller: scroll,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                children: [
                  Text('Edit ${widget.dayName}',
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text('Build the workout you actually do on this day.',
                      style: TextStyle(color: AppColors.muted)),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _title,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(labelText: 'Day name'),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Rest day'),
                    value: _rest,
                    activeColor: AppColors.primary,
                    onChanged: (v) => setState(() => _rest = v),
                  ),
                  if (!_rest) ...[
                    for (var i = 0; i < _rows.length; i++) _rowCard(i),
                    OutlinedButton.icon(
                      onPressed: () => setState(
                          () => _rows.add(_Row(const Exercise('', 3, 10)))),
                      icon: const Icon(Icons.add),
                      label: const Text('Add exercise'),
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!, style: TextStyle(color: AppColors.danger)),
                  ],
                  if (widget.isCustom)
                    TextButton(
                      onPressed: () {
                        widget.onReset();
                        Navigator.pop(context);
                      },
                      child: const Text('Go back to the suggested plan'),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(onPressed: _save, child: const Text('Save day')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _rowCard(int i) {
    final r = _rows[i];
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        radius: 16,
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: r.name,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(labelText: 'Exercise'),
                  ),
                ),
                IconButton(
                  tooltip: 'Remove',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => setState(() => _rows.removeAt(i).dispose()),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: r.sets,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Sets'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: r.reps,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                        labelText: r.unit == 'sec' ? 'Seconds' : 'Reps'),
                  ),
                ),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: r.unit,
                  items: const [
                    DropdownMenuItem(value: 'reps', child: Text('reps')),
                    DropdownMenuItem(value: 'sec', child: Text('sec')),
                  ],
                  onChanged: (v) => setState(() => r.unit = v ?? 'reps'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
