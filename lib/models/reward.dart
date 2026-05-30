import 'dart:convert';

import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';

import 'package:been/models/pilot_partner_offer.dart';
import 'package:been/models/spot.dart';
import 'package:been/services/pilot_partner_service.dart';
import 'package:been/services/spot_service.dart';

enum PartnerTier {
  featured,
  standard,
  trial;

  int get score {
    switch (this) {
      case PartnerTier.featured:
        return 35;
      case PartnerTier.standard:
        return 20;
      case PartnerTier.trial:
        return 10;
    }
  }

  String get storageValue => name;
}

enum RewardQuality {
  strong,
  medium,
  weak;

  int get score {
    switch (this) {
      case RewardQuality.strong:
        return 15;
      case RewardQuality.medium:
        return 10;
      case RewardQuality.weak:
        return 5;
    }
  }

  String get storageValue => name;
}

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
  final PartnerTier partnerTier;
  final String category;
  final double distance;
  final RewardQuality rewardQuality;
  final bool isActive;
  final int score;
  final String? selectionBadge;
  final DateTime expiresAt;

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
    required this.partnerTier,
    required this.category,
    required this.distance,
    required this.rewardQuality,
    required this.isActive,
    required this.score,
    required this.expiresAt,
    this.selectionBadge,
    this.proofId,
    this.capturedAt,
    this.distanceMeters,
  });

  String get expiryTimeLabel => DateFormat('HH:mm').format(expiresAt);

  String get distanceLabel => '${distance.round()} m';

  Map<String, dynamic> toJson() {
    return {
      'partnerId': partnerId,
      'partnerName': partnerName,
      'partnerAddress': partnerAddress,
      'gift': gift,
      'qrCode': qrCode,
      'expiryDate': expiryDate,
      'partnerUrl': partnerUrl,
      'partnerCategory': partnerCategory,
      'offerDescription': offerDescription,
      'purchaseCondition': purchaseCondition,
      'staffInstruction': staffInstruction,
      'dailyLimit': dailyLimit,
      'unlockedFromSpot': unlockedFromSpot,
      'proofId': proofId,
      'capturedAt': capturedAt?.toIso8601String(),
      'distanceMeters': distanceMeters,
      'partnerTier': partnerTier.storageValue,
      'category': category,
      'distance': distance,
      'rewardQuality': rewardQuality.storageValue,
      'isActive': isActive,
      'score': score,
      'selectionBadge': selectionBadge,
      'expiresAt': expiresAt.toIso8601String(),
    };
  }

  factory Reward.fromJson(Map<String, dynamic> json) {
    return Reward(
      partnerId: json['partnerId'] as String? ?? '',
      partnerName: json['partnerName'] as String? ?? '',
      partnerAddress: json['partnerAddress'] as String? ?? '',
      gift: json['gift'] as String? ?? '',
      qrCode: json['qrCode'] as String? ?? '',
      expiryDate: json['expiryDate'] as String? ?? '',
      partnerUrl: json['partnerUrl'] as String? ?? '',
      partnerCategory: json['partnerCategory'] as String? ?? '',
      offerDescription: json['offerDescription'] as String? ?? '',
      purchaseCondition: json['purchaseCondition'] as String? ?? '',
      staffInstruction: json['staffInstruction'] as String? ?? '',
      dailyLimit: (json['dailyLimit'] as num?)?.toInt() ?? 0,
      unlockedFromSpot: json['unlockedFromSpot'] as String? ?? '',
      proofId: json['proofId'] as String?,
      capturedAt: DateTime.tryParse(json['capturedAt'] as String? ?? ''),
      distanceMeters: (json['distanceMeters'] as num?)?.toDouble(),
      partnerTier: _parsePartnerTier(json['partnerTier'] as String?),
      category: json['category'] as String? ?? '',
      distance: (json['distance'] as num?)?.toDouble() ?? 0,
      rewardQuality: _parseRewardQuality(json['rewardQuality'] as String?),
      isActive: json['isActive'] as bool? ?? true,
      score: (json['score'] as num?)?.toInt() ?? 0,
      selectionBadge: json['selectionBadge'] as String?,
      expiresAt: DateTime.tryParse(json['expiresAt'] as String? ?? '') ??
          _endOfDay(DateTime.now()),
    );
  }

  String toRawJson() => jsonEncode(toJson());

  factory Reward.fromRawJson(String raw) {
    return Reward.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  static Reward generate(
    String spotId, {
    String? spotName,
    DateTime? capturedAt,
    double? distanceMeters,
    String? proofId,
  }) {
    final spot = SpotService.findSpotByIdOrName(
      spotId: spotId,
      spotName: spotName,
    );
    if (spot != null) {
      final rewards = availableForSpot(
        spot: spot,
        capturedAt: capturedAt,
        distanceMeters: distanceMeters,
        proofId: proofId,
      );
      if (rewards.isNotEmpty) {
        return rewards.first;
      }
    }

    final unlockTime = capturedAt ?? DateTime.now();
    final resolvedProofId =
        proofId ?? 'BP-$spotId-${unlockTime.toUtc().millisecondsSinceEpoch}';
    final offer = PilotPartnerService.offerForSpot(spotId);
    final expiresAt = _endOfDay(unlockTime);

    return _fromOffer(
      offer,
      unlockTime: unlockTime,
      spotId: spotId,
      spotName: spotName ?? 'this spot',
      distanceMeters: distanceMeters,
      proofId: resolvedProofId,
      partnerDistance: 0,
      score: offer.tierScore + offer.qualityScore + 25,
      selectionBadge: offer.partnerTier == 'featured' ? 'Featured' : 'Closest',
      expiresAt: expiresAt,
    );
  }

  static List<Reward> availableForSpot({
    required Spot spot,
    DateTime? capturedAt,
    double? distanceMeters,
    String? proofId,
  }) {
    final unlockTime = capturedAt ?? DateTime.now();
    final resolvedProofId =
        proofId ?? 'BP-${spot.id}-${unlockTime.toUtc().millisecondsSinceEpoch}';
    final expiresAt = _endOfDay(unlockTime);
    final eligible = PilotPartnerService.offers
        .where((offer) => offer.isActive)
        .map((offer) {
          final partnerDistance = Geolocator.distanceBetween(
            spot.lat,
            spot.lng,
            offer.partnerLat,
            offer.partnerLng,
          );
          if (partnerDistance > 500) {
            return null;
          }

          final score = offer.tierScore +
              _distanceScore(partnerDistance) +
              offer.qualityScore;

          return _RewardCandidate(
            reward: _fromOffer(
              offer,
              unlockTime: unlockTime,
              spotId: spot.id,
              spotName: spot.name,
              distanceMeters: distanceMeters,
              proofId: resolvedProofId,
              partnerDistance: partnerDistance,
              score: score,
              expiresAt: expiresAt,
            ),
            baseScore: score,
          );
        })
        .whereType<_RewardCandidate>()
        .toList();

    final ranked = <Reward>[];
    final remaining = List<_RewardCandidate>.of(eligible);
    final usedCategories = <String>{};

    while (remaining.isNotEmpty && ranked.length < 3) {
      remaining.sort((a, b) {
        final adjustedA = a.adjustedScore(usedCategories);
        final adjustedB = b.adjustedScore(usedCategories);
        if (adjustedA != adjustedB) {
          return adjustedB.compareTo(adjustedA);
        }
        return a.reward.distance.compareTo(b.reward.distance);
      });

      final chosen = remaining.removeAt(0);
      final adjustedScore = chosen.adjustedScore(usedCategories);
      final reward = chosen.reward.copyWith(
        score: adjustedScore,
      );
      ranked.add(reward);
      usedCategories.add(reward.category.toLowerCase());
    }

    if (ranked.isEmpty) {
      return <Reward>[];
    }

    final closestPartnerId = ranked
        .reduce(
          (best, current) => current.distance < best.distance ? current : best,
        )
        .partnerId;

    return ranked.asMap().entries.map((entry) {
      final index = entry.key;
      final reward = entry.value;
      String? badge;
      if (reward.partnerTier == PartnerTier.featured) {
        badge = 'Featured';
      } else if (reward.partnerId == closestPartnerId) {
        badge = 'Closest';
      } else if (index > 0) {
        badge = 'Also nearby';
      }

      return reward.copyWith(selectionBadge: badge);
    }).toList();
  }

  Reward copyWith({
    String? qrCode,
    int? score,
    String? selectionBadge,
  }) {
    return Reward(
      partnerId: partnerId,
      partnerName: partnerName,
      partnerAddress: partnerAddress,
      gift: gift,
      qrCode: qrCode ?? this.qrCode,
      expiryDate: expiryDate,
      partnerUrl: partnerUrl,
      partnerCategory: partnerCategory,
      offerDescription: offerDescription,
      purchaseCondition: purchaseCondition,
      staffInstruction: staffInstruction,
      dailyLimit: dailyLimit,
      unlockedFromSpot: unlockedFromSpot,
      proofId: proofId,
      capturedAt: capturedAt,
      distanceMeters: distanceMeters,
      partnerTier: partnerTier,
      category: category,
      distance: distance,
      rewardQuality: rewardQuality,
      isActive: isActive,
      score: score ?? this.score,
      selectionBadge: selectionBadge ?? this.selectionBadge,
      expiresAt: expiresAt,
    );
  }

  static Reward _fromOffer(
    PilotPartnerOffer offer, {
    required DateTime unlockTime,
    required String spotId,
    required String spotName,
    required double? distanceMeters,
    required String proofId,
    required double partnerDistance,
    required int score,
    required DateTime expiresAt,
    String? selectionBadge,
  }) {
    final today = DateFormat('yyyyMMdd').format(unlockTime);
    final expiryDate = DateFormat('dd MMM yyyy').format(expiresAt);
    return Reward(
      partnerId: offer.id,
      partnerName: offer.partnerName,
      partnerAddress: offer.partnerAddress,
      gift: offer.rewardTitle,
      qrCode: 'BEEN-$today-${offer.id}-$proofId',
      expiryDate: expiryDate,
      partnerUrl: offer.partnerUrl,
      partnerCategory: offer.partnerCategory,
      offerDescription: offer.offerDescription,
      purchaseCondition: offer.purchaseCondition,
      staffInstruction: offer.staffInstruction,
      dailyLimit: offer.dailyLimit,
      unlockedFromSpot: spotName,
      proofId: proofId,
      capturedAt: unlockTime,
      distanceMeters: distanceMeters,
      partnerTier: _parsePartnerTier(offer.partnerTier),
      category: offer.partnerCategory,
      distance: partnerDistance,
      rewardQuality: _parseRewardQuality(offer.rewardQuality),
      isActive: offer.isActive,
      score: score,
      selectionBadge: selectionBadge,
      expiresAt: expiresAt,
    );
  }

  static int _distanceScore(double distanceMeters) {
    if (distanceMeters <= 150) return 25;
    if (distanceMeters <= 300) return 20;
    if (distanceMeters <= 500) return 12;
    return -999;
  }

  static DateTime _endOfDay(DateTime dateTime) {
    return DateTime(
      dateTime.year,
      dateTime.month,
      dateTime.day,
      23,
      59,
      59,
    );
  }

  static PartnerTier _parsePartnerTier(String? raw) {
    switch (raw?.toLowerCase()) {
      case 'featured':
        return PartnerTier.featured;
      case 'trial':
        return PartnerTier.trial;
      case 'standard':
      default:
        return PartnerTier.standard;
    }
  }

  static RewardQuality _parseRewardQuality(String? raw) {
    switch (raw?.toLowerCase()) {
      case 'strong':
        return RewardQuality.strong;
      case 'weak':
        return RewardQuality.weak;
      case 'medium':
      default:
        return RewardQuality.medium;
    }
  }
}

class _RewardCandidate {
  final Reward reward;
  final int baseScore;

  const _RewardCandidate({
    required this.reward,
    required this.baseScore,
  });

  int adjustedScore(Set<String> usedCategories) {
    final hasDuplicateCategory =
        usedCategories.contains(reward.category.toLowerCase());
    return baseScore - (hasDuplicateCategory ? 6 : 0);
  }
}

extension on PilotPartnerOffer {
  int get tierScore {
    switch (partnerTier.toLowerCase()) {
      case 'featured':
        return 35;
      case 'trial':
        return 10;
      case 'standard':
      default:
        return 20;
    }
  }

  int get qualityScore {
    switch (rewardQuality.toLowerCase()) {
      case 'strong':
        return 15;
      case 'weak':
        return 5;
      case 'medium':
      default:
        return 10;
    }
  }
}
