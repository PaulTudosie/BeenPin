import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/remote_capture.dart';

abstract class CaptureRepository {
  String? get currentUserId;
  Future<List<RemoteCapture>> getOwnCaptures();
  Future<RemoteCapture> createCapture({
    required String spotId,
    required double latitude,
    required double longitude,
    required String clientCaptureId,
  });
}

class CaptureException implements Exception {
  const CaptureException(this.code);
  final String code;

  String get message => switch (code) {
        'not_authenticated' => 'Sign in again to save your capture.',
        'invalid_client_capture_id' =>
          'Please close the camera and start a new capture.',
        'invalid_coordinates' =>
          'Location is unavailable. Close the camera and try again.',
        'spot_unavailable' => "This spot isn't available right now.",
        'already_captured' => "You've already Been here.",
        'outside_capture_radius' => 'Move closer to the spot to capture it.',
        'local_save_failed' =>
          'Saved online. Try again to save this photo on your device.',
        _ => "Couldn't save your capture. Try again.",
      };

  static CaptureException fromError(Object error) {
    if (error is CaptureException) return error;
    if (error is PostgrestException) {
      const known = {
        'not_authenticated',
        'invalid_client_capture_id',
        'invalid_coordinates',
        'spot_unavailable',
        'already_captured',
        'outside_capture_radius',
        'capture_retry_required',
      };
      if (known.contains(error.message)) return CaptureException(error.message);
      if (error.code == 'PGRST301' || error.code == '42501') {
        return const CaptureException('not_authenticated');
      }
    }
    return const CaptureException('capture_retry_required');
  }
}

class SupabaseCaptureRepository implements CaptureRepository {
  SupabaseCaptureRepository({SupabaseClient? client}) : _client = client;
  final SupabaseClient? _client;
  SupabaseClient get _supabase => _client ?? Supabase.instance.client;

  @override
  String? get currentUserId => _supabase.auth.currentUser?.id;

  String _requireOwner() {
    final owner = currentUserId;
    if (owner == null) throw const CaptureException('not_authenticated');
    return owner;
  }

  void _checkOwner(String owner) {
    if (currentUserId != owner) {
      throw const CaptureException('not_authenticated');
    }
  }

  @override
  Future<RemoteCapture> createCapture({
    required String spotId,
    required double latitude,
    required double longitude,
    required String clientCaptureId,
  }) async {
    try {
      final owner = _requireOwner();
      if (!RemoteCapture.isUuid(spotId)) {
        throw const CaptureException('spot_unavailable');
      }
      if (!RemoteCapture.isUuid(clientCaptureId)) {
        throw const CaptureException('invalid_client_capture_id');
      }
      if (!latitude.isFinite ||
          !longitude.isFinite ||
          latitude.abs() > 90 ||
          longitude.abs() > 180) {
        throw const CaptureException('invalid_coordinates');
      }
      final rows =
          await _supabase.schema('public').rpc('create_capture', params: {
        'p_spot_id': spotId,
        'p_latitude': latitude,
        'p_longitude': longitude,
        'p_client_capture_id': clientCaptureId,
      }).timeout(const Duration(seconds: 15));
      _checkOwner(owner);
      if (rows is! List || rows.length != 1) {
        throw const FormatException('Expected one capture');
      }
      final capture =
          RemoteCapture.fromJson(Map<String, dynamic>.from(rows.single as Map));
      if (capture.spotId != spotId ||
          capture.clientCaptureId != clientCaptureId) {
        throw const FormatException('Capture retry identity mismatch');
      }
      return capture;
    } catch (error) {
      throw CaptureException.fromError(error);
    }
  }

  @override
  Future<List<RemoteCapture>> getOwnCaptures() async {
    try {
      final owner = _requireOwner();
      final captures = <RemoteCapture>[];
      const pageSize = 500;
      for (var offset = 0;; offset += pageSize) {
        _checkOwner(owner);
        // RLS owns filtering. Select only the projection; never fetch geography.
        final rows = await _supabase
            .schema('public')
            .from('captures')
            .select(
              'capture_id:id,spot_id,client_capture_id,captured_at,distance_from_spot_m,'
              'spot_slug:spot_slug_snapshot,spot_name:spot_name_snapshot,photo_storage_path',
            )
            .order('captured_at', ascending: false)
            .order('id')
            .range(
              offset,
              offset + pageSize - 1,
            )
            .timeout(const Duration(seconds: 15));
        _checkOwner(owner);
        captures.addAll(rows.map(RemoteCapture.fromJson));
        if (rows.length < pageSize) break;
      }
      return captures;
    } catch (error) {
      throw CaptureException.fromError(error);
    }
  }
}
