import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class HiddenCaptureRecord {
  final String spotId;
  final String spotName;
  final String imagePath;
  final DateTime discoveredAt;

  const HiddenCaptureRecord({
    required this.spotId,
    required this.spotName,
    required this.imagePath,
    required this.discoveredAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'spotId': spotId,
      'spotName': spotName,
      'imagePath': imagePath,
      'discoveredAt': discoveredAt.toIso8601String(),
    };
  }

  factory HiddenCaptureRecord.fromJson(Map<String, dynamic> json) {
    return HiddenCaptureRecord(
      spotId: json['spotId'] as String,
      spotName: json['spotName'] as String,
      imagePath: json['imagePath'] as String,
      discoveredAt: DateTime.parse(json['discoveredAt'] as String),
    );
  }
}

class HiddenCaptureStore {
  static const String _hiddenCapturesKey = 'hidden_captures';

  static Future<List<HiddenCaptureRecord>> getCaptures() async {
    final prefs = await SharedPreferences.getInstance();
    final rawList = prefs.getStringList(_hiddenCapturesKey) ?? [];

    final captures = rawList
        .map((item) => HiddenCaptureRecord.fromJson(
      jsonDecode(item) as Map<String, dynamic>,
    ))
        .toList();

    captures.sort((a, b) => b.discoveredAt.compareTo(a.discoveredAt));
    return captures;
  }

  static Future<void> saveCapture(HiddenCaptureRecord record) async {
    final prefs = await SharedPreferences.getInstance();
    final captures = await getCaptures();

    final existingIndex = captures.indexWhere((item) => item.spotId == record.spotId);

    if (existingIndex != -1) {
      captures[existingIndex] = record;
    } else {
      captures.add(record);
    }

    final encoded = captures.map((item) => jsonEncode(item.toJson())).toList();
    await prefs.setStringList(_hiddenCapturesKey, encoded);
  }

  static Future<bool> hasCapture(String spotId) async {
    final captures = await getCaptures();
    return captures.any((item) => item.spotId == spotId);
  }

  static Future<HiddenCaptureRecord?> getCaptureBySpotId(String spotId) async {
    final captures = await getCaptures();

    for (final capture in captures) {
      if (capture.spotId == spotId) {
        return capture;
      }
    }

    return null;
  }

  static Future<void> deleteCapture(String spotId) async {
    final prefs = await SharedPreferences.getInstance();
    final captures = await getCaptures()
      ..removeWhere((item) => item.spotId == spotId);

    final encoded = captures.map((item) => jsonEncode(item.toJson())).toList();
    await prefs.setStringList(_hiddenCapturesKey, encoded);
  }

  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_hiddenCapturesKey);
  }
}