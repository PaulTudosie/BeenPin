import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:been/core/theme/app_colors.dart';
import 'package:been/core/theme/app_spacing.dart';
import 'package:been/features/profile/user_profile_screen.dart';
import 'package:been/models/social_user.dart';
import 'package:been/services/capture_store.dart';
import 'package:been/services/engagement_store.dart';
import 'package:been/services/mock_social_service.dart';

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
                    TextSpan(
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
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
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
                      user: MockSocialService.userForCapture(captures[i], i),
                      allCaptures: captures,
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

  final String label;
  const _Reaction(String _, this.label);

  String get emoji => symbol;
}

extension _ReactionVisuals on _Reaction {
  String get symbol {
    switch (this) {
      case _Reaction.like:
        return '\u{1F44D}';
      case _Reaction.love:
        return '\u{1F499}';
      case _Reaction.wow:
        return '\u{2728}';
      case _Reaction.save:
        return '\u{1F4CD}';
      case _Reaction.fun:
        return '\u{1F604}';
    }
  }
}

class _PolaroidFeedCard extends StatefulWidget {
  final CaptureRecord record;
  final SocialUser user;
  final List<CaptureRecord> allCaptures;
  final VoidCallback onChanged;

  const _PolaroidFeedCard({
    required this.record,
    required this.user,
    required this.allCaptures,
    required this.onChanged,
  });

  @override
  State<_PolaroidFeedCard> createState() => _PolaroidFeedCardState();
}

class _PolaroidFeedCardState extends State<_PolaroidFeedCard> {
  _Reaction? _myReaction;
  CaptureEngagement? _engagement;

  @override
  void initState() {
    super.initState();
    _loadEngagement();
  }

  Future<void> _loadEngagement() async {
    final engagement =
        await EngagementStore.getEngagement(widget.record.spotId);
    if (!mounted) return;

    setState(() {
      _engagement = engagement;
      _myReaction =
          engagement.hasReacted ? (_myReaction ?? _Reaction.like) : null;
    });
  }

  Future<void> _toggleReaction(_Reaction r) async {
    final previousReaction = _myReaction;
    setState(() => _myReaction = (_myReaction == r) ? null : r);

    final engagement =
        await EngagementStore.toggleReaction(widget.record.spotId);
    if (!mounted) return;

    setState(() {
      _engagement = engagement;
      _myReaction = engagement.hasReacted ? r : null;
    });

    if (previousReaction != _myReaction) {
      widget.onChanged();
    }
  }

  void _onTap() {
    _toggleReaction(_Reaction.like);
  }

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
                          ? AppColors.brandBlue.withValues(alpha: 0.10)
                          : Colors.transparent,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      r.symbol,
                      style: TextStyle(fontSize: selected ? 28 : 24),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    r.label,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
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

  Future<void> _openComments() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _CommentsSheet(
        spotId: widget.record.spotId,
        spotName: widget.record.spotName,
      ),
    );

    if (!mounted) return;
    await _loadEngagement();
  }

  void _openProfile() {
    final userCaptures =
        MockSocialService.capturesForUser(widget.allCaptures, widget.user);

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => UserProfileScreen(
          user: widget.user,
          captures: userCaptures,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateText = DateFormat('dd MMM yyyy').format(widget.record.capturedAt);
    final engagement = _engagement;
    final reactionCount = engagement?.reactionCount ?? 0;
    final commentCount = engagement == null
        ? EngagementStore.demoSeedCommentCount
        : EngagementStore.displayCommentCount(engagement);

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
                        child: Center(
                          child: Text(
                            widget.user.name.substring(0, 1),
                            style: Theme.of(context)
                                .textTheme
                                .labelLarge
                                ?.copyWith(
                                  color: AppColors.brandBlue,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: InkWell(
                          onTap: _openProfile,
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Text(
                              widget.user.name,
                              style: Theme.of(context)
                                  .textTheme
                                  .labelLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.1,
                                    color: AppColors.textPrimary,
                                  ),
                            ),
                          ),
                        ),
                      ),
                      Text(
                        dateText,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
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
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.1,
                          color: AppColors.textPrimary,
                        ),
                  ),
                  Text(
                    widget.record.spotType,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
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
                                ? AppColors.brandBlue.withValues(alpha: 0.08)
                                : AppColors.surfaceSoft,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _myReaction?.symbol ?? '\u{1F44D}',
                                style: const TextStyle(fontSize: 14),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _myReaction == null
                                    ? '$reactionCount'
                                    : '${_myReaction!.label} $reactionCount',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: _myReaction == null
                                          ? AppColors.textMuted
                                          : AppColors.brandBlue,
                                    ),
                              ),
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
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.chat_bubble_outline_rounded,
                                size: 14,
                                color: AppColors.textMuted,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Comment $commentCount',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(color: AppColors.textMuted),
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
                            color: AppColors.amber.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '\u{1F4CD} Saved',
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
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

