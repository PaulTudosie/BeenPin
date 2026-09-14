import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:been/models/spot.dart';
import 'package:been/services/spot_service.dart';
import 'package:been/models/social_user.dart';
import 'package:been/services/current_user_profile.dart';
import 'package:been/models/app_profile.dart';
import 'package:been/models/remote_capture.dart';

class CaptureRecord {
  final SocialUser author;
  final String spotId;
  final String spotName;
  final String spotType;
  final String imagePath;
  final DateTime capturedAt;
  final double? userLatitude;
  final double? userLongitude;
  final double? distanceMeters;
  final String? proofId;
  final String? remoteCaptureId;
  final String? remoteSpotId;
  final String? clientCaptureId;

  const CaptureRecord({
    required this.author,
    required this.spotId,
    required this.spotName,
    required this.spotType,
    required this.imagePath,
    required this.capturedAt,
    this.userLatitude,
    this.userLongitude,
    this.distanceMeters,
    this.proofId,
    this.remoteCaptureId,
    this.remoteSpotId,
    this.clientCaptureId,
  });

  Map<String, dynamic> toJson() {
    return {
      'author': author.toJson(),
      'spotId': spotId,
      'spotName': spotName,
      'spotType': spotType,
      'imagePath': imagePath,
      'capturedAt': capturedAt.toIso8601String(),
      'userLatitude': userLatitude,
      'userLongitude': userLongitude,
      'distanceMeters': distanceMeters,
      'proofId': proofId,
      if (remoteCaptureId != null) 'remoteCaptureId': remoteCaptureId,
      if (remoteSpotId != null) 'remoteSpotId': remoteSpotId,
      if (clientCaptureId != null) 'clientCaptureId': clientCaptureId,
    };
  }

  factory CaptureRecord.fromJson(Map<String, dynamic> json) {
    final spotName = json['spotName'] as String? ?? '';
    final storedSpotId = json['spotId'] as String?;
    final spotId = storedSpotId != null && storedSpotId.trim().isNotEmpty
        ? storedSpotId.trim()
        : SpotService.resolveSpotId(spotName: spotName) ?? spotName;

    return CaptureRecord(
      author: json['author'] == null
          ? CurrentUserProfile.user
          : SocialUser.fromJson(json['author'] as Map<String, dynamic>),
      spotId: spotId,
      spotName: spotName,
      spotType: json['spotType'] as String? ?? '',
      imagePath: json['imagePath'] as String,
      capturedAt: DateTime.parse(json['capturedAt'] as String),
      userLatitude: (json['userLatitude'] as num?)?.toDouble(),
      userLongitude: (json['userLongitude'] as num?)?.toDouble(),
      distanceMeters: (json['distanceMeters'] as num?)?.toDouble(),
      proofId: json['proofId'] as String?,
      remoteCaptureId: json['remoteCaptureId'] as String?,
      remoteSpotId: json['remoteSpotId'] as String?,
      clientCaptureId: json['clientCaptureId'] as String?,
    );
  }
}

class CaptureStore {
  static const _capturedIdsKey = 'captured_spot_ids';
  static const _capturesKey = 'capture_records';
  static const _avatarPathKey = 'journey_avatar_path';
  static const _userBioKey = 'journey_user_bio';

  // Legacy methods/keys below remain available for manual reconciliation.
  // Authenticated screens exclusively use this separate compatibility store.
  static String _userKey(String key, String userId) => '$key:$userId';
  static Future<void>? _pendingRemoteSave;

  static Future<List<CaptureRecord>> getUserCaptures(String? userId) async {
    if (userId == null) return [];
    final prefs = await SharedPreferences.getInstance();
    final raw =
        prefs.getStringList(_userKey('capture_records_v2', userId)) ?? [];
    final records = raw
        .map((entry) => CaptureRecord.fromJson(
              jsonDecode(entry) as Map<String, dynamic>,
            ))
        .where((entry) => entry.author.id == userId)
        .toList();
    records.sort((a, b) => b.capturedAt.compareTo(a.capturedAt));
    return records;
  }

