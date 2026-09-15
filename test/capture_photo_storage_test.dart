import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:been/services/capture_draft.dart';
import 'package:been/services/capture_photo_storage.dart';
import 'package:been/services/capture_store.dart';
import 'package:been/services/reward_selection_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'captures_integration_test.dart' as fixtures;

class PhotoRemoteFake implements CapturePhotoRemote {
  @override
  String? currentUserId = fixtures.ownerA;
  Object? uploadFailure;
  Object? attachFailure;
  Completer<void>? uploadWait;
  final uploads = <PendingCapturePhoto>[];
  final attachments = <PendingCapturePhoto>[];
  final events = <String>[];

  @override
  Future<void> upload(PendingCapturePhoto photo) async {
    events.add('upload');
    uploads.add(photo);
    if (uploadWait != null) await uploadWait!.future;
    if (uploadFailure != null) throw uploadFailure!;
  }

  @override
  Future<String> attach(PendingCapturePhoto photo) async {
    events.add('attach');
    attachments.add(photo);
    if (attachFailure != null) throw attachFailure!;
    return photo.storagePath!;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late File jpeg;
  late PhotoRemoteFake remote;
  late CapturePhotoStorage storage;
  const owner = fixtures.ownerA;
  const id = fixtures.captureUuid;
  const path = '$owner/$id/original.jpg';

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    directory = await Directory.systemTemp.createTemp('beenpin-photo-test-');
    jpeg = await File('${directory.path}/camera.jpg')
        .writeAsBytes([255, 216, 255, 224, 0, 0]);
    remote = PhotoRemoteFake();
    storage = CapturePhotoStorage(remote: remote);
  });
  tearDown(() async {
    for (final entity in directory.listSync()) {
      await entity.delete();
    }
    await directory.delete();
  });

  CaptureDraft draft(fixtures.FakeCaptures repo) => CaptureDraft(
      repository: repo,
      photos: storage,
      profile: fixtures.profile,
      spot: fixtures.spot(),
      latitude: 44.45,
      longitude: 26.08,
      onAccepted: (_) {});

  Matcher failure(String code) =>
      throwsA(isA<CapturePhotoException>().having((e) => e.code, 'code', code));

  test('path contains auth and server capture UUIDs, never username or spot',
      () {
    expect(CapturePhotoType.storagePath(owner, id, 'jpg'), path);
    expect(path, isNot(contains(fixtures.profile.username)));
    expect(path, isNot(contains(fixtures.spotUuid)));
    expect(() => CapturePhotoType.storagePath('username', id, 'jpg'),
        failure('invalid_photo_path'));
    expect(() => CapturePhotoType.storagePath(owner, id, 'gif'),
        failure('invalid_photo_path'));
  });

  test('JPEG signature and jpg/jpeg suffix normalize to jpg with JPEG MIME',
      () async {
    final type = await CapturePhotoType.inspect(jpeg.path);
    expect(type.extension, 'jpg');
    expect(type.mimeType, 'image/jpeg');
    final other = await jpeg.copy('${directory.path}/image.JPEG');
    expect((await CapturePhotoType.inspect(other.path)).extension, 'jpg');
  });

  test('PNG and WebP require matching signatures and MIME', () async {
    final png = await File('${directory.path}/photo.png')
        .writeAsBytes([137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 0]);
    final webp = await File('${directory.path}/photo.webp')
        .writeAsBytes([82, 73, 70, 70, 0, 0, 0, 0, 87, 69, 66, 80]);
    expect((await CapturePhotoType.inspect(png.path)).mimeType, 'image/png');
    expect((await CapturePhotoType.inspect(webp.path)).mimeType, 'image/webp');
    await storage.enqueue(owner, id, png.path);
    expect(await storage.retry(owner, id), '$owner/$id/original.png');
    expect(remote.uploads.single.mimeType, 'image/png');
  });

  test('unsupported suffix and disguised non-JPEG content are rejected',
      () async {
    final gif = await jpeg.copy('${directory.path}/image.gif');
    await expectLater(
        CapturePhotoType.inspect(gif.path), failure('unsupported_photo'));
    await jpeg.writeAsBytes([137, 80, 78, 71, 13, 10, 26, 10]);
    await expectLater(
        CapturePhotoType.inspect(jpeg.path), failure('unsupported_photo'));
  });

  test('file too large is recoverable without upload', () async {
    final handle = await jpeg.open(mode: FileMode.append);
    await handle.truncate(15 * 1024 * 1024 + 1);
    await handle.close();
    await storage.enqueue(owner, id, jpeg.path);
    await expectLater(storage.retry(owner, id), failure('photo_too_large'));
    expect(remote.uploads, isEmpty);
    expect(await storage.pending(owner), hasLength(1));
  });

  test('queue saved before upload; success uploads then attaches and clears it',
      () async {
    remote.uploadWait = Completer<void>();
    await storage.enqueue(owner, id, jpeg.path);
    final first = storage.retry(owner, id);
    final second = storage.retry(owner, id);
    // Let file IO and SharedPreferences complete.
    while (remote.uploads.isEmpty) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    expect((await storage.pending(owner)).single.storagePath, path);
    expect(identical(first, second), isTrue);
    remote.uploadWait!.complete();
    expect(await first, path);
    expect(await second, path);
    expect(remote.events, ['upload', 'attach']);
    expect(await storage.pending(owner), isEmpty);
  });

  test(
      'upload failure preserves valid capture/local data; retry creates no capture or reward',
      () async {
    remote.uploadFailure = TimeoutException('network');
    final repo = fixtures.FakeCaptures();
    final attempt = draft(repo);
    await expectLater(
        attempt.submit(jpeg.path), failure('photo_upload_failed'));
    expect(attempt.accepted, isTrue);
    expect(await CaptureStore.getUserCaptures(owner), hasLength(1));
    expect(await RewardSelectionStore.getUserRewards(), isEmpty);
    expect(repo.attempts, hasLength(1));
    expect(remote.attachments, isEmpty);
    remote.uploadFailure = null;
    final result = await attempt.submit('ignored-new-file.jpg');
    expect(repo.attempts, hasLength(1));
    expect(remote.uploads.map((p) => p.storagePath).toSet(), {path});
    expect(result.remote.photoStoragePath, path);
    expect(result.local!.photoStoragePath, path);
    expect((await CaptureStore.getUserCaptures(owner)).single.photoStoragePath,
        path);
    expect(attempt.claimRewardTransition(), isTrue);
    expect(attempt.claimRewardTransition(), isFalse);
    await attempt.submit(jpeg.path);
    expect(attempt.claimRewardTransition(), isFalse);
    expect(await RewardSelectionStore.getUserRewards(), isEmpty);
  });

  test(
      'lost attach reply survives restart and retries only attachment at same path',
      () async {
    remote.attachFailure = TimeoutException('lost reply');
    await storage.enqueue(owner, id, jpeg.path);
    await expectLater(storage.retry(owner, id), failure('photo_upload_failed'));
    expect((await storage.pending(owner)).single.uploaded, isTrue);
    final prefs = await SharedPreferences.getInstance();
    SharedPreferences.setMockInitialValues(
        {for (final k in prefs.getKeys()) k: prefs.get(k)!});
    storage = CapturePhotoStorage(remote: remote);
    remote.attachFailure = null;
    await jpeg
        .delete(); // An uploaded photo can still attach after cache eviction.
    expect(await storage.retry(owner, id), path);
    expect(remote.uploads, hasLength(1));
    expect(remote.attachments.map((p) => p.storagePath), [path, path]);
    expect(await storage.pending(owner), isEmpty);
  });

  test('upload timeout survives restart and upserts same key', () async {
    remote.uploadFailure = TimeoutException('ambiguous upload');
    await storage.enqueue(owner, id, jpeg.path);
    await expectLater(storage.retry(owner, id), failure('photo_upload_failed'));
    storage = CapturePhotoStorage(remote: remote);
    remote.uploadFailure = null;
    await storage.retry(owner, id);
    expect(remote.uploads.map((p) => p.storagePath), [path, path]);
  });

  test('missing server object after upload permits re-upload at the same key',
      () async {
    remote.attachFailure =
        const PostgrestException(message: 'photo_not_uploaded');
    await storage.enqueue(owner, id, jpeg.path);
    await expectLater(storage.retry(owner, id), failure('photo_not_uploaded'));
    expect((await storage.pending(owner)).single.uploaded, isFalse);
    remote.attachFailure = null;
    await storage.retry(owner, id);
    expect(remote.uploads.map((p) => p.storagePath), [path, path]);
  });

  test(
      'photo_already_attached does not replace local remote identity or clear retry',
      () async {
    remote.attachFailure =
        const PostgrestException(message: 'photo_already_attached');
    final attempt = draft(fixtures.FakeCaptures());
    await expectLater(
        attempt.submit(jpeg.path), failure('photo_already_attached'));
    expect((await CaptureStore.getUserCaptures(owner)).single.photoStoragePath,
        isNull);
    expect((await storage.pending(owner)).single.storagePath, path);
    remote.attachFailure = null;
    await attempt.submit(jpeg.path);
    expect(remote.uploads, hasLength(1));
  });

  test('pending records are user-scoped and cannot execute as another account',
      () async {
    await storage.enqueue(owner, id, jpeg.path);
    remote.currentUserId = fixtures.ownerB;
    expect(await storage.pending(fixtures.ownerB), isEmpty);
    expect(() => storage.retry(owner, id), failure('not_authenticated'));
    await storage.enqueue(fixtures.ownerB, id, jpeg.path);
    expect((await storage.pending(fixtures.ownerB)).single.userId,
        fixtures.ownerB);
    remote.currentUserId = owner;
    expect((await storage.pending(owner)).single.localPath, jpeg.path);
    expect(remote.events, isEmpty);
  });

  test('account switch while upload runs never attaches under new account',
      () async {
    remote.uploadWait = Completer<void>();
    await storage.enqueue(owner, id, jpeg.path);
    final operation = storage.retry(owner, id);
    final expectation = expectLater(operation, failure('not_authenticated'));
    while (remote.uploads.isEmpty) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
    remote.currentUserId = fixtures.ownerB;
    remote.uploadWait!.complete();
    await expectation;
    expect(remote.attachments, isEmpty);
    expect(await storage.pending(fixtures.ownerB), isEmpty);
    remote.currentUserId = owner;
    expect(await storage.pending(owner), hasLength(1));
  });

  test('missing local file clears pending without deleting capture', () async {
    remote.uploadFailure = TimeoutException('offline');
    final repo = fixtures.FakeCaptures();
    final attempt = draft(repo);
    await expectLater(
        attempt.submit(jpeg.path), failure('photo_upload_failed'));
    await jpeg.delete();
    await expectLater(storage.retry(owner, id), failure('photo_missing'));
    expect(await storage.pending(owner), isEmpty);
    expect(await CaptureStore.getUserCaptures(owner), hasLength(1));
    expect(repo.attempts, hasLength(1));
  });

  test(
      'continue during photo failure permits one reward transition; restart retry grants none',
      () async {
    remote.uploadFailure = TimeoutException('offline');
    final repo = fixtures.FakeCaptures();
    final attempt = draft(repo);
    await expectLater(
        attempt.submit(jpeg.path), failure('photo_upload_failed'));
    final completion = attempt.continueWithoutPhoto();
    expect(completion.local, isNotNull);
    expect(attempt.claimRewardTransition(), isTrue);
    expect(attempt.claimRewardTransition(), isFalse);
    remote.uploadFailure = null;
    await CapturePhotoStorage(remote: remote).retry(owner, id);
    expect(attempt.claimRewardTransition(), isFalse);
    expect(repo.attempts, hasLength(1));
    expect(await RewardSelectionStore.getUserRewards(), isEmpty);
  });

  test('old local JSON still parses with null remote photo path', () {
    final record = CaptureRecord.fromJson({
      'spotId': '12',
      'spotName': 'Old',
      'imagePath': '/old.jpg',
      'capturedAt': '2026-09-01T10:00:00',
    });
    expect(record.photoStoragePath, isNull);
    expect(record.remoteCaptureId, isNull);
    expect(record.imagePath, '/old.jpg');
  });

  test('friendly attachment and storage errors never expose backend details',
      () {
    for (final code in [
      'not_authenticated',
      'capture_unavailable',
      'invalid_photo_path',
      'photo_not_uploaded',
      'photo_already_attached'
    ]) {
      expect(
          CapturePhotoException.fromError(PostgrestException(message: code))
              .code,
          code);
    }
    for (final pair in [
      ('403', 'photo_permission'),
      ('413', 'photo_too_large'),
      ('415', 'unsupported_photo')
    ]) {
      expect(
          CapturePhotoException.fromError(
                  StorageException('secret', statusCode: pair.$1))
              .code,
          pair.$2);
    }
    expect(
        CapturePhotoException.fromError(
                const PostgrestException(message: 'secret SQL'))
            .message,
        isNot(contains('secret')));
  });

  test(
      'real SDK sends private multipart upload/upsert then exact two RPC params',
      () async {
    final oldOverrides = HttpOverrides.current;
    HttpOverrides.global = null;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final client = SupabaseClient('http://127.0.0.1:${server.port}', 'test-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false));
    addTearDown(() async {
      await client.dispose();
      await server.close(force: true);
      HttpOverrides.global = oldOverrides;
    });
    final events = <String>[];
    final bodies = <Map<String, dynamic>>[];
    String? uploadBody;
    String? upsert;
    String? uploadAuth;
    server.listen((request) async {
      request.response.headers.contentType = ContentType.json;
      if (request.uri.path.startsWith('/auth/')) {
        request.response.write(jsonEncode({
          'access_token': 'test-token',
          'refresh_token': 'test-refresh',
          'token_type': 'bearer',
          'expires_in': 3600,
          'user': {
            'id': owner,
            'aud': 'authenticated',
            'app_metadata': {},
            'user_metadata': {},
            'created_at': '2026-09-15T00:00:00Z'
          },
        }));
      } else if (request.uri.path.startsWith('/storage/')) {
        events.add('upload');
        expect(request.uri.path, '/storage/v1/object/capture-photos/$path');
        upsert = request.headers.value('x-upsert');
        uploadAuth = request.headers.value('authorization');
        final bytes = await request.fold<List<int>>([], (a, b) => a..addAll(b));
        uploadBody = utf8.decode(bytes, allowMalformed: true);
        request.response.write(jsonEncode({'Key': 'capture-photos/$path'}));
      } else {
        events.add('attach');
        expect(request.uri.path, '/rest/v1/rpc/attach_capture_photo');
        bodies.add(jsonDecode(await utf8.decoder.bind(request).join())
            as Map<String, dynamic>);
        request.response.write(jsonEncode([
          {'capture_id': id, 'photo_storage_path': path}
        ]));
      }
      await request.response.close();
    });
    await client.auth.signInWithPassword(
        email: 'test@example.invalid', password: 'test-password');
    final service =
        CapturePhotoStorage(remote: SupabaseCapturePhotoRemote(client: client));
    await service.enqueue(owner, id, jpeg.path);
    expect(await service.retry(owner, id), path);
    expect(events, ['upload', 'attach']);
    expect(upsert, 'true');
    expect(uploadAuth, 'Bearer test-token');
    expect(uploadBody, contains('image/jpeg'));
    expect(bodies.single, {'p_capture_id': id, 'p_storage_path': path});
    expect(bodies.single.keys, isNot(contains('user_id')));
  });
}
