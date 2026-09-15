import 'dart:io';

import '../models/journey_capture.dart';
import 'capture_repository.dart';
import 'capture_store.dart';

class JourneyRepository {
  JourneyRepository(
      {CaptureRepository? captures,
      Future<List<CaptureRecord>> Function(String)? localCaptures,
      Future<bool> Function(String)? fileExists})
      : captures = captures ?? SupabaseCaptureRepository(),
        _localCaptures = localCaptures ?? CaptureStore.getUserCaptures,
        _fileExists = fileExists ?? ((path) => File(path).exists());

  final CaptureRepository captures;
  final Future<List<CaptureRecord>> Function(String) _localCaptures;
  final Future<bool> Function(String) _fileExists;
  String? get currentUserId => captures.currentUserId;

  Future<List<JourneyCapture>> load(String owner) async {
    void checkOwner() {
      if (currentUserId != owner) {
        throw const CaptureException('not_authenticated');
      }
    }

    checkOwner();
    final rows = await captures.getOwnCaptures();
    checkOwner();
    // A corrupt/missing compatibility cache must never hide remote history.
    var locals = <CaptureRecord>[];
    try {
      locals = await _localCaptures(owner);
    } catch (_) {}
    checkOwner();
    final fallback = <String, String>{};
    final ids = rows.map((r) => r.id).toSet();
    for (final local in locals) {
      final id = local.remoteCaptureId;
      if (local.author.id != owner || id == null || !ids.contains(id)) continue;
      try {
        if (local.imagePath.isNotEmpty && await _fileExists(local.imagePath)) {
          fallback[id] = local.imagePath;
        }
      } catch (_) {}
    }
    checkOwner();
    final items = {
      for (final row in rows)
        row.id: JourneyCapture(
            id: row.id,
            spotId: row.spotId,
            spotSlug: row.spotSlug,
            spotName: row.spotName,
            capturedAt: row.capturedAt,
            photoStoragePath: row.photoStoragePath,
            localPhotoPathFallback: fallback[row.id])
    }.values.toList();
    items.sort((a, b) {
      final time = b.capturedAt.compareTo(a.capturedAt);
      return time == 0 ? a.id.compareTo(b.id) : time;
    });
    return items;
  }
}
