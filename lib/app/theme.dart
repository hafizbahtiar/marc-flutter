import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Token warna mentah editorial. Untuk kebanyakan UI, utamakan
/// `Theme.of(context).colorScheme` — token ini untuk kes khusus sahaja.
class AppColors {
  static const bg = Color(0xFFFAF9F6); // kertas / surface
  static const ink = Color(0xFF1C1B19); // teks utama
  static const accent = Color(0xFF3B7A57);
  static const accentDark = Color(0xFF1F3D34);
  static const error = Color(0xFFB3261E);
  static const fieldFill = Color(0xFFEEECE6);
  static const muted = Color(0xFF6B6B6B);
  static const warning = Color(0xFF8A5A00);
  static const warningBg = Color(0xFFFBEFD3);
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
        surface: AppColors.bg,
        onSurface: AppColors.ink,
        onSurfaceVariant: AppColors.muted,
        surfaceContainerHighest: AppColors.fieldFill,
        error: AppColors.error,
        onError: Colors.white,
        outline: const Color(0xFFC9C6BF),
        outlineVariant: const Color(0xFFE4E1DA),
        inverseSurface: const Color(0xFF2A2A27),
        onInverseSurface: const Color(0xFFF3F1EB),
        inversePrimary: const Color(0xFF9FD3B4),
      );

  static ThemeData get light {
    final scheme = lightScheme;
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
