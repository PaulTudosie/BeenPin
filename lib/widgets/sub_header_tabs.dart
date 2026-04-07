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
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    final barHeight = isLandscape ? 58.0 : 74.0;
    final horizontalPadding = isLandscape ? AppSpacing.md : AppSpacing.sm;

    return Container(
      height: barHeight,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(
            color: AppColors.border,
            width: 1,
          ),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
        child: Row(
          children: HomeTab.values
              .map(
                (tab) => Expanded(
              child: _TabItem(
                tab: tab,
                isActive: currentTab == tab,
                isLandscape: isLandscape,
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
  final bool isLandscape;
  final VoidCallback onTap;

  const _TabItem({
    required this.tab,
    required this.isActive,
    required this.isLandscape,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isActive ? AppColors.tabActive : AppColors.tabInactive;

    final iconSize = isLandscape ? 18.0 : 18.0;
    final labelSize = isLandscape ? 12.5 : 12.5;
    final underlineWidth = isLandscape ? 28.0 : 32.0;
    final underlineHeight = 3.0;

    return InkWell(
      onTap: onTap,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (isLandscape) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                SvgPicture.asset(
                  tab.assetPath,
                  width: iconSize,
                  height: iconSize,
                  colorFilter: ColorFilter.mode(
                    color,
                    BlendMode.srcIn,
                  ),
                ),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    tab.label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: color,
                      fontSize: labelSize,
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                      letterSpacing: -0.1,
                      height: 1.0,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
          ] else ...[
            SvgPicture.asset(
              tab.assetPath,
              width: iconSize,
              height: iconSize,
              colorFilter: ColorFilter.mode(
                color,
                BlendMode.srcIn,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              tab.label,
              style: TextStyle(
                color: color,
                fontSize: labelSize,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                letterSpacing: -0.1,
                height: 1.0,
              ),
            ),
            const SizedBox(height: 6),
          ],
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            height: underlineHeight,
            width: isActive ? underlineWidth : 0,
            decoration: BoxDecoration(
              color: AppColors.tabIndicator,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
        ],
      ),
    );
  }
}