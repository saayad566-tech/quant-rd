/// Design tokens for Quant RD. Dark glassmorphism by default, with a full
/// light theme. Every colour, radius, spacing and motion value used in the app
/// is defined here — never as a scattered literal.
library;

import 'package:flutter/material.dart';

class Palette {
  const Palette._();

  // Dark theme — deep navy → midnight.
  static const Color bgTop = Color(0xFF070B1A);
  static const Color bgBottom = Color(0xFF0E1630);
  static const Color surface = Color(0xFF111A33);
  static const Color surfaceAlt = Color(0xFF16203D);

  // Accents.
  static const Color cyan = Color(0xFF22D3EE);
  static const Color cyanDeep = Color(0xFF06B6D4);
  static const Color gold = Color(0xFFF5C451);
  static const Color goldDeep = Color(0xFFD4A93A);

  // Text.
  static const Color textPrimary = Color(0xFFE6EDF7);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted = Color(0xFF64748B);

  // Semantic.
  static const Color success = Color(0xFF34D399);
  static const Color warning = Color(0xFFFBBF24);
  static const Color danger = Color(0xFFF87171);
  static const Color info = Color(0xFF60A5FA);

  // Glass.
  static const Color glassFill = Color(0x14FFFFFF); // white 8%
  static const Color glassFillStrong = Color(0x1FFFFFFF); // white 12%
  static const Color glassBorder = Color(0x24FFFFFF); // white 14%
  static const Color glassBorderStrong = Color(0x33FFFFFF); // white 20%

  // Light theme.
  static const Color lightBg = Color(0xFFF4F6FB);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceAlt = Color(0xFFEDF1F8);
  static const Color lightTextPrimary = Color(0xFF0F172A);
  static const Color lightTextSecondary = Color(0xFF475569);
  static const Color lightBorder = Color(0x14000000);
  static const Color lightCyan = Color(0xFF0891B2);
  static const Color lightGold = Color(0xFFB8860B);
}

class Radii {
  const Radii._();
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double pill = 999;

  static const BorderRadius rXs = BorderRadius.all(Radius.circular(xs));
  static const BorderRadius rSm = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius rMd = BorderRadius.all(Radius.circular(md));
  static const BorderRadius rLg = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius rPill = BorderRadius.all(Radius.circular(pill));
}

class Spacing {
  const Spacing._();
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
}

class Elevation {
  const Elevation._();

  static const List<BoxShadow> soft = [
    BoxShadow(color: Color(0x40000000), blurRadius: 18, offset: Offset(0, 6)),
  ];
  static const List<BoxShadow> lifted = [
    BoxShadow(color: Color(0x59000000), blurRadius: 32, offset: Offset(0, 12)),
  ];
  static const List<BoxShadow> glowCyan = [
    BoxShadow(color: Color(0x3322D3EE), blurRadius: 24, offset: Offset(0, 6)),
  ];
}

class Motion {
  const Motion._();
  static const Duration instant = Duration(milliseconds: 120);
  static const Duration fast = Duration(milliseconds: 200);
  static const Duration standard = Duration(milliseconds: 320);
  static const Duration slow = Duration(milliseconds: 480);

  static const Curve emphasized = Curves.easeOutCubic;
  static const Curve standardCurve = Curves.easeInOutCubic;
  static const Curve decelerate = Curves.decelerate;
}

/// Semantic colour set resolved for the active brightness.
class AppColors extends ThemeExtension<AppColors> {
  final Color bgTop;
  final Color bgBottom;
  final Color surface;
  final Color surfaceAlt;
  final Color glassFill;
  final Color glassBorder;
  final Color accent;
  final Color accentAlt;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color success;
  final Color warning;
  final Color danger;
  final Color info;
  final Color border;

  const AppColors({
    required this.bgTop,
    required this.bgBottom,
    required this.surface,
    required this.surfaceAlt,
    required this.glassFill,
    required this.glassBorder,
    required this.accent,
    required this.accentAlt,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.success,
    required this.warning,
    required this.danger,
    required this.info,
    required this.border,
  });

  static const AppColors dark = AppColors(
    bgTop: Palette.bgTop,
    bgBottom: Palette.bgBottom,
    surface: Palette.surface,
    surfaceAlt: Palette.surfaceAlt,
    glassFill: Palette.glassFill,
    glassBorder: Palette.glassBorder,
    accent: Palette.cyan,
    accentAlt: Palette.gold,
    textPrimary: Palette.textPrimary,
    textSecondary: Palette.textSecondary,
    textMuted: Palette.textMuted,
    success: Palette.success,
    warning: Palette.warning,
    danger: Palette.danger,
    info: Palette.info,
    border: Palette.glassBorder,
  );

  static const AppColors light = AppColors(
    bgTop: Palette.lightBg,
    bgBottom: Palette.lightSurfaceAlt,
    surface: Palette.lightSurface,
    surfaceAlt: Palette.lightSurfaceAlt,
    glassFill: Color(0x0A000000),
    glassBorder: Palette.lightBorder,
    accent: Palette.lightCyan,
    accentAlt: Palette.lightGold,
    textPrimary: Palette.lightTextPrimary,
    textSecondary: Palette.lightTextSecondary,
    textMuted: Color(0xFF94A3B8),
    success: Color(0xFF059669),
    warning: Color(0xFFD97706),
    danger: Color(0xFFDC2626),
    info: Color(0xFF2563EB),
    border: Palette.lightBorder,
  );

  @override
  AppColors copyWith({
    Color? bgTop,
    Color? bgBottom,
    Color? surface,
    Color? surfaceAlt,
    Color? glassFill,
    Color? glassBorder,
    Color? accent,
    Color? accentAlt,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? success,
    Color? warning,
    Color? danger,
    Color? info,
    Color? border,
  }) =>
      AppColors(
        bgTop: bgTop ?? this.bgTop,
        bgBottom: bgBottom ?? this.bgBottom,
        surface: surface ?? this.surface,
        surfaceAlt: surfaceAlt ?? this.surfaceAlt,
        glassFill: glassFill ?? this.glassFill,
        glassBorder: glassBorder ?? this.glassBorder,
        accent: accent ?? this.accent,
        accentAlt: accentAlt ?? this.accentAlt,
        textPrimary: textPrimary ?? this.textPrimary,
        textSecondary: textSecondary ?? this.textSecondary,
        textMuted: textMuted ?? this.textMuted,
        success: success ?? this.success,
        warning: warning ?? this.warning,
        danger: danger ?? this.danger,
        info: info ?? this.info,
        border: border ?? this.border,
      );

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      bgTop: Color.lerp(bgTop, other.bgTop, t)!,
      bgBottom: Color.lerp(bgBottom, other.bgBottom, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceAlt: Color.lerp(surfaceAlt, other.surfaceAlt, t)!,
      glassFill: Color.lerp(glassFill, other.glassFill, t)!,
      glassBorder: Color.lerp(glassBorder, other.glassBorder, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentAlt: Color.lerp(accentAlt, other.accentAlt, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      info: Color.lerp(info, other.info, t)!,
      border: Color.lerp(border, other.border, t)!,
    );
  }
}
