import 'package:supabase_flutter/supabase_flutter.dart';

import 'capture_photo_storage.dart';

abstract class PrivateCapturePhotos {
  Future<String> getUrl(String owner, String captureId, String storagePath);
}

/// Signs private URLs; JourneyController owns their user-scoped memory cache.
class SupabasePrivateCapturePhotos implements PrivateCapturePhotos {
  SupabasePrivateCapturePhotos({SupabaseClient? client}) : _client = client;
  final SupabaseClient? _client;
  SupabaseClient get _supabase => _client ?? Supabase.instance.client;
  static const lifetime = Duration(minutes: 30);

  @override
  Future<String> getUrl(
      String owner, String captureId, String storagePath) async {
    final session = _supabase.auth.currentSession;
    if (session == null || session.user.id != owner) {
      throw const CapturePhotoException('not_authenticated');
    }
    final extension = storagePath.split('.').last;
    if (storagePath !=
        CapturePhotoType.storagePath(owner, captureId, extension)) {
      throw const CapturePhotoException('invalid_photo_path');
    }
    final url = await _supabase.storage
        .from('capture-photos')
        .setHeader('Authorization', 'Bearer ${session.accessToken}')
        .createSignedUrl(storagePath, lifetime.inSeconds)
        .timeout(const Duration(seconds: 15));
    if (_supabase.auth.currentUser?.id != owner) {
      throw const CapturePhotoException('not_authenticated');
    }
    return url;
  }
}
