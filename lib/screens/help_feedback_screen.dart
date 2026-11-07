import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config.dart';
import '../state/app_state.dart';
import '../theme.dart';
import 'tour_screen.dart';

const _faq = <List<String>>[
  [
    'How do I log food with a photo?',
    'Tap the + button, then Meal photo. Take a photo of your plate from above. AI estimates the calories, you fix the portions with + and -, then add it to your diary.'
  ],
  [
    'How accurate are the calories?',
    'They are estimates. Portions from a photo can be off by 20 to 30 percent, and hidden oil or sugar cannot be seen. Fix the amounts, and check labels for allergies yourself.'
  ],
  [
    'How do I add my health report?',
    'Profile, then Medical report. Take a photo of your lab report. Healthy picks out foods to limit and prefer. It is general guidance, not medical advice.'
  ],
  [
    'How does form check work?',
    'While you log a workout, open an exercise and use form check. Send a photo or use the live camera. You get simple tips. It is not a trainer or a doctor.'
  ],
  [
    'What is a streak freeze?',
    'If you miss exactly one day, a streak freeze keeps your streak alive. You get 2 a month.'
  ],
  [
    'Who can see my data?',
    'Only you. Friends see your name, streaks, levels and records, only if you allow it. They never see your food diary, weight, allergies or health report. See Privacy and data.'
  ],
  [
    'Why did the AI say my daily limit is used?',
    'Free accounts get 10 AI requests a day (coach, photos, voice estimates). They reset at midnight.'
  ],
];

/// Short answers, a way to replay the tour, and an in-app feedback form.
class HelpFeedbackScreen extends StatefulWidget {
  const HelpFeedbackScreen({super.key});

  @override
  State<HelpFeedbackScreen> createState() => _HelpFeedbackScreenState();
}

class _HelpFeedbackScreenState extends State<HelpFeedbackScreen> {
  final _text = TextEditingController();
  String _kind = 'idea';
  bool _sending = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final s = context.read<AppState>();
    final msg = _text.text.trim();
    if (!cloudEnabled || !s.signedIn) {
      _snack('Sign in to send feedback.');
      return;
    }
    if (msg.length < 5) {
      _snack('Please write a few more words.');
      return;
    }
    setState(() => _sending = true);
    try {
      final r = await Supabase.instance.client.rpc('send_feedback', params: {
        'p_kind': _kind,
        'p_message': msg,
        'p_version': appVersion,
      }) as String;
      if (!mounted) return;
      if (r == 'ok') {
        _text.clear();
        _snack('Thank you. We read every message.');
      } else if (r == 'limit') {
        _snack('You sent a few already today. Try again tomorrow.');
      } else {
        _snack('Could not send. Try again.');
      }
    } catch (_) {
      if (mounted) _snack('Could not send. Check your internet and try again.');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(backgroundColor: Colors.transparent, title: const Text('Help and feedback')),
      body: AppBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            const Text('Common questions',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            AppCard(
              radius: 22,
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                children: [
                  for (final q in _faq)
                    ExpansionTile(
                      shape: const Border(),
                      collapsedShape: const Border(),
                      title: Text(q[0],
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      expandedCrossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(q[1],
                            style: TextStyle(fontSize: 13, height: 1.4, color: AppColors.muted)),
                      ],
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            MenuCard(rows: [
              MenuRow(
                icon: Icons.help_outline,
                title: 'App tour',
                subtitle: 'See the quick intro again',
                onTap: () => Navigator.of(context)
                    .push(MaterialPageRoute<void>(builder: (_) => const TourScreen())),
              ),
            ]),
            const SizedBox(height: 22),
            const Text('Send feedback',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            AppCard(
              radius: 22,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final k in const [
                        ['idea', 'Idea'],
                        ['bug', 'Problem'],
                        ['other', 'Other'],
                      ])
                        ChoiceChip(
                          label: Text(k[1]),
                          selected: _kind == k[0],
                          selectedColor: AppColors.chipBg,
                          onSelected: (_) => setState(() => _kind = k[0]),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _text,
                    minLines: 4,
                    maxLines: 8,
                    maxLength: 1500,
                    decoration: const InputDecoration(
                      hintText: 'Tell us what to fix or add. Do not include passwords.',
                    ),
                  ),
                  const SizedBox(height: 6),
                  GradientButton(
                    label: _sending ? 'Sending...' : 'Send',
                    icon: Icons.send_outlined,
                    onPressed: _sending ? () {} : _send,
                  ),
                  const SizedBox(height: 8),
                  Text(
                      'Your message is saved with your account and app version ($appVersion). Only the Healthy team can read it.',
                      style: TextStyle(fontSize: 11, color: AppColors.muted)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
