import 'dart:async';

import 'package:flutter/foundation.dart' show LicenseEntryWithLineBreaks, LicenseRegistry;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config.dart';
import 'screens/app_shell.dart';
import 'services/avatar_service.dart';
import 'services/cloud_sync.dart';
import 'services/health_service.dart';
import 'services/push_service.dart';
import 'services/reminder_service.dart';
import 'services/social_service.dart';
import 'services/step_service.dart';
import 'services/sound_service.dart';
import 'services/theme_service.dart';
import 'services/widget_actions.dart';
import 'services/widget_service.dart';
import 'state/app_state.dart';
import 'theme.dart';
import 'services/l10n.dart';
import 'services/notify_prefs.dart';
import 'services/units.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Licence notice for the body figure artwork (MIT).
  LicenseRegistry.addLicense(() async* {
    yield const LicenseEntryWithLineBreaks(
      ['react-native-body-highlighter (body figure artwork)'],
      'MIT License\n\n'
      'Copyright (c) 2022 ELABBASSI Hicham\n\n'
      'Permission is hereby granted, free of charge, to any person obtaining a copy '
      'of this software and associated documentation files (the "Software"), to deal '
      'in the Software without restriction, including without limitation the rights '
      'to use, copy, modify, merge, publish, distribute, sublicense, and/or sell '
      'copies of the Software, and to permit persons to whom the Software is '
      'furnished to do so, subject to the following conditions:\n\n'
      'The above copyright notice and this permission notice shall be included in all '
      'copies or substantial portions of the Software.\n\n'
      'THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR '
      'IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, '
      'FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE '
      'AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER '
      'LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, '
      'OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE '
      'SOFTWARE.',
    );
  });

  final state = AppState();
  await state.load();
  await ThemeService.instance.load();
  await SoundService.instance.load();
  await NotifyPrefs.instance.load();
  await Units.instance.load();
  await AppLang.instance.load();
  await AvatarService.instance.load();

  if (cloudEnabled) {
    await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
    state.cloud = CloudSync();
    state.listenAuth();
    // Already signed in from a previous run: merge cloud data in the background.
    unawaited(state.syncAfterLogin());
  }

  await ReminderService.instance.init();
  if (pushEnabled) unawaited(PushService.instance.start());
  unawaited(ReminderService.instance.reschedule(state));

  unawaited(StepService.instance.start());

  // Keep the home screen widget in step with the app.
  void refreshWidget() {
    unawaited(WidgetService.instance.update(state));
    SocialService.instance.schedulePush(state);
  }
  WidgetActions.instance.start(state);
  unawaited(HealthService.instance.init(state));
  state.addListener(refreshWidget);
  state.addListener(() => ReminderService.instance.onStateChanged(state));
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

class HealthApp extends StatefulWidget {
  const HealthApp({super.key});

  @override
  State<HealthApp> createState() => _HealthAppState();
}

class _HealthAppState extends State<HealthApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycle) {
    // Back in the app: if the last backup failed (offline), try again.
    if (lifecycle == AppLifecycleState.resumed) {
      final app = context.read<AppState>();
      if (app.signedIn && app.syncError != null) {
        unawaited(app.syncAfterLogin());
      }
    }
  }

  // The phone switched between light and dark: draw the app again.
  @override
  void didChangePlatformBrightness() {
    if (ThemeService.instance.mode == ThemeMode.system) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeService.instance,
      builder: (context, _) {
        final ts = ThemeService.instance;
        // Colours read this flag, so set it before anything is built.
        ts.dark = ts.resolveDark();
        final dark = ts.dark;
        return MaterialApp(
          key: ValueKey('${ts.accentIndex}-$dark-${ts.highContrast}'),
          navigatorKey: rootNavKey,
          title: 'Healthy',
          debugShowCheckedModeBanner: false,
          theme: buildTheme(),
          builder: (context, child) {
            final scaled = MediaQuery(
              data: MediaQuery.of(context).copyWith(
                disableAnimations: ts.reduceMotion || MediaQuery.disableAnimationsOf(context),
                boldText: ts.highContrast || MediaQuery.boldTextOf(context),
                textScaler: TextScaler.linear(
                  MediaQuery.textScalerOf(context).scale(1.0) * ts.textScale,
                ),
              ),
              child: child!,
            );
            return AnnotatedRegion<SystemUiOverlayStyle>(
              value: dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
              child: ColoredBox(color: AppColors.bg, child: scaled),
            );
          },
          home: const AppShell(),
        );
      },
    );
  }
}
