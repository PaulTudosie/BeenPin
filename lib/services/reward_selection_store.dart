import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:been/models/reward.dart';
import 'package:been/models/user_reward.dart';
import 'package:been/services/current_user_profile.dart';
import 'package:been/services/pilot_partner_service.dart';
import 'package:been/services/reward_redemption_store.dart';
import 'package:been/services/spot_service.dart';

class RewardSelectionStore {
  static const _selectedRewardsKey = 'selected_rewards_by_proof';
  static final ValueNotifier<int> selectedRewardsVersion =
      ValueNotifier<int>(0);
  static Future<void>? _pending;

  // Serialize read/modify/write operations, including double selection callbacks.
  static Future<T> _serial<T>(Future<T> Function() action) {
    final previous = _pending;
    final next = previous == null
        ? Future<T>.sync(action)
        : previous.then((_) => action());
    final gate = next.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    _pending = gate;
    return next.whenComplete(() {
      if (identical(_pending, gate)) _pending = null;
    });
  }

  static Future<Reward?> getSelectedReward(String proofId) async =>
      (await findRewardByProofId(proofId))?.reward;

  static Future<UserReward?> findRewardByProofId(String proofId) async {
    for (final item in await getUserRewards()) {
      if (item.proofId == proofId) return item;
    }
    return null;
  }

  static Future<UserReward?> findRewardById(String id) async {
    for (final item in await getUserRewards()) {
      if (item.id == id) return item;
    }
    return null;
  }

  static Future<List<UserReward>> getUserRewards() => _serial(() async {
        final prefs = await SharedPreferences.getInstance();
        final entries = await _readEntries(prefs);
        final rewards = await _loadAndReconcile(prefs, entries);
        final owned = rewards.values
            .where((item) => item.userId == CurrentUserProfile.user.id)
            .toList();
        owned.sort((a, b) => b.selectedAt.compareTo(a.selectedAt));
        return owned;
      });

  static Future<List<UserReward>> getActiveRewards() async =>
      (await getUserRewards())
          .where((item) => item.status == UserRewardStatus.active)
          .toList();

  static Future<List<UserReward>> getPastRewards() async =>
      (await getUserRewards())
          .where((item) => item.status != UserRewardStatus.active)
          .toList();

  static Future<UserReward> saveSelectedReward({
    required String proofId,
    required Reward reward,
    String? sourceSpotId,
  }) =>
      _serial(() async {
        final prefs = await SharedPreferences.getInstance();
        final entries = await _readEntries(prefs);
        final all = await _loadAndReconcile(prefs, entries);
        final existing = all[proofId];
        if (existing != null) return existing;
        if (entries.containsKey(proofId)) {
          throw StateError('This capture has an unreadable saved reward.');
        }
        if (proofId.isEmpty ||
            reward.proofId != proofId ||
            reward.qrCode.isEmpty) {
          throw ArgumentError(
              'A selected reward must have a stable proof and QR.');
        }
        final now = DateTime.now();
        if (now.isAfter(reward.expiresAt)) {
          throw StateError('This reward has expired.');
        }
        final item = _snapshot(reward, now, sourceSpotId: sourceSpotId);
        final redemption = await RewardRedemptionStore.getRedemption(proofId);
        final saved =
            item.reconcile(now, redemptionTime: redemption?.redeemedAt);
        entries[proofId] = saved.toJson();
        await _writeEntries(prefs, entries);
        selectedRewardsVersion.value++;
        return saved;
      });

