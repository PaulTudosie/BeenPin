import 'package:flutter/material.dart';

import 'package:been/core/theme/app_colors.dart';
import 'package:been/core/theme/app_spacing.dart';
import 'package:been/widgets/app_background.dart';

class LevelDetailsScreen extends StatelessWidget {
  final String levelName;
  final int current;
  final int target;
  final String nextLevelName;

  const LevelDetailsScreen({
    super.key,
    required this.levelName,
    required this.current,
    required this.target,
    required this.nextLevelName,
  });

  static const List<_LevelMilestone> _levels = [
    _LevelMilestone(name: 'Starter', requiredPins: 0),
    _LevelMilestone(name: 'Explorer', requiredPins: 3),
    _LevelMilestone(name: 'Walker', requiredPins: 6),
    _LevelMilestone(name: 'Traveler', requiredPins: 10),
    _LevelMilestone(name: 'Wanderer', requiredPins: 20),
    _LevelMilestone(name: 'Pathfinder', requiredPins: 30),
    _LevelMilestone(name: 'Globetrotter', requiredPins: 45),
  ];

  @override
  Widget build(BuildContext context) {
    final currentLevelIndex = _levels.indexWhere((level) {
      return level.name == levelName;
    }).clamp(0, _levels.length - 1);
    final isTopLevel = currentLevelIndex == _levels.length - 1;
    final resolvedNextLevelName =
        isTopLevel ? null : _levels[currentLevelIndex + 1].name;
    final progressValue = isTopLevel
        ? 1.0
        : (target == 0 ? 0.0 : (current / target).clamp(0.0, 1.0));
    final remaining = isTopLevel ? 0 : (target - current).clamp(0, 9999);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface.withValues(alpha: 0.92),
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        foregroundColor: AppColors.textPrimary,
        titleSpacing: 20,
        title: Text(
          'Level details',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                letterSpacing: -0.3,
              ),
        ),
      ),
      body: AppBackground(
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.md,
              AppSpacing.xl,
              AppSpacing.xxxl,
            ),
            child: Column(
              children: [
                _CompactHeroCard(
                  levelName: levelName,
                  progressValue: progressValue,
                  isTopLevel: isTopLevel,
                  current: current,
                  target: target,
                ),
                const SizedBox(height: AppSpacing.md),
                _CompactProgressPanel(
                  nextLevelName: resolvedNextLevelName,
                  remaining: remaining,
                  isTopLevel: isTopLevel,
                ),
                const SizedBox(height: AppSpacing.lg),
                _LevelTimeline(
                  levels: _levels,
                  currentLevelIndex: currentLevelIndex,
                  currentPins: current,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CompactHeroCard extends StatelessWidget {
  final String levelName;
  final double progressValue;
  final bool isTopLevel;
  final int current;
  final int target;

  const _CompactHeroCard({
    required this.levelName,
    required this.progressValue,
    required this.isTopLevel,
    required this.current,
    required this.target,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.7)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: AppColors.tabActiveBg,
              border:
                  Border.all(color: AppColors.border.withValues(alpha: 0.6)),
            ),
            child: const Icon(
              Icons.workspace_premium_rounded,
              size: 30,
              color: AppColors.brandBlue,
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  levelName,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.45,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  isTopLevel ? 'Top level reached' : 'Current level',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: progressValue,
                    minHeight: 8,
                    backgroundColor: AppColors.border,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      AppColors.brandGreen,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      isTopLevel
                          ? '100% completed'
                          : '${(progressValue * 100).round()}% completed',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                    ),
                    const Spacer(),
                    Text(
                      '$current / $target',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactProgressPanel extends StatelessWidget {
  final String? nextLevelName;
  final int remaining;
  final bool isTopLevel;

  const _CompactProgressPanel({
    required this.nextLevelName,
    required this.remaining,
    required this.isTopLevel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.7)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _InlineMetric(
              label: 'Next',
              value: isTopLevel ? 'Top level' : nextLevelName!,
            ),
          ),
          Container(
            width: 1,
            height: 30,
            color: AppColors.border.withValues(alpha: 0.8),
          ),
          Expanded(
            child: _InlineMetric(
              label: 'Remaining',
              value: '$remaining',
              alignEnd: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineMetric extends StatelessWidget {
  final String label;
  final String value;
  final bool alignEnd;

  const _InlineMetric({
    required this.label,
    required this.value,
    this.alignEnd = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
                letterSpacing: 0.1,
              ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                letterSpacing: -0.2,
              ),
        ),
      ],
    );
  }
}

class _LevelTimeline extends StatelessWidget {
  final List<_LevelMilestone> levels;
  final int currentLevelIndex;
  final int currentPins;

  const _LevelTimeline({
    required this.levels,
    required this.currentLevelIndex,
    required this.currentPins,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.7)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Level path',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.2,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'Your full progression route from first pin to top level.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          const SizedBox(height: 14),
          ...List.generate(levels.length, (index) {
            final level = levels[index];
            return _TimelineLevelRow(
              level: level,
              isReached: index < currentLevelIndex,
              isCurrent: index == currentLevelIndex,
              isFuture: index > currentLevelIndex,
              isLast: index == levels.length - 1,
              currentPins: currentPins,
            );
          }),
        ],
      ),
    );
  }
}

class _TimelineLevelRow extends StatelessWidget {
  final _LevelMilestone level;
  final bool isReached;
  final bool isCurrent;
  final bool isFuture;
  final bool isLast;
  final int currentPins;

  const _TimelineLevelRow({
    required this.level,
    required this.isReached,
    required this.isCurrent,
    required this.isFuture,
    required this.isLast,
    required this.currentPins,
  });

  @override
  Widget build(BuildContext context) {
    final accent = isFuture
        ? AppColors.textMuted
        : isCurrent
            ? AppColors.brandBlue
            : AppColors.brandGreen;
    final opacity = isFuture ? 0.38 : 1.0;
    final status = isCurrent
        ? 'Current - $currentPins pins'
        : isReached
            ? 'Unlocked'
            : 'Unlocks at ${level.requiredPins} pins';

    return Opacity(
      opacity: opacity,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 34,
            child: Column(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: isFuture ? AppColors.surfaceSoft : accent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isFuture ? AppColors.border : accent,
                    ),
                  ),
                  child: Icon(
                    isReached
                        ? Icons.check_rounded
                        : isCurrent
                            ? Icons.star_rounded
                            : Icons.circle_outlined,
                    size: 14,
                    color: isFuture ? AppColors.textMuted : Colors.white,
                  ),
                ),
                if (!isLast)
                  Container(
                    width: 2,
                    height: 31,
                    margin: const EdgeInsets.symmetric(vertical: 3),
                    color: isFuture ? AppColors.border : AppColors.brandGreen,
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          level.name,
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: isCurrent
                                        ? FontWeight.w800
                                        : FontWeight.w700,
                                    color: AppColors.textPrimary,
                                    letterSpacing: -0.15,
                                  ),
                        ),
                      ),
                      Text(
                        level.requiredPins == 0
                            ? 'Start'
                            : '${level.requiredPins} pins',
                        style:
                            Theme.of(context).textTheme.labelMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: accent,
                                ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    status,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight:
                              isCurrent ? FontWeight.w600 : FontWeight.w500,
                        ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LevelMilestone {
  final String name;
  final int requiredPins;

  const _LevelMilestone({
    required this.name,
    required this.requiredPins,
  });
}
