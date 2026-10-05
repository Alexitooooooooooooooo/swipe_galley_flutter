import 'package:flutter/material.dart';

/// Design tokens extracted from DESIGN.md ("Dimension" style reference).
/// Dusk-lit workspace with frosted glass panels.
class AppTokens {
  const AppTokens._();

  // Surfaces
  static const Color voidCanvas = Color(0xFF0A0A0A);
  static const Color graphite = Color(0xFF161616);
  static const Color snowWhite = Color(0xFFFFFFFF);
  static const Color inkBlack = Color(0xFF000000);

  // Text
  static const Color bone = Color(0xFFEDEDED);
  static const Color ash = Color(0xFFC2C2C2);
  static const Color slate = Color(0xFF686868);
  static const Color smoke = Color(0xFFB2B2B2);

  // Lines & accent
  static const Color hairline = Color(0xFFE5E5E5);
  static const Color duskViolet = Color(0xFF6B62F2);

  // Radii
  static const double radiusIcon = 4;
  static const double radiusUi = 10;
  static const double radiusCard = 24;
  static const double radiusPanel = 40;
  static const double radiusButton = 9999;

  // Spacing
  static const double s4 = 4;
  static const double s8 = 8;
  static const double s12 = 12;
  static const double s16 = 16;
  static const double s20 = 20;
  static const double s24 = 24;
  static const double s28 = 28;
  static const double s32 = 32;
  static const double s40 = 40;
  static const double s48 = 48;

  // Signature gradient: warm amber -> coral -> cobalt (hero horizon)
  static const LinearGradient heroHorizon = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [Color(0xFFE8A34C), Color(0xFFE06A67), Color(0xFF2E4BD8)],
    stops: [0.0, 0.5, 1.0],
  );

  // Dusk violet wash: the only chromatic accent, used as a horizontal strip.
  static const LinearGradient duskVioletWash = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [
      Color(0x00000000),
      Color(0x00000000),
      Color(0x906B62F2),
      Color(0x00000000),
      Color(0x00000000),
    ],
    stops: [0.0, 0.4, 0.5, 0.6, 1.0],
  );

  /// Radial spotlight from violet center fading out (product reveal).
  static final RadialGradient violetSpotlight = RadialGradient(
    colors: [
      duskViolet.withValues(alpha: 0.55),
      duskViolet.withValues(alpha: 0.0),
    ],
  );
}

/// Theme-aware palette. Dark is the signature look; light inverts it.
class AppPalette {
  final bool isDark;
  final Color canvas;
  final Color panel;
  final Color panelFrost;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color hairline;
  final Color ctaBg;
  final Color ctaFg;
  final Color accent;
  final Color danger;

  const AppPalette({
    required this.isDark,
    required this.canvas,
    required this.panel,
    required this.panelFrost,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.hairline,
    required this.ctaBg,
    required this.ctaFg,
    required this.accent,
    required this.danger,
  });

  static const AppPalette dark = AppPalette(
    isDark: true,
    canvas: AppTokens.voidCanvas,
    panel: AppTokens.graphite,
    panelFrost: Color(0x1AD4D4D4),
    textPrimary: AppTokens.bone,
    textSecondary: AppTokens.ash,
    textMuted: AppTokens.slate,
    hairline: Color(0x24E5E5E5),
    ctaBg: AppTokens.snowWhite,
    ctaFg: AppTokens.graphite,
    accent: AppTokens.duskViolet,
    danger: Color(0xFFFF4D4D),
  );

  static const AppPalette light = AppPalette(
    isDark: false,
    canvas: Color(0xFFF5F6F8),
    panel: Color(0xFFFFFFFF),
    panelFrost: Color(0x0D000000),
    textPrimary: Color(0xFF161616),
    textSecondary: Color(0xFF4A4A4A),
    textMuted: Color(0xFF8A8A8A),
    hairline: Color(0x1F000000),
    ctaBg: Color(0xFF161616),
    ctaFg: Color(0xFFFFFFFF),
    accent: AppTokens.duskViolet,
    danger: Color(0xFFE5484D),
  );

  static AppPalette of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;

  Border hairlineBorder({double radius = AppTokens.radiusCard}) =>
      Border.all(color: hairline, width: 1);
}

class AppTheme {
  const AppTheme._();

  static ThemeData dark() => _build(AppPalette.dark);
  static ThemeData light() => _build(AppPalette.light);

  static ThemeData _build(AppPalette p) {
    final base = ThemeData(brightness: p.isDark ? Brightness.dark : Brightness.light, useMaterial3: true);

    final textTheme = base.textTheme.apply(
      fontFamily: 'DM Sans',
      bodyColor: p.textPrimary,
      displayColor: p.textPrimary,
    );

    return base.copyWith(
      scaffoldBackgroundColor: p.canvas,
      colorScheme: base.colorScheme.copyWith(
        brightness: p.isDark ? Brightness.dark : Brightness.light,
        surface: p.panel,
        onSurface: p.textPrimary,
        primary: p.accent,
        onPrimary: p.ctaFg,
        secondary: p.accent,
        outline: p.hairline,
      ),
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: p.textPrimary,
      ),
      iconTheme: IconThemeData(color: p.textPrimary),
      dialogTheme: DialogThemeData(
        backgroundColor: p.panel,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: p.hairline, width: 1),
          borderRadius: BorderRadius.circular(AppTokens.radiusCard),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.panel,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppTokens.radiusPanel)),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: p.textPrimary),
      dividerTheme: DividerThemeData(color: p.hairline, thickness: 1),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: p.ctaBg,
          foregroundColor: p.ctaFg,
          elevation: 0,
          shape: const StadiumBorder(),
        ),
      ),
    );
  }
}
