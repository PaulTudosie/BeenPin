import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:been/models/spot.dart';

class CaptureRecord {
  final String spotId;
  final String spotName;
  final String spotType;
  final String imagePath;
  final DateTime capturedAt;
  final double? userLatitude;
  final double? userLongitude;
  final double? distanceMeters;
  final String? proofId;

  const CaptureRecord({
    required this.spotId,
    required this.spotName,
    required this.spotType,
    required this.imagePath,
    required this.capturedAt,
    this.userLatitude,
    this.userLongitude,
    this.distanceMeters,
    this.proofId,
  });

  Map<String, dynamic> toJson() {
    return {
      'spotId': spotId,
      'spotName': spotName,
      'spotType': spotType,
      'imagePath': imagePath,
      'capturedAt': capturedAt.toIso8601String(),
      'userLatitude': userLatitude,
      'userLongitude': userLongitude,
      'distanceMeters': distanceMeters,
      'proofId': proofId,
    };
  }

  factory CaptureRecord.fromJson(Map<String, dynamic> json) {
    return CaptureRecord(
      spotId: json['spotId'] as String,
      spotName: json['spotName'] as String,
      spotType: json['spotType'] as String? ?? '',
      imagePath: json['imagePath'] as String,
      capturedAt: DateTime.parse(json['capturedAt'] as String),
      userLatitude: (json['userLatitude'] as num?)?.toDouble(),
      userLongitude: (json['userLongitude'] as num?)?.toDouble(),
      distanceMeters: (json['distanceMeters'] as num?)?.toDouble(),
      proofId: json['proofId'] as String?,
    );
  }
}

class CaptureStore {
  static const _capturedIdsKey = 'captured_spot_ids';
  static const _capturesKey = 'capture_records';
  static const _avatarPathKey = 'journey_avatar_path';

  static Future<Set<String>> getCapturedIds() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_capturedIdsKey) ?? <String>[];
    return list.toSet();
  }

  static Future<bool> isCaptured(String spotId) async {
    final ids = await getCapturedIds();
    return ids.contains(spotId);
  }

  static Future<void> markCaptured(String spotId) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_capturedIdsKey) ?? <String>[];
    final set = list.toSet()..add(spotId);
    await prefs.setStringList(_capturedIdsKey, set.toList());
  }

  static Future<List<CaptureRecord>> getCaptures() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_capturesKey) ?? <String>[];

    final items = raw
        .map((e) =>
            CaptureRecord.fromJson(jsonDecode(e) as Map<String, dynamic>))
        .toList();

    items.sort((a, b) => b.capturedAt.compareTo(a.capturedAt));
    return items;
  }

  static Future<CaptureRecord> saveCapture({
    required Spot spot,
    required String imagePath,
    required double userLatitude,
    required double userLongitude,
    required double distanceMeters,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    final existingRaw = prefs.getStringList(_capturesKey) ?? <String>[];
    final existing = existingRaw
        .map((e) =>
            CaptureRecord.fromJson(jsonDecode(e) as Map<String, dynamic>))
        .toList();

    existing.removeWhere((item) => item.spotId == spot.id);

    final capturedAt = DateTime.now();
    final newItem = CaptureRecord(
      spotId: spot.id,
      spotName: spot.name,
      spotType: spot.type,
      imagePath: imagePath,
      capturedAt: capturedAt,
      userLatitude: userLatitude,
      userLongitude: userLongitude,
      distanceMeters: distanceMeters,
      proofId: _buildProofId(spot.id, capturedAt),
    );

    existing.insert(0, newItem);

    final encoded = existing.map((e) => jsonEncode(e.toJson())).toList();
    await prefs.setStringList(_capturesKey, encoded);

    final ids = (prefs.getStringList(_capturedIdsKey) ?? <String>[]).toSet()
      ..add(spot.id);
    await prefs.setStringList(_capturedIdsKey, ids.toList());

    return newItem;
  }

  static String _buildProofId(String spotId, DateTime capturedAt) {
    final timestamp = capturedAt.toUtc().millisecondsSinceEpoch;
    return 'BP-$spotId-$timestamp';
  }

  static Future<void> saveAvatarPath(String imagePath) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_avatarPathKey, imagePath);
  }

  static Future<String?> getAvatarPath() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_avatarPathKey);
  }

  static Future<void> clearAvatarPath() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_avatarPathKey);
  }

  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_capturedIdsKey);
    await prefs.remove(_capturesKey);
    await prefs.remove(_avatarPathKey);
  }
}
