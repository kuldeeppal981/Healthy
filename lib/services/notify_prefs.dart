import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// What the user wants to be notified about, and quiet hours.
/// Kept on the phone, and copied to the account so the server can respect it
/// for push messages too (see DATABASE.md, `notify_push`).
class NotifyPrefs extends ChangeNotifier {
  NotifyPrefs._();
  static final instance = NotifyPrefs._();

  bool friends = true; // friend requests, accepted requests, nudges
  bool cheers = true;
  bool quietOn = false;
  int quietFrom = 22 * 60; // minutes after midnight
  int quietTo = 7 * 60;

  Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      friends = p.getBool('np_friends') ?? true;
      cheers = p.getBool('np_cheers') ?? true;
      quietOn = p.getBool('np_quiet') ?? false;
      quietFrom = p.getInt('np_from') ?? quietFrom;
      quietTo = p.getInt('np_to') ?? quietTo;
    } catch (_) {}
  }

  Future<void> _save() async {
    notifyListeners();
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool('np_friends', friends);
      await p.setBool('np_cheers', cheers);
      await p.setBool('np_quiet', quietOn);
      await p.setInt('np_from', quietFrom);
      await p.setInt('np_to', quietTo);
    } catch (_) {}
    await sync();
  }

  Future<void> setFriends(bool v) {
    friends = v;
    return _save();
  }

  Future<void> setCheers(bool v) {
    cheers = v;
    return _save();
  }

  Future<void> setQuietOn(bool v) {
    quietOn = v;
    return _save();
  }

  Future<void> setQuiet(int from, int to) {
    quietFrom = from;
    quietTo = to;
    return _save();
  }

  /// Copies the choices to the account (ignored when signed out).
  Future<void> sync() async {
    try {
      final c = Supabase.instance.client;
      if (c.auth.currentUser == null) return;
      await c.rpc('set_notif_prefs', params: {
        'p_friends': friends,
        'p_cheers': cheers,
        'p_quiet_on': quietOn,
        'p_from': quietFrom,
        'p_to': quietTo,
        'p_tz': DateTime.now().timeZoneOffset.inMinutes,
      });
    } catch (_) {}
  }

  /// True when [minutes] after midnight falls inside quiet hours.
  bool quietAt(int minutes) {
    if (!quietOn || quietFrom == quietTo) return false;
    return quietFrom < quietTo
        ? (minutes >= quietFrom && minutes < quietTo)
        : (minutes >= quietFrom || minutes < quietTo);
  }

  bool quietNow() {
    final n = DateTime.now();
    return quietAt(n.hour * 60 + n.minute);
  }

  /// Which setting a notification title belongs to: 'cheer', 'friend' or 'other'.
  static String kindOf(String title) {
    if (title == 'New cheer') return 'cheer';
    if (title == 'New friend request' ||
        title == 'Friend request accepted' ||
        title.startsWith('Nudge from')) {
      return 'friend';
    }
    return 'other';
  }

  bool allows(String kind) {
    if (quietNow()) return false;
    if (kind == 'cheer') return cheers;
    if (kind == 'friend') return friends;
    return true;
  }
}
