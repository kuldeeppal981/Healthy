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
  AccentPalette('Black', Color(0xFF14161F), Color(0xFF3A3D4A), Color(0xFF0A0B12),
      Color(0xFF14161F), Color(0xFFF0F0F3), Color(0xFF14161F), Color(0xFFEDEDF0),
      Color(0xFFFAFAFB), Color(0xFFE6E6EA)),
];

/// Light, dark or follow the phone. Saved on this phone.
///
/// Dark mode is a real dark palette: [AppColors] returns dark values while
/// [dark] is true (set by the app root whenever the mode or the phone's
/// brightness changes). [undoDark] is kept for old call sites and does nothing.
class ThemeService extends ChangeNotifier {
  ThemeService._();
  static final instance = ThemeService._();

  ThemeMode mode = ThemeMode.system;

  /// Index into [accentPalettes] (0 = green, the default).
  int accentIndex = 0;

  /// True while the app is drawn in dark mode (set in main.dart).
  bool dark = false;

  AccentPalette get palette {
    final p = accentPalettes[accentIndex];
    return dark ? darkVariantOf(p) : p;
  }

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

  /// Dark or light right now, from the chosen mode and the phone's setting.
  bool resolveDark() =>
      mode == ThemeMode.dark ||
      (mode == ThemeMode.system &&
          WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark);

  bool isDark(BuildContext context) =>
      mode == ThemeMode.dark ||
      (mode == ThemeMode.system &&
          MediaQuery.platformBrightnessOf(context) == Brightness.dark);

  /// Old helper from the filter-based dark mode. Colours are real now, so
  /// this just returns [child].
  static Widget undoDark(BuildContext context, Widget child) => child;
}

const _darkBg = Color(0xFF0D110E);
const _darkCard = Color(0xFF151A17);
const _darkBorder = Color(0xFF26302A);

/// The dark version of an accent palette: dark backgrounds, softened tints.
/// The Black accent turns into a light grey so it can be seen on dark.
AccentPalette darkVariantOf(AccentPalette p) {
  final isBlack = p.name == 'Black';
  final primary = isBlack ? const Color(0xFF8B93A1) : p.primary;
  final light = isBlack ? const Color(0xFFA7AEBB) : p.light;
  final deep = isBlack ? const Color(0xFF6B7280) : p.deep;
  return AccentPalette(
    p.name,
    primary,
    light,
    deep,
    isBlack ? const Color(0xFFC7CCD6) : light,
    Color.alphaBlend(primary.withOpacity(0.18), _darkCard),
    isBlack ? const Color(0xFFE5E7EB) : light,
    Color.alphaBlend(primary.withOpacity(0.12), _darkBg),
    _darkBg,
    _darkBorder,
  );
}
