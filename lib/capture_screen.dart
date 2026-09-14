import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:been/models/spot.dart';
import 'package:been/services/capture_draft.dart';
import 'package:been/services/capture_repository.dart';

class CaptureScreen extends StatefulWidget {
  final Spot spot;
  final CaptureDraft draft;

  const CaptureScreen({super.key, required this.spot, required this.draft});

  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen> {
  CameraController? _controller;
  Future<void>? _initFuture;
  String? _capturedPath;
  bool _saving = false;
  String? _saveError;

  @override
  void initState() {
    super.initState();
    _capturedPath = widget.draft.imagePath;
    if (_capturedPath == null) _init();
  }

  Future<void> _init() async {
    final cams = await availableCameras();
    final back = cams.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => cams.first,
    );

    _controller = CameraController(
      back,
      ResolutionPreset.high,
      enableAudio: false,
    );

    _initFuture = _controller!.initialize();
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _takePicture() async {
    final c = _controller;
    if (c == null || _initFuture == null) return;

    await _initFuture!;
    final file = await c.takePicture();

    if (!mounted) return;
    setState(() => _capturedPath = file.path);
  }

  void _retake() {
    setState(() => _capturedPath = null);
  }

  Future<void> _confirm() async {
    if (_saving) return;
    final path = _capturedPath;
    if (path == null) return;
    setState(() {
      _saving = true;
      _saveError = null;
    });
    try {
      final result = await widget.draft.submit(path);
      if (mounted) Navigator.of(context).pop(result);
    } catch (error) {
      if (mounted) {
        setState(() => _saveError = CaptureException.fromError(error).message);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_capturedPath != null) {
      return PopScope(
        canPop: !_saving,
        child: Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            fit: StackFit.expand,
            children: [
              Image.file(
                File(_capturedPath!),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(color: Colors.black),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 48,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _RoundButton(
                      icon: Icons.refresh_rounded,
                      label: 'Retake',
                      onTap: _saving || widget.draft.started ? null : _retake,
                    ),
                    _RoundButton(
                      icon: Icons.check_rounded,
                      label: _saving
                          ? 'Saving…'
                          : _saveError != null
                              ? 'Retry Been'
                              : 'Been ✅',
                      onTap: _saving ? null : _confirm,
                      primary: true,
                    ),
                  ],
                ),
              ),
              if (_saving) const Center(child: CircularProgressIndicator()),
              if (_saveError != null)
                Positioned(
                  left: 20,
                  right: 20,
                  bottom: 158,
                  child: Text(_saveError!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Colors.white,
                          backgroundColor: Colors.black87)),
                ),
            ],
          ),
        ),
      );
    }

    final c = _controller;
    return Scaffold(
      backgroundColor: Colors.black,
      body: (c == null || _initFuture == null)
          ? const Center(child: CircularProgressIndicator())
          : FutureBuilder<void>(
              future: _initFuture,
              builder: (_, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }

                return Stack(
                  fit: StackFit.expand,
                  children: [
                    CameraPreview(c),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 48,
                      child: Center(
                        child: GestureDetector(
                          onTap: _takePicture,
                          child: Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white,
                                width: 4,
                              ),
                            ),
                            child: Container(
                              margin: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool primary;

  const _RoundButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.primary = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: primary ? scheme.primary : Colors.white24,
            ),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
