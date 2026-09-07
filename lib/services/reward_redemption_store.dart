import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class RewardRedemption {
  final String proofId;
  final DateTime redeemedAt;

  const RewardRedemption({
    required this.proofId,
    required this.redeemedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'proofId': proofId,
      'redeemedAt': redeemedAt.toIso8601String(),
    };
  }

  factory RewardRedemption.fromJson(Map<String, dynamic> json) {
    return RewardRedemption(
      proofId: json['proofId'] as String,
      redeemedAt: DateTime.parse(json['redeemedAt'] as String),
    );
  }
}

class RewardRedemptionStore {
  static const _redemptionsKey = 'reward_redemptions';
  static Future<void>? _pending;

  static Future<RewardRedemption?> getRedemption(String proofId) async {
    final redemptions = await _getRedemptions();
    return redemptions[proofId];
  }

  static Future<bool> isRedeemed(String proofId) async {
    return getRedemption(proofId).then((value) => value != null);
  }

  static Future<RewardRedemption> redeem(String proofId) {
    final previous = _pending;
    final next = previous == null
        ? _redeem(proofId)
        : previous.then((_) => _redeem(proofId));
    final gate = next.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    _pending = gate;
    return next.whenComplete(() {
      if (identical(_pending, gate)) _pending = null;
    });
  }

  static Future<RewardRedemption> _redeem(String proofId) async {
    final redemptions = await _getRedemptions();
    final existing = redemptions[proofId];
    if (existing != null) return existing;

    final redemption = RewardRedemption(
      proofId: proofId,
      redeemedAt: DateTime.now(),
    );
    redemptions[proofId] = redemption;
    await _saveRedemptions(redemptions);
    return redemption;
  }

  static Future<Map<String, RewardRedemption>> _getRedemptions() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_redemptionsKey);
    if (raw == null || raw.isEmpty) return <String, RewardRedemption>{};

    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Unreadable redemption ledger');
    }

    return decoded.map((key, value) {
      try {
        return MapEntry(
            key, RewardRedemption.fromJson(value as Map<String, dynamic>));
      } on FormatException {
        return MapEntry(key, _unknownRedemption(key));
      } on TypeError {
        return MapEntry(key, _unknownRedemption(key));
      }
    });
  }

  // An existing ledger entry must not become reusable if its date is damaged.
  static RewardRedemption _unknownRedemption(String proofId) =>
      RewardRedemption(
        proofId: proofId,
        redeemedAt: DateTime.fromMillisecondsSinceEpoch(0),
      );

  static Future<void> _saveRedemptions(
    Map<String, RewardRedemption> redemptions,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = redemptions.map(
      (key, value) => MapEntry(key, value.toJson()),
    );
    if (!await prefs.setString(_redemptionsKey, jsonEncode(encoded))) {
      throw StateError('Could not save redemption. Please try again.');
    }
  }
}
