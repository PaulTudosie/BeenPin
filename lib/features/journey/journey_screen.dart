import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:been/core/theme/app_colors.dart';
import 'package:been/core/theme/app_spacing.dart';
import 'package:been/services/capture_store.dart';
import 'package:been/widgets/level_sheet.dart';
import 'package:been/widgets/polaroid_tile.dart';

class JourneyScreen extends StatelessWidget {
  const JourneyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<CaptureRecord>>(
      future: CaptureStore.getCaptures(),
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
              const _ProfileHeader(),
              const SizedBox(height: AppSpacing.xl),
              _ProgressCard(
                levelName: progress.levelName,
                current: captures.length,
                target: progress.target,
              ),
              const SizedBox(height: AppSpacing.xxl),
              const Text(
                'Your photos',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              if (captures.isEmpty)
                const _EmptyJourneyState()
              else
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: captures.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: AppSpacing.lg,
                    mainAxisSpacing: AppSpacing.lg,
                    childAspectRatio: 0.78,
                  ),
                  itemBuilder: (context, index) {
                    final item = captures[index];
                    final dateText = DateFormat('dd MMM yyyy').format(item.capturedAt);

                    return PolaroidTile(
                      image: FileImage(File(item.imagePath)),
                      spotName: item.spotName,
                      cityCountry: 'Bucharest, Romania',
                      dateText: dateText,
                      onTap: () {
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
                                  File(item.imagePath),
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
                      },
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  _ProgressInfo _buildProgress(int count) {
    if (count < 3) {
      return const _ProgressInfo(levelName: 'Starter', target: 3);
    }
    if (count < 6) {
      return const _ProgressInfo(levelName: 'Explorer', target: 6);
    }
    if (count < 10) {
      return const _ProgressInfo(levelName: 'Traveler', target: 10);
    }
    return const _ProgressInfo(levelName: 'Pathfinder', target: 15);
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: AppColors.surfaceSoft,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Icon(
            Icons.person_outline_rounded,
            size: 34,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(width: AppSpacing.lg),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Paul',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Bucharest, Romania',
                style: TextStyle(
                  fontSize: 15,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProgressCard extends StatelessWidget {
  final String levelName;
  final int current;
  final int target;

  const _ProgressCard({
    required this.levelName,
    required this.current,
    required this.target,
  });

  @override
  Widget build(BuildContext context) {
    final progressValue = target == 0 ? 0.0 : (current / target).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Level: $levelName',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '$current / $target spots',
            style: const TextStyle(
              fontSize: 15,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progressValue,
              minHeight: 10,
              backgroundColor: AppColors.border,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.brandGreen),
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: () {
              showModalBottomSheet<void>(
                context: context,
                showDragHandle: false,
                backgroundColor: AppColors.surface,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                builder: (_) => LevelSheet(
                  levelName: levelName,
                  current: current,
                  target: target,
                ),
              );
            },
            child: const Text('See progress'),
          ),
        ],
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
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Capture your first spot and your polaroids will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
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

  const _ProgressInfo({
    required this.levelName,
    required this.target,
  });
}