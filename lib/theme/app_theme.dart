import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const Color primary = Color(0xFF6C5CE7);
  static const Color primaryLight = Color(0xFF9B8DF0);
  static const Color accent = Color(0xFF00CEC9);
  static const Color success = Color(0xFF00B894);
  static const Color warning = Color(0xFFFDCB6E);
  static const Color danger = Color(0xFFE17055);
  static const Color background = Color(0xFF0F0F13);
  static const Color surface = Color(0xFF1A1A24);
  static const Color surfaceLight = Color(0xFF242432);
  static const Color surfaceBorder = Color(0xFF2E2E40);
  static const Color textPrimary = Color(0xFFF0F0F5);
  static const Color textSecondary = Color(0xFF8888AA);
  static const Color textMuted = Color(0xFF55556A);

  static const Color merivaColor = Color(0xFF3D3D4F);
  static const Color fiorioColor = Color(0xFFD8D8E8);
}

ThemeData buildTheme() {
  final base = ThemeData.dark();
  return base.copyWith(
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.primary,
      secondary: AppColors.accent,
      surface: AppColors.surface,
      error: AppColors.danger,
    ),
    textTheme: GoogleFonts.interTextTheme(base.textTheme).copyWith(
      displayLarge: GoogleFonts.inter(
        fontSize: 32, fontWeight: FontWeight.w700, color: AppColors.textPrimary,
      ),
      headlineMedium: GoogleFonts.inter(
        fontSize: 22, fontWeight: FontWeight.w600, color: AppColors.textPrimary,
      ),
      titleLarge: GoogleFonts.inter(
        fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textPrimary,
      ),
      titleMedium: GoogleFonts.inter(
        fontSize: 15, fontWeight: FontWeight.w500, color: AppColors.textPrimary,
      ),
      bodyLarge: GoogleFonts.inter(
        fontSize: 15, fontWeight: FontWeight.w400, color: AppColors.textPrimary,
      ),
      bodyMedium: GoogleFonts.inter(
        fontSize: 13, fontWeight: FontWeight.w400, color: AppColors.textSecondary,
      ),
      labelSmall: GoogleFonts.inter(
        fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.textMuted,
      ),
    ),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.surfaceBorder, width: 0.5),
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      elevation: 0,
      centerTitle: false,
      iconTheme: IconThemeData(color: AppColors.textPrimary),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.surface,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: AppColors.textMuted,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surfaceLight,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.surfaceBorder, width: 0.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.surfaceBorder, width: 0.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      labelStyle: const TextStyle(color: AppColors.textSecondary),
      hintStyle: const TextStyle(color: AppColors.textMuted),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        textStyle: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: AppColors.surfaceBorder,
      thickness: 0.5,
    ),
  );
}
