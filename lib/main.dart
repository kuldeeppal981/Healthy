import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config.dart';
import 'screens/app_shell.dart';
import 'services/avatar_service.dart';
import 'services/cloud_sync.dart';
import 'services/health_service.dart';
import 'services/reminder_service.dart';
import 'services/social_service.dart';
import 'services/step_service.dart';
import 'services/theme_service.dart';
import 'services/widget_service.dart';
import 'state/app_state.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final state = AppState();
  await state.load();
  await ThemeService.instance.load();
  await AvatarService.instance.load();

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
  void refreshWidget() {
    unawaited(WidgetService.instance.update(state));
    SocialService.instance.schedulePush(state);
  }
  unawaited(HealthService.instance.init(state));
  state.addListener(refreshWidget);
  StepService.instance.addListener(refreshWidget);
  refreshWidget();

  SocialService.instance.startWatching();

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
    return ListenableBuilder(
      listenable: ThemeService.instance,
      builder: (context, _) => MaterialApp(
        key: ValueKey(ThemeService.instance.accentIndex),
        title: 'Healthy',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        builder: (context, child) {
          final dark = ThemeService.instance.isDark(context);
          final scaled = MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(
                MediaQuery.textScalerOf(context).scale(1.0) * ThemeService.instance.textScale,
              ),
            ),
            child: child!,
          );
          final body = dark
              ? ColorFiltered(colorFilter: ThemeService.darkFilter, child: scaled)
              : scaled;
          return AnnotatedRegion<SystemUiOverlayStyle>(
            value: dark
                ? SystemUiOverlayStyle.light
                : SystemUiOverlayStyle.dark,
            child: body,
          );
        },
        home: const AppShell(),
      ),
    );
  }
}
