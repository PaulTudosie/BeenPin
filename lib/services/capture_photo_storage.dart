import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/remote_capture.dart';
import 'capture_store.dart';

class CapturePhotoException implements Exception {
  const CapturePhotoException(this.code);
  final String code;

  String get message => switch (code) {
        'not_authenticated' =>
          'Capture saved. Sign in to its account to retry the photo.',
        'capture_unavailable' =>
          'Capture saved, but this account cannot attach its photo.',
        'invalid_photo_path' =>
          'Capture saved. The photo could not be linked safely.',
        'photo_not_uploaded' =>
          'Capture saved. Please retry uploading the photo.',
        'photo_already_attached' =>
          'Capture saved with another photo. It has not been replaced.',
        'unsupported_photo' =>
          'Capture saved. This photo format is not supported.',
        'photo_too_large' =>
          'Capture saved. The photo exceeds the 15 MB upload limit.',
        'photo_missing' =>
          'Capture saved. The local photo is no longer available.',
        'photo_permission' =>
          'Capture saved. Photo upload was denied. Please try again later.',
        'photo_persistence' =>
          'Capture saved. Could not save the photo retry on this device.',
        _ => 'Capture saved. Photo upload did not finish. Please retry.',
      };

  static CapturePhotoException fromError(Object error) {
    if (error is CapturePhotoException) return error;
    if (error is PostgrestException) {
      const codes = {
        'not_authenticated',
        'capture_unavailable',
        'invalid_photo_path',
        'photo_not_uploaded',
        'photo_already_attached'
      };
      if (codes.contains(error.message)) {
        return CapturePhotoException(error.message);
      }
      if (error.code == '42501' || error.code == 'PGRST301') {
        return const CapturePhotoException('photo_permission');
      }
    }
    if (error is StorageException) {
      if (error.statusCode == '413' || error.error == 'EntityTooLarge') {
        return const CapturePhotoException('photo_too_large');
      }
      if (error.statusCode == '415' || error.error == 'InvalidMimeType') {
        return const CapturePhotoException('unsupported_photo');
      }
      if (error.statusCode == '401' ||
          error.statusCode == '403' ||
          error.error == 'AccessDenied') {
        return const CapturePhotoException('photo_permission');
      }
    }
    return const CapturePhotoException('photo_upload_failed');
  }
}

class CapturePhotoType {
  const CapturePhotoType(this.extension, this.mimeType);
  final String extension;
  final String mimeType;

  static Future<CapturePhotoType> inspect(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      throw const CapturePhotoException('photo_missing');
    }
    final size = await file.length();
    if (size > 15 * 1024 * 1024) {
      throw const CapturePhotoException('photo_too_large');
    }
    final handle = await file.open();
    final List<int> bytes;
    try {
      bytes = await handle.read(12);
    } finally {
      await handle.close();
    }
    final extension =
        path.split(RegExp(r'[/\\]')).last.split('.').last.toLowerCase();
    bool starts(List<int> signature) =>
        bytes.length >= signature.length &&
        List.generate(signature.length, (i) => bytes[i] == signature[i])
            .every((v) => v);
    if ((extension == 'jpg' || extension == 'jpeg') &&
        starts([0xff, 0xd8, 0xff])) {
      return const CapturePhotoType('jpg', 'image/jpeg');
    }
    if (extension == 'png' && starts([137, 80, 78, 71, 13, 10, 26, 10])) {
      return const CapturePhotoType('png', 'image/png');
    }
    if (extension == 'webp' &&
        starts([82, 73, 70, 70]) &&
        bytes.length >= 12 &&
        bytes[8] == 87 &&
        bytes[9] == 69 &&
        bytes[10] == 66 &&
        bytes[11] == 80) {
      return const CapturePhotoType('webp', 'image/webp');
    }
    throw const CapturePhotoException('unsupported_photo');
  }

  static String storagePath(String owner, String captureId, String extension) {
    if (!RemoteCapture.isUuid(owner) ||
        !RemoteCapture.isUuid(captureId) ||
        !{'jpg', 'jpeg', 'png', 'webp'}.contains(extension)) {
      throw const CapturePhotoException('invalid_photo_path');
    }
    return '${owner.toLowerCase()}/${captureId.toLowerCase()}/original.$extension';
  }
}

