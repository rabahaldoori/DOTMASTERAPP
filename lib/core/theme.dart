import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const primary = Color(0xFF0D1B2E);
  static const primaryLight = Color(0xFF1A2B4A);
  static const accent = Color(0xFF2563EB);
  static const accentLight = Color(0xFF3B82F6);
  static const surface = Color(0xFFF8F9FB);
  static const surfaceCard = Color(0xFFFFFFFF);
  static const surfaceVariant = Color(0xFFEFF1F5);
  static const outline = Color(0xFFCDD5E0);
  static const onPrimary = Color(0xFFFFFFFF);
  static const onSurface = Color(0xFF191C1E);
  static const onSurfaceVariant = Color(0xFF44474E);
  static const success = Color(0xFF16A34A);
  static const successBg = Color(0xFFDCFCE7);
  static const warning = Color(0xFFD97706);
  static const warningBg = Color(0xFFFEF3C7);
  static const error = Color(0xFFDC2626);
  static const errorBg = Color(0xFFFEE2E2);
  static const info = Color(0xFF2563EB);
  static const infoBg = Color(0xFFEFF6FF);
}

class AppTheme {
  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.accent,
        brightness: Brightness.light,
        primary: AppColors.accent,
        surface: AppColors.surface,
      ),
      scaffoldBackgroundColor: AppColors.surface,
      textTheme: GoogleFonts.interTextTheme(),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.surface,
        elevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: AppColors.onSurface),
        titleTextStyle: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.onSurface,
        ),
      ),
      cardTheme: CardTheme(
        color: AppColors.surfaceCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.outline, width: 0.8),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceCard,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 16),
          textStyle: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
