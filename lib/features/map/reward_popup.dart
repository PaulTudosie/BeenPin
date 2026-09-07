import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:been/models/reward.dart';
import 'package:been/models/user_reward.dart';
import 'package:been/services/reward_selection_store.dart';
import 'package:url_launcher/url_launcher.dart';

class RewardPopup extends StatefulWidget {
  final Reward reward;

  const RewardPopup({super.key, required this.reward});

  static Future<void> show(BuildContext context, Reward reward) {
    return showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black87,
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (_, __, ___) => RewardPopup(reward: reward),
      transitionBuilder: (_, anim, __, child) {
        final curved = CurvedAnimation(
          parent: anim,
          curve: Curves.easeOutBack,
        );
        return ScaleTransition(
          scale: curved,
          child: FadeTransition(opacity: anim, child: child),
        );
      },
    );
  }

  @override
  State<RewardPopup> createState() => _RewardPopupState();
}

class _RewardPopupState extends State<RewardPopup> with WidgetsBindingObserver {
  UserReward? _saved;
  bool _loading = true;
  Timer? _expiryTimer;
  Reward get reward => _saved?.reward ?? widget.reward;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    RewardSelectionStore.selectedRewardsVersion.addListener(_refresh);
    _refresh();
  }

  Future<void> _refresh() async {
    _expiryTimer?.cancel();
    if (mounted) setState(() => _loading = true);
    UserReward? saved;
    try {
      final proofId = widget.reward.proofId;
      if (proofId != null) {
        saved = await RewardSelectionStore.findRewardByProofId(proofId);
      }
    } catch (_) {
      // A QR must not be redeemable when its saved state cannot be verified.
    }
    if (!mounted) return;
    setState(() {
      _saved = saved;
      _loading = false;
    });
    if (saved?.statusAt(DateTime.now()) == UserRewardStatus.active) {
      // Only runs while this QR is visible; no background expiry job is needed.
      _expiryTimer = Timer(
          saved!.validUntil.difference(DateTime.now()) +
              const Duration(milliseconds: 1),
          _refresh);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refresh();
    } else {
      _expiryTimer?.cancel();
      if (mounted) setState(() => _loading = true);
    }
  }

  @override
  void dispose() {
    _expiryTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    RewardSelectionStore.selectedRewardsVersion.removeListener(_refresh);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final status = _saved?.statusAt(DateTime.now());
    if (status != UserRewardStatus.active) {
      return AlertDialog(
        title: Text(status == UserRewardStatus.redeemed
            ? 'Redeemed'
            : status == UserRewardStatus.expired
                ? 'Expired'
                : 'Reward unavailable'),
        content: const Text('This reward cannot be redeemed.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'))
        ],
      );
    }
    final scheme = Theme.of(context).colorScheme;

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(28),
            boxShadow: const [
              BoxShadow(
                blurRadius: 40,
                spreadRadius: 0,
                offset: Offset(0, 16),
                color: Colors.black38,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // header icon
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.card_giftcard_rounded,
                  color: scheme.primary,
                  size: 28,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'You earned a reward!',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),

              // validity badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.green.shade300),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.timer_rounded,
                        size: 14, color: Colors.green.shade700),
                    const SizedBox(width: 6),
                    Text(
                      'Valid today - ${reward.expiryDate}',
                      style: TextStyle(
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // gift row
              _InfoRow(
                icon: Icons.redeem_rounded,
                label: 'Gift',
                value: reward.gift,
                scheme: scheme,
              ),
              const SizedBox(height: 10),

              // partner row (tappable link)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.store_rounded, size: 18, color: scheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        final uri = Uri.parse(reward.partnerUrl);
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri,
                              mode: LaunchMode.externalApplication);
                        }
                      },
                      child: RichText(
                        text: TextSpan(
                          style: Theme.of(context).textTheme.bodyMedium,
                          children: [
                            const TextSpan(
                              text: 'Partner: ',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            TextSpan(
                              text: reward.partnerName,
                              style: TextStyle(
                                color: scheme.primary,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // address row
              _InfoRow(
                icon: Icons.location_on_rounded,
                label: 'Address',
                value: reward.partnerAddress,
                scheme: scheme,
              ),
              if (reward.proofId != null) ...[
                const SizedBox(height: 10),
                _InfoRow(
                  icon: Icons.verified_user_rounded,
                  label: 'Proof ID',
                  value: reward.proofId!,
                  scheme: scheme,
                ),
              ],
              if (reward.distanceMeters != null) ...[
                const SizedBox(height: 10),
                _InfoRow(
                  icon: Icons.gps_fixed_rounded,
                  label: 'GPS proof',
                  value:
                      '${reward.distanceMeters!.round()}m from the pin at capture',
                  scheme: scheme,
                ),
              ],
              const SizedBox(height: 6),

              // go to location link
              GestureDetector(
                onTap: () async {
                  final uri = Uri.parse(
                    'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(reward.partnerAddress)}',
                  );
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.only(left: 28),
                  child: Text(
                    'Go to location →',
                    style: TextStyle(
                      color: scheme.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // QR code
              Text(
                'Show this to the staff',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurface.withValues(alpha: 0.5),
                    ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: QrImageView(
                  data: reward.qrCode,
                  version: QrVersions.auto,
                  size: 160,
                  eyeStyle: const QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: Colors.black,
                  ),
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: Colors.black,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                reward.qrCode,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurface.withValues(alpha: 0.35),
                      fontFamily: 'monospace',
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),

              // done button
              FilledButton(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Done'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final ColorScheme scheme;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.scheme,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: scheme.primary),
        const SizedBox(width: 10),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: Theme.of(context).textTheme.bodyMedium,
              children: [
                TextSpan(
                  text: '$label: ',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                TextSpan(text: value),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
