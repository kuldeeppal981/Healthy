import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/add_food_sheet.dart';
import '../widgets/food_art.dart';
import '../widgets/voice_review.dart';
import 'scan_screen.dart';

/// One line of advice from today's numbers (no AI, plain rules).
String dailyTip(AppState s) {
  final h = DateTime.now().hour;
  if (s.today.isEmpty) {
    return 'Log your first meal of the day. Scanning a barcode is the fastest way.';
  }
  if (s.kcalToday > s.kcalTarget) {
    return 'You are over your calorie target today. Keep the next meal light and take a short walk.';
  }
  if (h >= 15 && s.proteinToday < s.proteinTarget * 0.5) {
    return 'Protein is a bit low. Add dal, chana, eggs or paneer to your next meal.';
  }
  if (s.waterToday < s.waterTarget ~/ 2 && h >= 14) {
    return 'You are behind on water. Have a glass now.';
  }
  return 'You are doing well. Keep logging.';
}

/// Diary tab: pick a day, see meals, add, scan, speak and swipe to delete.
class DiaryScreen extends StatefulWidget {
  const DiaryScreen({super.key});

  @override
  State<DiaryScreen> createState() => _DiaryScreenState();
}

class _DiaryScreenState extends State<DiaryScreen> {
  static const _dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  DateTime? _selected;

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final now = DateTime.now();
    final day = _selected ?? now;
    final isToday = AppState.sameDay(day, now);
    final items = s.entriesOn(day);
    double sum(double Function(DiaryEntry e) f) => items.fold(0.0, (a, e) => a + f(e));

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      children: [
        Row(
          children: [
            const Expanded(
              child: Text('Diary',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
            ),
            if (isToday) ...[
              _roundIcon(Icons.qr_code_scanner, 'Scan product', () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const ScanScreen()),
                );
              }),
              const SizedBox(width: 8),
              _roundIcon(Icons.mic, 'Speak', () => logByVoice(context)),
              const SizedBox(width: 8),
              InkWell(
                onTap: () => showAddFoodSheet(context),
                borderRadius: BorderRadius.circular(24),
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.primaryLight, AppColors.primaryDeep],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.add, color: Colors.white, size: 26),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (var i = 6; i >= 0; i--) _dayChip(now.subtract(Duration(days: i)), day),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.chipBg.withOpacity(0.6),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _sumCell('Eaten', '${sum((e) => e.kcal).round()}'),
              _sumCell('Protein', '${sum((e) => e.protein).round()} g'),
              _sumCell('Carbs', '${sum((e) => e.carbs).round()} g'),
              _sumCell('Fat', '${sum((e) => e.fat).round()} g'),
            ],
          ),
        ),
        const SizedBox(height: 6),
        for (final meal in mealOrder)
          _mealCard(context, s, meal, items.where((e) => e.meal == meal).toList(), isToday),
        if (isToday) ...[
          const SizedBox(height: 4),
          AppCard(
            color: AppColors.chipBg,
            borderColor: AppColors.chipBg,
            radius: 18,
            padding: const EdgeInsets.all(14),
            child: Text.rich(
              TextSpan(children: [
                const TextSpan(
                  text: 'Tip: ',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                TextSpan(text: dailyTip(s)),
              ]),
              style: TextStyle(color: AppColors.chipInk, fontSize: 14, height: 1.35),
            ),
          ),
        ],
      ],
    );
  }

  Widget _roundIcon(IconData icon, String tip, VoidCallback onTap) {
    return Tooltip(
      message: tip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.border, width: 1.5),
            color: AppColors.card,
          ),
          child: Icon(icon, color: AppColors.primary, size: 22),
        ),
      ),
    );
  }

  Widget _dayChip(DateTime d, DateTime selected) {
    final on = AppState.sameDay(d, selected);
    return InkWell(
      onTap: () => setState(() => _selected = d),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 42,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: on
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.primaryLight, AppColors.primaryDeep],
                )
              : null,
        ),
        child: Column(
          children: [
            Text(_dayNames[d.weekday - 1],
                style: TextStyle(
                    fontSize: 12, color: on ? Colors.white : AppColors.muted)),
            const SizedBox(height: 2),
            Text('${d.day}',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: on ? Colors.white : AppColors.ink)),
          ],
        ),
      ),
    );
  }

  Widget _sumCell(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: AppColors.muted)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
      ],
    );
  }

  Widget _mealCard(BuildContext context, AppState s, String meal,
      List<DiaryEntry> items, bool canAdd) {
    final kcal = items.fold(0.0, (sum, e) => sum + e.kcal).round();

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        radius: 20,
        padding: const EdgeInsets.fromLTRB(16, 8, 6, 8),
        child: Column(
          children: [
            Row(
              children: [
                _mealTile(meal),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(mealLabels[meal]!,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                      if (items.isEmpty)
                        Text('Nothing added yet',
                            style: TextStyle(fontSize: 13, color: AppColors.muted)),
                    ],
                  ),
                ),
                if (items.isNotEmpty)
                  Text('$kcal kcal',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                if (canAdd)
                  IconButton(
                    tooltip: 'Add to ${mealLabels[meal]}',
                    onPressed: () => showAddFoodSheet(context, meal: meal),
                    icon: Icon(Icons.add_circle, color: AppColors.primary),
                  ),
              ],
            ),
            for (final e in items)
              Dismissible(
                key: ValueKey(e.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 16),
                  color: AppColors.dangerBg,
                  child: Icon(Icons.delete_outline, color: AppColors.danger),
                ),
                onDismissed: (_) => s.removeEntry(e.id),
                child: Padding(
                  padding: const EdgeInsets.only(right: 8, bottom: 6),
                  child: Row(
                    children: [
                      if (FoodArt.kindFor(e.name) != null) ...[
                        FoodArt(FoodArt.kindFor(e.name)!, size: 24),
                        const SizedBox(width: 8),
                      ],
                      Expanded(
                        child: Text(e.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 13, color: AppColors.muted)),
                      ),
                      Text('${e.kcal.round()} kcal',
                          style: TextStyle(fontSize: 13, color: AppColors.muted)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Small coloured icon tile for each meal.
  Widget _mealTile(String meal) {
    final m = meal.toLowerCase();
    IconData icon = Icons.restaurant;
    Color color = AppColors.primary;
    if (m.contains('break')) {
      icon = Icons.free_breakfast;
      color = const Color(0xFFF59E0B);
    } else if (m.contains('lunch')) {
      icon = Icons.lunch_dining;
      color = AppColors.primary;
    } else if (m.contains('snack')) {
      icon = Icons.cookie;
      color = const Color(0xFFEA580C);
    } else if (m.contains('dinner')) {
      icon = Icons.dinner_dining;
      color = const Color(0xFF6366F1);
    }
    FoodKind? art;
    if (m.contains('break')) art = FoodKind.bowl;
    if (m.contains('lunch') || m.contains('dinner')) art = FoodKind.thali;
    if (m.contains('snack')) art = FoodKind.chai;
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(14),
      ),
      child: art != null
          ? Center(child: FoodArt(art, size: 30))
          : Icon(icon, color: color, size: 22),
    );
  }
}
