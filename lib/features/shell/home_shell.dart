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
        // Base
        Positioned.fill(
          child: Container(
            color: AppColors.background,
          ),
        ),

        // Very light gradient (kept minimal)
        Positioned.fill(
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFFFFFFFF),
                  Color(0xFFF7FAFE),
                ],
              ),
            ),
          ),
        ),

        // 🔵 Stronger pattern (MAIN CHANGE)
        Positioned.fill(
          child: Opacity(
            opacity: 0.22, // was ~0.10–0.11 → now clearly visible
            child: Image.asset(
              'assets/backgrounds/bg_minimal.png',
              fit: BoxFit.cover,
            ),
          ),
        ),

        // ⚪ Reduced veil (SECOND CHANGE)
        Positioned.fill(
          child: Container(
            color: Colors.white.withOpacity(0.07), // was ~0.14 → now lighter
          ),
        ),

        // Grain (kept very subtle)
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
      ..color = const Color(0xFF000000).withOpacity(0.012)
      ..style = PaintingStyle.fill;

    final lightPaint = Paint()
      ..color = const Color(0xFFFFFFFF).withOpacity(0.008)
      ..style = PaintingStyle.fill;

    const double step = 16;

    for (double y = 0; y < size.height; y += step) {
      for (double x = 0; x < size.width; x += step) {
        final v1 = _hash(x, y);
        final v2 = _hash(x + 3.17, y + 7.91);

        if (v1 > 0.76) {
          final dx = x + (v1 * 6);
          final dy = y + (v2 * 6);
          canvas.drawCircle(
            Offset(dx, dy),
            0.5 + (v1 * 0.25),
            darkPaint,
          );
        }

        if (v2 > 0.84) {
          final dx = x + (v2 * 5);
          final dy = y + (v1 * 5);
          canvas.drawCircle(
            Offset(dx, dy),
            0.35 + (v2 * 0.2),
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