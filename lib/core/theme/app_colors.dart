import 'package:flutter/material.dart';

class AppColors {
  static const Color brandBlue = Color(0xFF2F55CC);
  static const Color brandGreen = Color(0xFF22C55E);

  // legacy aliases used in pins_screen
  static const Color blue = Color(0xFF1565FF);
  static const Color amber = Color(0xFFFFB020);
  static const Color green = brandGreen;
  static const Color text = textPrimary;

  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textMuted = Color(0xFF94A3B8);

  static const Color background = Color(0xFFF7F5EE);
  static const Color bgPaper = Color(0xFFF5F0E8);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceSoft = Color(0xFFF8FAFC);
  static const Color border = Color(0xFFE2E8F0);

  static const Color tabActive = textPrimary;
  static const Color tabInactive = textSecondary;
  static const Color tabIndicator = brandGreen;

  static const Color avatarBg = Color(0xFFEAF1FF);
}