  static Future<CaptureRecord> saveRemoteCapture({
    required AppProfile profile,
    required Spot spot,
    required RemoteCapture remote,
    required String imagePath,
    required double latitude,
    required double longitude,
  }) {
    final previous = _pendingRemoteSave ?? Future<void>.value();
    final result = previous.then((_) async {
      if (remote.spotId != spot.remoteId) {
        throw StateError('Capture spot mismatch');
      }
      final prefs = await SharedPreferences.getInstance();
      final records = await getUserCaptures(profile.id);
      final existing = records.where((r) => r.remoteCaptureId == remote.id);
      if (existing.isNotEmpty) return existing.first;
      final record = CaptureRecord(
        author: SocialUser(
          id: profile.id,
          name: profile.displayName,
          city: '',
          levelName: '',
          handle: '@${profile.username}',
          avatarPath: prefs.getString(_userKey(_avatarPathKey, profile.id)),
          tagline: profile.bio ?? '',
        ),
        spotId: spot.id,
        spotName: remote.spotName,
        spotType: spot.type,
        imagePath: imagePath,
        capturedAt: remote.capturedAt.toLocal(),
        userLatitude: latitude,
        userLongitude: longitude,
        distanceMeters: remote.distanceFromSpotMeters,
        proofId: _buildProofId(spot.id, remote.capturedAt),
        remoteCaptureId: remote.id,
        remoteSpotId: remote.spotId,
        clientCaptureId: remote.clientCaptureId,
      );
      records.insert(0, record);
      if (!await prefs.setStringList(
        _userKey('capture_records_v2', profile.id),
        records.map((r) => jsonEncode(r.toJson())).toList(),
      )) {
        throw StateError('Could not persist capture');
      }
      return record;
    });
    final gate =
        result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    _pendingRemoteSave = gate;
    return result.whenComplete(() {
      if (identical(_pendingRemoteSave, gate)) _pendingRemoteSave = null;
    });
  }

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
    var migrated = false;
    final items = raw.map((value) {
      final json = jsonDecode(value) as Map<String, dynamic>;
      // Before authors were stored, every record was a local Journey capture.
      // Persist the backfill so future profile changes cannot reassign ownership.
      if (json['author'] == null) {
        json['author'] = CurrentUserProfile.snapshot(
          avatarPath: prefs.getString(_avatarPathKey),
        ).toJson();
        migrated = true;
      }
      return CaptureRecord.fromJson(json);
    }).toList();
    if (migrated) {
      await prefs.setStringList(
        _capturesKey,
        items.map((item) => jsonEncode(item.toJson())).toList(),
      );
    }

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

    final existing = await getCaptures();

    existing.removeWhere((item) => item.spotId == spot.id);

    final capturedAt = DateTime.now();
    final newItem = CaptureRecord(
      author: CurrentUserProfile.snapshot(
        avatarPath: prefs.getString(_avatarPathKey),
      ),
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

  static Future<void> saveAvatarPath(String imagePath, {String? userId}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        userId == null ? _avatarPathKey : _userKey(_avatarPathKey, userId),
        imagePath);
  }

  static Future<String?> getAvatarPath({String? userId}) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(
        userId == null ? _avatarPathKey : _userKey(_avatarPathKey, userId));
  }

  static Future<void> clearAvatarPath() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_avatarPathKey);
  }

  static Future<void> saveUserBio(String bio, {String? userId}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        userId == null ? _userBioKey : _userKey(_userBioKey, userId), bio);
  }

  static Future<String?> getUserBio({String? userId}) async {
    final prefs = await SharedPreferences.getInstance();
    final bio = prefs.getString(
        userId == null ? _userBioKey : _userKey(_userBioKey, userId));
    if (bio == null) return null;

    final trimmed = bio.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_capturedIdsKey);
    await prefs.remove(_capturesKey);
    await prefs.remove(_avatarPathKey);
    await prefs.remove(_userBioKey);
  }
}
