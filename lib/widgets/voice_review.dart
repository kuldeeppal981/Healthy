import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config.dart';
import '../models.dart';
import '../services/voice_parser.dart';
import '../state/app_state.dart';
import '../theme.dart';
import 'voice_capture.dart';

/// Speak, understand, confirm, save. Handles food, water and weight.
Future<void> logByVoice(BuildContext context) async {
  final text = await showVoiceCapture(context);
  if (text == null || !context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _VoiceReview(text: text),
  );
}

class _VoiceReview extends StatefulWidget {
  final String text;

  const _VoiceReview({required this.text});

  @override
  State<_VoiceReview> createState() => _VoiceReviewState();
}

class _VoiceReviewState extends State<_VoiceReview> {
  late final TextEditingController _text = TextEditingController(text: widget.text);
  late VoiceResult _r = parseVoice(widget.text);
  late List<VoiceItem> _items = List.of(_r.items);
  late List<String> _unmatched = List.of(_r.unmatched);
  String _meal = mealForNow();
  bool _estimating = false;
  String? _note;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _reparse(String t) {
    final r = parseVoice(t);
    setState(() {
      _r = r;
      _items = List.of(r.items);
      _unmatched = List.of(r.unmatched);
      _note = null;
    });
  }

  double get _totalKcal => _items.fold(0.0, (s, i) => s + i.kcal * i.qty);

  String _q(double v) => v == v.roundToDouble() ? '${v.round()}' : v.toStringAsFixed(1);

  Future<void> _estimate() async {
    final s = context.read<AppState>();
    if (!cloudEnabled || !s.signedIn) {
      setState(() => _note = 'Sign in to let AI estimate these, or add them from the Add food screen.');
      return;
    }
    setState(() {
      _estimating = true;
      _note = null;
    });
    try {
      final res = await Supabase.instance.client.functions.invoke(
        'coach',
        body: {'mode': 'estimate', 'items': _unmatched},
      );
      final list = (res.data is Map ? res.data['items'] : null) as List?;
      if (list == null || list.isEmpty) throw Exception('empty');
      final added = <VoiceItem>[];
      for (final x in list) {
        final m = Map<String, dynamic>.from(x as Map);
        added.add(VoiceItem(
          name: '${m['name']}',
          serving: '${m['serving'] ?? '1 serving'}',
          kcal: (m['kcal'] as num?)?.toDouble() ?? 0,
          protein: (m['protein'] as num?)?.toDouble() ?? 0,
          carbs: (m['carbs'] as num?)?.toDouble() ?? 0,
          fat: (m['fat'] as num?)?.toDouble() ?? 0,
          qty: 1,
          estimated: true,
        ));
      }
      setState(() {
        _items.addAll(added);
        _unmatched = [];
        _estimating = false;
      });
    } on FunctionException catch (e) {
      final d = e.details;
      setState(() {
        _estimating = false;
        _note = d is Map && d['message'] is String
            ? d['message'] as String
            : 'The estimate failed. Try again.';
      });
    } catch (_) {
      setState(() {
        _estimating = false;
        _note = 'The estimate failed. Check your internet and try again.';
      });
    }
  }

  void _saveFood() {
    final s = context.read<AppState>();
    final now = DateTime.now();
    var n = 0;
    for (final i in _items) {
      if (i.qty <= 0) continue;
      final label = i.qty == 1 ? i.name : '${_q(i.qty)} x ${i.name}';
      s.addEntry(DiaryEntry(
        id: '${now.microsecondsSinceEpoch}${n++}',
        name: label,
        meal: _meal,
        kcal: i.kcal * i.qty,
        protein: i.protein * i.qty,
        carbs: i.carbs * i.qty,
        fat: i.fat * i.qty,
        at: now,
      ));
    }
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Added $n item${n == 1 ? '' : 's'} to ${mealLabels[_meal] ?? _meal}')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
      maxChildSize: 0.95,
      builder: (context, scroll) => Padding(
        padding: EdgeInsets.only(bottom: bottom),
        child: ListView(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          children: [
            const Text('Is this right?',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            TextField(
              controller: _text,
              minLines: 1,
              maxLines: 3,
              onChanged: _reparse,
              decoration: const InputDecoration(labelText: 'What we heard'),
            ),
            const SizedBox(height: 16),
            ..._body(),
          ],
        ),
      ),
    );
  }

  List<Widget> _body() {
    switch (_r.kind) {
      case VoiceKind.water:
        final n = _r.number ?? 1;
        return [
          AppCard(
            child: Text('Add ${_q(n)} glass${n == 1 ? '' : 'es'} of water',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () {
              context.read<AppState>().addWater(n.round().clamp(1, 20));
              Navigator.pop(context);
            },
            child: const Text('Add water'),
          ),
        ];
      case VoiceKind.weight:
        final kg = _r.number!;
        return [
          AppCard(
            child: Text('Log your weight as ${_q(kg)} kg',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () {
              context.read<AppState>().logWeight(kg);
              Navigator.pop(context);
            },
            child: const Text('Log weight'),
          ),
        ];
      case VoiceKind.food:
        return _foodBody();
      case VoiceKind.none:
        return [
          Text(
            'We could not find a food, water or weight in that. Fix the text above, or go back and try again.',
            style: TextStyle(color: AppColors.muted, height: 1.4),
          ),
        ];
    }
  }

  List<Widget> _foodBody() {
    return [
      for (var i = 0; i < _items.length; i++) _itemRow(i),
      if (_unmatched.isNotEmpty) ...[
        const SizedBox(height: 4),
        AppCard(
          color: AppColors.warnBg,
          borderColor: AppColors.warnBg,
          radius: 14,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Not in our food list:',
                  style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.warnInk)),
              const SizedBox(height: 4),
              Text(_unmatched.join(', '), style: TextStyle(color: AppColors.warnInk)),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: _estimating ? null : _estimate,
                child: _estimating
                    ? const SizedBox(
                        width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Estimate with AI'),
              ),
            ],
          ),
        ),
      ],
      if (_note != null) ...[
        const SizedBox(height: 8),
        Text(_note!, style: TextStyle(color: AppColors.danger, fontSize: 12)),
      ],
      if (_items.isNotEmpty) ...[
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: [
            for (final m in mealOrder)
              ChoiceChip(
                label: Text(mealLabels[m] ?? m),
                selected: _meal == m,
                onSelected: (_) => setState(() => _meal = m),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Text('About ${_totalKcal.round()} kcal in total',
            style: const TextStyle(fontWeight: FontWeight.w700)),
        Text('Home-cooked portions vary, so these numbers are approximate.',
            style: TextStyle(color: AppColors.muted, fontSize: 12)),
        const SizedBox(height: 12),
        FilledButton(onPressed: _saveFood, child: const Text('Add to diary')),
      ],
    ];
  }

  Widget _itemRow(int i) {
    final it = _items[i];
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        radius: 14,
        padding: const EdgeInsets.fromLTRB(14, 8, 6, 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(it.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text(
                    '${it.serving}  |  ${(it.kcal * it.qty).round()} kcal${it.estimated ? '  |  AI estimate' : ''}',
                    style: TextStyle(color: AppColors.muted, fontSize: 12),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.remove_circle_outline),
              onPressed: () => setState(() {
                if (it.qty > 0.5) {
                  it.qty -= 0.5;
                } else {
                  _items.removeAt(i);
                }
              }),
            ),
            Text(_q(it.qty), style: const TextStyle(fontWeight: FontWeight.w700)),
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              onPressed: () => setState(() => it.qty += 0.5),
            ),
          ],
        ),
      ),
    );
  }
}
