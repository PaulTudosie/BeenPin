import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:been/features/shell/home_shell.dart';
import 'package:been/core/theme/app_colors.dart';

class BeenPinOpeningScreen extends StatefulWidget {
  const BeenPinOpeningScreen({super.key});

  @override
  State<BeenPinOpeningScreen> createState() => _BeenPinOpeningScreenState();
}

class _BeenPinOpeningScreenState extends State<BeenPinOpeningScreen>
    with TickerProviderStateMixin {
  static const String _pinPath = 'assets/branding/beenpin_pin.png';
  static const String _onboardedKey = 'opening_user_onboarded';
  static const String _identifierKey = 'opening_user_identifier';

  late final AnimationController _pinController;
  late final AnimationController _textController;
  late final AnimationController _loginController;

  late final Animation<double> _pinY;
  late final Animation<double> _pinScale;
  late final Animation<double> _textOpacity;
  late final Animation<Offset> _textSlide;
  late final Animation<double> _loginOpacity;
  late final Animation<Offset> _loginSlide;

  final TextEditingController _identifierController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _assetReady = false;
  bool _showLoginHero = false;
  bool _isSavingSession = false;
  String? _loginError;

  @override
  void initState() {
    super.initState();

    _pinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    );

    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );

    _loginController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
    );

    _pinY = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: -320, end: 0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 70,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0, end: -22)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 15,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: -22, end: 0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 15,
      ),
    ]).animate(_pinController);

    _pinScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.0),
        weight: 70,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.88)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 15,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.88, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 15,
      ),
    ]).animate(_pinController);

    _textOpacity = CurvedAnimation(
      parent: _textController,
      curve: Curves.easeOut,
    );

    _textSlide = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _textController,
      curve: Curves.easeOut,
    ));

    _loginOpacity = CurvedAnimation(
      parent: _loginController,
      curve: Curves.easeOut,
    );

    _loginSlide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _loginController,
      curve: Curves.easeOutCubic,
    ));

    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  Future<void> _start() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSavedSession = prefs.getBool(_onboardedKey) == true &&
        (prefs.getString(_identifierKey)?.trim().isNotEmpty ?? false);
    if (!mounted) return;

    await precacheImage(const AssetImage(_pinPath), context);
    if (!mounted) return;

    setState(() => _assetReady = true);

    // small delay so the widget rebuilds with the image before animating
    await Future<void>.delayed(const Duration(milliseconds: 40));
    if (!mounted) return;

    final pinDrop = _pinController.forward();
    if (!mounted) return;

    await Future<void>.delayed(const Duration(milliseconds: 640));
    if (!mounted) return;

    await _textController.forward();
    if (!mounted) return;

    await pinDrop;
    if (!mounted) return;

    if (!hasSavedSession) {
      setState(() => _showLoginHero = true);
      await _loginController.forward();
      return;
    }

    await Future<void>.delayed(const Duration(milliseconds: 360));
    if (!mounted) return;

    _openHome();
  }

  Future<void> _saveSessionAndEnter() async {
    final identifier = _identifierController.text.trim();
    final password = _passwordController.text.trim();

    if (identifier.isEmpty || password.isEmpty) {
      setState(() {
        _loginError = 'Add your username/email/phone and password to continue.';
      });
      return;
    }

    setState(() {
      _isSavingSession = true;
      _loginError = null;
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardedKey, true);
    await prefs.setString(_identifierKey, identifier);

    if (!mounted) return;
    _openHome();
  }

  void _openHome() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const HomeShell()),
    );
  }

  @override
  void dispose() {
    _pinController.dispose();
    _textController.dispose();
    _loginController.dispose();
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: AnimatedBuilder(
        animation: Listenable.merge([
          _pinController,
          _textController,
          _loginController,
        ]),
        builder: (context, _) {
          return SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 0,
                  vertical: 24,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Transform.translate(
                      offset: Offset(0, _assetReady ? _pinY.value : -320),
                      child: Transform.scale(
                        scale: _assetReady ? _pinScale.value : 1.0,
                        child: _assetReady
                            ? Image.asset(
                                _pinPath,
                                width: 96,
                                height: 96,
                                filterQuality: FilterQuality.high,
                              )
                            : const SizedBox(width: 96, height: 96),
                      ),
                    ),
                    const SizedBox(height: 12),
                    FadeTransition(
                      opacity: _textOpacity,
                      child: SlideTransition(
                        position: _textSlide,
                        child: RichText(
                          text: TextSpan(
                            style: Theme.of(context)
                                .textTheme
                                .displaySmall
                                ?.copyWith(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.5,
                                  height: 1.0,
                                ),
                            children: const [
                              TextSpan(
                                text: 'Been',
                                style: TextStyle(color: AppColors.brandBlue),
                              ),
                              TextSpan(
                                text: 'Pin',
                                style: TextStyle(color: AppColors.brandGreen),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (_showLoginHero) ...[
                      const SizedBox(height: 28),
                      FadeTransition(
                        opacity: _loginOpacity,
                        child: SlideTransition(
                          position: _loginSlide,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 28),
                            child: _LoginHeroSection(
                              identifierController: _identifierController,
                              passwordController: _passwordController,
                              isSaving: _isSavingSession,
                              errorText: _loginError,
                              onSubmit: _saveSessionAndEnter,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _LoginHeroSection extends StatelessWidget {
  final TextEditingController identifierController;
  final TextEditingController passwordController;
  final bool isSaving;
  final String? errorText;
  final VoidCallback onSubmit;

  const _LoginHeroSection({
    required this.identifierController,
    required this.passwordController,
    required this.isSaving,
    required this.errorText,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 360),
      child: Column(
        children: [
          Text(
            'Start collecting real places.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.2,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create your BeenPin session once. The app remembers you after this.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textMuted,
                  height: 1.35,
                ),
          ),
          const SizedBox(height: 18),
          _FadedLoginField(
            controller: identifierController,
            hintText: 'Username/email/phone',
            icon: Icons.person_outline_rounded,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 10),
          _FadedLoginField(
            controller: passwordController,
            hintText: 'Password',
            icon: Icons.lock_outline_rounded,
            obscureText: true,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => onSubmit(),
          ),
          if (errorText != null) ...[
            const SizedBox(height: 10),
            Text(
              errorText!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: isSaving ? null : onSubmit,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.textPrimary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppColors.textMuted,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Enter BeenPin'),
            ),
          ),
        ],
      ),
    );
  }
}

class _FadedLoginField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final IconData icon;
  final bool obscureText;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onSubmitted;

  const _FadedLoginField({
    required this.controller,
    required this.hintText,
    required this.icon,
    required this.textInputAction,
    this.obscureText = false,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      textInputAction: textInputAction,
      onSubmitted: onSubmitted,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w800,
          ),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textMuted.withValues(alpha: 0.72),
              fontWeight: FontWeight.w800,
            ),
        prefixIcon: Icon(
          icon,
          color: AppColors.textMuted.withValues(alpha: 0.68),
          size: 20,
        ),
        filled: true,
        fillColor: AppColors.surfaceSoft.withValues(alpha: 0.88),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: BorderSide(
            color: AppColors.border.withValues(alpha: 0.78),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: BorderSide(
            color: AppColors.border.withValues(alpha: 0.78),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: BorderSide(
            color: AppColors.brandBlue.withValues(alpha: 0.42),
            width: 1.4,
          ),
        ),
      ),
    );
  }
}
