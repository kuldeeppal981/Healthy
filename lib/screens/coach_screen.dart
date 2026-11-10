import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config.dart';
import '../models.dart';
import '../services/health_service.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/pro_sheet.dart';
import '../widgets/ui_kit.dart';
import '../widgets/voice_capture.dart';

class _FoodItem {
  final String name;
  final String serving;
  final double kcal;
  final double protein;
  final double carbs;
  final double fat;

  const _FoodItem(this.name, this.serving, this.kcal, this.protein, this.carbs, this.fat);
}

/// One suggested meal from the coach (breakfast, lunch, snacks or dinner).
class _MealGroup {
  final String meal;
  final List<_FoodItem> items;

  const _MealGroup(this.meal, this.items);

  double get kcal => items.fold(0.0, (s, e) => s + e.kcal);
}

class _Msg {
  final bool user;
  final String text;
  final bool error;
  final List<_MealGroup> meals;

  const _Msg(this.user, this.text, {this.error = false, this.meals = const []});
}

double _num(Object? v) => v is num ? v.toDouble() : 0;

List<_MealGroup> _parseMeals(Object? raw) {
  if (raw is! List) return const [];
  final out = <_MealGroup>[];
  for (final g in raw) {
    if (g is! Map) continue;
    final items = <_FoodItem>[];
    for (final x in (g['items'] is List ? g['items'] as List : const [])) {
      if (x is! Map || x['name'] is! String) continue;
      items.add(_FoodItem(x['name'] as String, (x['serving'] as String?) ?? '',
          _num(x['kcal']), _num(x['protein']), _num(x['carbs']), _num(x['fat'])));
    }
    final meal = g['meal'];
    if (items.isNotEmpty) {
      out.add(_MealGroup(
          const ['breakfast', 'lunch', 'snacks', 'dinner'].contains(meal) ? meal as String : 'snacks',
          items));
    }
  }
  return out;
}

const _mealNames = {
  'breakfast': 'Breakfast',
  'lunch': 'Lunch',
  'snacks': 'Snack',
  'dinner': 'Dinner',
};

/// Chat with the AI coach. The question goes to a Supabase Edge Function,
/// which holds the AI key and enforces a daily limit per user.
class CoachScreen extends StatefulWidget {
  const CoachScreen({super.key});

  @override
  State<CoachScreen> createState() => _CoachScreenState();
}

