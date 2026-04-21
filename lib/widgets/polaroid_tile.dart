import 'package:flutter/material.dart';
import 'package:been/core/theme/app_colors.dart';

class PolaroidTile extends StatelessWidget {
  final ImageProvider image;
  final String spotName;
  final String cityCountry;
  final String dateText;
  final VoidCallback onTap;
  final int reactionCount;
  final int commentCount;
  final bool hasReacted;

  const PolaroidTile({
    super.key,
    required this.image,
    required this.spotName,
    required this.cityCountry,
    required this.dateText,
    required this.onTap,
    this.reactionCount = 0,
    this.commentCount = 0,
    this.hasReacted = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 8,
              offset: Offset(2, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
              child: AspectRatio(
                aspectRatio: 1.0,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image(
                    image: image,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: AppColors.border,
                      child: const Icon(
                        Icons.image_not_supported_rounded,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    spotName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.1,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    cityCountry,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    dateText,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _EngagementPill(
                        icon: hasReacted
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        label: '$reactionCount',
                        isActive: hasReacted,
                      ),
                      const SizedBox(width: 6),
                      _EngagementPill(
                        icon: Icons.chat_bubble_outline_rounded,
                        label: '$commentCount',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EngagementPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;

  const _EngagementPill({
    required this.icon,
    required this.label,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 12,
          color: isActive ? AppColors.brandBlue : AppColors.textMuted,
        ),
        const SizedBox(width: 3),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: isActive ? AppColors.brandBlue : AppColors.textMuted,
          ),
        ),
      ],
    );
  }
}
