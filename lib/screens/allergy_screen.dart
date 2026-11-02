import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/allergy_checker.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/ui_kit.dart';

/// Pick allergies, set severity, and control "may contain" warnings.
class AllergyScreen extends StatefulWidget {
  const AllergyScreen({super.key});

  @override
  State<AllergyScreen> createState() => _AllergyScreenState();
}

class _AllergyScreenState extends State<AllergyScreen> {
  bool _food = true;

  static const _levels = {
    'mild': 'Mild',
    'medium': 'Medium',
    'severe': 'Severe',
  };

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              right: -10,
              top: -6,
              child: IgnorePointer(
                child: AppImage('assets/images/shield.png', width: 150, fit: BoxFit.contain),
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(right: 110, top: 4, bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Allergy Profile',
                      style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
                  SizedBox(height: 6),
                  Text(
                    'Select your allergies to get personalized recommendations and alerts.',
                    style: TextStyle(color: AppColors.muted, fontSize: 15, height: 1.35),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        _tabs(),
        const SizedBox(height: 16),
        if (_food) ...[
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 2.25,
            children: [
              for (final a in allergenDefs)
                _AllergenTile(
                  id: a.id,
                  label: a.label,
                  selected: s.allergies.contains(a.id),
                  onTap: () => s.toggleAllergy(a.id),
                ),
            ],
          ),
          const SizedBox(height: 16),
          _severityCard(s),
          const SizedBox(height: 12),
          AppCard(
            radius: 22,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('"May contain" traces warning',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              subtitle: const Text('Cross-contamination alert'),
              value: s.traceWarning,
              activeColor: AppColors.primary,
              onChanged: s.setTraceWarning,
            ),
          ),
        ] else
          const AppCard(
            radius: 22,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.hourglass_empty, color: AppColors.primary),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Pollen, dust, latex and medicine allergies are coming later. For now the app checks food products and the foods you log.',
                    style: TextStyle(height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 12),
        AppCard(
          color: AppColors.chipBg,
          borderColor: AppColors.chipBg,
          radius: 22,
          padding: const EdgeInsets.all(14),
          child: const Row(
            children: [
              Icon(Icons.verified_user_outlined, color: AppColors.primary, size: 34),
              SizedBox(width: 14),
              Expanded(
                child: Text(
                  'We use this to alert you when you scan or log a food. This app is only a helper: for serious allergies, always read the label yourself and follow medical advice.',
                  style: TextStyle(color: AppColors.chipInk, fontSize: 13, height: 1.4),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        GradientButton(
          label: 'Save Profile',
          icon: Icons.check,
          onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(s.allergies.isEmpty
                  ? 'No allergies selected'
                  : 'Allergy profile saved (${s.allergies.length} selected)'),
            ),
          ),
        ),
      ],
    );
  }

  Widget _tabs() {
    Widget tab(bool food, IconData icon, String label) {
      final sel = _food == food;
      return Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(30),
          onTap: () => setState(() => _food = food),
          child: Container(
            height: 52,
            decoration: BoxDecoration(
              gradient: sel
                  ? const LinearGradient(
                      colors: [AppColors.primaryLight, AppColors.primaryDeep],
                    )
                  : null,
              borderRadius: BorderRadius.circular(30),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 22, color: sel ? Colors.white : AppColors.primary),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: sel ? Colors.white : AppColors.primary)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.7),
        borderRadius: BorderRadius.circular(34),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          tab(true, Icons.restaurant, 'Food Allergies'),
          tab(false, Icons.coronavirus_outlined, 'Other Allergies'),
        ],
      ),
    );
  }

  Widget _severityCard(AppState s) {
    final chosen = s.allergies.where((id) => allergenById(id) != null).toList();
    final levels = {for (final id in chosen) s.severity[id] ?? 'medium'};
    final common = levels.length == 1 ? levels.first : null;
    return AppCard(
      color: AppColors.chipBg.withOpacity(0.7),
      borderColor: AppColors.border,
      radius: 24,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: const BoxDecoration(
                    color: AppColors.primary, shape: BoxShape.circle),
                child: const Icon(Icons.priority_high, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('How severe?',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                    Text('Select the severity level for your allergies.',
                        style: TextStyle(fontSize: 13, color: AppColors.muted)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
            ),
            child: Row(
              children: [
                for (final e in _levels.entries)
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(26),
                      onTap: chosen.isEmpty
                          ? null
                          : () {
                              for (final id in chosen) {
                                s.setSeverity(id, e.key);
                              }
                            },
                      child: Container(
                        height: 44,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: common == e.key ? AppColors.primary : Colors.transparent,
                          borderRadius: BorderRadius.circular(26),
                        ),
                        child: Text(e.value,
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: common == e.key ? Colors.white : AppColors.ink)),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (chosen.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('Pick at least one allergy above first.',
                  style: TextStyle(fontSize: 12, color: AppColors.muted)),
            )
          else if (common == null)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('Your allergies have different levels. Tap one to set them all.',
                  style: TextStyle(fontSize: 12, color: AppColors.muted)),
            )
          else if (common == 'severe')
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'With a severe allergy, also avoid products that say "may contain".',
                style: TextStyle(fontSize: 12, color: AppColors.muted),
              ),
            ),
        ],
      ),
    );
  }
}

class _AllergenTile extends StatelessWidget {
  final String id;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _AllergenTile({
    required this.id,
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
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.fromLTRB(8, 6, 10, 6),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFE4F7EA) : Colors.white.withOpacity(0.85),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
              width: selected ? 1.6 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              SizedBox(
                width: 58,
                child: AppImage('assets/images/allergy_$id.png', fit: BoxFit.contain),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 6),
              Align(
                alignment: Alignment.topCenter,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: selected ? AppColors.primary : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected ? AppColors.primary : AppColors.border,
                      width: 1.6,
                    ),
                  ),
                  child: selected
                      ? const Icon(Icons.check, size: 16, color: Colors.white)
                      : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
