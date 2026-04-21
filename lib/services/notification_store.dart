import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:been/models/app_notification.dart';

class NotificationStore {
  static const String _notificationsKey = 'app_notifications';

  static Future<List<AppNotification>> getNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_notificationsKey) ?? [];

    final notifications = raw
        .map((item) {
      try {
        return AppNotification.fromJson(item);
      } catch (_) {
        return null;
      }
    })
        .whereType<AppNotification>()
        .toList();

    notifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return notifications;
  }

  static Future<void> saveNotifications(List<AppNotification> items) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = items.map((e) => jsonEncode(e.toMap())).toList();
    await prefs.setStringList(_notificationsKey, encoded);
  }

  static Future<void> addNotification(AppNotification notification) async {
    final current = await getNotifications();
    current.insert(0, notification);
    await saveNotifications(current);
  }

  static Future<void> addReactionNotification({
    required String actorName,
    required String spotId,
    required String spotName,
    String? imagePath,
    required String reactionLabel,
  }) async {
    await addNotification(
      AppNotification(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        type: AppNotificationType.reaction,
        actorName: actorName,
        spotId: spotId,
        spotName: spotName,
        imagePath: imagePath,
        createdAt: DateTime.now(),
        isRead: false,
        message: '$actorName reacted with $reactionLabel to your spot "$spotName".',
      ),
    );
  }

  static Future<void> addCommentNotification({
    required String actorName,
    required String spotId,
    required String spotName,
    String? imagePath,
    required String commentText,
  }) async {
    await addNotification(
      AppNotification(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        type: AppNotificationType.comment,
        actorName: actorName,
        spotId: spotId,
        spotName: spotName,
        imagePath: imagePath,
        createdAt: DateTime.now(),
        isRead: false,
        message: '$actorName commented on your spot "$spotName": "$commentText"',
      ),
    );
  }

  static Future<void> markAllAsRead() async {
    final current = await getNotifications();
    final updated = current.map((e) => e.copyWith(isRead: true)).toList();
    await saveNotifications(updated);
  }

  static Future<void> markAsRead(String id) async {
    final current = await getNotifications();
    final updated = current
        .map((e) => e.id == id ? e.copyWith(isRead: true) : e)
        .toList();
    await saveNotifications(updated);
  }

  static Future<int> unreadCount() async {
    final current = await getNotifications();
    return current.where((e) => !e.isRead).length;
  }

  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_notificationsKey);
  }
}