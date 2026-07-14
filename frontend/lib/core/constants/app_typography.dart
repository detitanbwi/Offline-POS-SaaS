import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'app_colors.dart';

class AppTypography {
  // Base font style using GoogleFonts.inter
  static TextStyle get baseStyle => GoogleFonts.inter();

  static TextStyle get displayLarge => baseStyle.copyWith(
        fontSize: 44.sp,
        fontWeight: FontWeight.normal,
        height: 1.12,
        color: AppColors.textPrimary,
      );

  static TextStyle get headlineLarge => baseStyle.copyWith(
        fontSize: 26.sp,
        fontWeight: FontWeight.bold,
        height: 1.25,
        color: AppColors.textPrimary,
      );

  static TextStyle get titleLarge => baseStyle.copyWith(
        fontSize: 20.sp,
        fontWeight: FontWeight.bold,
        height: 1.27,
        color: AppColors.textPrimary,
      );

  static TextStyle get titleMedium => baseStyle.copyWith(
        fontSize: 16.sp,
        fontWeight: FontWeight.bold,
        color: AppColors.textPrimary,
      );

  static TextStyle get bodyLarge => baseStyle.copyWith(
        fontSize: 15.sp,
        fontWeight: FontWeight.normal,
        color: AppColors.textPrimary,
      );

  static TextStyle get bodyMedium => baseStyle.copyWith(
        fontSize: 13.5.sp,
        fontWeight: FontWeight.normal,
        color: AppColors.textPrimary,
      );

  static TextStyle get labelLarge => baseStyle.copyWith(
        fontSize: 14.sp,
        fontWeight: FontWeight.w500,
        color: AppColors.textPrimary,
      );

  // Tabular figures for numbers
  static TextStyle get numberStyle => baseStyle.copyWith(
        fontFeatures: const [FontFeature.tabularFigures()],
      );
}
