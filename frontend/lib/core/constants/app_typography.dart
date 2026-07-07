import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTypography {
  // Base font style using GoogleFonts.inter
  static TextStyle get baseStyle => GoogleFonts.inter();

  static TextStyle get displayLarge => baseStyle.copyWith(
        fontSize: 57.0,
        fontWeight: FontWeight.normal,
        height: 1.12,
        color: AppColors.textPrimary,
      );

  static TextStyle get headlineLarge => baseStyle.copyWith(
        fontSize: 32.0,
        fontWeight: FontWeight.bold,
        height: 1.25,
        color: AppColors.textPrimary,
      );

  static TextStyle get titleLarge => baseStyle.copyWith(
        fontSize: 22.0,
        fontWeight: FontWeight.bold,
        height: 1.27,
        color: AppColors.textPrimary,
      );

  static TextStyle get titleMedium => baseStyle.copyWith(
        fontSize: 16.0,
        fontWeight: FontWeight.bold, // SemiBold in Figma is standard bold or w600 in Flutter
        color: AppColors.textPrimary,
      );

  static TextStyle get bodyLarge => baseStyle.copyWith(
        fontSize: 16.0,
        fontWeight: FontWeight.normal,
        color: AppColors.textPrimary,
      );

  static TextStyle get bodyMedium => baseStyle.copyWith(
        fontSize: 14.0,
        fontWeight: FontWeight.normal,
        color: AppColors.textPrimary,
      );

  static TextStyle get labelLarge => baseStyle.copyWith(
        fontSize: 14.0,
        fontWeight: FontWeight.w500, // Medium
        color: AppColors.textPrimary,
      );

  // Tabular figures for numbers
  static TextStyle get numberStyle => baseStyle.copyWith(
        fontFeatures: const [FontFeature.tabularFigures()],
      );
}
