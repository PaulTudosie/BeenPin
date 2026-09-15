import 'dart:async';
import 'package:flutter/foundation.dart';

import '../models/journey_capture.dart';
import 'capture_photo_storage.dart';
import 'journey_repository.dart';
import 'private_capture_photos.dart';

class JourneyController extends ChangeNotifier {
  JourneyController(
      {JourneyRepository? repository,
      PrivateCapturePhotos? photos,
      DateTime Function()? now})
      : repository = repository ?? JourneyRepository(),
        photos = photos ?? SupabasePrivateCapturePhotos(),
        _now = now ?? DateTime.now {
    CapturePhotoStorage.changes.addListener(_onCaptureChange);
  }
  final JourneyRepository repository;
  final PrivateCapturePhotos photos;
  final DateTime Function() _now;
  final Map<String, _PhotoUrl> _photoUrls = {};
  String? userId;
  List<JourneyCapture> items = const [];
  int get captureCount => items.length;
  bool loading = false;
  String? error;
  int _generation = 0;
  bool _disposed = false;
  Timer? _renewal;
  Timer? _changeDebounce;
  Future<void>? _activeLoad;
  bool _followUp = false;

  void _onCaptureChange() {
    // Queue writes can happen after the active query took its snapshot.
    if (_activeLoad != null) {
      _followUp = true;
      return;
    }
    _changeDebounce?.cancel();
    _changeDebounce = Timer(const Duration(milliseconds: 200), refresh);
  }

  Future<void> refresh({bool invalidatePhotos = false}) =>
      loadForUser(userId, invalidatePhotos: invalidatePhotos);

  Future<void> loadForUser(String? owner, {bool invalidatePhotos = false}) {
    if (_disposed) return Future.value();
    if (owner != userId) {
      ++_generation;
      _activeLoad = null;
      _followUp = false;
      _changeDebounce?.cancel();
      _renewal?.cancel();
      _photoUrls.clear();
      items = const [];
      userId = owner;
      error = null;
      loading = owner != null;
      notifyListeners();
    }
    if (owner == null) return Future.value();
    if (invalidatePhotos) {
      // Keep visible URLs in items until replacements are ready.
      _photoUrls.clear();
      if (_activeLoad != null) _followUp = true;
    }
    if (_activeLoad != null) return _activeLoad!;
    _changeDebounce?.cancel();
    _renewal?.cancel();
    final generation = ++_generation;
    final completion = Completer<void>();
    _activeLoad = completion.future;
    unawaited(_run(owner, generation).whenComplete(() {
      if (!_disposed && generation == _generation) {
        _activeLoad = null;
        _scheduleRenewal();
      }
      completion.complete();
    }));
    return completion.future;
  }

  bool _current(String owner, int generation) =>
      !_disposed &&
      generation == _generation &&
      userId == owner &&
      repository.currentUserId == owner;

  Future<void> _run(String owner, int generation) async {
    do {
      _followUp = false;
      await _load(owner, generation);
    } while (_current(owner, generation) && _followUp);
  }

  Future<void> _load(String owner, int generation) async {
    loading = items.isEmpty;
    error = null;
    notifyListeners();
    try {
      final loaded = await repository.load(owner);
      if (!_current(owner, generation)) return;
      final previous = {for (final item in items) item.id: item};
      final paths = loaded.map((item) => item.photoStoragePath).toSet();
      _photoUrls.removeWhere((path, _) => !paths.contains(path));
      items = List.unmodifiable(loaded.map((item) {
        final old = previous[item.id];
        final url = _photoUrls[item.photoStoragePath]?.url ??
            (old?.photoStoragePath == item.photoStoragePath
                ? old?.photoUrl
                : null);
        return item.withPhoto(url: url);
      }));
      loading = false;
      notifyListeners();
      var next = 0;
      Future<void> worker() async {
        while (_current(owner, generation) && next < loaded.length) {
          final index = next++;
          final item = items[index];
          final path = item.photoStoragePath;
          if (path == null) continue;
          final cached = _photoUrls[path];
          if (cached != null && _now().isBefore(cached.renewAt)) continue;
          JourneyCapture updated;
          try {
            final requestedAt = _now();
            final url = await photos.getUrl(owner, item.id, path);
            if (!_current(owner, generation)) return;
            _photoUrls[path] =
                _PhotoUrl(url, requestedAt.add(const Duration(minutes: 25)));
            updated = item.withPhoto(url: url);
          } catch (_) {
            updated = item.withPhoto(url: item.photoUrl, failed: true);
          }
          if (!_current(owner, generation)) return;
          items = List.unmodifiable([...items]..[index] = updated);
          notifyListeners();
        }
      }

      await Future.wait(List.generate(3, (_) => worker()));
    } catch (_) {
      if (!_current(owner, generation)) return;
      loading = false;
      error = 'Could not load your Journey. Please try again.';
      notifyListeners();
    }
  }

  void _scheduleRenewal() {
    _renewal?.cancel();
    if (userId == null) return;
    // Reopening the tab must not postpone the original URL expiry deadline.
    var delay = const Duration(minutes: 25);
    for (final cached in _photoUrls.values) {
      final remaining = cached.renewAt.difference(_now());
      if (remaining < delay) delay = remaining;
    }
    // Back off after a failed renewal instead of immediately retrying in a loop.
    if (delay < const Duration(minutes: 1)) delay = const Duration(minutes: 1);
    _renewal = Timer(delay, refresh);
  }

  @override
  void dispose() {
    _disposed = true;
    ++_generation;
    items = const [];
    userId = null;
    _photoUrls.clear();
    _renewal?.cancel();
    _changeDebounce?.cancel();
    CapturePhotoStorage.changes.removeListener(_onCaptureChange);
    super.dispose();
  }
}

class _PhotoUrl {
  const _PhotoUrl(this.url, this.renewAt);
  final String url;
  final DateTime renewAt;
}
