import 'dart:async';
import 'package:flutter/material.dart';
import 'package:been/core/theme/app_colors.dart';

/// Plays once when AuthGate mounts the authenticated app Navigator.
/// No authentication, persistence, or app lifecycle decisions belong here.
class BeenPinOpeningScreen extends StatefulWidget {
  const BeenPinOpeningScreen({super.key, required this.child});

  /// Existing app content, mounted only after the authenticated splash ends.
  final Widget child;

  @override
  State<BeenPinOpeningScreen> createState() => _BeenPinOpeningScreenState();
}

class _BeenPinOpeningScreenState extends State<BeenPinOpeningScreen>
    with TickerProviderStateMixin {
  static const String _pinPath = 'assets/branding/beenpin_pin.png';

  late final AnimationController _pinController;
  late final AnimationController _textController;

  late final Animation<double> _pinY;
  late final Animation<double> _pinScale;
  late final Animation<double> _textOpacity;
  late final Animation<Offset> _textSlide;

  bool _assetReady = false;
  bool _finished = false;

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

    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  Future<void> _start() async {
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

    await Future<void>.delayed(const Duration(milliseconds: 360));
    if (!mounted) return;

    setState(() => _finished = true);
  }

  @override
  void dispose() {
    _pinController.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_finished) return widget.child;
    return Scaffold(
      backgroundColor: Colors.white,
      body: AnimatedBuilder(
        animation: Listenable.merge([
          _pinController,
          _textController,
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
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0,
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
