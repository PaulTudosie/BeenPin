import 'package:flutter/material.dart';
import 'package:been/core/theme/app_colors.dart';
import 'package:been/core/theme/app_spacing.dart';
import 'package:been/core/theme/app_typography.dart';
import 'package:been/features/hidden/hidden_spots_screen.dart';
import 'package:been/features/journey/journey_screen.dart';
import 'package:been/features/map/map_screen.dart';
import 'package:been/features/pins/pins_screen.dart';
import 'package:been/features/notifications/notifications_screen.dart';
import 'package:been/features/reward/my_rewards_screen.dart';
import 'package:been/models/hidden_spot.dart';
import 'package:been/services/hidden_capture_store.dart';
import 'package:been/services/hidden_spot_service.dart';
import 'package:been/widgets/app_background.dart';
import 'package:been/widgets/sub_header_tabs.dart';
import 'package:been/widgets/top_header.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  HomeTab _currentTab = HomeTab.map;
  final Map<HomeTab, int> _tabRefreshTick = {
    for (final tab in HomeTab.values) tab: 0,
  };

  void _markTabStale(HomeTab tab) {
    _tabRefreshTick[tab] = (_tabRefreshTick[tab] ?? 0) + 1;
  }

  void _onTabSelected(HomeTab tab) {
    if (_currentTab == tab) {
      if (tab == HomeTab.map) return;

      setState(() {
        _markTabStale(tab);
      });
      return;
    }

    setState(() {
      _currentTab = tab;

      if (tab != HomeTab.map) {
        _markTabStale(tab);
      }
    });
  }

  int get _currentIndex => HomeTab.values.indexOf(_currentTab);

  void _onHeaderMenuAction(HeaderMenuAction action) {
    if (action == HeaderMenuAction.myRewards) {
      Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => const MyRewardsScreen(),
      ));
      return;
    }
    final content = _HeaderMenuContent.forAction(action);

    _openMenuDialog(
      title: content.title,
      body: content.body,
    );
  }

  void _openMenuDialog({
    required String title,
    required String body,
  }) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showHiddenScanDemo() async {
    final hiddenSpot = await showModalBottomSheet<HiddenSpot>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Demo hidden QR scan',
                  style: context.appTextStyles.sectionTitle,
                ),
                const SizedBox(height: 6),
                Text(
                  'Use this before physical QR stickers are printed. It simulates scanning a hidden street code.',
                  style: context.appTextStyles.bodyText.copyWith(
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 14),
                ...HiddenSpotService.spots.map((spot) {
                  return _HiddenScanRow(
                    spot: spot,
                    onTap: () => Navigator.of(context).pop(spot),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );

    if (hiddenSpot == null) return;

    await HiddenCaptureStore.saveCapture(
      HiddenCaptureRecord(
        spotId: hiddenSpot.id,
        spotName: hiddenSpot.name,
        imagePath: '',
        discoveredAt: DateTime.now(),
      ),
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.surfaceElevated,
        content: Text(
          '${hiddenSpot.name} unlocked: ${hiddenSpot.rewardTitle}',
          style: const TextStyle(color: AppColors.textPrimary),
        ),
      ),
    );
  }

  List<Widget> _buildScreens() {
    return [
      KeyedSubtree(
        key: ValueKey('pins-${_tabRefreshTick[HomeTab.pins]}'),
        child: const AppBackground(
          child: PinsScreen(),
        ),
      ),
      KeyedSubtree(
        key: ValueKey('hidden-${_tabRefreshTick[HomeTab.hidden]}'),
        child: AppBackground(
          child: HiddenSpotsScreen(
            onScanTap: _showHiddenScanDemo,
          ),
        ),
      ),
      const MapScreen(),
      KeyedSubtree(
        key:
            ValueKey('notifications-${_tabRefreshTick[HomeTab.notifications]}'),
        child: const AppBackground(
          child: NotificationsScreen(),
        ),
      ),
      KeyedSubtree(
        key: ValueKey('journey-${_tabRefreshTick[HomeTab.journey]}'),
        child: const AppBackground(
          child: JourneyScreen(),
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final screens = _buildScreens();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _HeaderZone(
            identityText: _currentTab.identityText,
            onMenuAction: _onHeaderMenuAction,
          ),
          Expanded(
            child: IndexedStack(
              index: _currentIndex,
              children: screens,
            ),
          ),
        ],
      ),
      bottomNavigationBar: SubHeaderTabs(
        currentTab: _currentTab,
        onTabSelected: _onTabSelected,
      ),
    );
  }
}

class _HeaderZone extends StatelessWidget {
  final String identityText;
  final ValueChanged<HeaderMenuAction> onMenuAction;

  const _HeaderZone({
    required this.identityText,
    required this.onMenuAction,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(
            color: AppColors.border.withValues(alpha: 0.48),
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.025),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TopHeader(
            onMenuAction: onMenuAction,
          ),
          _ScreenIdentityRow(text: identityText),
        ],
      ),
    );
  }
}

class _ScreenIdentityRow extends StatelessWidget {
  final String text;

  const _ScreenIdentityRow({
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return SizedBox(
      height: isLandscape ? 25 : 29,
      child: Padding(
        padding: EdgeInsets.only(
          top: isLandscape ? 4 : 6,
          left: AppSpacing.lg,
          right: AppSpacing.lg,
        ),
        child: Center(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: AppTypography.fontFamily,
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: Color(0xFF6B7280),
              letterSpacing: 0,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }
}

class _HeaderMenuContent {
  final String title;
  final String body;

  const _HeaderMenuContent({
    required this.title,
    required this.body,
  });

  factory _HeaderMenuContent.forAction(HeaderMenuAction action) {
    switch (action) {
      case HeaderMenuAction.myRewards:
        throw StateError('My Rewards opens its own screen.');
      case HeaderMenuAction.account:
        return const _HeaderMenuContent(
          title: 'Account',
          body:
              'Account controls will include profile editing, follow history, rewards, and sign-in options.',
        );
      case HeaderMenuAction.partnerAccount:
        return const _HeaderMenuContent(
          title: 'Partner Account',
          body:
              'Partner login and campaign tools will be connected here when the partner portal is ready.',
        );
      case HeaderMenuAction.contact:
        return const _HeaderMenuContent(
          title: 'Contact',
          body:
              'For the pilot demo, this can point partners and early users to contact@beenpin.app.',
        );
      case HeaderMenuAction.aboutBeenPin:
        return const _HeaderMenuContent(
          title: 'About BeenPin',
          body:
              'BeenPin is an exploration photo game for discovering city pins, proving visits, and unlocking same-day local rewards.',
        );
    }
  }
}

class _HiddenScanRow extends StatelessWidget {
  final HiddenSpot spot;
  final VoidCallback onTap;

  const _HiddenScanRow({
    required this.spot,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: AppColors.tabActiveBg,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(
          Icons.qr_code_2_rounded,
          color: AppColors.brandBlue,
        ),
      ),
      title: Text(
        spot.name,
        style: context.appTextStyles.sectionTitle,
      ),
      subtitle: Text(
        spot.clue,
        style: context.appTextStyles.captionText.copyWith(
          color: AppColors.textSecondary,
        ),
      ),
      trailing: const Icon(
        Icons.chevron_right_rounded,
        color: AppColors.textMuted,
      ),
      onTap: onTap,
    );
  }
}
