import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:been/core/theme/app_colors.dart';
import 'package:been/features/hidden/hidden_spots_screen.dart';
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
      case HomeTab.hidden:
        return 2;
      case HomeTab.journey:
        return 3;
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
                SnackBar(
                  backgroundColor: AppColors.surfaceElevated,
                  content: Text(
                    'Menu tapped',
                    style: TextStyle(color: AppColors.textPrimary),
                  ),
                ),
              );
            },
          ),
          Expanded(
            child: IndexedStack(
              index: _currentIndex,
              children: [
                const MapScreen(),
                const _DecoratedBackground(
                  child: PinsScreen(),
                ),
                _DecoratedBackground(
                  child: HiddenSpotsScreen(
                    onScanTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: AppColors.surfaceElevated,
                          content: Text(
                            'Hidden QR scan flow will be added next',
                            style: TextStyle(color: AppColors.textPrimary),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const _DecoratedBackground(
                  child: JourneyScreen(),
                ),
              ],
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

class _DecoratedBackground extends StatelessWidget {
  final Widget child;

  const _DecoratedBackground({
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: Container(
            color: AppColors.background,
          ),
        ),
        Positioned.fill(
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFFFDFEFF),
                  Color(0xFFF8FAFC),
                ],
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: Opacity(
            opacity: 0.055,
            child: Image.asset(
              'assets/backgrounds/bg_minimal.png',
              fit: BoxFit.cover,
            ),
          ),
        ),
        const Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: _NoiseGrainPainter(),
            ),
          ),
        ),
        Positioned.fill(child: child),
      ],
    );
  }
}

class _NoiseGrainPainter extends CustomPainter {
  const _NoiseGrainPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final darkPaint = Paint()
      ..color = const Color(0xFF000000).withOpacity(0.020)
      ..style = PaintingStyle.fill;

    final lightPaint = Paint()
      ..color = const Color(0xFFFFFFFF).withOpacity(0.012)
      ..style = PaintingStyle.fill;

    const double step = 14;

    for (double y = 0; y < size.height; y += step) {
      for (double x = 0; x < size.width; x += step) {
        final v1 = _hash(x, y);
        final v2 = _hash(x + 3.17, y + 7.91);

        if (v1 > 0.72) {
          final dx = x + (v1 * 6);
          final dy = y + (v2 * 6);
          canvas.drawCircle(
            Offset(dx, dy),
            0.55 + (v1 * 0.35),
            darkPaint,
          );
        }

        if (v2 > 0.80) {
          final dx = x + (v2 * 5);
          final dy = y + (v1 * 5);
          canvas.drawCircle(
            Offset(dx, dy),
            0.4 + (v2 * 0.25),
            lightPaint,
          );
        }
      }
    }
  }

  double _hash(double x, double y) {
    final v = math.sin((x * 12.9898) + (y * 78.233)) * 43758.5453;
    return v - v.floorToDouble();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}