class _CoachScreenState extends State<CoachScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final List<_Msg> _msgs = [];
  bool _busy = false;

  static const _suggestions = [
    'Aaj kya khaun?',
    'Protein kaise pura karun?',
    'Aaj ke workout ke tips do',
    'Weight loss ke liye kya karun?',
  ];

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  String _context(AppState s) {
    final p = s.profile;
    final plan = s.planFor(DateTime.now().weekday);
    final eaten = s.today.map((e) => '${e.name} (${e.kcal.round()} kcal)').take(15).join(', ');
    return [
      if (p != null) 'Goal: ${p.goal}',
      'Daily target: ${s.kcalTarget} kcal, protein ${s.proteinTarget} g, carbs ${s.carbsTarget} g, fat ${s.fatTarget} g',
      'Eaten today: ${s.kcalToday.round()} kcal, protein ${s.proteinToday.round()} g, carbs ${s.carbsToday.round()} g, fat ${s.fatToday.round()} g',
      'Foods today: ${eaten.isEmpty ? 'nothing yet' : eaten}',
      'Allergies: ${s.allergies.isEmpty ? 'none' : s.allergies.join(', ')}',
      if (s.conditions.isNotEmpty)
        'Health conditions (be conservative, defer to their doctor): ${s.conditions.join(', ')}',
      if (HealthService.instance.sleepHours != null)
        'Sleep last night: ${HealthService.instance.sleepHours!.toStringAsFixed(1)} hours',
      "Today's workout: ${plan.rest ? 'rest day' : plan.title}",
    ].join('\n');
  }

  Future<void> _send([String? preset]) async {
    final text = (preset ?? _input.text).trim();
    if (text.isEmpty || _busy) return;
    final state = context.read<AppState>();
    _input.clear();
    setState(() {
      _msgs.add(_Msg(true, text));
      _busy = true;
    });
    _toBottom();

    final history = [
      for (final m in _msgs.where((m) => !m.error))
        {'role': m.user ? 'user' : 'model', 'text': m.text},
    ];

    try {
      final res = await Supabase.instance.client.functions.invoke(
        'coach',
        body: {'messages': history, 'context': _context(state)},
      );
      final data = res.data;
      final reply = data is Map ? data['reply'] as String? : null;
      _add(_Msg(false, reply ?? 'I could not answer that. Try again.',
          error: reply == null, meals: _parseMeals(data is Map ? data['meals'] : null)));
    } on FunctionException catch (e) {
      final d = e.details;
      final msg = d is Map && d['message'] is String
          ? d['message'] as String
          : 'The coach could not answer. Try again.';
      _add(_Msg(false, msg, error: true));
      if (d is Map && d['error'] == 'limit' && mounted) showProLimitSheet(context, msg);
    } catch (_) {
      _add(const _Msg(false, 'No connection. Check your internet and try again.', error: true));
    }
  }

  void _add(_Msg m) {
    if (!mounted) return;
    setState(() {
      _msgs.add(m);
      _busy = false;
    });
    _toBottom();
  }

  void _toBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final ready = cloudEnabled && s.signedIn;

    return Scaffold(
      appBar: AppBar(title: const Text('Ask the coach')),
      body: AppBackground(
       child: !ready
          ? const EmptyState(
              icon: Icons.lock_outline,
              title: 'Sign in to use the coach',
              message: 'Your coach needs your account to see your targets and allergies.',
            )
          : Column(
              children: [
                Expanded(
                  child: _msgs.isEmpty
                      ? ListView(
                          padding: Space.pagePadding,
                          children: [
                            AppCard(
                              child: Row(
                                children: [
                                  Icon(Icons.auto_awesome, color: AppColors.primary, size: 30),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'Ask about food, protein, workouts or habits. The coach sees your targets, what you ate today and your allergies.',
                                      style: TextStyle(color: AppColors.muted, height: 1.4),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final q in _suggestions)
                                  ActionChip(label: Text(q), onPressed: () => _send(q)),
                              ],
                            ),
                          ],
                        )
                      : ListView.builder(
                          controller: _scroll,
                          padding: const EdgeInsets.all(16),
                          itemCount: _msgs.length + (_busy ? 1 : 0),
                          itemBuilder: (_, i) {
                            if (i == _msgs.length) {
                              return const Padding(
                                padding: EdgeInsets.symmetric(vertical: 6),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Skeleton(height: 38, width: 140, radius: 16),
                                ),
                              );
                            }
                            return _bubble(_msgs[i]);
                          },
                        ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'General guidance only, not medical advice.',
                    style: TextStyle(fontSize: 11, color: AppColors.muted),
                  ),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 6, 8, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _input,
                            minLines: 1,
                            maxLines: 4,
                            maxLength: 500,
                            textCapitalization: TextCapitalization.sentences,
                            decoration: const InputDecoration(
                              hintText: 'Ask something',
                              counterText: '',
                            ),
                            onSubmitted: (_) => _send(),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Speak',
                          onPressed: _busy
                              ? null
                              : () async {
                                  final t = await showVoiceCapture(context,
                                      hint: 'Ask the coach');
                                  if (t != null) _send(t);
                                },
                          icon: const Icon(Icons.mic),
                          color: AppColors.primary,
                        ),
                        IconButton(
                          onPressed: _busy ? null : _send,
                          icon: const Icon(Icons.send_rounded),
                          color: AppColors.primary,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
      ),
    );
  }

  /// Shows **bold** as bold and "* " list marks as dots, so no stars appear.
  List<InlineSpan> _spans(String text, Color color) {
    final clean = text.replaceAllMapped(RegExp(r'^\s*[*-]\s+', multiLine: true), (_) => '• ');
    final spans = <InlineSpan>[];
    final parts = clean.split('**');
    for (var i = 0; i < parts.length; i++) {
      if (parts[i].isEmpty) continue;
      spans.add(TextSpan(
        text: parts[i],
        style: TextStyle(fontWeight: i.isOdd ? FontWeight.w800 : FontWeight.w400, color: color),
      ));
    }
    return spans;
  }

  Widget _bubble(_Msg m) {
    final color = m.user ? Colors.white : (m.error ? AppColors.danger : AppColors.ink);
    return Align(
      alignment: m.user ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.86),
        decoration: BoxDecoration(
          color: m.user
              ? AppColors.primary
              : (m.error ? AppColors.dangerBg : AppColors.chipBg),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text.rich(
              TextSpan(children: _spans(m.text, color)),
              style: TextStyle(height: 1.4, color: color),
            ),
            for (final g in m.meals) _mealCard(g),
            if (m.meals.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('Coach\'s estimate. Change portions to match what you eat.',
                    style: TextStyle(fontSize: 11, color: AppColors.muted)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _mealCard(_MealGroup g) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_mealNames[g.meal] ?? 'Meal',
              style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.ink)),
          const SizedBox(height: 4),
          for (final it in g.items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      it.serving.isEmpty ? it.name : '${it.name} (${it.serving})',
                      style: TextStyle(fontSize: 13, color: AppColors.ink),
                    ),
                  ),
                  Text('${it.kcal.round()} kcal',
                      style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primaryDeep)),
                ],
              ),
            ),
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
              onPressed: () => _addToDiary(g),
              child: Text('Add to diary · ${g.kcal.round()} kcal'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addToDiary(_MealGroup g) async {
    final state = context.read<AppState>();
    var meal = g.meal;
    final on = List<bool>.filled(g.items.length, true);
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppColors.card,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          final picked = [for (var i = 0; i < g.items.length; i++) if (on[i]) g.items[i]];
          final kcal = picked.fold(0.0, (s, e) => s + e.kcal);
          final p = picked.fold(0.0, (s, e) => s + e.protein);
          final c = picked.fold(0.0, (s, e) => s + e.carbs);
          final f = picked.fold(0.0, (s, e) => s + e.fat);
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Add to diary',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.ink)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final e in _mealNames.entries)
                        ChoiceChip(
                          label: Text(e.value),
                          selected: meal == e.key,
                          onSelected: (_) => setS(() => meal = e.key),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  for (var i = 0; i < g.items.length; i++)
                    CheckboxListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      value: on[i],
                      onChanged: (v) => setS(() => on[i] = v ?? false),
                      title: Text(g.items[i].name),
                      subtitle: g.items[i].serving.isEmpty ? null : Text(g.items[i].serving),
                      secondary: Text('${g.items[i].kcal.round()} kcal',
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  const SizedBox(height: 6),
                  Text(
                    '${kcal.round()} kcal · P ${p.round()} g · C ${c.round()} g · F ${f.round()} g (estimate)',
                    style: TextStyle(color: AppColors.muted, fontSize: 12),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: picked.isEmpty ? null : () => Navigator.pop(ctx, true),
                      child: Text('Add ${picked.length} item${picked.length == 1 ? '' : 's'}'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    if (ok != true || !mounted) return;
    final now = DateTime.now();
    final ids = <String>[];
    var n = 0;
    for (var i = 0; i < g.items.length; i++) {
      if (!on[i]) continue;
      final it = g.items[i];
      final id = '${now.microsecondsSinceEpoch}-coach-${n++}';
      ids.add(id);
      state.addEntry(DiaryEntry(
        id: id,
        name: it.name,
        meal: meal,
        kcal: it.kcal,
        protein: it.protein,
        carbs: it.carbs,
        fat: it.fat,
        at: now,
      ));
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Added ${ids.length} to ${_mealNames[meal]}'),
      action: SnackBarAction(
        label: 'Undo',
        onPressed: () {
          for (final id in ids) {
            state.removeEntry(id);
          }
        },
      ),
    ));
  }
}
