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
        return 'Alerts';
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

  static const double _barHeight = 68;
  static const double _tabHeight = 54;
  static const double _iconFrameSize = 28;
  static const double _iconSize = 24;

  const SubHeaderTabs({
    super.key,
    required this.currentTab,
    required this.onTabSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: _barHeight,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xs,
        3,
        AppSpacing.xs,
        4,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.98),
        border: Border(
          top: BorderSide(
            color: AppColors.border.withValues(alpha: 0.82),
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.028),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: HomeTab.values.map((tab) {
          return Expanded(child: _buildTab(context, tab));
        }).toList(),
      ),
    );
  }

  Widget _buildTab(BuildContext context, HomeTab tab) {
    final isActive = currentTab == tab;
    final foreground = isActive ? AppColors.tabActive : AppColors.tabInactive;
    final labelStyle = Theme.of(context).textTheme.labelMedium;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 1),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () => onTabSelected(tab),
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            height: _tabHeight,
            padding: const EdgeInsets.fromLTRB(4, 5, 4, 4),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: _iconFrameSize,
                  height: _iconFrameSize,
                  child: Center(
                    child: SvgPicture.asset(
                      tab.assetPath,
                      width: _iconSize,
                      height: _iconSize,
                      colorFilter: ColorFilter.mode(
                        foreground,
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  tab.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: labelStyle?.copyWith(
                    color: foreground,
                    fontSize: 10.5,
                    fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                    letterSpacing: -0.2,
                    height: 1.0,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
