import 'dart:async';

import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';

import '../screens/exercise_library_screen.dart';
import '../screens/scan_screen.dart';
import '../state/app_state.dart';
import '../widgets/quick_add_sheet.dart';

final GlobalKey<NavigatorState> rootNavKey = GlobalKey<NavigatorState>();

/// Buttons on the home screen widget open the app on a link like
/// healthy://meal, healthy://water, healthy://scan, healthy://yoga.
class WidgetActions {
  WidgetActions._();
  static final instance = WidgetActions._();

  AppState? _state;

  void start(AppState state) {
    _state = state;
    unawaited(HomeWidget.initiallyLaunchedFromHomeWidget().then(_handle));
    HomeWidget.widgetClicked.listen(_handle);
  }

  Future<void> _handle(Uri? uri) async {
    final s = _state;
    if (uri == null || s == null || uri.scheme != 'healthy') return;
    // Give the first screen a moment to appear after a cold start.
    for (var i = 0; i < 20 && rootNavKey.currentContext == null; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    await Future<void>.delayed(const Duration(milliseconds: 400));
    final ctx = rootNavKey.currentContext;
    if (ctx == null || !ctx.mounted) return;
    switch (uri.host) {
      case 'meal':
        await showQuickAdd(ctx, s, onGoto: (_) {});
      case 'water':
        s.addWater(1);
        ScaffoldMessenger.maybeOf(ctx)?.showSnackBar(
          SnackBar(content: Text('Water added: ${s.waterToday} glasses today')),
        );
      case 'scan':
        await Navigator.of(ctx).push(
          MaterialPageRoute<void>(builder: (_) => const ScanScreen()),
        );
      case 'yoga':
        await Navigator.of(ctx).push(
          MaterialPageRoute<void>(
              builder: (_) => const ExerciseLibraryScreen(initialGroup: 'Yoga')),
        );
    }
  }
}
