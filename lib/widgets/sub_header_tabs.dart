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

  String get identityText {
    switch (this) {
      case HomeTab.map:
        return 'Explore. Capture. Enjoy.';
      case HomeTab.pins:
        return 'Where others have Been';
      case HomeTab.journey:
        return "Places you've Been";
      case HomeTab.hidden:
        return 'Beyond the Map';
      case HomeTab.notifications:
        return 'Recent Activity';
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

  static const double _portraitBarHeight = 56;
  static const double _landscapeBarHeight = 50;
  static const double _portraitCircleSize = 62;
  static const double _landscapeCircleSize = 56;
  static const double _portraitIconSize = 25;
  static const double _landscapeIconSize = 25;
  static const double _portraitLabelFontSize = 11;
  static const double _landscapeLabelFontSize = 11;
  static const double _portraitIconLabelGap = 1;
  static const double _landscapeIconLabelGap = 1;
  static const List<HomeTab> _leadingTabs = [
    HomeTab.pins,
    HomeTab.hidden,
  ];
  static const List<HomeTab> _trailingTabs = [
    HomeTab.notifications,
    HomeTab.journey,
  ];

  const SubHeaderTabs({
    super.key,
    required this.currentTab,
    required this.onTabSelected,
  });

  @override
  Widget build(BuildContext context) {
    final metrics = _SubHeaderMetrics.from(context);
    final centerGap = metrics.circleSize + 8;

    return SafeArea(
      top: false,
      child: SizedBox(
        height: metrics.barHeight,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.bottomCenter,
          children: [
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: metrics.barHeight,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  border: Border(
                    top: BorderSide(
                      color: AppColors.border.withValues(alpha: 0.62),
                    ),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.025),
                      blurRadius: 10,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                  child: Row(
                    children: [
                      for (final tab in _leadingTabs)
                        Expanded(child: _StandardTab(tab: tab)),
                      SizedBox(width: centerGap),
                      for (final tab in _trailingTabs)
                        Expanded(child: _StandardTab(tab: tab)),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: -metrics.overlapHeight,
              child: _CenterMapTab(metrics: metrics),
            ),
          ],
        ),
      ),
    );
  }
}

class _StandardTab extends StatelessWidget {
  final HomeTab tab;

  const _StandardTab({required this.tab});

  @override
  Widget build(BuildContext context) {
    final parent = context.findAncestorWidgetOfExactType<SubHeaderTabs>()!;
    final isActive = parent.currentTab == tab;
    final foreground = isActive ? AppColors.tabActive : AppColors.tabInactive;
    final labelStyle = Theme.of(context).textTheme.labelMedium;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () => parent.onTabSelected(tab),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            2,
            metricsFor(context).tabTopPadding,
            2,
            metricsFor(context).tabBottomPadding,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _TabAssetIcon(
                assetPath: tab.assetPath,
                color: foreground,
              ),
              SizedBox(height: metricsFor(context).iconLabelGap),
              _TabLabel(
                label: tab.label,
                color: foreground,
                style: labelStyle,
                isActive: isActive,
              ),
            ],
          ),
        ),
      ),
    );
  }

  _SubHeaderMetrics metricsFor(BuildContext context) {
    return _SubHeaderMetrics.from(context);
  }
}

class _CenterMapTab extends StatelessWidget {
  final _SubHeaderMetrics metrics;

  const _CenterMapTab({required this.metrics});

