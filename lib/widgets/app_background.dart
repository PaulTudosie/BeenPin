import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:been/core/theme/app_colors.dart';

class AppBackground extends StatelessWidget {
  final Widget child;

  const AppBackground({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: Container(color: AppColors.background),
        ),
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
        Positioned.fill(
          child: Opacity(
            opacity: 0.22,
            child: Image.asset(
              'assets/backgrounds/bg_minimal.png',
              fit: BoxFit.cover,
            ),
          ),
        ),
        Positioned.fill(
          child: Container(
            color: Colors.white.withValues(alpha: 0.07),
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
      ..color = const Color(0xFF000000).withValues(alpha: 0.012)
      ..style = PaintingStyle.fill;

    final lightPaint = Paint()
      ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.008)
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
