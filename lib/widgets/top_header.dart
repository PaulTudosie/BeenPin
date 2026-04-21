import 'package:flutter/material.dart';
import 'package:been/core/theme/app_colors.dart';
import 'package:been/core/theme/app_radii.dart';
import 'package:been/core/theme/app_spacing.dart';
import 'package:been/features/search/app_search_delegate.dart';

class TopHeader extends StatelessWidget {
  final VoidCallback? onMenuTap;

  const TopHeader({
    super.key,
    this.onMenuTap,
  });

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    final headerHeight = isLandscape ? 60.0 : 74.0;
    final logoFontSize = isLandscape ? 22.0 : 24.0;
    final menuSize = isLandscape ? 26.0 : 28.0;
    final horizontalPadding = isLandscape ? AppSpacing.lg : AppSpacing.xl;

    return Container(
      color: AppColors.surface,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: headerHeight,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
            child: Row(
              children: [
                RichText(
                  text: TextSpan(
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontSize: logoFontSize,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                    children: const [
                      TextSpan(
                        text: 'Been',
                        style: TextStyle(color: AppColors.brandBlue),
                      ),
                      TextSpan(
                        text: 'Pin',
                        style: TextStyle(color: AppColors.brandGreen),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () {
                      showSearch<void>(
                        context: context,
                        delegate: AppSearchDelegate(),
                      );
                    },
                    child: Container(
                      height: isLandscape ? 42 : 46,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceSoft,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.search_rounded,
                            color: AppColors.textSecondary,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Search pins, places, users',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: AppColors.textMuted,
                                    fontWeight: FontWeight.w500,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                _IconAction(
                  icon: Icons.menu_rounded,
                  iconSize: menuSize,
                  onTap: onMenuTap,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _IconAction extends StatelessWidget {
  final IconData icon;
  final double iconSize;
  final VoidCallback? onTap;

  const _IconAction({
    required this.icon,
    required this.iconSize,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: AppRadii.pill,
      onTap: onTap,
      child: SizedBox(
        width: 40,
        height: 40,
        child: Icon(
          icon,
          color: AppColors.textPrimary,
          size: iconSize,
        ),
      ),
    );
  }
}
