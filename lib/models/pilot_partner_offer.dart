class PilotPartnerOffer {
  final String id;
  final String partnerName;
  final String partnerCategory;
  final String partnerAddress;
  final String partnerUrl;
  final String rewardTitle;
  final String offerDescription;
  final String purchaseCondition;
  final String staffInstruction;
  final int dailyLimit;
  final List<String> spotIds;

  const PilotPartnerOffer({
    required this.id,
    required this.partnerName,
    required this.partnerCategory,
    required this.partnerAddress,
    required this.partnerUrl,
    required this.rewardTitle,
    required this.offerDescription,
    required this.purchaseCondition,
    required this.staffInstruction,
    required this.dailyLimit,
    required this.spotIds,
  });
}
