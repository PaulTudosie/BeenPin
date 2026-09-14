import 'package:flutter/foundation.dart';

import '../models/remote_capture.dart';
import '../models/spot.dart';
import 'capture_repository.dart';

/// Map state is remote-only, scoped to one auth identity and one load generation.
class CaptureState extends ChangeNotifier {
  CaptureState(this.repository);
  final CaptureRepository repository;
  String? userId;
  bool loading = false;
  bool loaded = false;
  String? error;
  Set<String> _spotIds = {};
  int _generation = 0;
  bool _disposed = false;

  Set<String> capturedLocalIds(List<Spot> spots) => spots
      .where(
          (spot) => spot.remoteId != null && _spotIds.contains(spot.remoteId))
      .map((spot) => spot.id)
      .toSet();

  Future<void> loadForUser(String? owner) async {
    final generation = ++_generation;
    if (userId != owner) {
      _spotIds = {};
      loaded = false;
    }
    userId = owner;
    error = null;
    loading = owner != null;
    notifyListeners();
    if (owner == null) return;
    try {
      if (repository.currentUserId != owner) {
        throw const CaptureException('not_authenticated');
      }
      final captures = await repository.getOwnCaptures();
      if (!_isCurrent(generation, owner)) return;
      _spotIds = captures.map((capture) => capture.spotId).toSet();
      loaded = true;
    } catch (_) {
      if (!_isCurrent(generation, owner)) return;
      error = 'Could not load your captures. Try again.';
    } finally {
      if (_isCurrent(generation, owner)) {
        loading = false;
        notifyListeners();
      }
    }
  }

  void accept(String owner, RemoteCapture capture) {
    if (_disposed || userId != owner || repository.currentUserId != owner) {
      return;
    }
    ++_generation; // A stale list response must not erase this acceptance.
    _spotIds = {..._spotIds, capture.spotId};
    loading = false;
    error = null;
    loaded = true;
    notifyListeners();
  }

  bool _isCurrent(int generation, String owner) =>
      !_disposed &&
      generation == _generation &&
      userId == owner &&
      repository.currentUserId == owner;

  @override
  void dispose() {
    _disposed = true;
    ++_generation;
    super.dispose();
  }
}
