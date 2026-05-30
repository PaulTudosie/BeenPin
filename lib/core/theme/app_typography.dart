import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTypography {
  static const String fontFamily = 'Manrope';

  static const TextStyle headerTitle = TextStyle(
    fontFamily: fontFamily,
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static const TextStyle screenTitle = TextStyle(
    fontFamily: fontFamily,
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static const TextStyle sectionTitle = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static const TextStyle bodyText = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
  );

  static const TextStyle captionText = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: AppColors.textMuted,
  );

  static const TextStyle cardTitle = sectionTitle;
  static const TextStyle bodyStrong = bodyText;
  static const TextStyle body = bodyText;
  static const TextStyle metadata = captionText;

  static const TextStyle captionAction = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: AppColors.textSecondary,
  );

  static const TextStyle sheetTitle = screenTitle;
}

@immutable
class AppTextStyles extends ThemeExtension<AppTextStyles> {
  final TextStyle headerTitle;
  final TextStyle screenTitle;
  final TextStyle sectionTitle;
  final TextStyle bodyText;
  final TextStyle captionText;

  const AppTextStyles({
    required this.headerTitle,
    required this.screenTitle,
    required this.sectionTitle,
    required this.bodyText,
    required this.captionText,
  });

  static const AppTextStyles light = AppTextStyles(
    headerTitle: AppTypography.headerTitle,
    screenTitle: AppTypography.screenTitle,
    sectionTitle: AppTypography.sectionTitle,
    bodyText: AppTypography.bodyText,
    captionText: AppTypography.captionText,
  );

  @override
  AppTextStyles copyWith({
    TextStyle? headerTitle,
    TextStyle? screenTitle,
    TextStyle? sectionTitle,
    TextStyle? bodyText,
    TextStyle? captionText,
  }) {
    return AppTextStyles(
      headerTitle: headerTitle ?? this.headerTitle,
      screenTitle: screenTitle ?? this.screenTitle,
      sectionTitle: sectionTitle ?? this.sectionTitle,
      bodyText: bodyText ?? this.bodyText,
      captionText: captionText ?? this.captionText,
    );
  }

  @override
  AppTextStyles lerp(ThemeExtension<AppTextStyles>? other, double t) {
    if (other is! AppTextStyles) {
      return this;
    }

    return AppTextStyles(
      headerTitle: TextStyle.lerp(headerTitle, other.headerTitle, t)!,
      screenTitle: TextStyle.lerp(screenTitle, other.screenTitle, t)!,
      sectionTitle: TextStyle.lerp(sectionTitle, other.sectionTitle, t)!,
      bodyText: TextStyle.lerp(bodyText, other.bodyText, t)!,
      captionText: TextStyle.lerp(captionText, other.captionText, t)!,
    );
  }
}

extension AppTextTheme on BuildContext {
  AppTextStyles get appTextStyles {
    return Theme.of(this).extension<AppTextStyles>() ?? AppTextStyles.light;
  }
}
