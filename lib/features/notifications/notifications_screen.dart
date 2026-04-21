import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:been/core/theme/app_colors.dart';
import 'package:been/features/spot/spot_detail_screen.dart';
import 'package:been/models/app_notification.dart';
import 'package:been/models/spot.dart';
import 'package:been/services/notification_store.dart';
import 'package:been/services/spot_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late Future<List<AppNotification>> _notificationsFuture;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _notificationsFuture = NotificationStore.getNotifications();
  }

  Future<void> _refresh() async {
    setState(_load);
  }

  Future<void> _markAllAsRead() async {
    await NotificationStore.markAllAsRead();
    setState(_load);
  }

  String _sectionTitle(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final value = DateTime(date.year, date.month, date.day);

    if (value == today) return 'Today';
    if (value == yesterday) return 'Yesterday';
    return DateFormat('d MMMM').format(date);
  }

  IconData _iconForType(AppNotificationType type) {
    switch (type) {
      case AppNotificationType.comment:
        return Icons.chat_bubble_rounded;
      case AppNotificationType.reaction:
        return Icons.favorite_rounded;
    }
  }

  Spot? _spotForNotification(AppNotification item) {
    final spots = SpotService.getSpots();

    for (final spot in spots) {
      if (spot.id == item.spotId) return spot;
    }

    for (final spot in spots) {
      if (spot.name == item.spotName) return spot;
    }

    return null;
  }

  Future<void> _openNotificationTarget(AppNotification item) async {
    if (!item.isRead) {
      await NotificationStore.markAsRead(item.id);
      setState(_load);
    }

    final spot = _spotForNotification(item);
    if (!mounted) return;

    if (spot == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.surfaceElevated,
          content: Text(
            'This captured spot is no longer available.',
            style: TextStyle(color: AppColors.textPrimary),
          ),
        ),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SpotDetailScreen(
          spot: spot,
          isCaptured: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<AppNotification>>(
      future: _notificationsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final notifications = snapshot.data ?? [];

        if (notifications.isEmpty) {
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 32, 20, 120),
              children: [
                const SizedBox(height: 40),
                Icon(
                  Icons.notifications_none_rounded,
                  size: 56,
                  color: AppColors.textMuted,
                ),
                const SizedBox(height: 16),
                Text(
                  'No notifications yet',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Reactions and comments on captured spots will appear here.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.45,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          );
        }

        String? lastHeader;

        return RefreshIndicator(
          onRefresh: _refresh,
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
            itemCount: notifications.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                final unread = notifications.where((e) => !e.isRead).length;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          unread > 0
                              ? '$unread unread notification${unread == 1 ? '' : 's'}'
                              : 'All caught up',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: _markAllAsRead,
                        child: const Text('Mark all read'),
                      ),
                    ],
                  ),
                );
              }

              final item = notifications[index - 1];
              final section = _sectionTitle(item.createdAt);
              final showHeader = section != lastHeader;
              lastHeader = section;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (showHeader) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 10, bottom: 10),
                      child: Text(
                        section,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                  _NotificationTile(
                    item: item,
                    icon: _iconForType(item.type),
                    onTap: () => _openNotificationTarget(item),
                  ),
                  const SizedBox(height: 10),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final AppNotification item;
  final IconData icon;
  final VoidCallback onTap;

  const _NotificationTile({
    required this.item,
    required this.icon,
    required this.onTap,
  });

  String _timeAgo(DateTime value) {
    final diff = DateTime.now().difference(value);

    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = item.imagePath != null && item.imagePath!.isNotEmpty;

    return Material(
      color: item.isRead ? AppColors.surface : AppColors.surfaceSoft,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: item.isRead
                  ? AppColors.surfaceSoft
                  : AppColors.brandGreen.withValues(alpha: 0.18),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.brandBlue.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: AppColors.brandBlue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.actorName,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        Text(
                          _timeAgo(item.createdAt),
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.message,
                      style: TextStyle(
                        fontSize: 13.5,
                        height: 1.4,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      item.spotName,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.brandGreen,
                      ),
                    ),
                  ],
                ),
              ),
              if (hasImage) ...[
                const SizedBox(width: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    File(item.imagePath!),
                    width: 52,
                    height: 52,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _ThumbFallback(icon: icon),
                  ),
                ),
              ],
              if (!hasImage) ...[
                const SizedBox(width: 12),
                _ThumbFallback(icon: icon),
              ],
              if (!item.isRead) ...[
                const SizedBox(width: 8),
                Container(
                  width: 10,
                  height: 10,
                  margin: const EdgeInsets.only(top: 6),
                  decoration: const BoxDecoration(
                    color: AppColors.brandGreen,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ThumbFallback extends StatelessWidget {
  final IconData icon;

  const _ThumbFallback({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: AppColors.bgPaper,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        icon,
        color: AppColors.textMuted,
      ),
    );
  }
}
