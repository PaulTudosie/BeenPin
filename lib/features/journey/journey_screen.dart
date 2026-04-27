import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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
  String? _avatarPath;
  String? _userBio;
  late Future<List<CaptureRecord>> _capturesFuture;

  @override
  void initState() {
    super.initState();
    _capturesFuture = CaptureStore.getCaptures();
    _loadAvatarPath();
    _loadUserBio();
  }

  Future<void> _loadAvatarPath() async {
    final savedPath = await CaptureStore.getAvatarPath();

    if (!mounted) return;

    setState(() {
      _avatarPath = savedPath;
    });
  }

  Future<void> _saveAvatarPath(String path) async {
    await CaptureStore.saveAvatarPath(path);

    if (!mounted) return;

    setState(() {
      _avatarPath = path;
    });
  }

  Future<void> _loadUserBio() async {
    final bio = await CaptureStore.getUserBio();
    if (!mounted) return;

    setState(() {
      _userBio = bio;
    });
  }

  Future<void> _editUserBio() async {
    final updated = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => _BioEditorSheet(initialText: _userBio),
    );

    if (updated == null) return;

    final normalized = updated.trim();
    await CaptureStore.saveUserBio(normalized);
    if (!mounted) return;

    setState(() {
      _userBio = normalized.isEmpty ? null : normalized;
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
              AppSpacing.lg,
              AppSpacing.xl,
              AppSpacing.xxxl,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 980),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ProfileHeader(
                      levelName: progress.levelName,
                      current: captures.length,
                      target: progress.target,
                      nextLevelName: progress.nextLevelName,
                      avatarPath: _avatarPath,
                      userBio: _userBio,
                      onAvatarTap: () => _showAvatarPicker(captures),
                      onBioTap: _editUserBio,
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    Row(
                      children: [
                        Expanded(
                          child: Text.rich(
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
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.25,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceSoft,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: AppColors.border.withValues(alpha: 0.72),
                            ),
                          ),
                          child: Text(
                            '${captures.length} capture${captures.length == 1 ? '' : 's'}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textSecondary,
                              letterSpacing: -0.1,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    if (captures.isEmpty)
                      const _EmptyJourneyState()
                    else
                      LayoutBuilder(
                        builder: (context, constraints) {
                          const horizontalSpacing = AppSpacing.lg;
                          const verticalSpacing = 14.0;

                          final availableWidth = constraints.maxWidth;

                          final crossAxisCount = availableWidth >= 900
                              ? 4
                              : availableWidth >= 600
                                  ? 3
                                  : 2;

                          final tileWidth = (availableWidth -
                                  (horizontalSpacing * (crossAxisCount - 1))) /
                              crossAxisCount;

                          final tileHeight =
                              tileWidth + (availableWidth >= 600 ? 92 : 88);

                          return GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: captures.length,
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: crossAxisCount,
                              crossAxisSpacing: horizontalSpacing,
                              mainAxisSpacing: verticalSpacing,
                              mainAxisExtent: tileHeight,
                            ),
                            itemBuilder: (context, index) {
                              final item = captures[index];
                              final dateText = DateFormat(
                                'dd MMM yyyy',
                              ).format(item.capturedAt);

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
              ),
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

class _BioEditorSheet extends StatefulWidget {
  final String? initialText;

  const _BioEditorSheet({
    required this.initialText,
  });

  @override
  State<_BioEditorSheet> createState() => _BioEditorSheetState();
}

class _BioEditorSheetState extends State<_BioEditorSheet> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.xl,
        AppSpacing.xl,
        MediaQuery.viewInsetsOf(context).bottom + AppSpacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'About me',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _controller,
            autofocus: true,
            minLines: 3,
            maxLines: 5,
            decoration: InputDecoration(
              hintText: 'Tell people what kind of places you explore.',
              filled: true,
              fillColor: AppColors.surfaceSoft,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: const BorderSide(color: AppColors.brandBlue),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.of(
                context,
              ).pop(_controller.text.trim()),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.brandBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: const Text('Save bio'),
            ),
          ),
        ],
      ),
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
  final String? userBio;
  final VoidCallback onAvatarTap;
  final VoidCallback onBioTap;

  const _ProfileHeader({
    required this.levelName,
    required this.current,
    required this.target,
    required this.nextLevelName,
    required this.avatarPath,
    required this.userBio,
    required this.onAvatarTap,
    required this.onBioTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasAvatar = avatarPath != null &&
        avatarPath!.isNotEmpty &&
        File(avatarPath!).existsSync();

    return Container(
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
            width: 92,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: onAvatarTap,
                  child: Stack(
                    children: [
                      Container(
                        width: 68,
                        height: 68,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceSoft,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppColors.border.withValues(alpha: 0.66),
                          ),
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
                                size: 31,
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
                            borderRadius: BorderRadius.circular(9),
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
                const SizedBox(height: 10),
                InkWell(
                  borderRadius: BorderRadius.circular(16),
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
                    width: 86,
                    padding: const EdgeInsets.fromLTRB(8, 7, 8, 7),
                    decoration: BoxDecoration(
                      color: AppColors.tabActiveBg.withValues(alpha: 0.82),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.brandBlue.withValues(alpha: 0.08),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                color:
                                    AppColors.surface.withValues(alpha: 0.76),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.workspace_premium_rounded,
                                size: 13,
                                color: AppColors.brandBlue,
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Expanded(
                              child: Text(
                                'Rank',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textSecondary,
                                  letterSpacing: -0.1,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                levelName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.brandBlue,
                                  letterSpacing: -0.1,
                                ),
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right_rounded,
                              size: 16,
                              color: AppColors.brandBlue,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
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
                  const Text(
                    'Camil',
                    style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.35,
                      height: 1.05,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Bucharest, Romania',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Baseline(
                        baseline: 14,
                        baselineType: TextBaseline.alphabetic,
                        child: Text(
                          '🇷🇴',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    fontSize: 13,
                                  ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _ProfileBio(
                    text: userBio,
                    onTap: onBioTap,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileBio extends StatelessWidget {
  final String? text;
  final VoidCallback onTap;

  const _ProfileBio({
    required this.text,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasText = text != null && text!.trim().isNotEmpty;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: AppColors.surfaceSoft.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.border.withValues(alpha: 0.62),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                hasText ? text!.trim() : 'Add something about yourself...',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: hasText
                          ? AppColors.textSecondary
                          : AppColors.textMuted,
                      fontWeight: hasText ? FontWeight.w600 : FontWeight.w500,
                      height: 1.4,
                    ),
              ),
            ),
            const SizedBox(width: 10),
            Icon(
              Icons.edit_outlined,
              size: 16,
              color: hasText ? AppColors.textSecondary : AppColors.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyJourneyState extends StatelessWidget {
  const _EmptyJourneyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 26, 22, 26),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.97),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: AppColors.border.withValues(alpha: 0.68),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 16,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: const Column(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.tabActiveBg,
              borderRadius: BorderRadius.all(Radius.circular(20)),
            ),
            child: SizedBox(
              width: 60,
              height: 60,
              child: Icon(
                Icons.photo_camera_back_outlined,
                size: 30,
                color: AppColors.brandBlue,
              ),
            ),
          ),
          SizedBox(height: 16),
          Text(
            'Your journey starts on the map',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
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
