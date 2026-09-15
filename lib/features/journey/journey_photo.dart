import 'dart:io';
import 'package:flutter/material.dart';
import 'package:been/core/theme/app_colors.dart';
import 'package:been/models/journey_capture.dart';

class JourneyPhoto extends StatefulWidget {
  const JourneyPhoto(
      {super.key, required this.capture, this.fit = BoxFit.cover});
  final JourneyCapture capture;
  final BoxFit fit;

  @override
  State<JourneyPhoto> createState() => _JourneyPhotoState();
}

class _JourneyPhotoState extends State<JourneyPhoto> {
  bool _hasRemoteFrame = false;

  @override
  void didUpdateWidget(JourneyPhoto oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.capture.id != widget.capture.id ||
        oldWidget.capture.photoStoragePath != widget.capture.photoStoragePath) {
      _hasRemoteFrame = false;
    }
  }

  Widget _fallback() {
    final path = widget.capture.localPhotoPathFallback;
    if (path != null) {
      return Image.file(File(path),
          fit: widget.fit,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) => _placeholder());
    }
    return _placeholder();
  }

  Widget _placeholder() => Container(
      color: AppColors.surfaceSoft,
      alignment: Alignment.center,
      child: const Icon(Icons.image_not_supported_outlined,
          color: AppColors.textSecondary, size: 28));

  @override
  Widget build(BuildContext context) {
    final url = widget.capture.photoUrl;
    return Stack(fit: StackFit.expand, children: [
      // This image stays mounted, including before the first network chunk.
      _fallback(),
      if (url != null)
        Positioned.fill(
            child: Image.network(
          url,
          key: ValueKey((widget.capture.id, widget.capture.photoStoragePath)),
          fit: widget.fit,
          gaplessPlayback: true,
          frameBuilder: (_, child, frame, synchronous) {
            if (frame != null || synchronous) _hasRemoteFrame = true;
            // On URL renewal gaplessPlayback retains the previously decoded
            // frame. On first load the local layer stays visible until decode.
            return _hasRemoteFrame ? child : const SizedBox.shrink();
          },
          errorBuilder: (_, __, ___) {
            _hasRemoteFrame = false;
            return const SizedBox.shrink();
          },
        )),
    ]);
  }
}
