import 'package:been/models/reward.dart';

enum UserRewardStatus { active, redeemed, expired }

/// A snapshot of a selected offer and its local ownership/lifecycle.
class UserReward {
  final String id;
  final String userId;
  final String offerId;
  final String sourceSpotId;
  final DateTime selectedAt;
  final Reward reward;
  final double? partnerLatitude;
  final double? partnerLongitude;
  final UserRewardStatus status;
  final DateTime? redeemedAt;

  const UserReward({
    required this.id,
    required this.userId,
    required this.offerId,
    required this.sourceSpotId,
    required this.selectedAt,
    required this.reward,
    this.partnerLatitude,
    this.partnerLongitude,
    this.status = UserRewardStatus.active,
    this.redeemedAt,
  });

  String get proofId => reward.proofId!;
  DateTime get validUntil => reward.expiresAt;

  UserRewardStatus statusAt(DateTime now) {
    if (status == UserRewardStatus.redeemed || redeemedAt != null) {
      return UserRewardStatus.redeemed;
    }
    if (status == UserRewardStatus.expired || now.isAfter(validUntil)) {
      return UserRewardStatus.expired;
    }
    return UserRewardStatus.active;
  }

  UserReward reconcile(DateTime now, {DateTime? redemptionTime}) {
    final redeemed = redemptionTime ?? redeemedAt;
    return UserReward(
      id: id,
      userId: userId,
      offerId: offerId,
      sourceSpotId: sourceSpotId,
      selectedAt: selectedAt,
      reward: reward,
      partnerLatitude: partnerLatitude,
      partnerLongitude: partnerLongitude,
      status: redeemed != null ? UserRewardStatus.redeemed : statusAt(now),
      redeemedAt: redeemed,
    );
  }

  Map<String, dynamic> toJson() => {
        'schemaVersion': 1,
        'id': id,
        'userId': userId,
        'offerId': offerId,
        'sourceSpotId': sourceSpotId,
        'selectedAt': selectedAt.toIso8601String(),
        'partnerLatitude': partnerLatitude,
        'partnerLongitude': partnerLongitude,
        'status': status.name,
        'redeemedAt': redeemedAt?.toIso8601String(),
        'reward': reward.toJson(),
      };

  factory UserReward.fromJson(Map<String, dynamic> json) {
    if (json['schemaVersion'] != 1) {
      throw const FormatException('Unsupported user reward version');
    }
    final rewardJson = json['reward'] as Map<String, dynamic>;
    // Never let the legacy date fallback renew a malformed reward.
    DateTime.parse(rewardJson['expiresAt'] as String);
    final reward = Reward.fromJson(rewardJson);
    if (reward.proofId == null ||
        reward.proofId!.isEmpty ||
        reward.qrCode.isEmpty) {
      throw const FormatException('Missing reward identity');
    }
    return UserReward(
      id: json['id'] as String,
      userId: json['userId'] as String,
      offerId: json['offerId'] as String,
      sourceSpotId: json['sourceSpotId'] as String,
      selectedAt: DateTime.parse(json['selectedAt'] as String),
      reward: reward,
      partnerLatitude: (json['partnerLatitude'] as num?)?.toDouble(),
      partnerLongitude: (json['partnerLongitude'] as num?)?.toDouble(),
      status: UserRewardStatus.values.byName(json['status'] as String),
      redeemedAt: json['redeemedAt'] == null
          ? null
          : DateTime.parse(json['redeemedAt'] as String),
    );
  }
}
