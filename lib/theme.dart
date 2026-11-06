import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'services/theme_service.dart';

/// Fresh green and white theme, Outfit font.
class AppColors {
  // Accent colours: change with the theme colour picker (ThemeService).
  static AccentPalette get _p => ThemeService.instance.palette;
  static Color get bg => _p.bg;
  static Color get bgTop => _p.bgTop;
  static Color get primaryLight => _p.light;
  static Color get primaryDeep => _p.deep;
  static bool get _hc => ThemeService.instance.highContrast;
  static Color get border => _hc
      ? (ThemeService.instance.dark ? const Color(0xFF6E8076) : const Color(0xFF5F6F66))
      : _p.border;
  static Color get track => _p.border;
  static Color get primary => _p.primary;
  static Color get link => _p.link;
  static Color get chipBg => _p.chipBg;
  static Color get chipInk => _p.chipInk;

  // Surface and text colours: they switch between the light and dark look.
  static bool get _d => ThemeService.instance.dark;
  static Color get card => _d ? const Color(0xFF151A17) : const Color(0xFFFFFFFF);
  static Color get ink => _hc
      ? (_d ? const Color(0xFFFFFFFF) : const Color(0xFF000000))
      : (_d ? const Color(0xFFF1F5F2) : const Color(0xFF0F1222));
  static Color get muted => _hc
      ? (_d ? const Color(0xFFD5DFD9) : const Color(0xFF2B3631))
      : (_d ? const Color(0xFF9BA9A1) : const Color(0xFF5C6A63));
  static Color get danger => _d ? const Color(0xFFFF8A80) : const Color(0xFFB3261E);
  static Color get dangerBg => _d ? const Color(0xFF3B1B19) : const Color(0xFFFCEBE9);
  static Color get warnBg => _d ? const Color(0xFF33280D) : const Color(0xFFFFF1D6);
  static Color get warnInk => _d ? const Color(0xFFF5D68A) : const Color(0xFF6B4700);
  static Color get safe => _d ? const Color(0xFF5BD68C) : const Color(0xFF1B7F4B);
  static Color get safeBg => _d ? const Color(0xFF11301F) : const Color(0xFFE3F4EA);

  /// Page colour the soft top gradient fades into (white in light mode).
  static Color get page => _d ? const Color(0xFF0D110E) : const Color(0xFFFFFFFF);

  /// Text and icons placed on the accent colour (buttons, gradients).
  static const onAccent = Color(0xFFFFFFFF);

  // Fixed colours (same in light and dark).
  static const ring = Color(0xFFFF5C35);
  static const dangerSolid = Color(0xFFB3261E);
  static const blue = Color(0xFF1E88F0);
}

ThemeData buildTheme() {
  final dark = ThemeService.instance.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    brightness: dark ? Brightness.dark : Brightness.light,
    primary: AppColors.primary,
    surface: AppColors.card,
  );
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.bg,
    canvasColor: AppColors.card,
  );
  return base.copyWith(
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: ZoomPageTransitionsBuilder(),
      },
    ),
    textTheme: GoogleFonts.outfitTextTheme(base.textTheme).apply(
      bodyColor: AppColors.ink,
      displayColor: AppColors.ink,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.bg,
      elevation: 0,
      scrolledUnderElevation: 0,
      foregroundColor: AppColors.ink,
      titleTextStyle: GoogleFonts.outfit(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: AppColors.ink,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onAccent,
        textStyle: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        foregroundColor: AppColors.ink,
        side: BorderSide(color: AppColors.border, width: 1.5),
        textStyle: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.card,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.border),
      ),
    ),
  );
}

/// White rounded card used across screens, with a soft green shadow.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Color? borderColor;
  final double radius;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color,
    this.borderColor,
    this.radius = 24,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? AppColors.card,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor ?? AppColors.border, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.05),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}

/// Big green gradient button. Always bounded, safe to use inside a Row
/// when [expand] is false.
class GradientButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final double height;
  final bool expand;

  const GradientButton({
    super.key,
    required this.label,
    this.icon,
    required this.onPressed,
    this.height = 54,
    this.expand = true,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final body = Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: enabled
              ? [AppColors.primaryLight, AppColors.primaryDeep]
              : [AppColors.muted.withOpacity(0.35), AppColors.muted.withOpacity(0.35)],
        ),
        borderRadius: BorderRadius.circular(height / 2.6),
        boxShadow: enabled
            ? [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.28),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: Row(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(height / 2.6),
        onTap: onPressed,
        child: body,
      ),
    );
  }
}

/// Soft green gradient behind the main tabs.
class AppBackground extends StatelessWidget {
  final Widget child;

  const AppBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.bgTop, AppColors.page, AppColors.page],
          stops: [0.0, 0.28, 1.0],
        ),
      ),
      child: child,
    );
  }
}

/// A list of tappable rows inside one card (used for menus).
class MenuCard extends StatelessWidget {
  final List<MenuRow> rows;

  const MenuCard({super.key, required this.rows});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      radius: 22,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            rows[i],
            if (i != rows.length - 1)
              Divider(height: 1, indent: 64, endIndent: 16, color: AppColors.border),
          ],
        ],
      ),
    );
  }
}

class MenuRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Widget? trailing;

  const MenuRow({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.chipBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, color: AppColors.muted)),
                ],
              ),
            ),
            trailing ?? Icon(Icons.chevron_right, color: AppColors.muted),
          ],
        ),
      ),
    );
  }
}
