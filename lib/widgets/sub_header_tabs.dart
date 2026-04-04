import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
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

  String get assetPath {
    switch (this) {
      case HomeTab.map:
        return 'assets/icons/tab_map.svg';
      case HomeTab.pins:
        return 'assets/icons/tab_pins.svg';
      case HomeTab.journey:
        return 'assets/icons/tab_journey.svg';
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
      height: 64,
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
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
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
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          const Spacer(),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SvgPicture.asset(
                  tab.assetPath,
                  width: 21,
                  height: 21,
                  colorFilter: ColorFilter.mode(
                    color,
                    BlendMode.srcIn,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  tab.label,
                  style: TextStyle(
                    color: color,
                    fontSize: 16,
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                    letterSpacing: -0.2,
                    height: 1.0,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 11),
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            height: 3,
            width: isActive ? 48 : 0,
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