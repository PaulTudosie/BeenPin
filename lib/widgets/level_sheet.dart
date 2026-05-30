import 'package:flutter/material.dart';
import 'package:been/core/theme/app_colors.dart';
import 'package:been/core/theme/app_spacing.dart';
import 'package:been/core/theme/app_typography.dart';

class LevelSheet extends StatelessWidget {
  final String levelName;
  final int current;
  final int target;

  const LevelSheet({
    super.key,
    required this.levelName,
    required this.current,
    required this.target,
  });

  @override
  Widget build(BuildContext context) {
    final progress = target == 0 ? 0.0 : (current / target).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 44,
              height: 5,
              margin: const EdgeInsets.only(bottom: AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          Text(
            levelName,
            style: context.appTextStyles.screenTitle,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '$current / $target spots',
            style: context.appTextStyles.captionText.copyWith(
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: const SizedBox.shrink(),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              backgroundColor: AppColors.border,
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppColors.brandGreen,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            current >= target
                ? 'You’re ready for the next level!'
                : 'Visit ${target - current} more spots to level up.',
            style: context.appTextStyles.bodyText.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
      ),
    );
  }
}
