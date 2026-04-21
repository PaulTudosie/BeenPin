import 'package:intl/intl.dart';
import 'package:been/services/pilot_partner_service.dart';

class Reward {
  final String partnerId;
  final String partnerName;
  final String partnerAddress;
  final String gift;
  final String qrCode;
  final String expiryDate;
  final String partnerUrl;

  final String partnerCategory;
  final String offerDescription;
  final String purchaseCondition;
  final String staffInstruction;
  final int dailyLimit;
  final String unlockedFromSpot;
  final String? proofId;
  final DateTime? capturedAt;
  final double? distanceMeters;

  const Reward({
    required this.partnerId,
    required this.partnerName,
    required this.partnerAddress,
    required this.gift,
    required this.qrCode,
    required this.expiryDate,
    required this.partnerUrl,
    required this.partnerCategory,
    required this.offerDescription,
    required this.purchaseCondition,
    required this.staffInstruction,
    required this.dailyLimit,
    required this.unlockedFromSpot,
    this.proofId,
    this.capturedAt,
    this.distanceMeters,
  });

  factory Reward.generate(
    String spotId, {
    String? spotName,
    DateTime? capturedAt,
    double? distanceMeters,
    String? proofId,
  }) {
    final unlockTime = capturedAt ?? DateTime.now();
    final today = DateFormat('yyyyMMdd').format(unlockTime);
    final displayDate = DateFormat('dd MMM yyyy').format(unlockTime);
    final resolvedProofId =
        proofId ?? 'BP-$spotId-${unlockTime.toUtc().millisecondsSinceEpoch}';
    final offer = PilotPartnerService.offerForSpot(spotId);

    return Reward(
      partnerId: offer.id,
      partnerName: offer.partnerName,
      partnerAddress: offer.partnerAddress,
      gift: offer.rewardTitle,
      qrCode: 'BEEN-$today-$resolvedProofId',
      expiryDate: displayDate,
      partnerUrl: offer.partnerUrl,
      partnerCategory: offer.partnerCategory,
      offerDescription: offer.offerDescription,
      purchaseCondition: offer.purchaseCondition,
      staffInstruction: offer.staffInstruction,
      dailyLimit: offer.dailyLimit,
      unlockedFromSpot: spotName ?? 'this spot',
      proofId: resolvedProofId,
      capturedAt: unlockTime,
      distanceMeters: distanceMeters,
    );
  }
}
