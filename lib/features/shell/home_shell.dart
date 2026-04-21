import 'package:flutter/material.dart';
import 'package:been/core/theme/app_colors.dart';
import 'package:been/features/hidden/hidden_spots_screen.dart';
import 'package:been/features/journey/journey_screen.dart';
import 'package:been/features/map/map_screen.dart';
import 'package:been/features/pins/pins_screen.dart';
import 'package:been/features/notifications/notifications_screen.dart';
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

  void _showMainMenu() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 14),
                _MenuRow(
                  icon: Icons.person_outline_rounded,
                  title: 'Account',
                  subtitle: 'Profile, follows, rewards, and settings',
                  onTap: () => _openMenuDialog(
                    context,
                    title: 'Account',
                    body:
                        'Account controls will include profile editing, follow history, rewards, and sign-in options.',
                  ),
                ),
                _MenuRow(
                  icon: Icons.mail_outline_rounded,
                  title: 'Contact',
                  subtitle: 'Partner, support, and feedback contact',
                  onTap: () => _openMenuDialog(
                    context,
                    title: 'Contact',
                    body:
                        'For the pilot demo, this can point partners and early users to contact@beenpin.app.',
                  ),
                ),
                _MenuRow(
                  icon: Icons.info_outline_rounded,
                  title: 'About BeenPin',
                  subtitle: 'What the app does and why it exists',
                  onTap: () => _openMenuDialog(
                    context,
                    title: 'About BeenPin',
                    body:
                        'BeenPin is an exploration photo game for discovering city pins, proving visits, and unlocking same-day local rewards.',
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openMenuDialog(
    BuildContext sheetContext, {
    required String title,
    required String body,
  }) {
    Navigator.of(sheetContext).pop();
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
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Use this before physical QR stickers are printed. It simulates scanning a hidden street code.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
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
          TopHeader(
            onMenuTap: _showMainMenu,
          ),
          Expanded(
            child: IndexedStack(
              index: _currentIndex,
              children: screens,
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: SubHeaderTabs(
          currentTab: _currentTab,
          onTabSelected: _onTabSelected,
        ),
      ),
    );
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
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
      ),
      subtitle: Text(
        spot.clue,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
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

class _MenuRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _MenuRow({
    required this.icon,
    required this.title,
    required this.subtitle,
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
        child: Icon(
          icon,
          color: AppColors.brandBlue,
        ),
      ),
      title: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
      ),
      subtitle: Text(
        subtitle,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
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
