import 'package:flutter/material.dart';

class AppTheme {
  static const Color background = Color(0xFFFAF7F4);
  static const Color cardBeige = Color(0xFFF0ECE6);
  static const Color accentRose = Color(0xFF8B2E42); // burgundy primary — single source of truth
  static const Color accentRoseLight = Color(0xFFF3E6EB);
  static const Color accentGreen = Color(0xFF4A7C59);
  static const Color accentGreenLight = Color(0xFFD4EAD9);
  static const Color textPrimary = Color(0xFF2C2420);
  static const Color textSecondary = Color(0xFF6B5B55);
  static const Color textSubtle = Color(0xFF6B6B6B);
  static const Color textMuted = Color(0xFFB0A090);
  static const Color divider = Color(0xFFE5DDD5);
  static const Color white = Color(0xFFFFFFFF);
  static const Color warningAmber = Color(0xFFD4935A);
  static const Color warningAmberLight = Color(0xFFF5E4D0);

  // Heat grid colors — single source of truth for all three tiers
  static const Color heatGreenBg = Color(0xFFEAF3DE);
  static const Color heatGreenBorder = Color(0xFFC0DD97);
  static const Color heatGreenText = Color(0xFF3B6D11);
  static const Color heatAmberBg = Color(0xFFFAEEDA);
  static const Color heatAmberBorder = Color(0xFFFAC775);
  static const Color heatAmberText = Color(0xFF633806);
  static const Color heatRedBg = Color(0xFFFAECE7);
  static const Color heatRedBorder = Color(0xFFF5C4B3);
  static const Color heatRedText = Color(0xFF712B13);

  static ThemeData get theme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: accentRose,
        brightness: Brightness.light,
        surface: white,
      ),
      scaffoldBackgroundColor: background,
      fontFamily: 'SF Pro Display',
      appBarTheme: const AppBarTheme(
        backgroundColor: background,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 17,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.3,
        ),
        iconTheme: IconThemeData(color: textPrimary),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: white,
        selectedItemColor: accentRose,
        unselectedItemColor: textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        unselectedLabelStyle: TextStyle(fontSize: 11),
      ),
      cardTheme: CardThemeData(
        color: cardBeige,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        margin: EdgeInsets.zero,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: cardBeige,
        selectedColor: accentRose,
        labelStyle: const TextStyle(fontSize: 13, color: textSecondary),
        secondaryLabelStyle: const TextStyle(fontSize: 13, color: white, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        side: BorderSide.none,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accentRose,
          foregroundColor: white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          side: const BorderSide(color: divider, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }
}
