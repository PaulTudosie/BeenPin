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
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            offset: const Offset(0, 3),
            blurRadius: 8,
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 76,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl,
            ),
            child: Row(
              children: [
                RichText(
                  text: const TextSpan(
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.6,
                    ),
                    children: [
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
  final VoidCallback? onTap;

  const _IconAction({
    required this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: AppRadii.pill,
      onTap: onTap,
      child: SizedBox(
        width: 42,
        height: 42,
        child: Icon(
          icon,
          color:AppColors.brandBlue,
          size: 29,
        ),
      ),
    );
  }
}