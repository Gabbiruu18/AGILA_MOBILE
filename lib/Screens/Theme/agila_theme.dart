import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const kAgilaBlue = Color(0xFF0058CE);
const kAgilaGold = Color(0xFFC88000);

// Softer brand variants for dark (optional)
const kAgilaBlueDark = Color(0xFF8FB6FF);
const kAgilaGoldDark = Color(0xFFCA903E);

// Neutral surfaces
const kSurfaceLight = Color(0xFFFFFFFF);   // white
const kSurfaceDark  = Color(0xFF151922);   // <- dark gray (not black)
const kScaffoldDark = Color(0xFF0F1115);   // page background

ThemeData _base(Brightness b, {required Color primary, required Color secondary}) {
  final isDark = b == Brightness.dark;

  // Use a neutral surface so anything using cs.surface won’t look blue
  final neutralSurface = isDark ? kSurfaceDark : kSurfaceLight;

  var scheme = ColorScheme.fromSeed(
    seedColor: primary,
    brightness: b,
  ).copyWith(
    primary: primary,
    secondary: secondary,
    surface: neutralSurface,
    outlineVariant: isDark ? const Color(0xFF373E4D) : const Color(0xFFE2E8F0),
    surfaceContainerHighest: isDark ? const Color(0xFF1E2430) : const Color(0xFFECEFF3),
  );

  // Poppins everywhere
  final baseText    = ThemeData(brightness: b).textTheme;
  final poppinsText = GoogleFonts.poppinsTextTheme(baseText).apply(
    bodyColor:    scheme.onSurface,
    displayColor: scheme.onSurface,
  );

  // Card color we want (neutral, not blue)
  final cardBg = neutralSurface;

  return ThemeData(
    useMaterial3: true,
    brightness: b,
    colorScheme: scheme,
    textTheme: poppinsText,

    // Page background
    scaffoldBackgroundColor: isDark ? kScaffoldDark : const Color(0xFFF6F7FB),

    // AppBar text/icons auto-contrast
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      foregroundColor: scheme.onSurface,
      titleTextStyle: poppinsText.titleLarge?.copyWith(fontWeight: FontWeight.w700),
    ),

    // IMPORTANT: kill the blue elevation tint + force neutral card bg
    cardColor: cardBg,
    cardTheme: CardThemeData(
      color: isDark ? const Color(0xFF1B202A) : Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: scheme.outlineVariant.withOpacity(isDark ? 0.6 : 0.7),
          width: 1.2,
        ),
      ),
      margin: const EdgeInsets.all(12),
    ),

    // Buttons still use brand colors
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: poppinsText.labelLarge,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: scheme.primary,
        textStyle: poppinsText.labelLarge,
      ),
    ),

    // Inputs
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: isDark ? const Color(0xFF171A21) : const Color(0xFFF1F5F9),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
    ),

    // Also neutralize surface tint on dialogs & sheets to avoid blue cast
    dialogTheme: DialogThemeData(
      backgroundColor: cardBg,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: cardBg,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
    ),
  );
}

// Keep your brand primaries; dark uses softened variants
final ThemeData agilaLight = _base(
  Brightness.light,
  primary: kAgilaBlue,
  secondary: kAgilaGold,
);

final ThemeData agilaDark = _base(
  Brightness.dark,
  primary: kAgilaBlueDark,
  secondary: kAgilaGoldDark,
);
