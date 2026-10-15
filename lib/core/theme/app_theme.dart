/// Builds Material 3 themes from the design tokens, for both brightnesses.
library;

import 'package:flutter/material.dart';

import 'design_tokens.dart';

class AppTheme {
  const AppTheme._();

  static ThemeData dark() => _build(AppColors.dark, Brightness.dark);
  static ThemeData light() => _build(AppColors.light, Brightness.light);

  static ThemeData _build(AppColors c, Brightness brightness) {
    final scheme = ColorScheme(
      brightness: brightness,
      primary: c.accent,
      onPrimary: brightness == Brightness.dark ? const Color(0xFF04121A) : Colors.white,
      secondary: c.accentAlt,
      onSecondary: const Color(0xFF241A00),
      error: c.danger,
      onError: Colors.white,
      surface: c.surface,
      onSurface: c.textPrimary,
      surfaceContainerHighest: c.surfaceAlt,
      onSurfaceVariant: c.textSecondary,
      outline: c.border,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: c.bgTop,
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.standard,
      extensions: <ThemeExtension<dynamic>>[c],
    );

    TextStyle t(double size, FontWeight w, Color color, {double? height, double? spacing, List<FontFeature>? features}) =>
        TextStyle(fontSize: size, fontWeight: w, color: color, height: height, letterSpacing: spacing, fontFeatures: features);

    return base.copyWith(
      textTheme: TextTheme(
        displayLarge: t(40, FontWeight.w700, c.textPrimary, height: 1.1, spacing: -0.5),
        displayMedium: t(32, FontWeight.w700, c.textPrimary, height: 1.15, spacing: -0.4),
        headlineMedium: t(24, FontWeight.w700, c.textPrimary, height: 1.2, spacing: -0.2),
        titleLarge: t(20, FontWeight.w600, c.textPrimary, height: 1.25),
        titleMedium: t(16, FontWeight.w600, c.textPrimary, height: 1.3),
        bodyLarge: t(15, FontWeight.w400, c.textPrimary, height: 1.45),
        bodyMedium: t(14, FontWeight.w400, c.textSecondary, height: 1.45),
        bodySmall: t(12, FontWeight.w400, c.textMuted, height: 1.4),
        labelLarge: t(14, FontWeight.w600, c.textPrimary, spacing: 0.2),
        labelSmall: t(11, FontWeight.w500, c.textMuted, spacing: 0.4),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: t(20, FontWeight.w700, c.textPrimary),
        iconTheme: IconThemeData(color: c.textSecondary),
      ),
      cardTheme: CardThemeData(
        color: c.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: Radii.rMd, side: BorderSide(color: c.border)),
      ),
      dividerTheme: DividerThemeData(color: c.border, thickness: 1, space: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.glassFill,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: Spacing.md, vertical: Spacing.sm),
        hintStyle: t(14, FontWeight.w400, c.textMuted),
        labelStyle: t(13, FontWeight.w500, c.textSecondary),
        border: OutlineInputBorder(borderRadius: Radii.rSm, borderSide: BorderSide(color: c.border)),
        enabledBorder: OutlineInputBorder(borderRadius: Radii.rSm, borderSide: BorderSide(color: c.border)),
        focusedBorder: OutlineInputBorder(borderRadius: Radii.rSm, borderSide: BorderSide(color: c.accent, width: 1.5)),
        errorBorder: OutlineInputBorder(borderRadius: Radii.rSm, borderSide: BorderSide(color: c.danger)),
        focusedErrorBorder: OutlineInputBorder(borderRadius: Radii.rSm, borderSide: BorderSide(color: c.danger, width: 1.5)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: c.accent,
          foregroundColor: brightness == Brightness.dark ? const Color(0xFF04121A) : Colors.white,
          minimumSize: const Size(0, 46),
          padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
          shape: const RoundedRectangleBorder(borderRadius: Radii.rSm),
          textStyle: t(14, FontWeight.w600, brightness == Brightness.dark ? const Color(0xFF04121A) : Colors.white),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: c.textPrimary,
          side: BorderSide(color: c.border),
          minimumSize: const Size(0, 46),
          padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
          shape: const RoundedRectangleBorder(borderRadius: Radii.rSm),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: c.accent, textStyle: t(14, FontWeight.w600, c.accent)),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: c.glassFill,
        side: BorderSide(color: c.border),
        labelStyle: t(12, FontWeight.w500, c.textSecondary),
        shape: const RoundedRectangleBorder(borderRadius: Radii.rPill),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(color: c.surfaceAlt, borderRadius: Radii.rXs, border: Border.all(color: c.border)),
        textStyle: t(12, FontWeight.w500, c.textPrimary),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: c.surfaceAlt,
        contentTextStyle: t(14, FontWeight.w500, c.textPrimary),
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(borderRadius: Radii.rSm),
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStatePropertyAll(c.textMuted.withValues(alpha: 0.4)),
        radius: const Radius.circular(Radii.pill),
        thickness: const WidgetStatePropertyAll(8),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: c.accent, linearTrackColor: c.glassFill),
      tabBarTheme: TabBarThemeData(
        labelColor: c.textPrimary,
        unselectedLabelColor: c.textMuted,
        indicatorColor: c.accent,
        dividerColor: c.border,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.lg))),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: Radii.rMd, side: BorderSide(color: c.border)),
      ),
    );
  }
}

/// Convenience accessor for the semantic colour extension.
extension AppColorsX on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>()!;
}
