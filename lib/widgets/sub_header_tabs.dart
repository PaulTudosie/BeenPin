import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:been/core/theme/app_colors.dart';
import 'package:been/core/theme/app_spacing.dart';

enum HomeTab {
  map,
  pins,
  hidden,
  journey;

  String get label {
    switch (this) {
      case HomeTab.map:
        return 'Map';
      case HomeTab.pins:
        return 'Pins';
      case HomeTab.hidden:
        return 'Hidden';
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
      case HomeTab.hidden:
        return 'assets/icons/tab_hidden.svg';
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
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(
            color: Colors.black.withOpacity(0.04),
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.10),
            offset: const Offset(0, -4),
            blurRadius: 16,
            spreadRadius: 0,
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xs,
            8,
            AppSpacing.xs,
            8,
          ),
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
    final Color iconColor =
    isActive ? AppColors.tabActive : AppColors.tabInactive;
    final Color textColor =
    isActive ? AppColors.tabActive : AppColors.tabInactive;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isActive
                ? AppColors.brandBlue.withOpacity(0.06)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SvgPicture.asset(
                tab.assetPath,
                width: 22,
                height: 22,
                colorFilter: ColorFilter.mode(
                  iconColor,
                  BlendMode.srcIn,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                tab.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: textColor,
                  fontSize: 11.5,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                  letterSpacing: -0.1,
                  height: 1.0,
                ),
              ),
              const SizedBox(height: 6),
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                height: 3,
                width: isActive ? 22 : 0,
                decoration: BoxDecoration(
                  color: AppColors.tabIndicator,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}