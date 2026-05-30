import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:been/models/reward.dart';

class RewardSelectionStore {
  static const _selectedRewardsKey = 'selected_rewards_by_proof';
  static final ValueNotifier<int> selectedRewardsVersion =
      ValueNotifier<int>(0);

  static Future<Reward?> getSelectedReward(String proofId) async {
    final all = await _getSelectedRewards();
    return all[proofId];
  }

  static Future<void> saveSelectedReward({
    required String proofId,
    required Reward reward,
  }) async {
    final all = await _getSelectedRewards();
    all[proofId] = reward;
    await _saveSelectedRewards(all);
    selectedRewardsVersion.value++;
  }

  static Future<Map<String, Reward>> _getSelectedRewards() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_selectedRewardsKey);
    if (raw == null || raw.isEmpty) {
      return <String, Reward>{};
    }

    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      return <String, Reward>{};
    }

    return decoded.map((key, value) {
      return MapEntry(
        key,
        Reward.fromJson(value as Map<String, dynamic>),
      );
    });
  }

  static Future<void> _saveSelectedRewards(Map<String, Reward> rewards) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = rewards.map(
      (key, value) => MapEntry(key, value.toJson()),
    );
    await prefs.setString(_selectedRewardsKey, jsonEncode(encoded));
  }
}
