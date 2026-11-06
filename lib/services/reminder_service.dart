import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../models.dart';
import '../state/app_state.dart';

class Reminder {
  bool enabled;
  TimeOfDay time;

  Reminder(this.enabled, this.time);

  Map<String, dynamic> toJson() =>
      {'on': enabled, 'h': time.hour, 'm': time.minute};

  static Reminder fromJson(Object? j, Reminder fallback) {
    if (j is! Map) return fallback;
    return Reminder(
      j['on'] as bool? ?? fallback.enabled,
      TimeOfDay(
        hour: (j['h'] as num?)?.toInt() ?? fallback.time.hour,
        minute: (j['m'] as num?)?.toInt() ?? fallback.time.minute,
      ),
    );
  }
}

/// Local reminders on this phone: meals, water and workout days.
/// They are device settings, so they are not part of the cloud backup.
class ReminderService extends ChangeNotifier {
  ReminderService._();
  static final instance = ReminderService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  Reminder breakfast = Reminder(false, const TimeOfDay(hour: 8, minute: 30));
  Reminder lunch = Reminder(false, const TimeOfDay(hour: 13, minute: 0));
  Reminder dinner = Reminder(false, const TimeOfDay(hour: 20, minute: 0));
  Reminder workout = Reminder(false, const TimeOfDay(hour: 18, minute: 0));
  bool water = false;
  int waterEveryHours = 2; // between 9:00 and 21:00

  /// Smart reminders: no reminder for something already done today, and meal
  /// reminders move to the time you usually eat (after a few days of logs).
  bool smart = true;

  static const _channel = AndroidNotificationDetails(
    'reminders',
    'Reminders',
    channelDescription: 'Meal, water and workout reminders',
    importance: Importance.high,
    priority: Priority.high,
  );
  static const _details = NotificationDetails(android: _channel);

  /// Gym alarm: rings on the alarm volume and repeats the sound until the
  /// user opens or dismisses it.
  static final _gymAlarm = NotificationDetails(
    android: AndroidNotificationDetails(
      'gym_alarm',
      'Gym alarm',
      channelDescription: 'Rings at your daily gym time',
      importance: Importance.max,
      priority: Priority.max,
      category: AndroidNotificationCategory.alarm,
      audioAttributesUsage: AudioAttributesUsage.alarm,
      fullScreenIntent: true,
      autoCancel: false,
      playSound: true,
      enableVibration: true,
      additionalFlags: Int32List.fromList(<int>[4]), // FLAG_INSISTENT
    ),
  );

  bool _exact = false;

