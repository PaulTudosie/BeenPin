import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:been/core/theme/app_colors.dart';
import 'package:been/core/theme/app_spacing.dart';
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
    await _notificationsFuture;
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

  List<_NotificationSection> _buildSections(
    List<AppNotification> notifications,
  ) {
    final sections = <_NotificationSection>[];

    for (final item in notifications) {
      final title = _sectionTitle(item.createdAt);

      if (sections.isEmpty || sections.last.title != title) {
        sections.add(_NotificationSection(title: title, items: [item]));
      } else {
        sections.last.items.add(item);
      }
    }

    return sections;
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
            color: AppColors.brandBlue,
            backgroundColor: AppColors.surface,
            child: const _EmptyNotificationsState(),
          );
        }

        final unreadCount = notifications.where((item) => !item.isRead).length;
        final sections = _buildSections(notifications);

        return RefreshIndicator(
          onRefresh: _refresh,
          color: AppColors.brandBlue,
          backgroundColor: AppColors.surface,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.md,
              AppSpacing.xl,
              120,
            ),
            children: [
              _NotificationsHeader(
                totalCount: notifications.length,
                unreadCount: unreadCount,
                onMarkAllRead: unreadCount == 0 ? null : _markAllAsRead,
              ),
              const SizedBox(height: AppSpacing.md),
              ...sections.map((section) {
                return _NotificationSectionCard(
                  section: section,
                  iconForType: _iconForType,
                  onNotificationTap: _openNotificationTarget,
                );
              }),
            ],
          ),
        );
      },
    );
  }
}

class _NotificationSection {
  final String title;
  final List<AppNotification> items;

  _NotificationSection({
    required this.title,
    required this.items,
  });
}

class _NotificationsHeader extends StatelessWidget {
  final int totalCount;
  final int unreadCount;
  final VoidCallback? onMarkAllRead;

  const _NotificationsHeader({
    required this.totalCount,
    required this.unreadCount,
    required this.onMarkAllRead,
  });

  @override
  Widget build(BuildContext context) {
    final isCaughtUp = unreadCount == 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.97),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: AppColors.border.withValues(alpha: 0.68),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 16,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color:
                  isCaughtUp ? AppColors.successSoftBg : AppColors.tabActiveBg,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: isCaughtUp
                    ? AppColors.successSoftBorder
                    : AppColors.brandBlue.withValues(alpha: 0.08),
              ),
            ),
            child: Icon(
              isCaughtUp
                  ? Icons.check_circle_rounded
                  : Icons.notifications_active_rounded,
              color: isCaughtUp ? AppColors.brandGreen : AppColors.brandBlue,
              size: 21,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isCaughtUp ? 'All caught up' : '$unreadCount unread',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.3,
                      ),
                ),
                const SizedBox(height: 3),
                Text(
                  '$totalCount update${totalCount == 1 ? '' : 's'} from your captures',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          TextButton(
            onPressed: onMarkAllRead,
            style: TextButton.styleFrom(
              backgroundColor: onMarkAllRead == null
                  ? AppColors.surfaceSoft
                  : AppColors.tabActiveBg.withValues(alpha: 0.86),
              foregroundColor: onMarkAllRead == null
                  ? AppColors.textMuted
                  : AppColors.brandBlue,
              disabledForegroundColor: AppColors.textMuted.withValues(
                alpha: 0.64,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Mark read'),
          ),
        ],
      ),
    );
  }
}

class _NotificationSectionCard extends StatelessWidget {
  final _NotificationSection section;
  final IconData Function(AppNotificationType type) iconForType;
  final ValueChanged<AppNotification> onNotificationTap;

  const _NotificationSectionCard({
    required this.section,
    required this.iconForType,
    required this.onNotificationTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 3, bottom: 8),
            child: Text(
              section.title,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.16,
                  ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(alpha: 0.99),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: AppColors.border.withValues(alpha: 0.68),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.035),
                  blurRadius: 16,
                  offset: const Offset(0, 7),
                ),
              ],
            ),
            child: Column(
              children: [
                for (var index = 0; index < section.items.length; index++) ...[
                  _NotificationTile(
                    item: section.items[index],
                    icon: iconForType(section.items[index].type),
                    onTap: () => onNotificationTap(section.items[index]),
                  ),
                  if (index != section.items.length - 1)
                    Divider(
                      height: 1,
                      indent: 74,
                      color: AppColors.border.withValues(alpha: 0.66),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
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
    final isUnread = !item.isRead;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 13, 12, 13),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isUnread
                          ? AppColors.tabActiveBg
                          : AppColors.surfaceSoft,
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color: isUnread
                            ? AppColors.brandBlue.withValues(alpha: 0.12)
                            : AppColors.border.withValues(alpha: 0.7),
                      ),
                    ),
                    child: Icon(
                      icon,
                      size: 19,
                      color:
                          isUnread ? AppColors.brandBlue : AppColors.textMuted,
                    ),
                  ),
                  if (isUnread)
                    Positioned(
                      right: -2,
                      top: -2,
                      child: Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(
                          color: AppColors.brandGreen,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.surface,
                            width: 1.8,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            item.actorName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .labelLarge
                                ?.copyWith(
                                  color: AppColors.textPrimary,
                                  fontWeight: isUnread
                                      ? FontWeight.w900
                                      : FontWeight.w700,
                                  letterSpacing: -0.15,
                                ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _timeAgo(item.createdAt),
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: AppColors.textMuted,
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.message,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                            height: 1.35,
                          ),
                    ),
                    const SizedBox(height: 7),
                    Row(
                      children: [
                        const Icon(
                          Icons.place_rounded,
                          size: 14,
                          color: AppColors.brandGreen,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            item.spotName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                  color: AppColors.brandGreen,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.1,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              if (hasImage)
                _NotificationThumb(
                  imagePath: item.imagePath!,
                  fallbackIcon: icon,
                )
              else
                _ThumbFallback(icon: icon),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotificationThumb extends StatelessWidget {
  final String imagePath;
  final IconData fallbackIcon;

  const _NotificationThumb({
    required this.imagePath,
    required this.fallbackIcon,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(15),
      child: Image.file(
        File(imagePath),
        width: 52,
        height: 52,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _ThumbFallback(icon: fallbackIcon),
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
        color: AppColors.surfaceSoft,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: AppColors.border.withValues(alpha: 0.68),
        ),
      ),
      child: Icon(
        icon,
        size: 19,
        color: AppColors.textMuted,
      ),
    );
  }
}

class _EmptyNotificationsState extends StatelessWidget {
  const _EmptyNotificationsState();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.xxxl,
        AppSpacing.xl,
        120,
      ),
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(22, 26, 22, 26),
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.97),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(
              color: AppColors.border.withValues(alpha: 0.68),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 16,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: AppColors.tabActiveBg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.notifications_none_rounded,
                  size: 30,
                  color: AppColors.brandBlue,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'No notifications yet',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.35,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Reactions and comments on captured spots will appear here.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
