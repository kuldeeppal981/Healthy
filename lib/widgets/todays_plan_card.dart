import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../services/step_service.dart';
import '../state/app_state.dart';
import '../theme.dart';
import 'add_food_sheet.dart';
import 'celebrate.dart';
import 'ui_kit.dart';
import '../services/l10n.dart';

class _Item {
  final String id;
  final IconData icon;
  final String title;
  final String detail;
  final bool done;
  final VoidCallback? onTap;
  const _Item(this.id, this.icon, this.title, this.detail, this.done, this.onTap);
}

/// Home card: today's to-do list that ticks itself as you log things.
class TodaysPlanCard extends StatefulWidget {
  final void Function(int tab) onGoto;

  /// Compact (Home): shows only the next 3 things, "View all" opens the list.
  final bool compact;

  const TodaysPlanCard({super.key, required this.onGoto, this.compact = false});

  @override
  State<TodaysPlanCard> createState() => _TodaysPlanCardState();
}

class _TodaysPlanCardState extends State<TodaysPlanCard> {
  bool? _wasAllDone;

  List<_Item> _items(AppState s) {
    final now = DateTime.now();
    final plan = s.planFor(now.weekday);
    final steps = StepService.instance;
    final out = <_Item>[];
    for (final m in const ['breakfast', 'lunch', 'dinner']) {
      final logged = s.mealEntries(m).isNotEmpty;
      out.add(_Item(
        m,
        logged ? Icons.check_circle : Icons.circle_outlined,
        'Log ${mealLabels[m]!.toLowerCase()}',
        logged ? '${s.mealEntries(m).fold<double>(0, (a, e) => a + e.kcal).round()} kcal' : 'Tap to add',
        logged,
        () => showAddFoodSheet(context, meal: m),
      ));
    }
    final waterDone = s.waterToday >= s.waterTarget;
    out.add(_Item(
      'water',
      waterDone ? Icons.check_circle : Icons.circle_outlined,
      'Drink water',
      '${s.waterToday} of ${s.waterTarget} glasses',
      waterDone,
      () {
        Haptic.splash();
        s.addWater(1);
      },
    ));
    if (steps.granted) {
      final done = steps.steps >= steps.goal;
      out.add(_Item(
        'steps',
        done ? Icons.check_circle : Icons.circle_outlined,
        'Walk',
        '${steps.steps} of ${steps.goal} steps',
        done,
        null,
      ));
    }
    if (!plan.rest) {
      final done = s.workouts.any((w) => AppState.sameDay(w.at, now));
      out.add(_Item(
        'workout',
        done ? Icons.check_circle : Icons.circle_outlined,
        'Workout: ${plan.title}',
        done ? 'Done' : 'Tap to open',
        done,
        () => widget.onGoto(2),
      ));
    }
    final checked = s.checkedInToday;
    out.add(_Item(
      'checkin',
      checked ? Icons.check_circle : Icons.circle_outlined,
      'Check in',
      checked ? 'Streak safe for today' : 'Logging anything checks you in too',
      checked,
      () {
        Haptic.done();
        s.checkIn();
      },
    ));
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    // Rebuild when steps change too.
    return ListenableBuilder(
      listenable: StepService.instance,
      builder: (context, _) {
        final items = _items(s);
        final done = items.where((i) => i.done).length;
        final all = done == items.length;
        final prev = _wasAllDone;
        _wasAllDone = all;
        if (prev == false && all) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            Haptic.win();
            Celebrate.show(context);
          });
        }
        return AppCard(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(tr("Today's plan"),
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  ),
                  InkWell(
                    onTap: widget.compact ? () => _showAll(context, items) : null,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Text(
                          widget.compact
                              ? (all ? 'All done  ›' : '$done of ${items.length}  View all ›')
                              : (all ? 'All done' : '$done of ${items.length}'),
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: widget.compact
                                  ? AppColors.link
                                  : (all ? AppColors.safe : AppColors.muted))),
                    ),
                  ),
                ],
              ),
              if (!all)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text('Next: ${items.firstWhere((i) => !i.done).title}',
                      style: TextStyle(fontSize: 12, color: AppColors.muted)),
                ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: items.isEmpty ? 0 : done / items.length,
                  minHeight: 8,
                  color: AppColors.primary,
                  backgroundColor: AppColors.track,
                ),
              ),
              const SizedBox(height: 6),
              for (final i in (widget.compact ? _shown(items) : items)) _row(i),
            ],
          ),
        );
      },
    );
  }

  /// Compact list: the next 3 things to do (or the last done ones when all done).
  List<_Item> _shown(List<_Item> items) {
    final open = items.where((i) => !i.done).toList();
    if (open.isEmpty) return items.take(3).toList();
    return open.take(3).toList();
  }

  void _showAll(BuildContext context, List<_Item> items) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.card,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(tr("Today's plan"),
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              for (final i in items)
                _row(i, onDone: () => Navigator.of(ctx).pop()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(_Item i, {VoidCallback? onDone}) {
    return Semantics(
      button: i.onTap != null,
      checked: i.done,
      label: '${i.title}. ${i.detail}. ${i.done ? 'Done' : 'Not done'}',
      excludeSemantics: true,
      child: InkWell(
        onTap: i.onTap == null
            ? null
            : () {
                onDone?.call();
                i.onTap!();
              },
        borderRadius: BorderRadius.circular(12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Row(
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
                child: Icon(
                  i.done ? Icons.check_circle : Icons.circle_outlined,
                  key: ValueKey(i.done),
                  color: i.done ? AppColors.safe : AppColors.muted,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(i.title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          decoration: i.done ? TextDecoration.lineThrough : null,
                          color: i.done ? AppColors.muted : AppColors.ink,
                        )),
                    Text(i.detail, style: TextStyle(fontSize: 12, color: AppColors.muted)),
                  ],
                ),
              ),
              if (i.onTap != null && !i.done)
                Icon(Icons.chevron_right, color: AppColors.muted, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
