import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Token warna semantik tambahan yang tiada slot dalam `ColorScheme`
/// standard Material (warning, warningBg, accentDark). Guna
/// `Theme.of(context).extension<AppSemanticColors>()!` — JANGAN rujuk
/// warna mentah terus, supaya ia bertukar automatik antara light/dark.
@immutable
class AppSemanticColors extends ThemeExtension<AppSemanticColors> {
  const AppSemanticColors({
    required this.warning,
    required this.warningBg,
    required this.accentDark,
  });

  final Color warning;
  final Color warningBg;
  final Color accentDark;

  static const light = AppSemanticColors(
    warning: Color(0xFF8A5A00),
    warningBg: Color(0xFFFBEFD3),
    accentDark: Color(0xFF1F3D34),
  );

  static const dark = AppSemanticColors(
    warning: Color(0xFFE3B255),
    warningBg: Color(0xFF3A2E12),
    accentDark: Color(0xFFB6E2C8),
  );

  @override
  AppSemanticColors copyWith({
    Color? warning,
    Color? warningBg,
    Color? accentDark,
  }) {
    return AppSemanticColors(
      warning: warning ?? this.warning,
      warningBg: warningBg ?? this.warningBg,
      accentDark: accentDark ?? this.accentDark,
    );
  }

  @override
  AppSemanticColors lerp(ThemeExtension<AppSemanticColors>? other, double t) {
    if (other is! AppSemanticColors) return this;
    return AppSemanticColors(
      warning: Color.lerp(warning, other.warning, t)!,
      warningBg: Color.lerp(warningBg, other.warningBg, t)!,
      accentDark: Color.lerp(accentDark, other.accentDark, t)!,
    );
  }
}

class AppTheme {
  static const _seed = Color(0xFF2F6B4F);

  static ColorScheme get lightScheme =>
      ColorScheme.fromSeed(
        seedColor: _seed,
        brightness: Brightness.light,
      ).copyWith(
        primary: const Color(0xFF2F6B4F),
        onPrimary: Colors.white,
        secondary: const Color(0xFF55635B),
        onSecondary: Colors.white,
        surface: const Color(0xFFFAF9F6),
        onSurface: const Color(0xFF1C1B19),
        onSurfaceVariant: const Color(0xFF6B6B6B),
        surfaceContainerHighest: const Color(0xFFEEECE6),
        error: const Color(0xFFB3261E),
        onError: Colors.white,
        outline: const Color(0xFFC9C6BF),
        outlineVariant: const Color(0xFFE4E1DA),
        inverseSurface: const Color(0xFF2A2A27),
        onInverseSurface: const Color(0xFFF3F1EB),
        inversePrimary: const Color(0xFF9FD3B4),
      );

  static ColorScheme get darkScheme =>
      ColorScheme.fromSeed(
        seedColor: _seed,
        brightness: Brightness.dark,
      ).copyWith(
        primary: const Color(0xFF7FC79E),
        onPrimary: const Color(0xFF08331F),
        secondary: const Color(0xFFAEB8B0),
        onSecondary: const Color(0xFF1A211C),
        surface: const Color(0xFF17181A),
        onSurface: const Color(0xFFEBEAE6),
        onSurfaceVariant: const Color(0xFFA8A69F),
        surfaceContainerHighest: const Color(0xFF262825),
        error: const Color(0xFFFFB4A9),
        onError: const Color(0xFF690003),
        outline: const Color(0xFF4A4B47),
        outlineVariant: const Color(0xFF313330),
        inverseSurface: const Color(0xFFEBEAE6),
        onInverseSurface: const Color(0xFF1C1B19),
        inversePrimary: const Color(0xFF2F6B4F),
      );

  static ThemeData get light => _build(lightScheme, AppSemanticColors.light);

  static ThemeData get dark => _build(darkScheme, AppSemanticColors.dark);

  static ThemeData _build(ColorScheme scheme, AppSemanticColors semantic) {
    final base = ThemeData(useMaterial3: true, colorScheme: scheme);

    final textTheme = GoogleFonts.interTextTheme(base.textTheme).copyWith(
      displaySmall: GoogleFonts.fraunces(
        fontSize: 32,
        fontWeight: FontWeight.w600,
        color: scheme.onSurface,
        height: 1.1,
      ),
      headlineSmall: GoogleFonts.fraunces(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: scheme.onSurface,
      ),
      titleMedium: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: scheme.onSurface,
      ),
      bodyMedium: GoogleFonts.inter(
        fontSize: 15,
        color: scheme.onSurfaceVariant,
      ),
      labelSmall: GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.2,
        color: scheme.onSurfaceVariant,
      ),
    );

    return base.copyWith(
      scaffoldBackgroundColor: scheme.surface,
      textTheme: textTheme,
      extensions: [semantic],
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.fraunces(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: scheme.onSurface,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 18,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.error, width: 1.2),
        ),
        labelStyle: GoogleFonts.inter(color: scheme.onSurfaceVariant),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          minimumSize: const Size.fromHeight(54),
          textStyle: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: scheme.primary),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: GoogleFonts.inter(color: scheme.onInverseSurface),
        actionTextColor: scheme.inversePrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        insetPadding: const EdgeInsets.all(16),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: scheme.primary.withValues(alpha: 0.14),
        elevation: 0,
        height: 66,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => GoogleFonts.inter(
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w600
                : FontWeight.w500,
            color: scheme.onSurface,
          ),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),
    );
  }
}
