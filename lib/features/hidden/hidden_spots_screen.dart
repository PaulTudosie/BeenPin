import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:been/core/theme/app_colors.dart';
import 'package:been/core/theme/app_spacing.dart';
import 'package:been/services/hidden_capture_store.dart';

class HiddenSpotsScreen extends StatefulWidget {
  final VoidCallback onScanTap;

  const HiddenSpotsScreen({
    super.key,
    required this.onScanTap,
  });

  @override
  State<HiddenSpotsScreen> createState() => _HiddenSpotsScreenState();
}

class _HiddenSpotsScreenState extends State<HiddenSpotsScreen> {
  late Future<List<HiddenCaptureRecord>> _capturesFuture;

  @override
  void initState() {
    super.initState();
    _capturesFuture = HiddenCaptureStore.getCaptures();
  }

  Future<void> _reloadCaptures() async {
    setState(() {
      _capturesFuture = HiddenCaptureStore.getCaptures();
    });
    await _capturesFuture;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.transparent,
      child: FutureBuilder<List<HiddenCaptureRecord>>(
        future: _capturesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final captures = snapshot.data ?? [];

          return RefreshIndicator(
            onRefresh: _reloadCaptures,
            color: AppColors.brandBlue,
            backgroundColor: AppColors.surface,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: AppSpacing.md),

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: AppColors.border,
                      ),
                    ),
                    child: Column(
                      children: [
                        InkWell(
                          onTap: widget.onScanTap,
                          borderRadius: BorderRadius.circular(999),
                          child: Container(
                            width: 92,
                            height: 92,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.tabActiveBg,
                              border: Border.all(
                                color: AppColors.border,
                              ),
                            ),
                            child: const Icon(
                              Icons.qr_code_scanner_rounded,
                              color: AppColors.brandBlue,
                              size: 40,
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          'Have you found a hidden spot?',
                          textAlign: TextAlign.center,
                          style:
                          Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Scan its code and save it to your hidden collection.',
                          textAlign: TextAlign.center,
                          style:
                          Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondary,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppSpacing.xl),

                  Row(
                    children: [
                      Text(
                        'Hidden discoveries',
                        style:
                        Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: AppSpacing.md),

                  if (captures.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: AppColors.border,
                        ),
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: AppColors.surfaceSoft,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.border,
                              ),
                            ),
                            child: const Icon(
                              Icons.lock_outline_rounded,
                              color: AppColors.textMuted,
                              size: 24,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'No hidden spots discovered yet',
                            textAlign: TextAlign.center,
                            style:
                            Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'When you unlock one, it will appear here.',
                            textAlign: TextAlign.center,
                            style:
                            Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.textSecondary,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ListView.separated(
                      itemCount: captures.length,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.md),
                      itemBuilder: (context, index) {
                        final item = captures[index];

                        return Container(
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(
                              color: AppColors.border,
                            ),
                          ),
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Image.file(
                                  File(item.imagePath),
                                  width: 96,
                                  height: 120,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      width: 96,
                                      height: 120,
                                      decoration: BoxDecoration(
                                        color: AppColors.surfaceSoft,
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      alignment: Alignment.center,
                                      child: const Icon(
                                        Icons.image_not_supported_outlined,
                                        color: AppColors.textMuted,
                                      ),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.tabActiveBg,
                                        borderRadius:
                                        BorderRadius.circular(999),
                                        border: Border.all(
                                          color: AppColors.border,
                                        ),
                                      ),
                                      child: Text(
                                        'Hidden',
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelMedium
                                            ?.copyWith(
                                          color: AppColors.brandBlue,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      item.spotName,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                        color: AppColors.textPrimary,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: -0.2,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      DateFormat('dd MMM yyyy')
                                          .format(item.discoveredAt),
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),

                  const SizedBox(height: AppSpacing.xl),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}