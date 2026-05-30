class PilotPartnerOffer {
  final String id;
  final String partnerName;
  final String partnerCategory;
  final String partnerAddress;
  final double partnerLat;
  final double partnerLng;
  final String partnerUrl;
  final String rewardTitle;
  final String offerDescription;
  final String purchaseCondition;
  final String staffInstruction;
  final int dailyLimit;
  final String partnerTier;
  final String rewardQuality;
  final bool isActive;
  final List<String> spotIds;

  const PilotPartnerOffer({
    required this.id,
    required this.partnerName,
    required this.partnerCategory,
    required this.partnerAddress,
    required this.partnerLat,
    required this.partnerLng,
    required this.partnerUrl,
    required this.rewardTitle,
    required this.offerDescription,
    required this.purchaseCondition,
    required this.staffInstruction,
    required this.dailyLimit,
    required this.partnerTier,
    required this.rewardQuality,
    required this.isActive,
    required this.spotIds,
  });
}
