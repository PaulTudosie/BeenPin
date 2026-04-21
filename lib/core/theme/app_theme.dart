import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_typography.dart';

class AppTheme {
  static ThemeData get light {
    final base = ThemeData(
      useMaterial3: true,
      fontFamily: AppTypography.fontFamily,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.brandBlue,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: AppColors.background,
    );
    final textTheme = _boldTextTheme(base.textTheme);
    final primaryTextTheme = _boldTextTheme(base.primaryTextTheme);

    return base.copyWith(
      textTheme: textTheme,
      primaryTextTheme: primaryTextTheme,
      scaffoldBackgroundColor: AppColors.background,
      canvasColor: AppColors.background,
      dividerColor: AppColors.border,
      cardColor: AppColors.surface,
      splashFactory: InkRipple.splashFactory,
      appBarTheme: const AppBarTheme(
        elevation: 0,
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
      ),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: AppColors.brandBlue,
        selectionColor: Color(0x3322C55E),
        selectionHandleColor: AppColors.brandGreen,
      ),
    );
  }

  static TextTheme _boldTextTheme(TextTheme source) {
    return source.copyWith(
      displayLarge: _withFont(source.displayLarge, FontWeight.w900),
      displayMedium: _withFont(source.displayMedium, FontWeight.w900),
      displaySmall: _withFont(source.displaySmall, FontWeight.w900),
      headlineLarge: _withFont(source.headlineLarge, FontWeight.w900),
      headlineMedium: _withFont(source.headlineMedium, FontWeight.w800),
      headlineSmall: _withFont(source.headlineSmall, FontWeight.w800),
      titleLarge: _withFont(source.titleLarge, FontWeight.w800),
      titleMedium: _withFont(source.titleMedium, FontWeight.w700),
      titleSmall: _withFont(source.titleSmall, FontWeight.w700),
      bodyLarge: _withFont(source.bodyLarge, FontWeight.w600),
      bodyMedium: _withFont(source.bodyMedium, FontWeight.w600),
      bodySmall: _withFont(source.bodySmall, FontWeight.w500),
      labelLarge: _withFont(source.labelLarge, FontWeight.w700),
      labelMedium: _withFont(source.labelMedium, FontWeight.w700),
      labelSmall: _withFont(source.labelSmall, FontWeight.w600),
    );
  }

  static TextStyle? _withFont(TextStyle? style, FontWeight weight) {
    return style?.copyWith(
      fontFamily: AppTypography.fontFamily,
      fontWeight: weight,
    );
  }
}
