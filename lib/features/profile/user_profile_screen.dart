import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:been/core/theme/app_colors.dart';
import 'package:been/core/theme/app_spacing.dart';
import 'package:been/features/level/level_path_screen.dart';
import 'package:been/models/social_user.dart';
import 'package:been/services/capture_store.dart';
import 'package:been/services/engagement_store.dart';
import 'package:been/services/follow_store.dart';
import 'package:been/services/profile_about_store.dart';
import 'package:been/widgets/app_background.dart';

class UserProfileScreen extends StatefulWidget {
  final SocialUser user;
  final List<CaptureRecord> captures;

  const UserProfileScreen({
    super.key,
    required this.user,
    required this.captures,
  });

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  bool _isLoadingFollowState = true;
  bool _isFollowing = false;
  String? _aboutText;

  @override
  void initState() {
    super.initState();
    _loadFollowState();
    _loadAboutText();
  }

  Future<void> _loadFollowState() async {
    final isFollowing = await FollowStore.isFollowing(widget.user.id);
    if (!mounted) return;

    setState(() {
      _isFollowing = isFollowing;
      _isLoadingFollowState = false;
    });
  }

  Future<void> _toggleFollow() async {
    final isFollowing = await FollowStore.toggleFollow(widget.user.id);
    if (!mounted) return;

    setState(() {
      _isFollowing = isFollowing;
    });
  }

  Future<void> _loadAboutText() async {
    final about = await ProfileAboutStore.getAbout(
      widget.user.id,
      widget.user.tagline,
    );
    if (!mounted) return;

    setState(() {
      _aboutText = about;
    });
  }

  void _openPhotoPreview(CaptureRecord record) {
    showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: AspectRatio(
            aspectRatio: 3 / 4,
            child: Image.file(
              File(record.imagePath),
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: AppColors.surfaceSoft,
                alignment: Alignment.center,
                child: const Icon(
                  Icons.image_not_supported_outlined,
                  size: 36,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final avatarPath = widget.user.avatarPath;
    final hasAvatar = avatarPath != null &&
        avatarPath.isNotEmpty &&
        File(avatarPath).existsSync();
    final progress = _buildProgress(widget.user.levelName);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.user.handle),
      ),
      body: AppBackground(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.xl,
            AppSpacing.xl,
            AppSpacing.xxxl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                      decoration: BoxDecoration(
                        color: AppColors.surface.withValues(alpha: 0.89),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: AppColors.border.withValues(alpha: 0.68),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 98,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 68,
                                  height: 68,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(20),
                                    color: AppColors.surfaceSoft,
                                    border: Border.all(
                                      color: AppColors.border.withValues(
                                        alpha: 0.66,
                                      ),
                                    ),
                                    image: hasAvatar
                                        ? DecorationImage(
                                            image: FileImage(File(avatarPath)),
                                            fit: BoxFit.cover,
                                          )
                                        : null,
                                  ),
                                  child: hasAvatar
                                      ? null
                                      : const Icon(
                                          Icons.person_rounded,
                                          size: 34,
                                          color: AppColors.textSecondary,
                                        ),
                                ),
                                const SizedBox(height: 10),
                                _ProfileLevelCard(
                                  levelName: widget.user.levelName,
                                  current: widget.captures.length,
                                  target: progress.target,
                                  nextLevelName: progress.nextLevelName,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: AppSpacing.lg),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  LayoutBuilder(
                                    builder: (context, constraints) {
                                      final isTight =
                                          constraints.maxWidth < 205;
                                      final followButton = FilledButton(
                                        onPressed: _isLoadingFollowState
                                            ? null
                                            : _toggleFollow,
                                        style: FilledButton.styleFrom(
                                          backgroundColor: _isFollowing
                                              ? AppColors.brandGreen
                                              : AppColors.brandBlue,
                                          foregroundColor: Colors.white,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 9,
                                          ),
                                          minimumSize: const Size(0, 36),
                                          tapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                          visualDensity: VisualDensity.compact,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(18),
                                          ),
                                        ),
                                        child: Text(
                                          _isFollowing ? 'Following' : 'Follow',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: Theme.of(context)
                                              .textTheme
                                              .labelLarge
                                              ?.copyWith(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w700,
                                                letterSpacing: -0.1,
                                              ),
                                        ),
                                      );

                                      final nameText = Text(
                                        widget.user.name,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme
                                            .headlineSmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.w900,
                                              color: AppColors.textPrimary,
                                              letterSpacing: -0.4,
                                              height: 1.05,
                                            ),
                                      );

                                      if (isTight) {
                                        return Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            nameText,
                                            const SizedBox(height: 8),
                                            Align(
                                              alignment: Alignment.centerRight,
                                              child: followButton,
                                            ),
                                          ],
                                        );
                                      }

                                      return Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Expanded(child: nameText),
                                          const SizedBox(width: 10),
                                          followButton,
                                        ],
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          widget.user.city,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyLarge
                                              ?.copyWith(
                                                color: AppColors.textSecondary,
                                                fontWeight: FontWeight.w600,
                                              ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        '\u{1F1F7}\u{1F1F4}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(fontSize: 13),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  _ProfileAboutText(
                                    text: _aboutText ?? widget.user.tagline,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xxl),
              Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(text: 'Places '),
                    TextSpan(
                      text: widget.user.name,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const TextSpan(text: ' has '),
                    const TextSpan(
                      text: 'Been',
                      style: TextStyle(
                        color: AppColors.brandBlue,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: AppSpacing.lg),
              if (widget.captures.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text(
                    'No public pins from ${widget.user.name} yet.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                )
              else
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: widget.captures.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: AppSpacing.lg,
                    mainAxisSpacing: AppSpacing.lg,
                    mainAxisExtent: 236,
                  ),
                  itemBuilder: (context, index) {
                    final item = widget.captures[index];
                    return _ProfilePinCard(
                      record: item,
                      onTap: () => _openPhotoPreview(item),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  _ProfileProgress _buildProgress(String levelName) {
    switch (levelName) {
      case 'Starter':
        return const _ProfileProgress(target: 3, nextLevelName: 'Explorer');
      case 'Explorer':
        return const _ProfileProgress(target: 6, nextLevelName: 'Walker');
      case 'Walker':
        return const _ProfileProgress(target: 10, nextLevelName: 'Traveler');
      case 'Traveler':
        return const _ProfileProgress(target: 20, nextLevelName: 'Wanderer');
      case 'Wanderer':
        return const _ProfileProgress(target: 30, nextLevelName: 'Pathfinder');
      case 'Pathfinder':
        return const _ProfileProgress(
          target: 45,
          nextLevelName: 'Globetrotter',
        );
    }

    return const _ProfileProgress(target: 45, nextLevelName: 'Top level');
  }
}

class _ProfileLevelCard extends StatelessWidget {
  final String levelName;
  final int current;
  final int target;
  final String nextLevelName;

  const _ProfileLevelCard({
    required this.levelName,
    required this.current,
    required this.target,
    required this.nextLevelName,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => LevelDetailsScreen(
              levelName: levelName,
              current: current,
              target: target,
              nextLevelName: nextLevelName,
            ),
          ),
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(8, 9, 8, 9),
        decoration: BoxDecoration(
          color: AppColors.tabActiveBg.withValues(alpha: 0.82),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.brandBlue.withValues(alpha: 0.08),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Align(
              alignment: Alignment.center,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: AppColors.surface.withValues(alpha: 0.76),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.workspace_premium_rounded,
                  size: 14,
                  color: AppColors.brandBlue,
                ),
              ),
            ),
            const SizedBox(height: 7),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    levelName,
                    maxLines: 1,
                    overflow: TextOverflow.visible,
                    softWrap: false,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.brandBlue,
                      letterSpacing: -0.1,
                    ),
                  ),
                ),
                const SizedBox(width: 2),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 15,
                  color: AppColors.brandBlue,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileAboutText extends StatelessWidget {
  final String text;

  const _ProfileAboutText({
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textMuted,
              height: 1.45,
            ),
      ),
    );
  }
}

