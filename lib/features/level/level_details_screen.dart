import 'package:flutter/material.dart';

import 'package:been/core/theme/app_colors.dart';
import 'package:been/core/theme/app_spacing.dart';

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

  static const List<String> _levels = [
    'Starter',
    'Explorer',
    'Walker',
    'Traveler',
    'Wanderer',
    'Pathfinder',
    'Globetrotter',
  ];

  @override
  Widget build(BuildContext context) {
    final currentLevelIndex = _levels.indexOf(levelName);
    final isTopLevel = currentLevelIndex == _levels.length - 1;

    final previousLevelName =
    currentLevelIndex > 0 ? _levels[currentLevelIndex - 1] : null;
    final resolvedNextLevelName =
    isTopLevel ? null : _levels[currentLevelIndex + 1];

    final progressValue = isTopLevel
        ? 1.0
        : (target == 0 ? 0.0 : (current / target).clamp(0.0, 1.0));

    final remaining = isTopLevel ? 0 : (target - current).clamp(0, 9999);

    return Scaffold(
      backgroundColor: AppColors.surfaceSoft,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceSoft,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        foregroundColor: AppColors.textPrimary,
        titleSpacing: 20,
        title: const Text(
          'Level details',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            letterSpacing: -0.3,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.sm,
            AppSpacing.xl,
            AppSpacing.xxxl,
          ),
          child: Column(
            children: [
              _PremiumHeroCard(
                levelName: levelName,
                progressValue: progressValue,
                isTopLevel: isTopLevel,
                current: current,
                target: target,
              ),
              const SizedBox(height: AppSpacing.xl),
              _CompactProgressPanel(
                nextLevelName: resolvedNextLevelName,
                remaining: remaining,
                isTopLevel: isTopLevel,
              ),
              const SizedBox(height: AppSpacing.xl),
              _SwipeLevelRail(
                previousLevelName: previousLevelName,
                currentLevelName: levelName,
                nextLevelName: resolvedNextLevelName,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PremiumHeroCard extends StatelessWidget {
  final String levelName;
  final double progressValue;
  final bool isTopLevel;
  final int current;
  final int target;

  const _PremiumHeroCard({
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
      padding: const EdgeInsets.fromLTRB(
        22,
        22,
        22,
        20,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.surface,
            AppColors.surface,
            AppColors.surfaceSoft,
          ],
        ),
        border: Border.all(
          color: AppColors.border.withOpacity(0.65),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.045),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 78,
            height: 78,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.surface,
                  AppColors.tabActiveBg,
                ],
              ),
              border: Border.all(
                color: AppColors.border.withOpacity(0.55),
              ),
            ),
            child: const Icon(
              Icons.workspace_premium_rounded,
              size: 36,
              color: AppColors.brandBlue,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            levelName,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              letterSpacing: -0.45,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isTopLevel ? 'Top level reached' : 'Current level',
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 20),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progressValue,
              minHeight: 9,
              backgroundColor: AppColors.border,
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppColors.brandGreen,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                isTopLevel
                    ? '100% completed'
                    : '${(progressValue * 100).round()}% completed',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const Spacer(),
              Text(
                '$current / $target',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
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
      padding: const EdgeInsets.symmetric(
        horizontal: 18,
        vertical: 18,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: AppColors.border.withOpacity(0.7),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.025),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _InlineMetric(
              label: 'Next',
              value: isTopLevel ? '—' : nextLevelName!,
            ),
          ),
          Container(
            width: 1,
            height: 34,
            color: AppColors.border.withOpacity(0.8),
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
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
            letterSpacing: 0.1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
            letterSpacing: -0.2,
          ),
        ),
      ],
    );
  }
}

class _SwipeLevelRail extends StatelessWidget {
  final String? previousLevelName;
  final String currentLevelName;
  final String? nextLevelName;

  const _SwipeLevelRail({
    required this.previousLevelName,
    required this.currentLevelName,
    required this.nextLevelName,
  });

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[
      if (previousLevelName != null)
        _RailLevelCard(
          title: previousLevelName!,
          subtitle: 'Previous',
          accent: AppColors.brandGreen,
          background: AppColors.surface,
          foreground: AppColors.textPrimary,
          icon: Icons.check_rounded,
        ),
      _RailLevelCard(
        title: currentLevelName,
        subtitle: 'Current',
        accent: AppColors.brandBlue,
        background: AppColors.tabActiveBg,
        foreground: AppColors.brandBlue,
        icon: Icons.workspace_premium_rounded,
        isCurrent: true,
      ),
      if (nextLevelName != null)
        _RailLevelCard(
          title: nextLevelName!,
          subtitle: 'Next',
          accent: AppColors.border,
          background: AppColors.surface,
          foreground: AppColors.textSecondary,
          icon: Icons.circle_outlined,
        ),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: AppColors.border.withOpacity(0.7),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.025),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Level ladder',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Swipe through your progression.',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 142,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) => items[index],
            ),
          ),
        ],
      ),
    );
  }
}

class _RailLevelCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color accent;
  final Color background;
  final Color foreground;
  final IconData icon;
  final bool isCurrent;

  const _RailLevelCard({
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.background,
    required this.foreground,
    required this.icon,
    this.isCurrent = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 180,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isCurrent
              ? AppColors.brandBlue.withOpacity(0.18)
              : AppColors.border.withOpacity(0.8),
        ),
        boxShadow: isCurrent
            ? [
          BoxShadow(
            color: Colors.black.withOpacity(0.035),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: isCurrent ? AppColors.surface : AppColors.surfaceSoft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              icon,
              size: 20,
              color: accent,
            ),
          ),
          const Spacer(),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: foreground.withOpacity(0.72),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 18,
              fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w700,
              color: foreground,
              letterSpacing: -0.25,
            ),
          ),
        ],
      ),
    );
  }
}