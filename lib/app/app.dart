import 'package:flutter/material.dart';
import 'package:been/app/opening/opening_screen.dart';
import 'package:been/core/theme/app_theme.dart';
import 'package:been/features/auth/auth_gate.dart';
import 'package:been/features/shell/home_shell.dart';

class BeenApp extends StatelessWidget {
  const BeenApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      builder: (context, child) => AuthGate(child: child!),
      home: const BeenPinOpeningScreen(child: HomeShell()),
    );
  }
}
