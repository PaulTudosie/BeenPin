import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:been/core/theme/app_colors.dart';
import 'package:been/core/theme/app_spacing.dart';
import 'package:been/services/capture_store.dart';

class PinsScreen extends StatefulWidget {
  const PinsScreen({super.key});

  @override
  State<PinsScreen> createState() => _PinsScreenState();
}

class _PinsScreenState extends State<PinsScreen> {
  late Future<List<CaptureRecord>> _capturesFuture;

  @override
  void initState() {
    super.initState();
    _capturesFuture = CaptureStore.getCaptures();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.transparent,
      child: FutureBuilder<List<CaptureRecord>>(
        future: _capturesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final captures = snapshot.data ?? [];

          if (captures.isEmpty) {
            return const _EmptyPinsState();
          }

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xl,
                    AppSpacing.xl,
                    AppSpacing.xl,
                    AppSpacing.sm,
                  ),
                  child: Text.rich(
                    const TextSpan(
                      children: [
                        TextSpan(
                          text: 'Where others have ',
                          style: TextStyle(
                            color: AppColors.textMuted,
                          ),
                        ),
                        TextSpan(
                          text: 'Been',
                          style: TextStyle(
                            color: AppColors.brandBlue,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  AppSpacing.sm,
                  AppSpacing.xl,
                  AppSpacing.xxxl,
                ),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                        (context, i) => _PolaroidFeedCard(
                      record: captures[i],
                      onChanged: () => setState(() {
                        _capturesFuture = CaptureStore.getCaptures();
                      }),
                    ),
                    childCount: captures.length,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

enum _Reaction {
  like('👍', 'Like'),
  love('💙', 'Love'),
  wow('✨', 'Wow'),
  save('📍', 'Save'),
  fun('😄', 'Fun');

  final String emoji;
  final String label;
  const _Reaction(this.emoji, this.label);
}

class _PolaroidFeedCard extends StatefulWidget {
  final CaptureRecord record;
  final VoidCallback onChanged;

  const _PolaroidFeedCard({
    required this.record,
    required this.onChanged,
  });

  @override
  State<_PolaroidFeedCard> createState() => _PolaroidFeedCardState();
}

class _PolaroidFeedCardState extends State<_PolaroidFeedCard> {
  _Reaction? _myReaction;

  void _toggleReaction(_Reaction r) {
    setState(() => _myReaction = (_myReaction == r) ? null : r);
    widget.onChanged();
  }

  void _onTap() => _toggleReaction(_Reaction.like);

  void _onLongPress() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black26,
      builder: (_) => Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 48),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: _Reaction.values.map((r) {
            final selected = _myReaction == r;
            return GestureDetector(
              onTap: () {
                Navigator.pop(context);
                _toggleReaction(r);
              },
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.brandBlue.withOpacity(0.10)
                          : Colors.transparent,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      r.emoji,
                      style: TextStyle(fontSize: selected ? 28 : 24),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    r.label,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: selected
                          ? AppColors.brandBlue
                          : AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  void _openComments() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _CommentsSheet(spotName: widget.record.spotName),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateText =
    DateFormat('dd MMM yyyy').format(widget.record.capturedAt);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 10,
              offset: Offset(2, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 4),
              child: AspectRatio(
                aspectRatio: 1.0,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    File(widget.record.imagePath),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: AppColors.border,
                      child: const Icon(
                        Icons.image_not_supported_rounded,
                        color: AppColors.textMuted,
                        size: 40,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: AppColors.avatarBg,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.person_rounded,
                          size: 16,
                          color: AppColors.brandBlue,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'You',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.1,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      Text(
                        dateText,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    widget.record.spotName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.1,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    widget.record.spotType,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: _onTap,
                        onLongPress: _onLongPress,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: _myReaction != null
                                ? AppColors.brandBlue.withOpacity(0.08)
                                : AppColors.surfaceSoft,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _myReaction?.emoji ?? '👍',
                                style: const TextStyle(fontSize: 14),
                              ),
                              if (_myReaction != null) ...[
                                const SizedBox(width: 4),
                                Text(
                                  _myReaction!.label,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.brandBlue,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: _openComments,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceSoft,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: AppColors.buttonSecondaryBorder,
                            ),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.chat_bubble_outline_rounded,
                                size: 14,
                                color: AppColors.textMuted,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Comment',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (_myReaction == _Reaction.save) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.amber.withOpacity(0.10),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            '📍 Saved',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.amber,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CommentsSheet extends StatelessWidget {
  final String spotName;
  const _CommentsSheet({required this.spotName});

  static const List<_MockComment> _comments = [
    _MockComment(
      avatar: '🧡',
      user: 'andreea_explores',
      text: 'Love this spot! 😍',
    ),
    _MockComment(
      avatar: '💙',
      user: 'mihai.urban',
      text: 'Been there last summer, incredible.',
    ),
    _MockComment(
      avatar: '💚',
      user: 'irina.wanders',
      text: 'Adding this to my list!',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.55,
      maxChildSize: 0.9,
      builder: (_, controller) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Text(
              spotName,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              controller: controller,
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              itemCount: _comments.length,
              itemBuilder: (_, i) {
                final c = _comments[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        c.avatar,
                        style: const TextStyle(fontSize: 20),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              c.user,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              c.text,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              8,
              16,
              MediaQuery.of(context).viewInsets.bottom + 12,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: AppColors.surfaceSoft,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
              ),
              child: const Text(
                'Add a comment...',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textMuted,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyPinsState extends StatelessWidget {
  const _EmptyPinsState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.xl),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.border),
          ),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.photo_library_outlined,
                size: 34,
                color: AppColors.textSecondary,
              ),
              SizedBox(height: 12),
              Text(
                'No pins yet',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Capture your first spot from the map and it will appear here.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MockComment {
  final String avatar;
  final String user;
  final String text;

  const _MockComment({
    required this.avatar,
    required this.user,
    required this.text,
  });
}