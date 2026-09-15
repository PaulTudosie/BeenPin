import 'dart:async';
import 'package:flutter/material.dart';
import '../features/auth/auth_scope.dart';
import '../services/capture_photo_storage.dart';

/// Photo-only recovery. Never enters the capture or reward creation flow.
class PendingCapturePhotosBanner extends StatefulWidget {
  const PendingCapturePhotosBanner({super.key});
  @override
  State<PendingCapturePhotosBanner> createState() =>
      _PendingCapturePhotosBannerState();
}

class _PendingCapturePhotosBannerState extends State<PendingCapturePhotosBanner>
    with WidgetsBindingObserver {
  final _storage = CapturePhotoStorage.instance;
  String? _owner;
  int _generation = 0;
  int _count = 0;
  bool _busy = false;
  String? _notice;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    CapturePhotoStorage.changes.addListener(_reload);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final owner = AuthScope.profileOf(context)?.id;
    if (owner != _owner) {
      _owner = owner;
      _generation++;
      _count = 0;
      _busy = false;
      _notice = null;
      _reload();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _reload();
  }

  void _reload() => unawaited(_load());

  Future<void> _load() async {
    final owner = _owner;
    final generation = _generation;
    if (owner == null) return;
    try {
      final pending = await _storage.pending(owner);
      if (mounted && generation == _generation) {
        setState(() => _count = pending.length);
      }
    } catch (error) {
      if (mounted && generation == _generation) {
        setState(
            () => _notice = CapturePhotoException.fromError(error).message);
      }
    }
  }

  Future<void> _retry() async {
    final owner = _owner;
    final generation = _generation;
    if (owner == null || _busy) return;
    setState(() {
      _busy = true;
      _notice = null;
    });
    try {
      final pending = await _storage.pending(owner);
      for (final photo in pending) {
        if (!mounted || generation != _generation) return;
        try {
          await _storage.retry(owner, photo.captureId);
        } catch (error) {
          if (!mounted || generation != _generation) return;
          setState(
              () => _notice = CapturePhotoException.fromError(error).message);
        }
      }
    } catch (error) {
      if (mounted && generation == _generation) {
        setState(
            () => _notice = CapturePhotoException.fromError(error).message);
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _busy = false);
        await _load();
      }
    }
  }

  @override
  void dispose() {
    _generation++;
    WidgetsBinding.instance.removeObserver(this);
    CapturePhotoStorage.changes.removeListener(_reload);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_count == 0 && _notice == null) return const SizedBox.shrink();
    return Material(
      color: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Row(children: [
          Expanded(
              child: Text(_notice ??
                  (_busy
                      ? 'Uploading capture photos…'
                      : '$_count capture photo${_count == 1 ? '' : 's'} waiting to upload.'))),
          if (_count > 0)
            TextButton(
                onPressed: _busy ? null : _retry,
                child: const Text('Retry Upload')),
          if (_count == 0)
            IconButton(
                tooltip: 'Dismiss',
                onPressed: () => setState(() => _notice = null),
                icon: const Icon(Icons.close)),
        ]),
      ),
    );
  }
}
