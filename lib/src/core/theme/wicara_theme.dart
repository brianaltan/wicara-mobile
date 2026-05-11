import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'wicara_colors.dart';

class WicaraTheme {
  const WicaraTheme._();

  static ThemeData light() {
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: WicaraColors.periwinkle,
          brightness: Brightness.light,
        ).copyWith(
          primary: WicaraColors.periwinkle,
          secondary: WicaraColors.secondary,
          surface: WicaraColors.pageBackground,
          onSurface: WicaraColors.ink,
        );

    const baseTextTheme = TextTheme(
      headlineMedium: TextStyle(
        color: WicaraColors.ink,
        fontSize: 27,
        fontWeight: FontWeight.w800,
        height: 1.12,
      ),
      titleLarge: TextStyle(
        color: WicaraColors.ink,
        fontSize: 22,
        fontWeight: FontWeight.w800,
        height: 1.16,
      ),
      titleMedium: TextStyle(
        color: WicaraColors.text,
        fontSize: 15,
        fontWeight: FontWeight.w600,
        height: 1.25,
      ),
      bodyLarge: TextStyle(
        color: WicaraColors.text,
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 1.35,
      ),
      bodyMedium: TextStyle(
        color: WicaraColors.muted,
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.35,
      ),
      bodySmall: TextStyle(
        color: WicaraColors.muted,
        fontSize: 12,
        fontWeight: FontWeight.w400,
        height: 1.3,
      ),
      labelLarge: TextStyle(
        color: WicaraColors.text,
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 1.2,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: WicaraColors.pageBackground,
      visualDensity: VisualDensity.standard,
      textTheme: GoogleFonts.poppinsTextTheme(baseTextTheme),
      inputDecorationTheme: const InputDecorationTheme(
        border: InputBorder.none,
        hintStyle: TextStyle(
          color: WicaraColors.softMuted,
          fontSize: 15,
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }
}
