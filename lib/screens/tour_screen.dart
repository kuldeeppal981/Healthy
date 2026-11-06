import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme.dart';

class _Slide {
  final IconData icon;
  final String title;
  final String text;
  const _Slide(this.icon, this.title, this.text);
}

const _slides = [
  _Slide(Icons.waving_hand_outlined, 'Welcome to Healthy',
      'A free health app made for India. A quick look at the main things you can do. It takes 30 seconds.'),
  _Slide(Icons.photo_camera_outlined, 'Log food with a photo',
      'Tap the + button, then Meal photo. Take a picture of your plate and AI estimates the calories. Fix the portions, then add it to your diary. You can also use voice, barcode or type.'),
  _Slide(Icons.medical_information_outlined, 'Add your health report',
      'Open Profile, then Medical report, and take a photo of your lab report. Healthy tells you which foods to limit and eat more of, and checks your meals against it. General guidance, not medical advice.'),
  _Slide(Icons.accessibility_new, 'Check your workout form',
      'While you log a workout, tap form check on an exercise. Send a photo or use the live camera and get simple tips to fix your form.'),
  _Slide(Icons.shield_outlined, 'Allergy alerts',
      'Set your allergies once. Every scan is checked against them. Always read the label too.'),
  _Slide(Icons.fitness_center, 'Workouts and streaks',
      'Plan your week in the Workout tab, log sets, and keep your streak alive for XP and badges.'),
  _Slide(Icons.groups_outlined, 'Friends and groups',
      'Add friends, join a group, compete in the weekly league and cheer each other on. Sharing is always your choice.'),
  _Slide(Icons.explore_outlined, 'Explore your fitness',
      'On Home, scroll down to Explore for nutrition, health reports, the exercise library, community and challenges. The AI coach is on Home too. Your profile opens from your picture at the top.'),
];

/// First-run walkthrough. Next, Back and Skip. Shown once; can be replayed
/// from Profile.
class TourScreen extends StatefulWidget {
  const TourScreen({super.key});

  @override
  State<TourScreen> createState() => _TourScreenState();
}

class _TourScreenState extends State<TourScreen> {
  final _ctl = PageController();
  int _i = 0;

  void _finish() {
    final s = context.read<AppState>();
    final next = Map<String, dynamic>.from(s.prefs)..['tourDone'] = true;
    s.savePrefs(next);
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final last = _i == _slides.length - 1;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _finish();
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: AppBackground(
          child: SafeArea(
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _finish,
                    child: Text(last ? '' : 'Skip', style: TextStyle(color: AppColors.muted)),
                  ),
                ),
                Expanded(
                  child: PageView.builder(
                    controller: _ctl,
                    itemCount: _slides.length,
                    onPageChanged: (v) => setState(() => _i = v),
                    itemBuilder: (_, i) {
                      final s = _slides[i];
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                color: AppColors.chipBg,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(s.icon, size: 56, color: AppColors.primary),
                            ),
                            const SizedBox(height: 32),
                            Text(s.title,
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
                            const SizedBox(height: 14),
                            Text(s.text,
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 16, height: 1.45, color: AppColors.muted)),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < _slides.length; i++)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: i == _i ? 22 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: i == _i ? AppColors.primary : AppColors.track,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                  child: Row(
                    children: [
                      if (_i > 0) ...[
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(minimumSize: const Size(0, 52)),
                          onPressed: () => _ctl.previousPage(
                              duration: const Duration(milliseconds: 250), curve: Curves.easeOut),
                          child: const Text('Back'),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        child: GradientButton(
                          label: last ? 'Get started' : 'Next',
                          onPressed: last
                              ? _finish
                              : () => _ctl.nextPage(
                                  duration: const Duration(milliseconds: 250), curve: Curves.easeOut),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
