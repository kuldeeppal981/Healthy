import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Light, dark or follow the phone. Saved on this phone.
///
/// Dark mode recolours the whole app with one colour filter (colours are
/// inverted and the hue is turned back so purple stays purple). Things that
/// must keep their real colours, like the camera view, use [undoDark].
class ThemeService extends ChangeNotifier {
  ThemeService._();
  static final instance = ThemeService._();

  ThemeMode mode = ThemeMode.system;

  Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      mode = switch (p.getString('themeMode')) {
        'dark' => ThemeMode.dark,
        'light' => ThemeMode.light,
        _ => ThemeMode.system,
      };
    } catch (_) {}
  }

  Future<void> set(ThemeMode m) async {
    mode = m;
    notifyListeners();
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString('themeMode', m.name);
    } catch (_) {}
  }

  bool isDark(BuildContext context) =>
      mode == ThemeMode.dark ||
      (mode == ThemeMode.system &&
          MediaQuery.platformBrightnessOf(context) == Brightness.dark);

  // out = scale * (invert then hue-rotate 180) + lift
  static const _scale = 0.92;
  static const _lift = 18.0;
  static const _a = <double>[
    // rows: R, G, B
    0.574, -1.430, -0.144,
    -0.426, -0.430, -0.144,
    -0.426, -1.430, 0.856,
  ];

  static List<double> get _darkMatrix => [
        _a[0] * _scale, _a[1] * _scale, _a[2] * _scale, 0, 255 * _scale + _lift,
        _a[3] * _scale, _a[4] * _scale, _a[5] * _scale, 0, 255 * _scale + _lift,
        _a[6] * _scale, _a[7] * _scale, _a[8] * _scale, 0, 255 * _scale + _lift,
        0, 0, 0, 1, 0,
      ];

  static ColorFilter get darkFilter => ColorFilter.matrix(_darkMatrix);

  /// Exact inverse of [darkFilter], to restore real colours inside dark mode.
  static ColorFilter get restoreFilter {
    final m = [
      for (var r = 0; r < 3; r++)
        for (var c = 0; c < 3; c++) _a[r * 3 + c] * _scale,
    ];
    final b = 255 * _scale + _lift;
    final det = m[0] * (m[4] * m[8] - m[5] * m[7]) -
        m[1] * (m[3] * m[8] - m[5] * m[6]) +
        m[2] * (m[3] * m[7] - m[4] * m[6]);
    final inv = [
      (m[4] * m[8] - m[5] * m[7]) / det,
      (m[2] * m[7] - m[1] * m[8]) / det,
      (m[1] * m[5] - m[2] * m[4]) / det,
      (m[5] * m[6] - m[3] * m[8]) / det,
      (m[0] * m[8] - m[2] * m[6]) / det,
      (m[2] * m[3] - m[0] * m[5]) / det,
      (m[3] * m[7] - m[4] * m[6]) / det,
      (m[1] * m[6] - m[0] * m[7]) / det,
      (m[0] * m[4] - m[1] * m[3]) / det,
    ];
    // x = inv * (out - b)  =>  offset = -inv * [b, b, b]
    double off(int r) => -(inv[r * 3] + inv[r * 3 + 1] + inv[r * 3 + 2]) * b;
    return ColorFilter.matrix([
      inv[0], inv[1], inv[2], 0, off(0),
      inv[3], inv[4], inv[5], 0, off(1),
      inv[6], inv[7], inv[8], 0, off(2),
      0, 0, 0, 1, 0,
    ]);
  }

  /// Wrap content that must show its real colours (camera, photos).
  static Widget undoDark(BuildContext context, Widget child) {
    if (!instance.isDark(context)) return child;
    return ColorFiltered(colorFilter: restoreFilter, child: child);
  }
}
