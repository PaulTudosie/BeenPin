import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTypography {
  static const String fontFamily = 'Roboto';

  static const TextStyle sectionTitle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.2,
    color: AppColors.textPrimary,
  );

  static const TextStyle cardTitle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.1,
    color: AppColors.textPrimary,
  );

  static const TextStyle bodyStrong = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.1,
    color: AppColors.textPrimary,
  );

  static const TextStyle body = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
  );

  static const TextStyle metadata = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    color: AppColors.textMuted,
  );

  static const TextStyle captionAction = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    color: AppColors.textSecondary,
  );

  static const TextStyle sheetTitle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.2,
    color: AppColors.textPrimary,
  );
}