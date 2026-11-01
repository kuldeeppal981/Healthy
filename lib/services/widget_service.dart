import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

import '../state/app_state.dart';
import 'step_service.dart';

/// Pushes today's numbers to the Android home screen widget.
class WidgetService {
  WidgetService._();
  static final instance = WidgetService._();

  String _last = '';

  Future<void> update(AppState s) async {
    final kcal = '${s.kcalToday.round()} / ${s.kcalTarget} kcal';
    final protein = 'Protein ${s.proteinToday.round()} / ${s.proteinTarget} g';
    final steps = 'Steps ${StepService.instance.steps}';
    final streak = s.foodStreak > 0 ? '${s.foodStreak} day streak' : 'Log a meal to start';
    final sig = '$kcal|$protein|$steps|$streak';
    if (sig == _last) return;
    _last = sig;
    try {
      await HomeWidget.saveWidgetData<String>('w_kcal', kcal);
      await HomeWidget.saveWidgetData<String>('w_protein', protein);
      await HomeWidget.saveWidgetData<String>('w_steps', steps);
      await HomeWidget.saveWidgetData<String>('w_streak', streak);
      await HomeWidget.updateWidget(androidName: 'HealthyWidgetProvider');
    } catch (e) {
      if (kDebugMode) debugPrint('widget update failed: $e');
    }
  }
}