class PendingCapturePhoto {
  const PendingCapturePhoto(
      {required this.userId,
      required this.captureId,
      required this.localPath,
      this.storagePath,
      this.mimeType,
      this.uploaded = false});
  final String userId;
  final String captureId;
  final String localPath;
  final String? storagePath;
  final String? mimeType;
  final bool uploaded;

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'captureId': captureId,
        'localPath': localPath,
        'storagePath': storagePath,
        'mimeType': mimeType,
        'uploaded': uploaded,
      };
  factory PendingCapturePhoto.fromJson(Map<String, dynamic> json) =>
      PendingCapturePhoto(
          userId: json['userId'] as String,
          captureId: json['captureId'] as String,
          localPath: json['localPath'] as String,
          storagePath: json['storagePath'] as String?,
          mimeType: json['mimeType'] as String?,
          uploaded: json['uploaded'] == true);
}

abstract class CapturePhotos {
  Future<void> enqueue(String owner, String captureId, String localPath);
  Future<String> retry(String owner, String captureId);
}

abstract class CapturePhotoRemote {
  String? get currentUserId;
  Future<void> upload(PendingCapturePhoto photo);
  Future<String> attach(PendingCapturePhoto photo);
}

class SupabaseCapturePhotoRemote implements CapturePhotoRemote {
  SupabaseCapturePhotoRemote({SupabaseClient? client}) : _client = client;
  final SupabaseClient? _client;
  SupabaseClient get _supabase => _client ?? Supabase.instance.client;
  @override
  String? get currentUserId => _supabase.auth.currentUser?.id;

  String _token(String owner) {
    final session = _supabase.auth.currentSession;
    if (session == null || session.user.id != owner) {
      throw const CapturePhotoException('not_authenticated');
    }
    return session.accessToken;
  }

  @override
  Future<void> upload(PendingCapturePhoto photo) async {
    // Pin only this request to the initiating session. Never mutate shared
    // client headers or persist tokens. An in-flight request cannot become Abel's.
    final token = _token(photo.userId);
    await _supabase.storage
        .from('capture-photos')
        .setHeader('Authorization', 'Bearer $token')
        .upload(photo.storagePath!, File(photo.localPath),
            fileOptions:
                FileOptions(contentType: photo.mimeType!, upsert: true),
            retryAttempts: 0)
        .timeout(const Duration(seconds: 45));
  }

  @override
  Future<String> attach(PendingCapturePhoto photo) async {
    final token = _token(photo.userId);
    final rows = await _supabase
        .schema('public')
        .rpc('attach_capture_photo', params: {
          'p_capture_id': photo.captureId,
          'p_storage_path': photo.storagePath,
        })
        .setHeader('Authorization', 'Bearer $token')
        .timeout(const Duration(seconds: 15));
    if (rows is! List ||
        rows.length != 1 ||
        rows.single['capture_id'] != photo.captureId ||
        rows.single['photo_storage_path'] != photo.storagePath) {
      throw const CapturePhotoException('invalid_photo_path');
    }
    return rows.single['photo_storage_path'] as String;
  }
}

/// Durable, user-scoped photo queue. It never creates captures or grants rewards.
class CapturePhotoStorage implements CapturePhotos {
  CapturePhotoStorage({CapturePhotoRemote? remote})
      : remote = remote ?? SupabaseCapturePhotoRemote();
  static final instance = CapturePhotoStorage();
  static final changes = ValueNotifier<int>(0);
  final CapturePhotoRemote remote;
  final Map<String, Future<String>> _inFlight = {};
  static const _prefix = 'capture_photo_pending_v1:';
  String _key(String owner, String id) => '$_prefix$owner:$id';

  void _checkOwner(String owner) {
    if (remote.currentUserId != owner) {
      throw const CapturePhotoException('not_authenticated');
    }
  }

