import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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
    final textTheme = _appTextTheme(GoogleFonts.manropeTextTheme(
      base.textTheme,
    ));
    final primaryTextTheme = _appTextTheme(GoogleFonts.manropeTextTheme(
      base.primaryTextTheme,
    ));

    return base.copyWith(
      textTheme: textTheme,
      primaryTextTheme: primaryTextTheme,
      extensions: const <ThemeExtension<dynamic>>[
        AppTextStyles.light,
      ],
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

  static TextTheme _appTextTheme(TextTheme source) {
    return source.copyWith(
      displayLarge: _withFont(source.displayLarge, 20, FontWeight.w600),
      displayMedium: _withFont(source.displayMedium, 20, FontWeight.w600),
      displaySmall: _withFont(source.displaySmall, 18, FontWeight.w600),
      headlineLarge: _withFont(source.headlineLarge, 20, FontWeight.w600),
      headlineMedium: _withFont(source.headlineMedium, 18, FontWeight.w600),
      headlineSmall: _withFont(source.headlineSmall, 20, FontWeight.w600),
      titleLarge: _withFont(source.titleLarge, 18, FontWeight.w600),
      titleMedium: _withFont(source.titleMedium, 16, FontWeight.w600),
      titleSmall: _withFont(source.titleSmall, 16, FontWeight.w600),
      bodyLarge: _withFont(source.bodyLarge, 14, FontWeight.w500),
      bodyMedium: _withFont(source.bodyMedium, 14, FontWeight.w500),
      bodySmall: _withFont(source.bodySmall, 12, FontWeight.w500),
      labelLarge: _withFont(source.labelLarge, 16, FontWeight.w600),
      labelMedium: _withFont(source.labelMedium, 14, FontWeight.w500),
      labelSmall: _withFont(source.labelSmall, 12, FontWeight.w500),
    );
  }

  static TextStyle _withFont(TextStyle? style, double size, FontWeight weight) {
    return (style ?? const TextStyle()).copyWith(
      fontFamily: AppTypography.fontFamily,
      fontFamilyFallback: const [AppTypography.fontFamily],
      fontSize: size,
      fontWeight: weight,
      color: AppColors.textPrimary,
      letterSpacing: 0,
    );
  }
}
