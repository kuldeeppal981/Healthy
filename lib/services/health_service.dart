import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../profile_models.dart';
import '../state/app_state.dart';
import 'step_service.dart';

class SyncedWorkout {
  final String id;
  final DateTime start;
  final int minutes;
  final String name;
  final int? kcal;

  const SyncedWorkout(this.id, this.start, this.minutes, this.name, this.kcal);
}

/// Reads steps, heart rate, sleep and exercise sessions that a smartwatch or
/// another app saved in Android Health Connect. Read only, on this phone.
class HealthService extends ChangeNotifier {
  HealthService._();
  static final instance = HealthService._();

  final Health _h = Health();

  bool connected = false;
  bool unavailable = false;
  bool busy = false;
  String? error;

  int? steps;
  double? avgHr;
  int? minHr;
  int? maxHr;
  double? sleepHours;
  List<SyncedWorkout> workouts = [];
  DateTime? lastSync;

  static const _types = [
    HealthDataType.STEPS,
    HealthDataType.HEART_RATE,
    HealthDataType.SLEEP_SESSION,
    HealthDataType.WORKOUT,
  ];

  Future<void> init(AppState state) async {
    try {
      await _h.configure();
      connected = (await SharedPreferences.getInstance()).getBool('hcConnected') ?? false;
    } catch (_) {
      connected = false;
    }
    notifyListeners();
    if (connected) unawaited(refresh(state));
  }

  Future<bool> connect(AppState state) async {
    busy = true;
    error = null;
    notifyListeners();
    try {
      final status = await _h.getHealthConnectSdkStatus();
      if (status != HealthConnectSdkStatus.sdkAvailable) {
        unavailable = true;
        busy = false;
        error =
            'Health Connect is not installed or needs an update. Install it from the Play Store, then try again.';
        notifyListeners();
        return false;
      }
      unavailable = false;
      final ok = await _h.requestAuthorization(
        _types,
        permissions: List.filled(_types.length, HealthDataAccess.READ),
      );
      connected = ok;
      await (await SharedPreferences.getInstance()).setBool('hcConnected', ok);
      if (!ok) error = 'Permission was not given. Allow access in Health Connect and try again.';
      busy = false;
      notifyListeners();
      if (ok) await refresh(state);
      return ok;
    } catch (_) {
      busy = false;
      error = 'Could not connect to Health Connect on this phone.';
      notifyListeners();
      return false;
    }
  }

  Future<void> disconnect() async {
    connected = false;
    steps = null;
    avgHr = null;
    sleepHours = null;
    workouts = [];
    await (await SharedPreferences.getInstance()).setBool('hcConnected', false);
    notifyListeners();
  }

  /// Reads today's numbers and imports new exercise sessions into the log.
  Future<void> refresh(AppState state) async {
    if (!connected) return;
    busy = true;
    error = null;
    notifyListeners();
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day);

    try {
      steps = await _h.getTotalStepsInInterval(midnight, now);
      if (steps != null && steps! > 0) StepService.instance.setExternal(steps!);
    } catch (_) {}

    try {
      final hr = await _h.getHealthDataFromTypes(
        types: [HealthDataType.HEART_RATE],
        startTime: midnight,
        endTime: now,
      );
      final vals = <double>[];
      for (final p in hr) {
        final v = p.value;
        if (v is NumericHealthValue) vals.add(v.numericValue.toDouble());
      }
      if (vals.isEmpty) {
        avgHr = null;
        minHr = null;
        maxHr = null;
      } else {
        avgHr = vals.reduce((a, b) => a + b) / vals.length;
        minHr = vals.reduce((a, b) => a < b ? a : b).round();
        maxHr = vals.reduce((a, b) => a > b ? a : b).round();
      }
    } catch (_) {}

    try {
      final sleep = await _h.getHealthDataFromTypes(
        types: [HealthDataType.SLEEP_SESSION],
        startTime: now.subtract(const Duration(hours: 30)),
        endTime: now,
      );
      var minutes = 0;
      for (final p in sleep) {
        minutes += p.dateTo.difference(p.dateFrom).inMinutes;
      }
      sleepHours = minutes == 0 ? null : minutes / 60;
    } catch (_) {}

    try {
      final raw = await _h.getHealthDataFromTypes(
        types: [HealthDataType.WORKOUT],
        startTime: now.subtract(const Duration(days: 14)),
        endTime: now,
      );
      final list = <SyncedWorkout>[];
      for (final p in raw) {
        final v = p.value;
        var name = 'Workout';
        int? kcal;
        if (v is WorkoutHealthValue) {
          name = _pretty(v.workoutActivityType.name);
          kcal = v.totalEnergyBurned;
        }
        list.add(SyncedWorkout(
          'hc_${p.dateFrom.millisecondsSinceEpoch}',
          p.dateFrom,
          p.dateTo.difference(p.dateFrom).inMinutes,
          name,
          kcal,
        ));
      }
      list.sort((a, b) => b.start.compareTo(a.start));
      workouts = list;
      final have = state.workouts.map((w) => w.id).toSet();
      for (final w in list) {
        if (have.contains(w.id) || w.minutes < 5) continue;
        state.addWorkout(WorkoutLog(
          id: w.id,
          at: w.start,
          title: '${w.name} ${w.minutes} min',
          sets: 0,
          volumeKg: 0,
        ));
      }
    } catch (_) {}

    lastSync = DateTime.now();
    busy = false;
    notifyListeners();
  }

  static String _pretty(String raw) {
    final words = raw.toLowerCase().split('_');
    return words.map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}').join(' ');
  }
}
