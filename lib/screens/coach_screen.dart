import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config.dart';
import '../services/health_service.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/voice_capture.dart';

class _Msg {
  final bool user;
  final String text;
  final bool error;

  const _Msg(this.user, this.text, {this.error = false});
}

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
      _add(_Msg(false, reply ?? 'I could not answer that. Try again.', error: reply == null));
    } on FunctionException catch (e) {
      final d = e.details;
      final msg = d is Map && d['message'] is String
          ? d['message'] as String
          : 'The coach could not answer. Try again.';
      _add(_Msg(false, msg, error: true));
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
      body: !ready
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Sign in to your account to use the coach.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: _msgs.isEmpty
                      ? ListView(
                          padding: const EdgeInsets.all(20),
                          children: [
                            const Text(
                              'Ask about food, protein, workouts or habits. The coach sees your targets, what you ate today and your allergies.',
                              style: TextStyle(color: AppColors.muted, height: 1.4),
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
                                padding: EdgeInsets.all(8),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                ),
                              );
                            }
                            return _bubble(_msgs[i]);
                          },
                        ),
                ),
                const Padding(
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
    );
  }

  Widget _bubble(_Msg m) {
    return Align(
      alignment: m.user ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
        decoration: BoxDecoration(
          color: m.user
              ? AppColors.primary
              : (m.error ? const Color(0xFFFDECEA) : AppColors.chipBg),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          m.text,
          style: TextStyle(
            height: 1.4,
            color: m.user ? Colors.white : (m.error ? AppColors.danger : AppColors.ink),
          ),
        ),
      ),
    );
  }
}