  static Future<UserReward> redeemReward(String id) => _serial(() async {
        final prefs = await SharedPreferences.getInstance();
        final entries = await _readEntries(prefs);
        final all = await _loadAndReconcile(prefs, entries);
        final item = all.values.firstWhere((item) =>
            item.id == id && item.userId == CurrentUserProfile.user.id);
        if (item.status == UserRewardStatus.redeemed) return item;
        if (item.statusAt(DateTime.now()) != UserRewardStatus.active) {
          throw StateError('This reward has expired.');
        }
        // Keep the one-use proof ledger. Reconciliation recovers a crash
        // between the ledger write and the user reward write.
        final redemption = await RewardRedemptionStore.redeem(item.proofId);
        final redeemed = item.reconcile(DateTime.now(),
            redemptionTime: redemption.redeemedAt);
        entries[item.proofId] = redeemed.toJson();
        await _writeEntries(prefs, entries);
        selectedRewardsVersion.value++;
        return redeemed;
      });

  static UserReward _snapshot(Reward reward, DateTime selectedAt,
      {String? sourceSpotId}) {
    final offers = PilotPartnerService.offers
        .where((offer) => offer.id == reward.partnerId);
    final offer = offers.isEmpty ? null : offers.first;
    return UserReward(
      id: 'UR-${reward.proofId}',
      userId: CurrentUserProfile.user.id,
      // The pilot catalog uses one offer ID per partner.
      offerId: reward.partnerId,
      sourceSpotId: sourceSpotId ??
          SpotService.resolveSpotId(spotName: reward.unlockedFromSpot) ??
          '',
      selectedAt: selectedAt,
      reward: reward,
      partnerLatitude: offer?.partnerLat,
      partnerLongitude: offer?.partnerLng,
    );
  }

  static Future<Map<String, dynamic>> _readEntries(
      SharedPreferences prefs) async {
    final raw = prefs.getString(_selectedRewardsKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
    } on FormatException {
      // Preserve original bytes before allowing future selections to save.
    }
    final backupKey = '${_selectedRewardsKey}_unreadable_backup';
    if (!prefs.containsKey(backupKey)) {
      if (!await prefs.setString(backupKey, raw)) {
        throw StateError('Could not preserve unreadable rewards.');
      }
    }
    return {};
  }

  static Future<Map<String, UserReward>> _loadAndReconcile(
      SharedPreferences prefs, Map<String, dynamic> entries) async {
    final result = <String, UserReward>{};
    var changed = false;
    final now = DateTime.now();
    for (final entry in entries.entries.toList()) {
      UserReward item;
      try {
        final json = Map<String, dynamic>.from(entry.value as Map);
        if (json.containsKey('schemaVersion')) {
          item = UserReward.fromJson(json);
        } else {
          // Old selections contain the exact QR token. Never regenerate it or
          // grant a fresh validity period for a missing old date.
          json['proofId'] ??= entry.key;
          if (DateTime.tryParse(json['expiresAt'] as String? ?? '') == null) {
            json['expiresAt'] = DateTime.fromMillisecondsSinceEpoch(0)
                .toUtc()
                .toIso8601String();
          }
          final reward = Reward.fromJson(json);
          if (reward.qrCode.isEmpty) continue;
          item = _snapshot(reward,
              reward.capturedAt ?? DateTime.fromMillisecondsSinceEpoch(0));
        }
        if (item.proofId != entry.key) continue;
      } on FormatException {
        continue;
      } on TypeError {
        continue;
      } on ArgumentError {
        continue;
      }
      final redemption =
          await RewardRedemptionStore.getRedemption(item.proofId);
      item = item.reconcile(now, redemptionTime: redemption?.redeemedAt);
      final encoded = item.toJson();
      if (jsonEncode(entry.value) != jsonEncode(encoded)) {
        entries[entry.key] = encoded;
        changed = true;
      }
      result[entry.key] = item;
    }
    // Unreadable individual entries remain in the original map untouched.
    if (changed) await _writeEntries(prefs, entries);
    return result;
  }

  static Future<void> _writeEntries(
      SharedPreferences prefs, Map<String, dynamic> entries) async {
    if (!await prefs.setString(_selectedRewardsKey, jsonEncode(entries))) {
      throw StateError('Could not save rewards. Please try again.');
    }
  }
}
