import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:been/core/theme/app_colors.dart';
import 'package:been/core/theme/app_spacing.dart';

enum HomeTab {
  pins,
  hidden,
  map,
  notifications,
  journey;

  String get label {
    switch (this) {
      case HomeTab.map:
        return 'Map';
      case HomeTab.pins:
        return 'Pins';
      case HomeTab.hidden:
        return 'Hidden';
      case HomeTab.notifications:
        return 'Notifications';
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
      case HomeTab.notifications:
        return 'assets/icons/tab_notifications.svg';
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
      height: 78,
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: Row(
        children: HomeTab.values.map((tab) {
          return Expanded(child: _buildTab(context, tab));
        }).toList(),
      ),
    );
  }

  Widget _buildTab(BuildContext context, HomeTab tab) {
    final isActive = currentTab == tab;
    final color = isActive ? AppColors.tabActive : AppColors.tabInactive;
    final labelStyle = Theme.of(context).textTheme.labelMedium;

    return GestureDetector(
      onTap: () => onTabSelected(tab),
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SvgPicture.asset(
            tab.assetPath,
            width: 25,
            height: 25,
            colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
          ),
          const SizedBox(height: 7),
          Text(
            tab.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: labelStyle?.copyWith(
              color: color,
              fontSize: 11,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              letterSpacing: -0.25,
            ),
          ),
        ],
      ),
    );
  }
}
