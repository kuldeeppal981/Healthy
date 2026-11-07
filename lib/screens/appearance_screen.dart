import 'package:flutter/material.dart';

import '../services/sound_service.dart';
import '../services/theme_service.dart';
import '../theme.dart';

/// Light/dark, theme colour, text size, sounds and accessibility.
class AppearanceScreen extends StatelessWidget {
  const AppearanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(backgroundColor: Colors.transparent, title: const Text('Appearance')),
      body: AppBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
        ListenableBuilder(
          listenable: ThemeService.instance,
          builder: (context, _) => AppCard(
            radius: 22,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.dark_mode_outlined, color: AppColors.primary),
                    SizedBox(width: 12),
                    Text('Appearance',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<ThemeMode>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(value: ThemeMode.system, label: Text('Auto')),
                      ButtonSegment(value: ThemeMode.light, label: Text('Light')),
                      ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
                    ],
                    selected: {ThemeService.instance.mode},
                    onSelectionChanged: (v) => ThemeService.instance.set(v.first),
                  ),
                ),
                const SizedBox(height: 6),
                ListenableBuilder(
                  listenable: SoundService.instance,
                  builder: (context, _) => SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Sounds',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: const Text('Chime on check-in, pop on a finished set',
                        style: TextStyle(fontSize: 12)),
                    value: SoundService.instance.enabled,
                    activeColor: AppColors.primary,
                    onChanged: SoundService.instance.setEnabled,
                  ),
                ),
                const SizedBox(height: 8),
                const Text('Theme colour', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 14,
                  runSpacing: 10,
                  children: [
                    for (var i = 0; i < accentPalettes.length; i++)
                      GestureDetector(
                        onTap: () => ThemeService.instance.setAccent(i),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [accentPalettes[i].light, accentPalettes[i].deep],
                                ),
                                border: Border.all(
                                  color: ThemeService.instance.accentIndex == i
                                      ? AppColors.ink
                                      : Colors.transparent,
                                  width: 2.5,
                                ),
                              ),
                              child: ThemeService.instance.accentIndex == i
                                  ? const Icon(Icons.check, color: Colors.white, size: 22)
                                  : null,
                            ),
                            const SizedBox(height: 4),
                            Text(accentPalettes[i].name, style: const TextStyle(fontSize: 11)),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                const Text('Text size', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<double>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(value: 1.0, label: Text('Normal')),
                      ButtonSegment(value: 1.15, label: Text('Large')),
                      ButtonSegment(value: 1.3, label: Text('Extra')),
                    ],
                    selected: {ThemeService.instance.textScale},
                    onSelectionChanged: (v) => ThemeService.instance.setTextScale(v.first),
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('High contrast',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: const Text('Darker text, stronger borders, bold text',
                      style: TextStyle(fontSize: 12)),
                  value: ThemeService.instance.highContrast,
                  activeColor: AppColors.primary,
                  onChanged: ThemeService.instance.setHighContrast,
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Reduce motion',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: const Text('Fewer animations and no confetti',
                      style: TextStyle(fontSize: 12)),
                  value: ThemeService.instance.reduceMotion,
                  activeColor: AppColors.primary,
                  onChanged: ThemeService.instance.setReduceMotion,
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
}