  @override
  Widget build(BuildContext context) {
    final parent = context.findAncestorWidgetOfExactType<SubHeaderTabs>()!;
    final isActive = parent.currentTab == HomeTab.map;
    final foreground = isActive ? AppColors.tabActive : AppColors.tabInactive;
    final labelStyle = Theme.of(context).textTheme.labelMedium;

    return SizedBox(
      width: metrics.circleSize,
      height: metrics.circleSize,
      child: Material(
        color: AppColors.surface,
        shape: const CircleBorder(),
        elevation: isActive ? 5 : 3,
        shadowColor: Colors.black.withValues(alpha: 0.12),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => parent.onTabSelected(HomeTab.map),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isActive
                    ? AppColors.tabActive.withValues(alpha: 0.28)
                    : AppColors.border,
              ),
            ),
            padding: EdgeInsets.only(
              top: metrics.circleTopPadding,
              left: 6,
              right: 6,
              bottom: metrics.circleBottomPadding,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _TabAssetIcon(
                  assetPath: HomeTab.map.assetPath,
                  color: foreground,
                ),
                SizedBox(height: metrics.iconLabelGap),
                _TabLabel(
                  label: HomeTab.map.label,
                  color: foreground,
                  style: labelStyle,
                  isActive: isActive,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TabLabel extends StatelessWidget {
  final String label;
  final Color color;
  final TextStyle? style;
  final bool isActive;

  const _TabLabel({
    required this.label,
    required this.color,
    required this.style,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        label,
        maxLines: 1,
        textAlign: TextAlign.center,
        style: (style ?? const TextStyle()).copyWith(
          color: color,
          fontSize: _SubHeaderMetrics.from(context).labelFontSize,
          fontWeight: isActive ? FontWeight.w600 : FontWeight.w600,
          letterSpacing: 0,
          height: 1.0,
        ),
      ),
    );
  }
}

class _TabAssetIcon extends StatelessWidget {
  final String assetPath;
  final Color color;

  const _TabAssetIcon({
    required this.assetPath,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final size = _SubHeaderMetrics.from(context).iconSize;

    if (assetPath.toLowerCase().endsWith('.svg')) {
      return SvgPicture.asset(
        assetPath,
        width: size,
        height: size,
        fit: BoxFit.contain,
        colorFilter: ColorFilter.mode(
          color,
          BlendMode.srcIn,
        ),
      );
    }

    return Image.asset(
      assetPath,
      width: size,
      height: size,
      fit: BoxFit.contain,
      color: color,
      colorBlendMode: BlendMode.srcIn,
    );
  }
}

class _SubHeaderMetrics {
  final double barHeight;
  final double circleSize;
  final double overlapHeight;
  final double iconSize;
  final double labelFontSize;
  final double iconLabelGap;
  final double tabTopPadding;
  final double tabBottomPadding;
  final double circleTopPadding;
  final double circleBottomPadding;

  const _SubHeaderMetrics({
    required this.barHeight,
    required this.circleSize,
    required this.overlapHeight,
    required this.iconSize,
    required this.labelFontSize,
    required this.iconLabelGap,
    required this.tabTopPadding,
    required this.tabBottomPadding,
    required this.circleTopPadding,
    required this.circleBottomPadding,
  });

  factory _SubHeaderMetrics.from(BuildContext context) {
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    final compactLandscape =
        isLandscape || MediaQuery.of(context).size.height < 430;

    return _SubHeaderMetrics(
      barHeight: compactLandscape
          ? SubHeaderTabs._landscapeBarHeight
          : SubHeaderTabs._portraitBarHeight,
      circleSize: compactLandscape
          ? SubHeaderTabs._landscapeCircleSize
          : SubHeaderTabs._portraitCircleSize,
      overlapHeight: compactLandscape ? 4 : 6,
      iconSize: compactLandscape
          ? SubHeaderTabs._landscapeIconSize
          : SubHeaderTabs._portraitIconSize,
      labelFontSize: compactLandscape
          ? SubHeaderTabs._landscapeLabelFontSize
          : SubHeaderTabs._portraitLabelFontSize,
      iconLabelGap: compactLandscape
          ? SubHeaderTabs._landscapeIconLabelGap
          : SubHeaderTabs._portraitIconLabelGap,
      tabTopPadding: compactLandscape ? 1 : 2,
      tabBottomPadding: compactLandscape ? 1 : 1,
      circleTopPadding: compactLandscape ? 4 : 6,
      circleBottomPadding: compactLandscape ? 5 : 6,
    );
  }
}
