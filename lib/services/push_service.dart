import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config.dart';
import 'reminder_service.dart';

/// Push notifications through Firebase Cloud Messaging.
///
/// Firebase is started from build-time values (see config.dart), so no
/// google-services.json file is needed. The phone token is stored in Supabase
/// (table device_tokens) and the `push` edge function sends the messages.
/// Messages that arrive while the app is closed are shown by Android itself;
/// while the app is open we show them through the local notification plugin.
class PushService {
  PushService._();
  static final PushService instance = PushService._();

  bool _started = false;
  String? _token;

  SupabaseClient get _db => Supabase.instance.client;

  Future<void> start() async {
    if (_started || !pushEnabled) return;
    try {
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: firebaseApiKey,
          appId: firebaseAppId,
          messagingSenderId: firebaseSenderId,
          projectId: firebaseProjectId,
        ),
      );
      _started = true;
      await ReminderService.instance.createFriendsChannel();
      final fm = FirebaseMessaging.instance;
      await fm.requestPermission();

      FirebaseMessaging.onMessage.listen((m) {
        final n = m.notification;
        if (n == null) return;
        unawaited(ReminderService.instance.showNow(
          (m.messageId ?? DateTime.now().toIso8601String()).hashCode & 0x3fffffff,
          n.title ?? 'Healthy',
          n.body ?? '',
        ));
      });
      fm.onTokenRefresh.listen((t) {
        _token = t;
        unawaited(_register());
      });
      // Register again whenever someone signs in.
      _db.auth.onAuthStateChange.listen((e) {
        if (e.session != null) unawaited(_register());
      });

      _token = await fm.getToken();
      await _register();
    } catch (_) {
      // Push is optional: never block the app because of it.
    }
  }

  Future<void> _register() async {
    final t = _token;
    if (t == null || _db.auth.currentUser == null) return;
    try {
      await _db.rpc('register_device_token', params: {'p_token': t});
    } catch (_) {}
  }

  /// Call before signing out so this phone stops getting the old user's messages.
  Future<void> unregister() async {
    final t = _token;
    if (t == null || _db.auth.currentUser == null) return;
    try {
      await _db.rpc('unregister_device_token', params: {'p_token': t});
    } catch (_) {}
  }

  /// After account deletion the server rows are already gone.
  Future<void> forget() async {
    _token = null;
  }
}