  /// Exact alarms need a permission the user grants in system settings.
  Future<bool> askExactAlarm() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    try {
      var ok = await android?.canScheduleExactNotifications() ?? true;
      if (!ok) {
        await android?.requestExactAlarmsPermission();
        ok = await android?.canScheduleExactNotifications() ?? false;
      }
      return ok;
    } catch (_) {
      return false;
    }
  }

  Future<void> init() async {
    if (_ready) return;
    try {
      tzdata.initializeTimeZones();
      _setLocalZone();
      await _plugin.initialize(const InitializationSettings(
        android: AndroidInitializationSettings('ic_notification'),
      ));
      await _load();
      _ready = true;
    } catch (_) {
      _ready = false;
    }
  }

  bool get available => _ready;

  /// Picks the time zone that matches the phone's current UTC offset.
  void _setLocalZone() {
    final offset = DateTime.now().timeZoneOffset;
    const preferred = {
      330: 'Asia/Kolkata',
      0: 'Europe/London',
      240: 'Asia/Dubai',
      480: 'Asia/Singapore',
      -300: 'America/New_York',
      -480: 'America/Los_Angeles',
      600: 'Australia/Sydney',
    };
    final pref = preferred[offset.inMinutes];
    if (pref != null) {
      tz.setLocalLocation(tz.getLocation(pref));
      return;
    }
    for (final loc in tz.timeZoneDatabase.locations.values) {
      if (!loc.name.contains('/')) continue;
      if (tz.TZDateTime.now(loc).timeZoneOffset == offset) {
        tz.setLocalLocation(loc);
        return;
      }
    }
    tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));
  }

  /// Creates the "Friends" channel up front, so push messages that arrive while
  /// the app is closed show as a banner (high importance) from the very first one.
  Future<void> createFriendsChannel() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    try {
      await android?.createNotificationChannel(const AndroidNotificationChannel(
        'cheers',
        'Friends',
        description: 'Cheers on your achievements',
        importance: Importance.high,
      ));
    } catch (_) {}
  }

  Future<bool> askPermission() async {
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    return await android?.requestNotificationsPermission() ?? true;
  }

  Future<void> _load() async {
    final raw = (await SharedPreferences.getInstance()).getString('reminders');
    if (raw == null) return;
    final j = jsonDecode(raw) as Map<String, dynamic>;
    breakfast = Reminder.fromJson(j['breakfast'], breakfast);
    lunch = Reminder.fromJson(j['lunch'], lunch);
    dinner = Reminder.fromJson(j['dinner'], dinner);
    workout = Reminder.fromJson(j['workout'], workout);
    water = j['water'] as bool? ?? false;
    waterEveryHours = (j['waterEvery'] as num?)?.toInt() ?? 2;
    smart = j['smart'] as bool? ?? true;
  }

  Future<void> _store() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(
      'reminders',
      jsonEncode({
        'breakfast': breakfast.toJson(),
        'lunch': lunch.toJson(),
        'dinner': dinner.toJson(),
        'workout': workout.toJson(),
        'water': water,
        'waterEvery': waterEveryHours,
        'smart': smart,
      }),
    );
  }

  tz.TZDateTime _next(int hour, int minute, {int? weekday, bool skipToday = false}) {
    final now = tz.TZDateTime.now(tz.local);
    var t = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    while (t.isBefore(now) ||
        (weekday != null && t.weekday != weekday) ||
        (skipToday && t.year == now.year && t.month == now.month && t.day == now.day)) {
      t = t.add(const Duration(days: 1));
    }
    return t;
  }

  Future<void> _daily(int id, String title, String body, TimeOfDay t,
      {bool skipToday = false}) {
    return _plugin.zonedSchedule(
      id,
      title,
      body,
      _next(t.hour, t.minute, skipToday: skipToday),
      _details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> _weekly(int id, int weekday, String title, String body, TimeOfDay t,
      {bool alarm = false, bool skipToday = false}) {
    return _plugin.zonedSchedule(
      id,
      title,
      body,
      _next(t.hour, t.minute, weekday: weekday, skipToday: skipToday),
      alarm ? _gymAlarm : _details,
      androidScheduleMode: (alarm && _exact)
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    );
  }

  /// Saves the settings and schedules everything again from scratch.
  /// Shows a notification straight away (used for friends' cheers).
  Future<void> showNow(int id, String title, String body) async {
    if (!_ready) return;
    try {
      await _plugin.show(
        id,
        title,
        body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'cheers',
            'Friends',
            channelDescription: 'Cheers on your achievements',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
      );
    } catch (_) {}
  }

  // ---- Rest timer shown on the lock screen / notification shade ----
  static const _restId = 9001;
  static const _restDoneId = 9002;

  /// Starts a countdown notification. The phone itself draws the ticking time
  /// (chronometer), so it keeps running with the screen off and shows on the
  /// lock screen. A second notification rings when the rest is over.
  Future<void> startRestTimer(int seconds, {String? exercise}) async {
    if (!_ready) return;
    try {
      final end = DateTime.now().add(Duration(seconds: seconds));
      await _plugin.show(
        _restId,
        'Rest timer',
        exercise == null ? 'Next set when the timer ends' : 'Next: $exercise',
        NotificationDetails(
          android: AndroidNotificationDetails(
            'rest_timer',
            'Rest timer',
            channelDescription: 'Countdown between sets',
            importance: Importance.low,
            priority: Priority.low,
            ongoing: true,
            autoCancel: false,
            onlyAlertOnce: true,
            showWhen: true,
            when: end.millisecondsSinceEpoch,
            usesChronometer: true,
            chronometerCountDown: true,
            timeoutAfter: seconds * 1000,
            visibility: NotificationVisibility.public,
          ),
        ),
      );
      await _plugin.zonedSchedule(
        _restDoneId,
        'Rest over',
        exercise == null ? 'Time for your next set' : 'Time for your next set of $exercise',
        tz.TZDateTime.now(tz.local).add(Duration(seconds: seconds)),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'rest_done',
            'Rest over',
            channelDescription: 'Rings when your rest between sets is over',
            importance: Importance.high,
            priority: Priority.high,
            visibility: NotificationVisibility.public,
          ),
        ),
        androidScheduleMode: _exact
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (_) {}
  }

  /// Removes the countdown and the "rest over" ring (skip, finish or app open).
  Future<void> stopRestTimer() async {
    if (!_ready) return;
    try {
      await _plugin.cancel(_restId);
      await _plugin.cancel(_restDoneId);
    } catch (_) {}
  }

  Future<void> apply(AppState state) async {
    await _store();
    await reschedule(state);
    notifyListeners();
  }

  /// Usual time (minutes after midnight) the user logs [meal], from the last
  /// two weeks. Null until there are at least 4 logs.
  int? _usualMinutes(AppState state, String meal) {
    final since = DateTime.now().subtract(const Duration(days: 14));
    final mins = <int>[
      for (final e in state.entries)
        if (e.meal == meal && e.at.isAfter(since)) e.at.hour * 60 + e.at.minute,
    ]..sort();
    if (mins.length < 4) return null;
    return mins[mins.length ~/ 2];
  }

  /// Reminder time for a meal: your usual time minus 15 minutes when that is
  /// more than 45 minutes away from the time you set, else the time you set.
  TimeOfDay _mealTime(AppState state, String meal, TimeOfDay set) {
    if (!smart) return set;
    final usual = _usualMinutes(state, meal);
    if (usual == null) return set;
    final target = (usual - 15).clamp(5 * 60, 22 * 60).toInt();
    final setMin = set.hour * 60 + set.minute;
    if ((target - setMin).abs() <= 45) return set;
    return TimeOfDay(hour: target ~/ 60, minute: target % 60);
  }

  String _lastSignature = '';
  Timer? _debounce;

  /// Called whenever the app data changes. Plans the reminders again only when
  /// something that matters changed (a meal, the workout or water goal done).
  void onStateChanged(AppState state) {
    if (!_ready || !smart) return;
    final now = DateTime.now();
    final sig = [
      AppState.dayKey(now),
      for (final m in mealOrder) state.mealEntries(m).isNotEmpty,
      state.workouts.any((w) => AppState.sameDay(w.at, now)),
      state.waterToday >= state.waterTarget,
    ].join('|');
    if (sig == _lastSignature) return;
    _lastSignature = sig;
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 2), () => reschedule(state));
  }

  Future<void> reschedule(AppState state) async {
    if (!_ready) return;
    try {
      // Cancel only our own reminders (not the rest timer notification).
      for (final id in [1, 2, 3, 11, 12, 13, 14, 15, 16, 17]) {
        await _plugin.cancel(id);
      }
      for (var id = 100; id < 125; id++) {
        await _plugin.cancel(id);
      }
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      try {
        _exact = await android?.canScheduleExactNotifications() ?? false;
      } catch (_) {
        _exact = false;
      }
      final now = DateTime.now();
      bool logged(String meal) => smart && state.mealEntries(meal).isNotEmpty;
      if (breakfast.enabled) {
        await _daily(1, 'Breakfast time', 'Log your breakfast in Healthy.',
            _mealTime(state, 'breakfast', breakfast.time),
            skipToday: logged('breakfast'));
      }
      if (lunch.enabled) {
        await _daily(2, 'Lunch time', 'Log your lunch in Healthy.',
            _mealTime(state, 'lunch', lunch.time),
            skipToday: logged('lunch'));
      }
      if (dinner.enabled) {
        await _daily(3, 'Dinner time', 'Log your dinner in Healthy.',
            _mealTime(state, 'dinner', dinner.time),
            skipToday: logged('dinner'));
      }
      if (workout.enabled) {
        final doneToday = smart && state.workouts.any((w) => AppState.sameDay(w.at, now));
        for (var wd = 1; wd <= 7; wd++) {
          final plan = state.planFor(wd);
          if (plan.rest) continue;
          await _weekly(10 + wd, wd, 'Time to hit the gym', "Today: ${plan.title}", workout.time,
              alarm: true, skipToday: doneToday && wd == now.weekday);
        }
      }
      if (water) {
        final goalDone = smart && state.waterToday >= state.waterTarget;
        var id = 100;
        for (var h = 9; h <= 21; h += waterEveryHours) {
          await _daily(id++, 'Drink some water',
              'Have a glass of water and log it.', TimeOfDay(hour: h, minute: 0),
              skipToday: goalDone);
        }
      }
    } catch (_) {}
  }
}
