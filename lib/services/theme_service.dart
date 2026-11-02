import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One accent colour set (the picker in Profile chooses between these).
class AccentPalette {
  final String name;
  final Color primary, light, deep, link, chipBg, chipInk, bgTop, bg, border;
  const AccentPalette(this.name, this.primary, this.light, this.deep, this.link,
      this.chipBg, this.chipInk, this.bgTop, this.bg, this.border);
}

const accentPalettes = <AccentPalette>[
  AccentPalette('Green', Color(0xFF16A34A), Color(0xFF4ADE80), Color(0xFF16A34A),
      Color(0xFF15803D), Color(0xFFE4F7EA), Color(0xFF166534), Color(0xFFE0F5E8),
      Color(0xFFF6FBF8), Color(0xFFE1F0E6)),
  AccentPalette('Indigo', Color(0xFF4F46E5), Color(0xFF818CF8), Color(0xFF4F46E5),
      Color(0xFF4338CA), Color(0xFFE8E9FD), Color(0xFF3730A3), Color(0xFFE3E5FF),
      Color(0xFFF7F7FF), Color(0xFFE4E6F7)),
  AccentPalette('Orange', Color(0xFFEA580C), Color(0xFFFB923C), Color(0xFFEA580C),
      Color(0xFFC2410C), Color(0xFFFFEDD9), Color(0xFF9A3412), Color(0xFFFFE8D2),
      Color(0xFFFFF9F4), Color(0xFFF7E6D8)),
  AccentPalette('Pink', Color(0xFFDB2777), Color(0xFFF472B6), Color(0xFFDB2777),
      Color(0xFFBE185D), Color(0xFFFCE7F3), Color(0xFF9D174D), Color(0xFFFFE0EF),
      Color(0xFFFFF7FB), Color(0xFFF6E3EE)),
  AccentPalette('Blue', Color(0xFF0284C7), Color(0xFF38BDF8), Color(0xFF0284C7),
      Color(0xFF0369A1), Color(0xFFE0F2FE), Color(0xFF075985), Color(0xFFDDF1FD),
      Color(0xFFF5FAFE), Color(0xFFDEEBF4)),
  AccentPalette('Teal', Color(0xFF0D9488), Color(0xFF2DD4BF), Color(0xFF0D9488),
      Color(0xFF0F766E), Color(0xFFD5F5F1), Color(0xFF115E59), Color(0xFFD3F5EF),
      Color(0xFFF4FCFB), Color(0xFFDAEEEB)),
];

/// Light, dark or follow the phone. Saved on this phone.
///
/// Dark mode recolours the whole app with one colour filter (colours are
/// inverted and the hue is turned back so green stays green). Things that
/// must keep their real colours, like the camera view, use [undoDark].
class ThemeService extends ChangeNotifier {
  ThemeService._();
  static final instance = ThemeService._();

  ThemeMode mode = ThemeMode.system;

  /// Index into [accentPalettes] (0 = green, the default).
  int accentIndex = 0;
  AccentPalette get palette => accentPalettes[accentIndex];

  Future<void> setAccent(int i) async {
    if (i < 0 || i >= accentPalettes.length) return;
    accentIndex = i;
    notifyListeners();
    try {
      final p = await SharedPreferences.getInstance();
      await p.setInt('accent', i);
    } catch (_) {}
  }

  /// Text size multiplier (1.0 normal, 1.15 large, 1.3 extra large).
  double textScale = 1.0;

  Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      mode = switch (p.getString('themeMode')) {
        'dark' => ThemeMode.dark,
        'light' => ThemeMode.light,
        _ => ThemeMode.system,
      };
      textScale = p.getDouble('textScale') ?? 1.0;
      final a = p.getInt('accent') ?? 0;
      accentIndex = (a >= 0 && a < accentPalettes.length) ? a : 0;
    } catch (_) {}
  }

  Future<void> setTextScale(double v) async {
    textScale = v;
    notifyListeners();
    try {
      final p = await SharedPreferences.getInstance();
      await p.setDouble('textScale', v);
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