  Future<void> _write(PendingCapturePhoto photo) async {
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString(
        _key(photo.userId, photo.captureId), jsonEncode(photo.toJson()))) {
      throw const CapturePhotoException('photo_persistence');
    }
    changes.value++;
  }

  Future<List<PendingCapturePhoto>> pending(String owner) async {
    _checkOwner(owner);
    final prefs = await SharedPreferences.getInstance();
    _checkOwner(owner);
    final result = <PendingCapturePhoto>[];
    for (final key
        in prefs.getKeys().where((k) => k.startsWith('$_prefix$owner:'))) {
      final photo = PendingCapturePhoto.fromJson(
          jsonDecode(prefs.getString(key)!) as Map<String, dynamic>);
      if (photo.userId != owner || key != _key(owner, photo.captureId)) {
        throw const CapturePhotoException('invalid_photo_path');
      }
      result.add(photo);
    }
    return result;
  }

  @override
  Future<void> enqueue(String owner, String captureId, String localPath) async {
    _checkOwner(owner);
    if (!RemoteCapture.isUuid(owner) || !RemoteCapture.isUuid(captureId)) {
      throw const CapturePhotoException('invalid_photo_path');
    }
    final existing = await pending(owner);
    _checkOwner(owner);
    if (existing.any((p) => p.captureId == captureId)) return;
    // Persist before inspecting/reading the file and before any photo network IO.
    await _write(PendingCapturePhoto(
        userId: owner, captureId: captureId, localPath: localPath));
  }

  @override
  Future<String> retry(String owner, String captureId) {
    final key = _key(owner, captureId);
    _checkOwner(owner);
    return _inFlight[key] ??= _retry(owner, captureId).whenComplete(() {
      _inFlight.remove(key);
    });
  }

  Future<void> _remove(String owner, String id) async {
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.remove(_key(owner, id))) {
      throw const CapturePhotoException('photo_persistence');
    }
    changes.value++;
  }

  Future<String> _retry(String owner, String captureId) async {
    PendingCapturePhoto? attaching;
    try {
      final entries = await pending(owner);
      var photo = entries.where((p) => p.captureId == captureId).first;
      _checkOwner(owner);
      if (photo.storagePath == null) {
        final type = await CapturePhotoType.inspect(photo.localPath);
        _checkOwner(owner);
        photo = PendingCapturePhoto(
            userId: owner,
            captureId: captureId,
            localPath: photo.localPath,
            storagePath:
                CapturePhotoType.storagePath(owner, captureId, type.extension),
            mimeType: type.mimeType);
        await _write(photo);
      }
      final ext = photo.storagePath!.split('.').last;
      if (photo.storagePath !=
              CapturePhotoType.storagePath(owner, captureId, ext) ||
          photo.mimeType !=
              (ext == 'jpg' || ext == 'jpeg' ? 'image/jpeg' : 'image/$ext')) {
        throw const CapturePhotoException('invalid_photo_path');
      }
      if (!photo.uploaded) {
        final type = await CapturePhotoType.inspect(photo.localPath);
        if (type.mimeType != photo.mimeType ||
            (type.extension != ext &&
                !(type.extension == 'jpg' && ext == 'jpeg'))) {
          throw const CapturePhotoException('unsupported_photo');
        }
        _checkOwner(owner);
        await remote.upload(photo);
        _checkOwner(owner);
        photo = PendingCapturePhoto(
            userId: owner,
            captureId: captureId,
            localPath: photo.localPath,
            storagePath: photo.storagePath,
            mimeType: photo.mimeType,
            uploaded: true);
        await _write(photo);
      }
      _checkOwner(owner);
      attaching = photo;
      final path = await remote.attach(photo);
      _checkOwner(owner);
      if (path != photo.storagePath) {
        throw const CapturePhotoException('invalid_photo_path');
      }
      await CaptureStore.attachPhotoPath(owner, captureId, path);
      _checkOwner(owner);
      await _remove(owner, captureId);
      return path;
    } catch (error) {
      final failure = CapturePhotoException.fromError(error);
      if (failure.code == 'photo_not_uploaded' && attaching != null) {
        _checkOwner(owner);
        await _write(PendingCapturePhoto(
          userId: owner,
          captureId: captureId,
          localPath: attaching.localPath,
          storagePath: attaching.storagePath,
          mimeType: attaching.mimeType,
        ));
      }
      if (failure.code == 'photo_missing') {
        _checkOwner(owner);
        await _remove(owner, captureId);
      }
      throw failure;
    }
  }
}