class _ProfileProgress {
  final int target;
  final String nextLevelName;

  const _ProfileProgress({
    required this.target,
    required this.nextLevelName,
  });
}

class _ProfilePinCard extends StatelessWidget {
  final CaptureRecord record;
  final VoidCallback onTap;

  const _ProfilePinCard({
    required this.record,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<CaptureEngagement>(
      future: EngagementStore.getEngagement(record.spotId),
      builder: (context, snapshot) {
        final engagement = snapshot.data;

        return InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Image.file(
                        File(record.imagePath),
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: AppColors.surfaceSoft,
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.image_not_supported_outlined,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    record.spotName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    record.spotType,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        DateFormat('dd MMM yyyy').format(record.capturedAt),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textMuted,
                            ),
                      ),
                      const Spacer(),
                      _MiniEngagement(
                        icon: engagement?.hasReacted == true
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        value: engagement?.reactionCount ?? 0,
                        active: engagement?.hasReacted ?? false,
                      ),
                      const SizedBox(width: 6),
                      _MiniEngagement(
                        icon: Icons.chat_bubble_outline_rounded,
                        value: engagement == null
                            ? EngagementStore.demoSeedCommentCount
                            : EngagementStore.displayCommentCount(engagement),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MiniEngagement extends StatelessWidget {
  final IconData icon;
  final int value;
  final bool active;

  const _MiniEngagement({
    required this.icon,
    required this.value,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 13,
          color: active ? AppColors.brandBlue : AppColors.textMuted,
        ),
        const SizedBox(width: 3),
        Text(
          '$value',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: active ? AppColors.brandBlue : AppColors.textMuted,
                fontWeight: FontWeight.w700,
              ),
        ),
      ],
    );
  }
}
