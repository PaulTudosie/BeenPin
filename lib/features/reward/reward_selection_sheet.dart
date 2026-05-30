import 'package:flutter/material.dart';

import 'package:been/core/theme/app_colors.dart';
import 'package:been/core/theme/app_spacing.dart';
import 'package:been/models/reward.dart';
import 'package:been/models/spot.dart';
import 'package:been/services/reward_selection_store.dart';

class RewardSelectionSheet extends StatefulWidget {
  final Spot spot;
  final DateTime capturedAt;
  final double? distanceMeters;
  final String proofId;

  const RewardSelectionSheet({
    super.key,
    required this.spot,
    required this.capturedAt,
    required this.distanceMeters,
    required this.proofId,
  });

  static Future<Reward?> show(
    BuildContext context, {
    required Spot spot,
    required DateTime capturedAt,
    required double? distanceMeters,
    required String proofId,
  }) async {
    final existing = await RewardSelectionStore.getSelectedReward(proofId);
    if (!context.mounted) {
      return existing;
    }

    if (existing != null) {
      return _showConfirmation(
        context,
        reward: existing,
      );
    }

    final selected = await showModalBottomSheet<Reward>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RewardSelectionSheet(
        spot: spot,
        capturedAt: capturedAt,
        distanceMeters: distanceMeters,
        proofId: proofId,
      ),
    );

    if (selected == null || !context.mounted) {
      return selected;
    }

    return _showConfirmation(
      context,
      reward: selected,
    );
  }

  static Future<Reward?> _showConfirmation(
    BuildContext context, {
    required Reward reward,
  }) {
    return showModalBottomSheet<Reward>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RewardConfirmationSheet(
        reward: reward,
      ),
    );
  }

  @override
  State<RewardSelectionSheet> createState() => _RewardSelectionSheetState();
}

class _RewardSelectionSheetState extends State<RewardSelectionSheet> {
  late final List<Reward> _rewards;
  String? _selectedPartnerId;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _rewards = Reward.availableForSpot(
      spot: widget.spot,
      capturedAt: widget.capturedAt,
      distanceMeters: widget.distanceMeters,
      proofId: widget.proofId,
    );
  }

  Future<void> _chooseReward(Reward reward) async {
    if (_isSubmitting || _selectedPartnerId != null) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _selectedPartnerId = reward.partnerId;
    });

    await RewardSelectionStore.saveSelectedReward(
      proofId: widget.proofId,
      reward: reward,
    );

    if (!mounted) {
      return;
    }

    Navigator.of(context).pop(reward);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 24, 16, 16),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.xl,
        ),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.10),
              blurRadius: 28,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'You' 've unlocked rewards nearby',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0,
                  ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Choose 1 reward. Valid only today.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
            const SizedBox(height: AppSpacing.lg),
            if (_rewards.isEmpty)
              _EmptyRewardsState(spotName: widget.spot.name)
            else
              ..._rewards.map((reward) {
                final isLocked = _selectedPartnerId != null &&
                    _selectedPartnerId != reward.partnerId;
                final isSelected = _selectedPartnerId == reward.partnerId;

                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: _RewardSelectionCard(
                    reward: reward,
                    isLocked: isLocked,
                    isSelected: isSelected,
                    onChoose: () => _chooseReward(reward),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _RewardSelectionCard extends StatelessWidget {
  final Reward reward;
  final bool isLocked;
  final bool isSelected;
  final VoidCallback onChoose;

  const _RewardSelectionCard({
    required this.reward,
    required this.isLocked,
    required this.isSelected,
    required this.onChoose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isSelected
              ? AppColors.brandGreen
              : AppColors.border.withValues(alpha: 0.9),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reward.partnerName,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _RewardMetaChip(
                          icon: Icons.place_rounded,
                          label: reward.distanceLabel,
                        ),
                        _RewardMetaChip(
                          icon: Icons.category_rounded,
                          label: reward.category,
                        ),
                        _RewardMetaChip(
                          icon: Icons.schedule_rounded,
                          label: reward.expiryTimeLabel,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (reward.selectionBadge != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: reward.selectionBadge == 'Featured'
                        ? AppColors.brandBlue.withValues(alpha: 0.10)
                        : AppColors.surfaceSoft,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    reward.selectionBadge!,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: reward.selectionBadge == 'Featured'
                              ? AppColors.brandBlue
                              : AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            reward.gift,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Ends today at ${reward.expiryTimeLabel}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: isLocked ? null : onChoose,
              style: FilledButton.styleFrom(
                backgroundColor:
                    isSelected ? AppColors.brandGreen : AppColors.brandBlue,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(46),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                isSelected ? 'Chosen' : 'Choose reward',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RewardMetaChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _RewardMetaChip({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: AppColors.textMuted,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

class _RewardConfirmationSheet extends StatelessWidget {
  final Reward reward;

  const _RewardConfirmationSheet({
    required this.reward,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 24, 16, 16),
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.10),
              blurRadius: 28,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Reward selected',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              reward.partnerName,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              reward.offerDescription,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
            ),
            const SizedBox(height: AppSpacing.md),
            _RewardMetaChip(
              icon: Icons.schedule_rounded,
              label: 'Valid until ${reward.expiryTimeLabel}',
            ),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => Navigator.of(context).pop(reward),
                icon: const Icon(Icons.qr_code_rounded),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.brandGreen,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                label: const Text('Show QR code'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyRewardsState extends StatelessWidget {
  final String spotName;

  const _EmptyRewardsState({
    required this.spotName,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'No rewards within 500m',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Keep $spotName captured in your Journey. More nearby partner rewards can be added for the pilot route.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
          ),
        ],
      ),
    );
  }
}
