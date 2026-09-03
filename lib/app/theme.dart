import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Token warna semantik tambahan yang tiada slot dalam `ColorScheme`
/// standard Material (warning, warningBg, success, successBg, accentDark).
/// Guna
/// `Theme.of(context).extension<AppSemanticColors>()!` - JANGAN rujuk
/// warna mentah terus, supaya ia bertukar automatik antara light/dark.
@immutable
class AppSemanticColors extends ThemeExtension<AppSemanticColors> {
  const AppSemanticColors({
    required this.warning,
    required this.warningBg,
    required this.success,
    required this.successBg,
    required this.accentDark,
  });

  final Color warning;
  final Color warningBg;

  /// Hijau "berjaya/aktif". SENGAJA bukan `colorScheme.tertiary` - tertiary
  /// ialah biru diraja jenama MARC, dan status positif kena kekal hijau
  /// mengikut konvensyen. Guna `success` untuk teks/ikon, `successBg` untuk
  /// latar chip/banner.
  final Color success;
  final Color successBg;

  final Color accentDark;

  static const light = AppSemanticColors(
    warning: Color(0xFF8A5A00),
    warningBg: Color(0xFFFBEFD3),
    // #146B41 atas #DBF1E4 = 5.5:1 - selamat untuk label chip 12px.
    success: Color(0xFF146B41),
    successBg: Color(0xFFDBF1E4),
    // Merah gelap - dibaca atas chip `primary @ 12%` (~#FCE8E9): 7.8:1.
    accentDark: Color(0xFF8C1A1E),
  );

  static const dark = AppSemanticColors(
    warning: Color(0xFFE3B255),
    warningBg: Color(0xFF3A2E12),
    success: Color(0xFF6FD79E),
    successBg: Color(0xFF123424),
    accentDark: Color(0xFFFFB3B0),
  );

  @override
  AppSemanticColors copyWith({
    Color? warning,
    Color? warningBg,
    Color? success,
    Color? successBg,
    Color? accentDark,
  }) {
    return AppSemanticColors(
      warning: warning ?? this.warning,
      warningBg: warningBg ?? this.warningBg,
      success: success ?? this.success,
      successBg: successBg ?? this.successBg,
      accentDark: accentDark ?? this.accentDark,
    );
  }

  @override
  AppSemanticColors lerp(ThemeExtension<AppSemanticColors>? other, double t) {
    if (other is! AppSemanticColors) return this;
    return AppSemanticColors(
      warning: Color.lerp(warning, other.warning, t)!,
      warningBg: Color.lerp(warningBg, other.warningBg, t)!,
      success: Color.lerp(success, other.success, t)!,
      successBg: Color.lerp(successBg, other.successBg, t)!,
      accentDark: Color.lerp(accentDark, other.accentDark, t)!,
    );
  }
}

class AppTheme {
  /// Palet MARC - diambil dari `assets/splash/full_logo_android12.png`.
  /// Merah perisai `#E21E28` (~48% piksel berwarna), navy ikon/wordmark
  /// `#223145` (~15%), biru diraja huruf "MARC" `#2D3089` (~5%).
  static const brandRed = Color(0xFFE21E28);
  static const brandNavy = Color(0xFF223145);
  static const brandRoyal = Color(0xFF2D3089);

  static const _seed = brandRed;

  // `static final` (BUKAN `static get`) - SENGAJA. Skema/tema ni tak
  // pernah berubah secara dinamik (seed warna tetap), tapi setiap
  // `AppTheme.light`/`.dark` DULU dikira semula dari kosong pada setiap
  // panggilan (~15 panggilan GoogleFonts.* + ColorScheme.fromSeed penuh
  // setiap satu). `MaterialApp.router` (main.dart) perlukan KEDUA-DUA
  // `theme:` DAN `darkTheme:` pada SETIAP rebuild `MyApp`, dan `MyApp`
  // rebuild TEPAT bila `themeModeProvider` berubah - jadi suis tema
  // (satu-satunya sebab MyApp rebuild) mencetuskan KERJA PALING BERAT di
  // fail ni dua kali, serentak dengan animasi peralihan tema cuba mula,
  // punca sebenar "slow/clunky/stutter" yang dilaporkan. `late final`
  // kira sekali sahaja (lazy, pada akses pertama), kemudian cache
  // selama-lamanya.
  static final ColorScheme lightScheme =
      ColorScheme.fromSeed(
        seedColor: _seed,
        brightness: Brightness.light,
      ).copyWith(
        primary: brandRed,
        onPrimary: Colors.white,
        primaryContainer: const Color(0xFFFFDAD8),
        onPrimaryContainer: const Color(0xFF5E0F12),
        secondary: brandNavy,
        onSecondary: Colors.white,
        secondaryContainer: const Color(0xFFD9E2F2),
        onSecondaryContainer: const Color(0xFF16202F),
        tertiary: brandRoyal,
        onTertiary: Colors.white,
        tertiaryContainer: const Color(0xFFE2E2FF),
        onTertiaryContainer: const Color(0xFF1A1C5C),
        surface: const Color(0xFFFAF8F7),
        onSurface: const Color(0xFF1B1A1A),
        onSurfaceVariant: const Color(0xFF5F5A5A),
        surfaceContainerHighest: const Color(0xFFF1ECEC),
        error: const Color(0xFFB3261E),
        onError: Colors.white,
        outline: const Color(0xFFC9C2C2),
        outlineVariant: const Color(0xFFE6DEDE),
        inverseSurface: const Color(0xFF2E2A2A),
        onInverseSurface: const Color(0xFFF5F0EF),
        inversePrimary: const Color(0xFFFFB3B0),
      );

  static final ColorScheme darkScheme =
      ColorScheme.fromSeed(
        seedColor: _seed,
        brightness: Brightness.dark,
      ).copyWith(
        primary: const Color(0xFFFF8A85),
        onPrimary: const Color(0xFF5E0F12),
        primaryContainer: const Color(0xFF8C1A1E),
        onPrimaryContainer: const Color(0xFFFFDAD8),
        secondary: const Color(0xFFA9B8D8),
        onSecondary: const Color(0xFF16202F),
        secondaryContainer: const Color(0xFF33415A),
        onSecondaryContainer: const Color(0xFFD9E2F2),
        tertiary: const Color(0xFF9AA0F0),
        onTertiary: const Color(0xFF1A1C5C),
        tertiaryContainer: const Color(0xFF3F42A0),
        onTertiaryContainer: const Color(0xFFE2E2FF),
        surface: const Color(0xFF171718),
        onSurface: const Color(0xFFEBE8E7),
        onSurfaceVariant: const Color(0xFFA9A2A1),
        surfaceContainerHighest: const Color(0xFF262323),
        error: const Color(0xFFFFB4A9),
        onError: const Color(0xFF690003),
        outline: const Color(0xFF4C4747),
        outlineVariant: const Color(0xFF332F2F),
        inverseSurface: const Color(0xFFEBE8E7),
        onInverseSurface: const Color(0xFF1B1A1A),
        inversePrimary: brandRed,
      );

  static final ThemeData light = _build(lightScheme, AppSemanticColors.light);

  static final ThemeData dark = _build(darkScheme, AppSemanticColors.dark);

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
