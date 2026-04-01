import 'package:flutter/material.dart';
import 'package:been/core/theme/app_colors.dart';
import 'package:been/core/theme/app_spacing.dart';

enum HomeTab {
  map,
  pins,
  journey;

  String get label {
    switch (this) {
      case HomeTab.map:
        return 'Map';
      case HomeTab.pins:
        return 'Pins';
      case HomeTab.journey:
        return 'Journey';
    }
  }

  IconData get icon {
    switch (this) {
      case HomeTab.map:
        return Icons.map_outlined;
      case HomeTab.pins:
        return Icons.view_stream_outlined;
      case HomeTab.journey:
        return Icons.person_outline_rounded;
    }
  }
}

class SubHeaderTabs extends StatelessWidget {
  final HomeTab currentTab;
  final ValueChanged<HomeTab> onTabSelected;

  const SubHeaderTabs({
    super.key,
    required this.currentTab,
    required this.onTabSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 62,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(
            color: AppColors.border,
            width: 1,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: Row(
          children: HomeTab.values
              .map(
                (tab) => Expanded(
              child: _TabItem(
                tab: tab,
                isActive: currentTab == tab,
                onTap: () => onTabSelected(tab),
              ),
            ),
          )
              .toList(),
        ),
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  final HomeTab tab;
  final bool isActive;
  final VoidCallback onTap;

  const _TabItem({
    required this.tab,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isActive ? AppColors.tabActive : AppColors.tabInactive;

    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                tab.icon,
                size: 18,
                color: color,
              ),
              const SizedBox(width: 6),
              Text(
                tab.label,
                style: TextStyle(
                  color: color,
                  fontSize: 16,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            height: 2.5,
            width: isActive ? 44 : 0,
            decoration: BoxDecoration(
              color: AppColors.tabIndicator,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}