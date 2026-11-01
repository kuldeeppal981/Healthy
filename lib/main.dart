import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config.dart';
import 'screens/app_shell.dart';
import 'services/cloud_sync.dart';
import 'state/app_state.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final state = AppState();
  await state.load();

  if (cloudEnabled) {
    await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
    state.cloud = CloudSync();
    // Already signed in from a previous run: merge cloud data in the background.
    unawaited(state.syncAfterLogin());
  }

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
