import 'package:flutter/material.dart';

import '../theme.dart';

/// Plain-language privacy policy. Review it before publishing the app.
class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  static const _sections = <(String, String)>[
    ('What we store',
        'Your profile (age, height, weight, goals), food diary, water, workouts, weight log, allergies and health conditions you choose to add. This stays on your phone and, if you sign in, in your private account so you can use another phone.'),
    ('Who can see it',
        'Only you. Friends see only what you choose to share: your name, streak, level and achievements, and only if you turn sharing on. You can turn sharing off at any time.'),
    ('AI features',
        'When you use the coach, voice logging or label photo scan, the text or photo you send is processed by Google Gemini to answer you. Do not send photos of people or documents. We do not use your data for advertising and we do not sell it.'),
    ('Label scans',
        'Ingredient lists read from product labels may be saved in a shared product list (without your name) so the next person scanning the same product gets a faster answer.'),
    ('Health information',
        'Everything in this app is general guidance, not medical advice. Always check the real product label if you have a serious allergy, and talk to a doctor about your health.'),
    ('Your choices',
        'You can delete all your data from Settings, or delete your account completely. Deleting your account removes your data from our servers.'),
    ('Contact',
        'Questions about privacy: write to the app owner at the email shown on the store page.'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(backgroundColor: Colors.transparent, title: const Text('Privacy policy')),
      body: AppBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            for (final s in _sections)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: AppCard(
                  radius: 20,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.$1,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 6),
                      Text(s.$2,
                          style: const TextStyle(
                              fontSize: 14, height: 1.45, color: AppColors.muted)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
