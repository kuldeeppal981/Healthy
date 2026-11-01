import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config.dart';
import 'screens/app_shell.dart';
import 'services/cloud_sync.dart';
import 'services/reminder_service.dart';
import 'services/step_service.dart';
import 'services/widget_service.dart';
import 'state/app_state.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final state = AppState();
  await state.load();

  if (cloudEnabled) {
    await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
    state.cloud = CloudSync();
    state.listenAuth();
    // Already signed in from a previous run: merge cloud data in the background.
    unawaited(state.syncAfterLogin());
  }

  await ReminderService.instance.init();
  unawaited(ReminderService.instance.reschedule(state));

  unawaited(StepService.instance.start());

  // Keep the home screen widget in step with the app.
  void refreshWidget() => unawaited(WidgetService.instance.update(state));
  state.addListener(refreshWidget);
  StepService.instance.addListener(refreshWidget);
  refreshWidget();

  runApp(
    ChangeNotifierProvider<AppState>.value(
      value: state,
      child: const HealthApp(),
    ),
  );
}

class HealthApp extends StatelessWidget {
  const HealthApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Healthy',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: const AppShell(),
    );
  }
}
