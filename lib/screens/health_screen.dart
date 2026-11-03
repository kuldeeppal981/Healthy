import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/health_conditions.dart';
import '../state/app_state.dart';
import '../theme.dart';

/// Pick health conditions. Scanned products are then checked against them.
class HealthScreen extends StatelessWidget {
  const HealthScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final chosen = [
      for (final c in healthConditions)
        if (s.conditions.contains(c.id)) c,
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Health conditions')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Switch on what applies to you. Scanned products will show a warning when they are high in sugar, salt or bad fats for you.',
            style: TextStyle(color: AppColors.muted, height: 1.4),
          ),
          const SizedBox(height: 12),
          AppCard(
            color: AppColors.warnBg,
            borderColor: AppColors.warnBg,
            radius: 14,
            child: Text(
              'This is general guidance, not medical advice. Follow what your doctor or dietitian tells you.',
              style: TextStyle(color: AppColors.warnInk, fontSize: 13, height: 1.4),
            ),
          ),
          const SizedBox(height: 16),
          for (final c in healthConditions)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: AppCard(
                radius: 16,
                padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(c.label,
                              style: const TextStyle(fontWeight: FontWeight.w700)),
                          Text(c.summary,
                              style: TextStyle(
                                  color: AppColors.muted, fontSize: 12)),
                        ],
                      ),
                    ),
                    Switch(
                      value: s.conditions.contains(c.id),
                      activeColor: AppColors.primary,
                      onChanged: (_) => s.toggleCondition(c.id),
                    ),
                  ],
                ),
              ),
            ),
          for (final c in chosen) ...[
            const SizedBox(height: 12),
            Text('Eating guide: ${c.label}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            _list('Prefer', c.prefer, AppColors.safe, Icons.check_circle_outline),
            const SizedBox(height: 8),
            _list('Go easy on', c.limit, AppColors.danger, Icons.remove_circle_outline),
          ],
        ],
      ),
    );
  }

  Widget _list(String title, List<String> items, Color color, IconData icon) {
    return AppCard(
      radius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontWeight: FontWeight.w700, color: color)),
          const SizedBox(height: 6),
          for (final t in items)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, size: 16, color: color),
                  const SizedBox(width: 8),
                  Expanded(child: Text(t, style: const TextStyle(height: 1.3))),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
