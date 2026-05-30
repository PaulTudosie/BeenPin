import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SavedSpotStore {
  static final ValueNotifier<int> version = ValueNotifier<int>(0);

  static const _savedSpotIdsKey = 'saved_spot_ids';
  static const _reactedSpotIdsKey = 'capture_reacted_spot_ids';
  static const _reactionTypesKey = 'capture_reaction_types';

  static Future<Set<String>> getSavedSpotIds() async {
    final prefs = await SharedPreferences.getInstance();
    final storedIds = prefs.getStringList(_savedSpotIdsKey);
    if (storedIds != null) {
      return storedIds.where((id) => id.trim().isNotEmpty).toSet();
    }

    final migratedIds = _savedIdsFromLegacyReactions(prefs);
    if (migratedIds.isNotEmpty) {
      await prefs.setStringList(_savedSpotIdsKey, migratedIds.toList());
    }

    return migratedIds;
  }

  static Future<bool> isSaved(String spotId) async {
    final savedIds = await getSavedSpotIds();
    return savedIds.contains(spotId);
  }

  static Future<void> setSaved(String spotId, bool saved) async {
    final trimmedSpotId = spotId.trim();
    if (trimmedSpotId.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final savedIds = (prefs.getStringList(_savedSpotIdsKey) ?? <String>[])
        .where((id) => id.trim().isNotEmpty)
        .toSet();
    final didChange =
        saved ? savedIds.add(trimmedSpotId) : savedIds.remove(trimmedSpotId);

    if (!didChange) return;

    await prefs.setStringList(_savedSpotIdsKey, savedIds.toList());
    version.value++;
  }

  static Set<String> _savedIdsFromLegacyReactions(SharedPreferences prefs) {
    final reactedIds =
        (prefs.getStringList(_reactedSpotIdsKey) ?? <String>[]).toSet();
    final reactionTypes = _decodeStringMap(prefs.getString(_reactionTypesKey));

    return reactionTypes.entries
        .where(
          (entry) => reactedIds.contains(entry.key) && entry.value == 'save',
        )
        .map((entry) => entry.key)
        .where((id) => id.trim().isNotEmpty)
        .toSet();
  }

  static Map<String, String> _decodeStringMap(String? raw) {
    if (raw == null || raw.isEmpty) return <String, String>{};

    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) return <String, String>{};

    return decoded.map(
      (key, value) => MapEntry(key, value?.toString() ?? ''),
    );
  }
}
