import 'package:flutter/material.dart';
import 'package:been/core/theme/app_colors.dart';
import 'package:been/features/journey/journey_screen.dart';
import 'package:been/features/map/map_screen.dart';
import 'package:been/features/pins/pins_screen.dart';
import 'package:been/widgets/sub_header_tabs.dart';
import 'package:been/widgets/top_header.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  HomeTab _currentTab = HomeTab.map;

  void _onTabSelected(HomeTab tab) {
    if (_currentTab == tab) return;
    setState(() => _currentTab = tab);
  }

  int get _currentIndex {
    switch (_currentTab) {
      case HomeTab.map:
        return 0;
      case HomeTab.pins:
        return 1;
      case HomeTab.journey:
        return 2;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          TopHeader(
            onMenuTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Menu tapped')),
              );
            },
          ),
          SubHeaderTabs(
            currentTab: _currentTab,
            onTabSelected: _onTabSelected,
          ),
          Expanded(
            child: IndexedStack(
              index: _currentIndex,
              children: const [
                MapScreen(),
                PinsScreen(),
                JourneyScreen(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}