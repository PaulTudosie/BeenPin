import 'dart:math';

import '../models/app_profile.dart';
import '../models/remote_capture.dart';
import '../models/spot.dart';
import 'capture_repository.dart';
import 'capture_store.dart';

class CaptureCompletion {
  const CaptureCompletion(this.remote, this.local);
  final RemoteCapture remote;
  // Null for already_captured reconciliation: no photo/proof/reward fabrication.
  final CaptureRecord? local;
}

/// Lives with the camera route. Retries reuse identity, photo and GPS sample.
class CaptureDraft {
  CaptureDraft({
    required this.repository,
    required this.profile,
    required this.spot,
    required this.latitude,
    required this.longitude,
    required this.onAccepted,
    this.persist = CaptureStore.saveRemoteCapture,
  }) : clientCaptureId = _newUuid();

  final CaptureRepository repository;
  final AppProfile profile;
  final Spot spot;
  final double latitude;
  final double longitude;
  final void Function(RemoteCapture) onAccepted;
  final Future<CaptureRecord> Function({
    required AppProfile profile,
    required Spot spot,
    required RemoteCapture remote,
    required String imagePath,
    required double latitude,
    required double longitude,
  }) persist;
  final String clientCaptureId;
  String? _imagePath;
  RemoteCapture? _accepted;
  Future<CaptureCompletion>? _pending;
  CaptureCompletion? _completed;
  bool get started => _imagePath != null;
  String? get imagePath => _imagePath;

  Future<CaptureCompletion> submit(String imagePath) {
    if (_pending != null) return _pending!;
    _imagePath ??= imagePath;
    final pending = _save();
    _pending = pending;
    return pending.whenComplete(() => _pending = null);
  }

  void _checkOwner() {
    if (repository.currentUserId != profile.id) {
      throw const CaptureException('not_authenticated');
    }
  }

  Future<CaptureCompletion> _save() async {
    _checkOwner();
    if (_completed != null) return _completed!;
    if (_imagePath == null || _imagePath!.isEmpty) {
      throw const CaptureException('capture_retry_required');
    }
    if (spot.remoteId == null) throw const CaptureException('spot_unavailable');
    if (_accepted == null) {
      try {
        _accepted = await repository.createCapture(
          spotId: spot.remoteId!,
          latitude: latitude,
          longitude: longitude,
          clientCaptureId: clientCaptureId,
        );
      } catch (error) {
        final failure = CaptureException.fromError(error);
        if (failure.code != 'already_captured') throw failure;
        _checkOwner();
        final captures = await repository.getOwnCaptures();
        _checkOwner();
        final existing =
            captures.where((capture) => capture.spotId == spot.remoteId);
        if (existing.isEmpty) {
          throw const CaptureException('capture_retry_required');
        }
        onAccepted(existing.first);
        return _completed = CaptureCompletion(existing.first, null);
      }
    }
    _checkOwner();
    onAccepted(
        _accepted!); // Map updates even if the following local write fails.
    CaptureRecord local;
    try {
      local = await persist(
        profile: profile,
        spot: spot,
        remote: _accepted!,
        imagePath: _imagePath!,
        latitude: latitude,
        longitude: longitude,
      );
    } catch (_) {
      throw const CaptureException('local_save_failed');
    }
    _checkOwner();
    return _completed = CaptureCompletion(_accepted!, local);
  }

  static String _newUuid() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-'
        '${hex.substring(16, 20)}-${hex.substring(20)}';
  }
}
