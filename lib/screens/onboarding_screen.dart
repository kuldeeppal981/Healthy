import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../profile_models.dart';
import '../services/nutrition_calc.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/ui_kit.dart';

/// First-run setup (also used to edit the profile later). Works out daily
/// calorie and macro targets from age, height, weight, activity and goal.
class OnboardingScreen extends StatefulWidget {
  final UserProfile? initial;
  final bool editing;

  const OnboardingScreen({super.key, this.initial, this.editing = false});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  late String _sex = widget.initial?.sex ?? 'male';
  late String _activity = widget.initial?.activity ?? 'light';
  late String _goal = widget.initial?.goal ?? 'lose';
  late final TextEditingController _age =
      TextEditingController(text: widget.initial?.age.toString() ?? '');
  late final TextEditingController _height = TextEditingController(
      text: widget.initial == null ? '' : widget.initial!.heightCm.round().toString());
  late final TextEditingController _weight = TextEditingController(
      text: widget.initial == null ? '' : widget.initial!.weightKg.toString());

  @override
  void dispose() {
    _age.dispose();
    _height.dispose();
    _weight.dispose();
    super.dispose();
  }

  UserProfile? _build() {
    final age = int.tryParse(_age.text.trim());
    final h = double.tryParse(_height.text.trim());
    final w = double.tryParse(_weight.text.trim());
    if (age == null || age < 18 || age > 90) return null;
    if (h == null || h < 120 || h > 230) return null;
    if (w == null || w < 30 || w > 250) return null;
    return UserProfile(
      sex: _sex,
      age: age,
      heightCm: h,
      weightKg: w,
      activity: _activity,
      goal: _goal,
    );
  }

  void _save() {
    final p = _build();
    if (p == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter age 18-90, height 120-230 cm and weight 30-250 kg.'),
        ),
      );
      return;
    }
    context.read<AppState>().saveProfile(p);
    if (widget.editing) Navigator.of(context).pop();
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 8),
        child: Text(text, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
      );

  Widget _field(String label, TextEditingController c, String suffix) {
    return TextField(
      controller: c,
      onChanged: (_) => setState(() {}),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(labelText: label, suffixText: suffix),
    );
  }

  @override
  Widget build(BuildContext context) {
    final preview = _build();
    final t = preview == null ? null : targetsFor(preview);

    return Scaffold(
      appBar: widget.editing ? AppBar(title: const Text('Edit profile')) : null,
      body: AppBackground(
       child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          children: [
            if (!widget.editing) ...[
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [AppColors.primaryLight, AppColors.primaryDeep]),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.favorite, color: Colors.white, size: 30),
              ),
              const SizedBox(height: 16),
              const Text('Welcome',
                  style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(
                'Tell us a little about you and we will set your daily calorie and protein targets.',
                style: TextStyle(color: AppColors.muted, height: 1.4),
              ),
              const SizedBox(height: 16),
            ],
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
            _label('Sex'),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<String>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: 'male', label: Text('Male')),
                  ButtonSegment(value: 'female', label: Text('Female')),
                ],
                selected: {_sex},
                onSelectionChanged: (v) => setState(() => _sex = v.first),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(child: _field('Age', _age, 'yrs')),
                const SizedBox(width: 8),
                Expanded(child: _field('Height', _height, 'cm')),
                const SizedBox(width: 8),
                Expanded(child: _field('Weight', _weight, 'kg')),
              ],
            ),
                ],
              ),
            ),
            const SizedBox(height: Space.gap),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
            _label('How active are you?'),
            for (final e in activityLabels.entries)
              _choice(e.value, _activity == e.key, () => setState(() => _activity = e.key)),
                ],
              ),
            ),
            const SizedBox(height: Space.gap),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
            _label('Your goal'),
            for (final e in goalLabels.entries)
              _choice(e.value, _goal == e.key, () => setState(() => _goal = e.key)),
                ],
              ),
            ),
            const SizedBox(height: Space.gap),
            if (t != null)
              AppCard(
                color: AppColors.chipBg,
                borderColor: AppColors.chipBg,
                radius: 18,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Your daily targets',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, color: AppColors.chipInk)),
                    const SizedBox(height: 6),
                    Text(
                      '${t.kcal} kcal  |  ${t.protein} g protein  |  ${t.carbs} g carbs  |  ${t.fat} g fat',
                      style: TextStyle(
                          fontSize: 15, height: 1.4, color: AppColors.chipInk),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            Text(
              'These are estimates for healthy adults (18+), not medical advice. If you have a medical condition, check with your doctor first.',
              style: TextStyle(fontSize: 12, color: AppColors.muted, height: 1.4),
            ),
            const SizedBox(height: 16),
            GradientButton(
              onPressed: _save,
              label: widget.editing ? 'Save' : 'Get started',
            ),
            if (!widget.editing)
              TextButton(
                onPressed: () => context.read<AppState>().skipOnboarding(),
                child: const Text('Skip for now'),
              ),
          ],
        ),
       ),
      ),
    );
  }

  Widget _choice(String text, bool selected, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          constraints: const BoxConstraints(minHeight: 52),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppColors.chipBg : AppColors.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? AppColors.chipInk : AppColors.ink,
                  ),
                ),
              ),
              if (selected) Icon(Icons.check_circle, color: AppColors.primary),
            ],
          ),
        ),
      ),
    );
  }
}