class _CommentsSheet extends StatefulWidget {
  final String spotId;
  final String spotName;

  const _CommentsSheet({
    required this.spotId,
    required this.spotName,
  });

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
      user: 'paul.wanders',
      text: 'Adding this to my list!',
    ),
  ];

  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  final TextEditingController _commentController = TextEditingController();
  late Future<CaptureEngagement> _engagementFuture;
  bool _isWritingComment = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _engagementFuture = EngagementStore.getEngagement(widget.spotId);
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submitComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty || _isSubmitting) return;

    setState(() => _isSubmitting = true);
    await EngagementStore.addComment(
      spotId: widget.spotId,
      text: text,
    );

    if (!mounted) return;

    _commentController.clear();
    setState(() {
      _engagementFuture = EngagementStore.getEngagement(widget.spotId);
      _isWritingComment = false;
      _isSubmitting = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.55,
      maxChildSize: 0.9,
      builder: (_, controller) => FutureBuilder<CaptureEngagement>(
        future: _engagementFuture,
        builder: (context, snapshot) {
          final localComments =
              snapshot.data?.comments ?? const <CaptureComment>[];

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Text(
                  widget.spotName,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  controller: controller,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  children: [
                    ..._CommentsSheet._comments.map(_CommentRow.mock),
                    ...localComments.map(_CommentRow.local),
                  ],
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
                child: _isWritingComment
                    ? Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _commentController,
                              autofocus: true,
                              minLines: 1,
                              maxLines: 3,
                              textInputAction: TextInputAction.send,
                              onSubmitted: (_) => _submitComment(),
                              decoration: InputDecoration(
                                hintText: 'Write your comment...',
                                filled: true,
                                fillColor: AppColors.surfaceSoft,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  borderSide: const BorderSide(
                                    color: AppColors.border,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  borderSide: const BorderSide(
                                    color: AppColors.border,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  borderSide: const BorderSide(
                                    color: AppColors.brandBlue,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton.filled(
                            onPressed: _isSubmitting ? null : _submitComment,
                            style: IconButton.styleFrom(
                              backgroundColor: AppColors.brandBlue,
                              foregroundColor: Colors.white,
                            ),
                            icon: _isSubmitting
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.send_rounded),
                          ),
                        ],
                      )
                    : InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () {
                          setState(() => _isWritingComment = true);
                        },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceSoft,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Text(
                            'Add a comment...',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: AppColors.textMuted),
                          ),
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

class _CommentRow extends StatelessWidget {
  final String avatar;
  final String user;
  final String text;

  const _CommentRow({
    required this.avatar,
    required this.user,
    required this.text,
  });

  factory _CommentRow.mock(_MockComment comment) {
    return _CommentRow(
      avatar: comment.avatar,
      user: comment.user,
      text: comment.text,
    );
  }

  factory _CommentRow.local(CaptureComment comment) {
    return _CommentRow(
      avatar: '\u{1F4AC}',
      user: comment.authorName,
      text: comment.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            avatar,
            style: const TextStyle(fontSize: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  text,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textPrimary,
                      ),
                ),
              ],
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.photo_library_outlined,
                size: 34,
                color: AppColors.textSecondary,
              ),
              const SizedBox(height: 12),
              Text(
                'No pins yet',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Capture your first spot from the map and it will appear here.',
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MockComment {
  final String _legacyAvatar;
  final String user;
  final String _legacyText;

  const _MockComment({
    required String avatar,
    required this.user,
    required String text,
  })  : _legacyAvatar = avatar,
        _legacyText = text;

  String get avatar {
    switch (user) {
      case 'andreea_explores':
        return '\u{1F9E1}';
      case 'mihai.urban':
        return '\u{1F499}';
      case 'paul.wanders':
        return '\u{1F49A}';
    }

    return _legacyAvatar;
  }

  String get text {
    if (user == 'andreea_explores') {
      return 'Love this spot! \u{1F60D}';
    }

    return _legacyText;
  }
}
