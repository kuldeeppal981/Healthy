import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Body weight and height display. Everything is stored in kg and cm;
/// only what is shown (and typed for body weight and height) changes.
/// Gym lifts (sets, volume, records) always stay in kg.
class Units extends ChangeNotifier {
  Units._();
  static final instance = Units._();

  bool imperial = false;

  Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      imperial = p.getBool('unitsImperial') ?? false;
    } catch (_) {}
  }

  Future<void> setImperial(bool v) async {
    imperial = v;
    notifyListeners();
    try {
      final p = await SharedPreferences.getInstance();
      await p.setBool('unitsImperial', v);
    } catch (_) {}
  }

  static const _lbPerKg = 2.2046226;

  String get weightUnit => imperial ? 'lb' : 'kg';

  /// Height field unit: centimetres, or inches in imperial mode.
  String get heightUnit => imperial ? 'in' : 'cm';

  double weightValue(double kg) => imperial ? kg * _lbPerKg : kg;
  double kgFromInput(double v) => imperial ? v / _lbPerKg : v;
  double heightValue(double cm) => imperial ? cm / 2.54 : cm;
  double cmFromInput(double v) => imperial ? v * 2.54 : v;

  String weight(double kg, {int decimals = 1}) =>
      '${weightValue(kg).toStringAsFixed(decimals)} $weightUnit';

  /// A change such as "+0.8 kg".
  String weightChange(double deltaKg, {int decimals = 1}) {
    final v = weightValue(deltaKg);
    return '${v > 0 ? '+' : ''}${v.toStringAsFixed(decimals)} $weightUnit';
  }

  String height(double cm) {
    if (!imperial) return '${cm.round()} cm';
    final totalIn = (cm / 2.54).round();
    return '${totalIn ~/ 12} ft ${totalIn % 12} in';
  }
}
