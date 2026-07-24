import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Material Design 3 Typography Scale
class AppTypography {
  static TextStyle get baseStyle => GoogleFonts.inter();

  // Display
  static TextStyle get displayLarge => baseStyle.copyWith(
        fontSize: 57,
        fontWeight: FontWeight.w400,
        height: 1.12,
        letterSpacing: -0.25,
        color: AppColors.textPrimary,
      );

  static TextStyle get displayMedium => baseStyle.copyWith(
        fontSize: 45,
        fontWeight: FontWeight.w400,
        height: 1.16,
        color: AppColors.textPrimary,
      );

  static TextStyle get displaySmall => baseStyle.copyWith(
        fontSize: 36,
        fontWeight: FontWeight.w400,
        height: 1.22,
        color: AppColors.textPrimary,
      );

  // Headline
  static TextStyle get headlineLarge => baseStyle.copyWith(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        height: 1.25,
        color: AppColors.textPrimary,
      );

  static TextStyle get headlineMedium => baseStyle.copyWith(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        height: 1.29,
        color: AppColors.textPrimary,
      );

  static TextStyle get headlineSmall => baseStyle.copyWith(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        height: 1.33,
        color: AppColors.textPrimary,
      );

  // Title
  static TextStyle get titleLarge => baseStyle.copyWith(
        fontSize: 22,
        fontWeight: FontWeight.bold,
        height: 1.27,
        color: AppColors.textPrimary,
      );

  static TextStyle get titleMedium => baseStyle.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        height: 1.5,
        color: AppColors.textPrimary,
      );

  static TextStyle get titleSmall => baseStyle.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        height: 1.43,
        color: AppColors.textPrimary,
      );

  // Body
  static TextStyle get bodyLarge => baseStyle.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 1.5,
        color: AppColors.textPrimary,
      );

  static TextStyle get bodyMedium => baseStyle.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.43,
        color: AppColors.textPrimary,
      );

  static TextStyle get bodySmall => baseStyle.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        height: 1.33,
        color: AppColors.textSecondary,
      );

  // Label
  static TextStyle get labelLarge => baseStyle.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        height: 1.43,
        color: AppColors.textPrimary,
      );

  static TextStyle get labelMedium => baseStyle.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        height: 1.33,
        color: AppColors.textPrimary,
      );

  static TextStyle get labelSmall => baseStyle.copyWith(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        height: 1.45,
        color: AppColors.textSecondary,
      );

  // Tabular figures for numbers
  static TextStyle get numberStyle => baseStyle.copyWith(
        fontFeatures: const [FontFeature.tabularFigures()],
      );
}

