import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/l10n.dart';
import '../services/units.dart';
import '../state/app_state.dart';
import '../theme.dart';

/// Units (kg/lb, cm/ft) and language.
class UnitsLanguageScreen extends StatelessWidget {
  const UnitsLanguageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.read<AppState>();
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
          backgroundColor: Colors.transparent,
          title: Text('${tr('Units')} / ${tr('Language')}')),
      body: AppBackground(
        child: ListenableBuilder(
          listenable: Listenable.merge([Units.instance, AppLang.instance]),
          builder: (context, _) {
            final u = Units.instance;
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
              children: [
                AppCard(
                  radius: 22,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tr('Units'),
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: SegmentedButton<bool>(
                          showSelectedIcon: false,
                          segments: const [
                            ButtonSegment(value: false, label: Text('kg, cm')),
                            ButtonSegment(value: true, label: Text('lb, ft')),
                          ],
                          selected: {u.imperial},
                          onSelectionChanged: (v) async {
                            await u.setImperial(v.first);
                            s.refreshUi();
                          },
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                          'Changes how your body weight and height are shown and typed. Gym weights (sets and records) always stay in kg. Food stays in kcal.',
                          style: TextStyle(fontSize: 12, color: AppColors.muted, height: 1.4)),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                AppCard(
                  radius: 22,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tr('Language'),
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: SegmentedButton<bool>(
                          showSelectedIcon: false,
                          segments: const [
                            ButtonSegment(value: false, label: Text('English')),
                            ButtonSegment(value: true, label: Text('हिन्दी')),
                          ],
                          selected: {AppLang.instance.hindi},
                          onSelectionChanged: (v) async {
                            await AppLang.instance.set(v.first);
                            s.refreshUi();
                          },
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                          'Hindi is partial for now: the menus, Home, Settings and Profile headings. The rest stays in English until it is translated.',
                          style: TextStyle(fontSize: 12, color: AppColors.muted, height: 1.4)),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
