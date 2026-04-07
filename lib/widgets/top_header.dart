import 'package:flutter/material.dart';
import 'package:been/core/theme/app_colors.dart';
import 'package:been/core/theme/app_radii.dart';
import 'package:been/core/theme/app_shadows.dart';
import 'package:been/core/theme/app_spacing.dart';

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

    final headerHeight = isLandscape ? 56.0 : 62.0;
    final logoFontSize = isLandscape ? 22.0 : 24.0;
    final menuSize = isLandscape ? 26.0 : 28.0;
    final horizontalPadding = isLandscape ? AppSpacing.lg : AppSpacing.xl;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: AppShadows.header,
      ),
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
                    style: TextStyle(
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
                const Spacer(),
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
        width: 36,
        height: 36,
        child: Icon(
          icon,
          color: AppColors.textPrimary,
          size: iconSize,
        ),
      ),
    );
  }
}