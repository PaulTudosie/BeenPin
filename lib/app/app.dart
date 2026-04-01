import 'package:flutter/material.dart';
import 'package:been/core/theme/app_theme.dart';
import 'package:been/app/opening/opening_screen.dart';

class BeenApp extends StatelessWidget {
  const BeenApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const BeenPinOpeningScreen(),
    );
  }
}