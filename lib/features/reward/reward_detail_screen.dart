import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:been/models/reward.dart';
import 'package:been/core/theme/app_colors.dart';
import 'package:been/features/map/reward_popup.dart';
import 'package:been/services/reward_redemption_store.dart';
import 'package:url_launcher/url_launcher.dart';

class RewardDetailScreen extends StatefulWidget {
  final Reward reward;

  const RewardDetailScreen({
    super.key,
    required this.reward,
  });

  @override
  State<RewardDetailScreen> createState() => _RewardDetailScreenState();
}

class _RewardDetailScreenState extends State<RewardDetailScreen> {
  late Future<RewardRedemption?> _redemptionFuture;

  Reward get reward => widget.reward;

  @override
  void initState() {
    super.initState();
    _redemptionFuture = _loadRedemption();
  }

  Future<RewardRedemption?> _loadRedemption() {
    final proofId = reward.proofId;
    if (proofId == null) return Future.value();
    return RewardRedemptionStore.getRedemption(proofId);
  }

  Future<void> _openPartnerUrl() async {
    final uri = Uri.parse(reward.partnerUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _openMaps() async {
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(reward.partnerAddress)}',
    );
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _showQr(BuildContext context) async {
    await RewardPopup.show(context, reward);
  }

  Future<void> _markRedeemed() async {
    final proofId = reward.proofId;
    if (proofId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: const Text('Mark reward as redeemed?'),
          content: Text(
            'This simulates the partner staff scanner for the pilot. Proof ID $proofId will become one-use on this demo device.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Mark redeemed'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    await RewardRedemptionStore.redeem(proofId);
    if (!mounted) return;

    setState(() {
      _redemptionFuture = _loadRedemption();
    });
  }

  @override
  Widget build(BuildContext context) {
    final proofId = reward.proofId;
    final capturedAt = reward.capturedAt;
    final distanceMeters = reward.distanceMeters;

    return FutureBuilder<RewardRedemption?>(
      future: _redemptionFuture,
      builder: (context, snapshot) {
        final redemption = snapshot.data;
        final isRedeemed = redemption != null;

        return Scaffold(
          backgroundColor: const Color(0xFFF7F8FA),
          appBar: AppBar(
            elevation: 0,
            scrolledUnderElevation: 0,
            backgroundColor: const Color(0xFFF7F8FA),
            foregroundColor: AppColors.textPrimary,
            title: const Text(
              'Reward unlocked',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          body: SafeArea(
            top: false,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _PartnerHeader(
                    partnerName: reward.partnerName,
                    partnerCategory: reward.partnerCategory,
                  ),
                  const SizedBox(height: 20),
                  if (isRedeemed) ...[
                    _RedeemedStatusCard(redemption: redemption),
                    const SizedBox(height: 16),
                  ],
                  _HeroOfferCard(reward: reward),
                  const SizedBox(height: 20),
                  _ActionCard(
                    icon: Icons.place_rounded,
                    title: reward.partnerAddress,
                    subtitle: 'Redeem in person at the partner location.',
                    onTap: _openMaps,
                    buttonLabel: 'Open location',
                  ),
                  const SizedBox(height: 14),
                  _ActionCard(
                    icon: Icons.public_rounded,
                    title: reward.partnerName,
                    subtitle: 'Open the partner page in your browser.',
                    onTap: _openPartnerUrl,
                    buttonLabel: 'Open partner',
                  ),
                  const SizedBox(height: 24),
                  const _SectionTitle(title: 'How redemption works'),
                  const SizedBox(height: 12),
                  _StepRow(
                    number: '1',
                    title: 'Visit the partner',
                    subtitle: 'Go to the location shown above.',
                  ),
                  const SizedBox(height: 12),
                  _StepRow(
                    number: '2',
                    title: 'Order normally',
                    subtitle:
                        'The reward is an extra, not a standalone free claim.',
                  ),
                  const SizedBox(height: 12),
                  _StepRow(
                    number: '3',
                    title: 'Show the QR code',
                    subtitle: 'Present it to the staff when requested.',
                  ),
                  const SizedBox(height: 24),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Reward details',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 14),
                        _InfoLine(
                          label: 'Offer',
                          value: reward.gift,
                        ),
                        const SizedBox(height: 10),
                        _InfoLine(
                          label: 'Category',
                          value: reward.partnerCategory,
                        ),
                        const SizedBox(height: 10),
                        _InfoLine(
                          label: 'Unlocked from',
                          value: reward.unlockedFromSpot,
                        ),
                        const SizedBox(height: 10),
                        _InfoLine(
                          label: 'Valid',
                          value: 'Today - ${reward.expiryDate}',
                        ),
                        if (proofId != null) ...[
                          const SizedBox(height: 10),
                          _InfoLine(
                            label: 'Proof ID',
                            value: proofId,
                          ),
                        ],
                        if (capturedAt != null) ...[
                          const SizedBox(height: 10),
                          _InfoLine(
                            label: 'Captured at',
                            value: DateFormat('dd MMM yyyy, HH:mm').format(
                              capturedAt,
                            ),
                          ),
                        ],
                        if (distanceMeters != null) ...[
                          const SizedBox(height: 10),
                          _InfoLine(
                            label: 'GPS proof',
                            value:
                                '${distanceMeters.round()}m from the pin when captured',
                          ),
                        ],
                        const SizedBox(height: 10),
                        _InfoLine(
                          label: 'Purchase condition',
                          value: reward.purchaseCondition,
                        ),
                        const SizedBox(height: 10),
                        _InfoLine(
                          label: 'Staff instruction',
                          value: reward.staffInstruction,
                        ),
                        const SizedBox(height: 10),
                        _InfoLine(
                          label: 'Daily demo limit',
                          value: '${reward.dailyLimit} redemptions',
                        ),
                        const SizedBox(height: 10),
                        const _InfoLine(
                          label: 'Redemption rule',
                          value: 'Same day, one use, extra with a purchase',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: isRedeemed ? null : () => _showQr(context),
                      icon: Icon(
                        isRedeemed
                            ? Icons.check_circle_rounded
                            : Icons.qr_code_rounded,
                      ),
                      label:
                          Text(isRedeemed ? 'Already redeemed' : 'Reveal QR'),
                      style: FilledButton.styleFrom(
                        backgroundColor: isRedeemed
                            ? AppColors.textMuted
                            : AppColors.brandGreen,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(54),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: isRedeemed ? null : _markRedeemed,
                      icon: const Icon(Icons.verified_rounded),
                      label: const Text('Partner demo: mark redeemed'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        foregroundColor: AppColors.textPrimary,
                        side: const BorderSide(color: AppColors.border),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                    ),
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

class _RedeemedStatusCard extends StatelessWidget {
  final RewardRedemption redemption;

  const _RedeemedStatusCard({required this.redemption});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEFFCF3),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.successSoftBorder),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle_rounded,
            color: AppColors.brandGreen,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Redeemed at ${DateFormat('dd MMM yyyy, HH:mm').format(redemption.redeemedAt)}. This proof ID is now one-use on this demo device.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PartnerHeader extends StatelessWidget {
  final String partnerName;
  final String partnerCategory;

  const _PartnerHeader({
    required this.partnerName,
    required this.partnerCategory,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Icon(
            Icons.storefront_rounded,
            color: Color(0xFF2563EB),
            size: 30,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Partner',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                partnerName,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                partnerCategory,
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
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

class _HeroOfferCard extends StatelessWidget {
  final Reward reward;

  const _HeroOfferCard({
    required this.reward,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1D4ED8),
            Color(0xFF10B981),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
            ),
            child: const Text(
              'YOUR EXTRA TODAY',
              style: TextStyle(
                color: Colors.white,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.7,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            reward.gift,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.w800,
              height: 1.08,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            reward.offerDescription,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 15,
              height: 1.45,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _OfferChip(
                icon: Icons.check_circle_rounded,
                label: 'Unlocked after capture',
              ),
              _OfferChip(
                icon: Icons.timer_rounded,
                label: 'Valid today',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OfferChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _OfferChip({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final String buttonLabel;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.buttonLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: AppColors.textPrimary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 14.5,
              height: 1.45,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 14),
          OutlinedButton(
            onPressed: onTap,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textPrimary,
              side: const BorderSide(color: AppColors.border),
              minimumSize: const Size.fromHeight(46),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Text(buttonLabel),
          ),
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  final String number;
  final String title;
  final String subtitle;

  const _StepRow({
    required this.number,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: const BoxDecoration(
            color: Color(0xFFEFF6FF),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            number,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: Color(0xFF2563EB),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 14.5,
                  height: 1.45,
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

class _InfoLine extends StatelessWidget {
  final String label;
  final String value;

  const _InfoLine({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textPrimary,
              fontSize: 14.5,
              height: 1.45,
            ),
        children: [
          TextSpan(
            text: '$label: ',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          TextSpan(text: value),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 21,
        fontWeight: FontWeight.w800,
        color: AppColors.textPrimary,
      ),
    );
  }
}
