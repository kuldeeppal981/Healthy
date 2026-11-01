import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/allergy_checker.dart';
import '../state/app_state.dart';
import '../theme.dart';

/// Pick allergies, set severity, and control "may contain" warnings.
class AllergyScreen extends StatelessWidget {
  const AllergyScreen({super.key});

  static const _levels = {
    'mild': 'Halki',
    'medium': 'Medium',
    'severe': 'Severe',
  };

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      children: [
        const Text('Allergy profile',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        const Text(
          'Jo select karoge, scan karte hi uska alert milega.',
          style: TextStyle(color: AppColors.muted),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final a in allergenDefs)
              _AllergyChip(
                label: a.label,
                selected: s.allergies.contains(a.id),
                onTap: () => s.toggleAllergy(a.id),
              ),
          ],
        ),
        const SizedBox(height: 20),
        for (final id in s.allergies)
          if (allergenById(id) != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: AppCard(
                radius: 18,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${allergenById(id)!.label}: kitni serious?',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: SegmentedButton<String>(
                        showSelectedIcon: false,
                        segments: [
                          for (final e in _levels.entries)
                            ButtonSegment<String>(value: e.key, label: Text(e.value)),
                        ],
                        selected: {s.severity[id] ?? 'medium'},
                        onSelectionChanged: (v) => s.setSeverity(id, v.first),
                      ),
                    ),
                    if (s.severity[id] == 'severe')
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text(
                          'Severe allergy mein "may contain" wale products bhi avoid karo.',
                          style: TextStyle(fontSize: 12, color: AppColors.muted),
                        ),
                      ),
                  ],
                ),
              ),
            ),
        AppCard(
          radius: 18,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('"May contain" traces warning',
                style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: const Text('Cross-contamination ka alert'),
            value: s.traceWarning,
            activeColor: AppColors.primary,
            onChanged: s.setTraceWarning,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Ye app sirf madad ke liye hai. Serious allergy mein hamesha product label khud padho aur doctor ki salah lo.',
          style: TextStyle(fontSize: 12, color: AppColors.muted, height: 1.4),
        ),
      ],
    );
  }
}

class _AllergyChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _AllergyChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppColors.dangerBg : AppColors.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppColors.danger : AppColors.border,
              width: selected ? 2 : 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              color: selected ? AppColors.danger : AppColors.ink,
            ),
          ),
        ),
      ),
    );
  }
}
