import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Counts steps with the phone's own step sensor. The sensor reports the
/// total since the phone last restarted, so today's steps are worked out
/// from a baseline saved at the start of each day. Data stays on this phone.
class StepService extends ChangeNotifier {
  StepService._();
  static final instance = StepService._();

  StreamSubscription<StepCount>? _sub;
  SharedPreferences? _p;

  bool granted = false;
  bool unavailable = false;
  int steps = 0;
  int goal = 10000;
  final Map<String, int> history = {}; // yyyy-mm-dd -> steps

  // Saved state used to turn the raw counter into "today".
  String _day = '';
  int _base = 0;
  int _carry = 0; // steps taken before a phone restart today
  int _lastRaw = 0;
  int _external = 0; // steps reported by Health Connect today
  String _externalDay = '';

  static String _key(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> start() async {
    _p = await SharedPreferences.getInstance();
    final p = _p!;
    goal = p.getInt('stepGoal') ?? 10000;
    _day = p.getString('stepDay') ?? '';
    _base = p.getInt('stepBase') ?? 0;
    _carry = p.getInt('stepCarry') ?? 0;
    _lastRaw = p.getInt('stepLastRaw') ?? 0;
    final h = p.getString('stepHistory');
    if (h != null) {
      history
        ..clear()
        ..addAll(Map<String, int>.from(jsonDecode(h) as Map));
    }
    if (_day == _key(DateTime.now())) steps = _carry + (_lastRaw - _base).clamp(0, 1 << 30);

    try {
      granted = await Permission.activityRecognition.isGranted;
    } catch (_) {
      granted = false;
    }
    notifyListeners();
    if (granted) _listen();
  }

  /// Asks for the "Physical activity" permission, then starts counting.
  Future<bool> requestPermission() async {
    try {
      final r = await Permission.activityRecognition.request();
      granted = r.isGranted;
    } catch (_) {
      granted = false;
    }
    notifyListeners();
    if (granted) _listen();
    return granted;
  }

  void _listen() {
    _sub?.cancel();
    _sub = Pedometer.stepCountStream.listen(
      _onRaw,
      onError: (_) {
        unavailable = true;
        notifyListeners();
      },
      cancelOnError: false,
    );
  }

  void _onRaw(StepCount e) {
    final raw = e.steps;
    final today = _key(DateTime.now());

    if (_day != today) {
      // New day: close yesterday and start again from the current count.
      if (_day.isNotEmpty) history[_day] = steps;
      _day = today;
      _base = raw;
      _carry = 0;
    } else if (raw < _lastRaw) {
      // The phone restarted and the counter began again from zero.
      _carry += (_lastRaw - _base).clamp(0, 1 << 30);
      _base = 0;
    }

    _lastRaw = raw;
    steps = _carry + (raw - _base).clamp(0, 1 << 30);
    if (_externalDay == today && _external > steps) steps = _external;
    history[today] = steps;
    // Keep only the last 14 days.
    if (history.length > 14) {
      final keys = history.keys.toList()..sort();
      for (final k in keys.take(history.length - 14)) {
        history.remove(k);
      }
    }
    _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    final p = _p;
    if (p == null) return;
    await p.setString('stepDay', _day);
    await p.setInt('stepBase', _base);
    await p.setInt('stepCarry', _carry);
    await p.setInt('stepLastRaw', _lastRaw);
    await p.setString('stepHistory', jsonEncode(history));
  }

  /// Steps from Health Connect (watch). The larger of the two sources is used.
  void setExternal(int v) {
    final today = _key(DateTime.now());
    _externalDay = today;
    _external = v;
    if (v > steps) {
      steps = v;
      history[today] = v;
      _persist();
      notifyListeners();
    }
  }

  Future<void> setGoal(int g) async {
    goal = g.clamp(1000, 50000);
    await _p?.setInt('stepGoal', goal);
    notifyListeners();
  }

  /// Rough estimate: about 0.00045 kcal per kg of body weight per step.
  static int kcalFor(int steps, double weightKg) =>
      (steps * weightKg * 0.00045).round();

  /// Steps for the last [n] days, oldest first (today last).
  List<MapEntry<DateTime, int>> lastDays(int n) {
    final now = DateTime.now();
    return [
      for (var i = n - 1; i >= 0; i--)
        MapEntry(
          DateTime(now.year, now.month, now.day - i),
          history[_key(DateTime(now.year, now.month, now.day - i))] ?? 0,
        ),
    ];
  }
}
