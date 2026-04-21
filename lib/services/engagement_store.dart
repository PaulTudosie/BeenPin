import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class CaptureEngagement {
  final int reactionCount;
  final bool hasReacted;
  final List<CaptureComment> comments;

  const CaptureEngagement({
    required this.reactionCount,
    required this.hasReacted,
    required this.comments,
  });

  int get commentCount => comments.length;
}

class CaptureComment {
  final String authorName;
  final String text;
  final DateTime createdAt;

  const CaptureComment({
    required this.authorName,
    required this.text,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'authorName': authorName,
      'text': text,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory CaptureComment.fromJson(Map<String, dynamic> json) {
    return CaptureComment(
      authorName: json['authorName'] as String? ?? 'You',
      text: json['text'] as String? ?? '',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

class EngagementStore {
  static const int demoSeedCommentCount = 3;

  static const _reactionCountsKey = 'capture_reaction_counts';
  static const _reactedSpotIdsKey = 'capture_reacted_spot_ids';
  static const _commentsKey = 'capture_comments';

  static Future<CaptureEngagement> getEngagement(String spotId) async {
    final prefs = await SharedPreferences.getInstance();
    final counts = _decodeIntMap(prefs.getString(_reactionCountsKey));
    final reactedIds =
        (prefs.getStringList(_reactedSpotIdsKey) ?? <String>[]).toSet();
    final comments = _decodeComments(
          prefs.getString(_commentsKey),
        )[spotId] ??
        <CaptureComment>[];

    return CaptureEngagement(
      reactionCount: counts[spotId] ?? 0,
      hasReacted: reactedIds.contains(spotId),
      comments: comments,
    );
  }

  static Future<CaptureEngagement> toggleReaction(String spotId) async {
    final prefs = await SharedPreferences.getInstance();
    final counts = _decodeIntMap(prefs.getString(_reactionCountsKey));
    final reactedIds =
        (prefs.getStringList(_reactedSpotIdsKey) ?? <String>[]).toSet();

    if (reactedIds.contains(spotId)) {
      reactedIds.remove(spotId);
      final updatedCount = (counts[spotId] ?? 1) - 1;
      counts[spotId] = updatedCount < 0 ? 0 : updatedCount;
    } else {
      reactedIds.add(spotId);
      counts[spotId] = (counts[spotId] ?? 0) + 1;
    }

    await prefs.setString(_reactionCountsKey, jsonEncode(counts));
    await prefs.setStringList(_reactedSpotIdsKey, reactedIds.toList());

    return getEngagement(spotId);
  }

  static Future<CaptureEngagement> addComment({
    required String spotId,
    required String text,
    String authorName = 'You',
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return getEngagement(spotId);
    }

    final prefs = await SharedPreferences.getInstance();
    final allComments = _decodeComments(prefs.getString(_commentsKey));
    final comments = List<CaptureComment>.of(
      allComments[spotId] ?? const <CaptureComment>[],
    )..add(
        CaptureComment(
          authorName: authorName,
          text: trimmed,
          createdAt: DateTime.now(),
        ),
      );

    allComments[spotId] = comments;

    final encoded = allComments.map(
      (key, value) => MapEntry(
        key,
        value.map((comment) => comment.toJson()).toList(),
      ),
    );

    await prefs.setString(_commentsKey, jsonEncode(encoded));
    return getEngagement(spotId);
  }

  static int displayCommentCount(CaptureEngagement engagement) {
    return demoSeedCommentCount + engagement.commentCount;
  }

  static Map<String, int> _decodeIntMap(String? raw) {
    if (raw == null || raw.isEmpty) return <String, int>{};

    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) return <String, int>{};

    return decoded.map(
      (key, value) => MapEntry(key, (value as num?)?.toInt() ?? 0),
    );
  }

  static Map<String, List<CaptureComment>> _decodeComments(String? raw) {
    if (raw == null || raw.isEmpty) {
      return <String, List<CaptureComment>>{};
    }

    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      return <String, List<CaptureComment>>{};
    }

    return decoded.map((key, value) {
      final list = value is List<dynamic> ? value : const <dynamic>[];
      final comments = list
          .whereType<Map<String, dynamic>>()
          .map(CaptureComment.fromJson)
          .where((comment) => comment.text.isNotEmpty)
          .toList();

      return MapEntry(key, comments);
    });
  }
}
