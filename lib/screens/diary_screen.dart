import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/add_food_sheet.dart';
import '../widgets/voice_review.dart';

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

/// Today's meals: add, speak and swipe to delete.
class DiaryScreen extends StatelessWidget {
  const DiaryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text("Today's meals"),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.tonalIcon(
              onPressed: () => logByVoice(context),
              icon: const Icon(Icons.mic, size: 18),
              label: const Text('Speak'),
              style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
            ),
          ),
        ],
      ),
      body: AppBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            for (final meal in mealOrder) _mealCard(context, s, meal),
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
        ),
      ),
    );
  }

  Widget _mealCard(BuildContext context, AppState s, String meal) {
    final items = s.mealEntries(meal);
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
                        const Text('Nothing added yet',
                            style: TextStyle(fontSize: 13, color: AppColors.muted)),
                    ],
                  ),
                ),
                if (items.isNotEmpty)
                  Text('$kcal kcal',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
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
                  child: const Icon(Icons.delete_outline, color: AppColors.danger),
                ),
                onDismissed: (_) => s.removeEntry(e.id),
                child: Padding(
                  padding: const EdgeInsets.only(right: 8, bottom: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(e.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 13, color: AppColors.muted)),
                      ),
                      Text('${e.kcal.round()} kcal',
                          style: const TextStyle(fontSize: 13, color: AppColors.muted)),
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
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: color.withOpacity(0.14),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, color: color, size: 22),
    );
  }
}
