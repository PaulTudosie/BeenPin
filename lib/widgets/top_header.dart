import 'package:flutter/material.dart';
import 'package:been/core/theme/app_colors.dart';
import 'package:been/core/theme/app_radii.dart';
import 'package:been/core/theme/app_shadows.dart';
import 'package:been/core/theme/app_spacing.dart';

class TopHeader extends StatelessWidget {
  final VoidCallback? onMenuTap;
  final VoidCallback? onAvatarTap;

  const TopHeader({
    super.key,
    this.onMenuTap,
    this.onAvatarTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: AppShadows.header,
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
                const SizedBox(width: 12),
                _AvatarAction(
                  onTap: onAvatarTap,
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
          color: AppColors.textPrimary,
          size: 29,
        ),
      ),
    );
  }
}

class _AvatarAction extends StatelessWidget {
  final VoidCallback? onTap;

  const _AvatarAction({this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: AppRadii.avatar,
      onTap: onTap,
      child: Ink(
        width: 46,
        height: 46,
        decoration: const BoxDecoration(
          color: AppColors.avatarBg,
          borderRadius: BorderRadius.all(Radius.circular(16)),
        ),
        child: const Center(
          child: Text(
            'B',
            style: TextStyle(
              color: AppColors.brandBlue,
              fontWeight: FontWeight.w800,
              fontSize: 22,
            ),
          ),
        ),
      ),
    );
  }
}