import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:been/core/theme/app_colors.dart';
import 'package:been/core/theme/app_spacing.dart';
import 'package:been/features/level/level_path_screen.dart';
import 'package:been/services/capture_store.dart';
import 'package:been/services/engagement_store.dart';
import 'package:been/widgets/polaroid_tile.dart';

class JourneyScreen extends StatefulWidget {
  const JourneyScreen({super.key});

  @override
  State<JourneyScreen> createState() => _JourneyScreenState();
}

class _JourneyScreenState extends State<JourneyScreen> {
  static const String _avatarPathKey = 'journey_avatar_path';

  String? _avatarPath;
  late Future<List<CaptureRecord>> _capturesFuture;

  @override
  void initState() {
    super.initState();
    _capturesFuture = CaptureStore.getCaptures();
    _loadAvatarPath();
  }

  Future<void> _loadAvatarPath() async {
    final prefs = await SharedPreferences.getInstance();
    final savedPath = prefs.getString(_avatarPathKey);

    if (!mounted) return;

    setState(() {
      _avatarPath = savedPath;
    });
  }

  Future<void> _saveAvatarPath(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_avatarPathKey, path);

    if (!mounted) return;

    setState(() {
      _avatarPath = path;
    });
  }

  Future<void> _showAvatarPicker(List<CaptureRecord> captures) async {
    if (captures.isEmpty) return;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.lg,
              AppSpacing.xl,
              AppSpacing.xl,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Choose avatar',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Select one of your captured photos',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                SizedBox(
                  height: 320,
                  child: GridView.builder(
                    itemCount: captures.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: AppSpacing.md,
                      mainAxisSpacing: AppSpacing.md,
                      childAspectRatio: 1,
                    ),
                    itemBuilder: (context, index) {
                      final item = captures[index];

                      return InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () async {
                          await _saveAvatarPath(item.imagePath);
                          if (context.mounted) {
                            Navigator.of(context).pop();
                          }
                        },
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: Image.file(
                            File(item.imagePath),
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: AppColors.surfaceSoft,
                              alignment: Alignment.center,
                              child: const Icon(
                                Icons.image_not_supported_outlined,
                                size: 28,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.transparent,
      child: FutureBuilder<List<CaptureRecord>>(
        future: _capturesFuture,
        builder: (context, snapshot) {
          final captures = snapshot.data ?? const <CaptureRecord>[];

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final progress = _buildProgress(captures.length);

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.xl,
              AppSpacing.xl,
              AppSpacing.xxxl,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ProfileHeader(
                  levelName: progress.levelName,
                  current: captures.length,
                  target: progress.target,
                  nextLevelName: progress.nextLevelName,
                  avatarPath: _avatarPath,
                  onAvatarTap: () => _showAvatarPicker(captures),
                ),
                const SizedBox(height: AppSpacing.xxl),
                Text.rich(
                  const TextSpan(
                    children: [
                      TextSpan(
                        text: "Places you've ",
                        style: TextStyle(
                          color: AppColors.textMuted,
                        ),
                      ),
                      TextSpan(
                        text: 'Been',
                        style: TextStyle(
                          color: AppColors.brandBlue,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                if (captures.isEmpty)
                  const _EmptyJourneyState()
                else
                  LayoutBuilder(
                    builder: (context, constraints) {
                      const horizontalSpacing = AppSpacing.lg;
                      const verticalSpacing = AppSpacing.lg;

                      final availableWidth = constraints.maxWidth;

                      final crossAxisCount = availableWidth >= 900
                          ? 4
                          : availableWidth >= 600
                              ? 3
                              : 2;

                      final tileWidth = (availableWidth -
                              (horizontalSpacing * (crossAxisCount - 1))) /
                          crossAxisCount;

                      final tileHeight = tileWidth + 112;

                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: captures.length,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          crossAxisSpacing: horizontalSpacing,
                          mainAxisSpacing: verticalSpacing,
                          mainAxisExtent: tileHeight,
                        ),
                        itemBuilder: (context, index) {
                          final item = captures[index];
                          final dateText =
                              DateFormat('dd MMM yyyy').format(item.capturedAt);

                          return _EngagedPolaroidTile(
                            record: item,
                            dateText: dateText,
                            onTap: () => _openPhotoPreview(item),
                          );
                        },
                      );
                    },
                  ),
              ],
            ),
          );
        },
      ),
    );
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

  _ProgressInfo _buildProgress(int count) {
    if (count < 3) {
      return const _ProgressInfo(
        levelName: 'Starter',
        target: 3,
        nextLevelName: 'Explorer',
      );
    }
    if (count < 6) {
      return const _ProgressInfo(
        levelName: 'Explorer',
        target: 6,
        nextLevelName: 'Walker',
      );
    }
    if (count < 10) {
      return const _ProgressInfo(
        levelName: 'Walker',
        target: 10,
        nextLevelName: 'Traveler',
      );
    }
    if (count < 20) {
      return const _ProgressInfo(
        levelName: 'Traveler',
        target: 20,
        nextLevelName: 'Wanderer',
      );
    }
    if (count < 30) {
      return const _ProgressInfo(
        levelName: 'Wanderer',
        target: 30,
        nextLevelName: 'Pathfinder',
      );
    }
    if (count < 45) {
      return const _ProgressInfo(
        levelName: 'Pathfinder',
        target: 45,
        nextLevelName: 'Globetrotter',
      );
    }
    return const _ProgressInfo(
      levelName: 'Globetrotter',
      target: 45,
      nextLevelName: 'Top level',
    );
  }
}

class _EngagedPolaroidTile extends StatelessWidget {
  final CaptureRecord record;
  final String dateText;
  final VoidCallback onTap;

  const _EngagedPolaroidTile({
    required this.record,
    required this.dateText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<CaptureEngagement>(
      future: EngagementStore.getEngagement(record.spotId),
      builder: (context, snapshot) {
        final engagement = snapshot.data;

        return PolaroidTile(
          image: FileImage(File(record.imagePath)),
          spotName: record.spotName,
          cityCountry: 'Bucharest, Romania',
          dateText: dateText,
          reactionCount: engagement?.reactionCount ?? 0,
          commentCount: engagement == null
              ? EngagementStore.demoSeedCommentCount
              : EngagementStore.displayCommentCount(engagement),
          hasReacted: engagement?.hasReacted ?? false,
          onTap: onTap,
        );
      },
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  final String levelName;
  final int current;
  final int target;
  final String nextLevelName;
  final String? avatarPath;
  final VoidCallback onAvatarTap;

  const _ProfileHeader({
    required this.levelName,
    required this.current,
    required this.target,
    required this.nextLevelName,
    required this.avatarPath,
    required this.onAvatarTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasAvatar = avatarPath != null &&
        avatarPath!.isNotEmpty &&
        File(avatarPath!).existsSync();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: onAvatarTap,
          child: Stack(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.surfaceSoft,
                  borderRadius: BorderRadius.circular(20),
                  image: hasAvatar
                      ? DecorationImage(
                          image: FileImage(File(avatarPath!)),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: hasAvatar
                    ? null
                    : const Icon(
                        Icons.person_outline_rounded,
                        size: 34,
                        color: AppColors.textSecondary,
                      ),
              ),
              Positioned(
                right: 4,
                bottom: 4,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: AppColors.brandBlue,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.white,
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.edit_rounded,
                    size: 12,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.lg),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Camil',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Bucharest, Romania',
                style: TextStyle(
                  fontSize: 15,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              InkWell(
                borderRadius: BorderRadius.circular(14),
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
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: AppColors.tabActiveBg,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.workspace_premium_rounded,
                          size: 14,
                          color: AppColors.brandBlue,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        levelName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.brandBlue,
                          letterSpacing: -0.1,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.chevron_right_rounded,
                        size: 18,
                        color: AppColors.brandBlue,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EmptyJourneyState extends StatelessWidget {
  const _EmptyJourneyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.photo_camera_back_outlined,
            size: 34,
            color: AppColors.textSecondary,
          ),
          SizedBox(height: 12),
          Text(
            'Your journey starts on the map',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              letterSpacing: -0.2,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Capture your first spot and your polaroids will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressInfo {
  final String levelName;
  final int target;
  final String nextLevelName;

  const _ProgressInfo({
    required this.levelName,
    required this.target,
    required this.nextLevelName,
  });
}
