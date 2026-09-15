import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:been/features/auth/auth_scope.dart';
import 'package:been/features/journey/journey_photo.dart';
import 'package:been/features/journey/journey_screen.dart';
import 'package:been/features/search/app_search_delegate.dart';
import 'package:been/models/app_profile.dart';
import 'package:been/models/journey_capture.dart';
import 'package:been/models/remote_capture.dart';
import 'package:been/models/social_user.dart';
import 'package:been/services/auth_controller.dart';
import 'package:been/services/capture_photo_storage.dart';
import 'package:been/services/capture_store.dart';
import 'package:been/services/journey_controller.dart';
import 'package:been/services/journey_repository.dart';
import 'package:been/services/private_capture_photos.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_test.dart' as auth;
import 'captures_integration_test.dart' as f;

class Photos extends PrivateCapturePhotos {
  final calls = <String>[];
  final failures = <String>{};
  Completer<String>? wait;
  @override
  Future<String> getUrl(String owner, String captureId, String path) async {
    calls.add(path);
    if (failures.contains(path)) throw StateError('offline');
    return wait?.future ??
        'https://example.invalid/photo?token=${calls.length}';
  }
}

class Captures extends f.FakeCaptures {
  bool failRead = false;
  @override
  Future<List<RemoteCapture>> getOwnCaptures() {
    if (failRead) return Future.error(StateError('offline'));
    return super.getOwnCaptures();
  }
}

RemoteCapture remote(
        {String id = f.captureUuid,
        String? path,
        String time = '2026-09-15T10:00:00Z'}) =>
    RemoteCapture.fromJson({
      ...f.row(),
      'capture_id': id,
      'captured_at': time,
      'photo_storage_path': path,
    });

CaptureRecord local(
        {String owner = f.ownerA,
        String? id = f.captureUuid,
        String path = '/cache/photo.jpg'}) =>
    CaptureRecord(
        author: SocialUser(
            id: owner,
            name: 'Owner',
            city: '',
            levelName: '',
            handle: '@owner',
            avatarPath: null,
            tagline: ''),
        spotId: '12',
        spotName: 'Server spot name',
        spotType: 'urban',
        imagePath: path,
        capturedAt: DateTime.utc(2030),
        remoteCaptureId: id);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const path = '${f.ownerA}/${f.captureUuid}/original.jpg';
  late Captures captures;
  late Photos photos;
  late JourneyController controller;
  late DateTime now;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    captures = Captures();
    photos = Photos();
    now = DateTime.utc(2026, 9, 16);
    controller = JourneyController(
        repository: JourneyRepository(captures: captures),
        photos: photos,
        now: () => now);
  });
  tearDown(() => controller.dispose());

  test('remote rows reconstruct history newest first without local data',
      () async {
    captures.byOwner[f.ownerA] = [
      remote(),
      remote(id: f.otherSpotUuid, time: '2026-09-16T10:00:00Z', path: path)
    ];
    await controller.loadForUser(f.ownerA);
    expect(controller.items.map((c) => c.id), [f.otherSpotUuid, f.captureUuid]);
    expect(controller.items.first.photoStoragePath, path);
    expect(controller.items.first.photoUrl, startsWith('https://'));
    expect(controller.items.last.photoUrl, isNull);
    expect(controller.captureCount, 2);
    expect((await SharedPreferences.getInstance()).getKeys(), isEmpty);
  });

  test('fallback requires owner and remote UUID; no legacy claim or duplicate',
      () async {
    captures.byOwner[f.ownerA] = [remote(), remote()];
    final repo = JourneyRepository(
        captures: captures,
        localCaptures: (_) async => [
              local(id: null),
              local(owner: f.ownerB),
              local(id: f.otherSpotUuid),
              local(path: '/valid.jpg')
            ],
        fileExists: (_) async => true);
    final items = await repo.load(f.ownerA);
    expect(items, hasLength(1));
    expect(items.single.localPhotoPathFallback, '/valid.jpg');
    expect(items.single.capturedAt, DateTime.utc(2026, 9, 15, 10));
    final noMatch = JourneyRepository(
        captures: captures,
        localCaptures: (_) async => [local(id: null), local(owner: f.ownerB)],
        fileExists: (_) async => true);
    expect(
        (await noMatch.load(f.ownerA)).single.localPhotoPathFallback, isNull);
  });

  test('missing file and broken compatibility store keep remote capture',
      () async {
    captures.byOwner[f.ownerA] = [remote()];
    final repo = JourneyRepository(
        captures: captures,
        localCaptures: (_) async => [local()],
        fileExists: (_) async => false);
    expect((await repo.load(f.ownerA)).single.localPhotoPathFallback, isNull);
    final broken = JourneyRepository(
        captures: captures,
        localCaptures: (_) async => throw const FormatException('old cache'));
    expect(await broken.load(f.ownerA), hasLength(1));
  });

  test('legacy device-wide storage preserved and excluded; old JSON readable',
      () async {
    final old = {
      'spotName': 'Old spot',
      'imagePath': '/old.jpg',
      'capturedAt': '2020-01-01T00:00:00Z'
    };
    SharedPreferences.setMockInitialValues({
      'capture_records': [jsonEncode(old)]
    });
    expect(CaptureRecord.fromJson(old).remoteCaptureId, isNull);
    captures.byOwner[f.ownerA] = [remote()];
    await controller.loadForUser(f.ownerA);
    expect(controller.items.single.localPhotoPathFallback, isNull);
    expect(
        (await SharedPreferences.getInstance())
            .getStringList('capture_records'),
        [jsonEncode(old)]);
  });

  test('auth switch clears immediately and ignores late photo response',
      () async {
    captures.byOwner[f.ownerA] = [remote(path: path)];
    photos.wait = Completer<String>();
    final pending = controller.loadForUser(f.ownerA);
    while (photos.calls.isEmpty) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(controller.captureCount, 1);
    captures.currentUserId = f.ownerB;
    captures.readWait = Completer<List<RemoteCapture>>();
    final switched = controller.loadForUser(f.ownerB);
    expect(controller.items, isEmpty);
    expect(controller.loading, isTrue);
    photos.wait!.complete('https://old.invalid');
    await pending;
    expect(controller.items, isEmpty);
    captures.readWait!.complete([remote(id: f.otherSpotUuid)]);
    await switched;
    expect(controller.items.single.id, f.otherSpotUuid);
    expect(controller.items.single.photoUrl, isNull);
    await controller.loadForUser(null);
    expect(controller.items, isEmpty);
  });

  test('late capture list cannot replace new owner or switch-back generation',
      () async {
    captures.readWait = Completer<List<RemoteCapture>>();
    final oldWait = captures.readWait!;
    final old = controller.loadForUser(f.ownerA);
    captures.currentUserId = f.ownerB;
    captures.readWait = null;
    await controller.loadForUser(f.ownerB);
    captures.currentUserId = f.ownerA;
    captures.byOwner[f.ownerA] = [remote(id: f.otherSpotUuid)];
    await controller.loadForUser(f.ownerA);
    oldWait.complete([remote()]);
    await old;
    expect(controller.items.single.id, f.otherSpotUuid);
  });

  test('photo failure is isolated and refresh renews temporary URLs', () async {
    captures.byOwner[f.ownerA] = [
      remote(path: path),
      remote(id: f.otherSpotUuid)
    ];
    photos.failures.add(path);
    await controller.loadForUser(f.ownerA);
    expect(controller.error, isNull);
    expect(controller.captureCount, 2);
    expect(
        controller.items.firstWhere((c) => c.id == f.captureUuid).photoFailed,
        isTrue);
    photos.failures.clear();
    await controller.refresh();
    final firstUrl =
        controller.items.firstWhere((c) => c.id == f.captureUuid).photoUrl;
    await controller.refresh(invalidatePhotos: true);
    expect(controller.items.firstWhere((c) => c.id == f.captureUuid).photoUrl,
        isNot(firstUrl));
  });

  test('photo attachment notification updates same capture, no duplicate',
      () async {
    captures.byOwner[f.ownerA] = [remote()];
    await controller.loadForUser(f.ownerA);
    captures.byOwner[f.ownerA] = [remote(path: path)];
    CapturePhotoStorage.changes.value++;
    await Future<void>.delayed(const Duration(milliseconds: 250));
    expect(controller.items, hasLength(1));
    expect(controller.items.single.photoUrl, isNotNull);
  });

  test('tab refresh reuses URL and preserves items during a shared load',
      () async {
    captures.byOwner[f.ownerA] = [remote(path: path)];
    await controller.loadForUser(f.ownerA);
    final visible = controller.items;
    captures.readWait = Completer<List<RemoteCapture>>();
    final first = controller.refresh();
    final second = controller.refresh();
    expect(identical(first, second), isTrue);
    expect(identical(controller.items, visible), isTrue);
    expect(controller.loading, isFalse);
    expect(captures.reads, 2);
    captures.readWait!.complete([remote(path: path)]);
    await Future.wait([first, second]);
    expect(controller.items.single.photoUrl, visible.single.photoUrl);
    expect(photos.calls, hasLength(1));
    captures.readWait = null;
    now = now.add(const Duration(minutes: 24));
    await controller.refresh();
    expect(photos.calls, hasLength(1));
    now = now.add(const Duration(minutes: 1));
    photos.wait = Completer<String>();
    final renewal = controller.refresh();
    while (photos.calls.length < 2) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(controller.items.single.photoUrl, visible.single.photoUrl);
    photos.wait!.complete('https://example.invalid/renewed');
    await renewal;
    expect(controller.items, hasLength(1));
    expect(controller.items.single.photoUrl, endsWith('/renewed'));
  });

  test('queue changes during load trigger only one follow-up with fresh data',
      () async {
    captures.readWait = Completer<List<RemoteCapture>>();
    final pending = captures.readWait!;
    final load = controller.loadForUser(f.ownerA);
    CapturePhotoStorage.changes.value++;
    CapturePhotoStorage.changes.value++;
    captures.byOwner[f.ownerA] = [remote(path: path)];
    captures.readWait = null;
    pending.complete([remote()]);
    await load;
    expect(captures.reads, 2);
    expect(controller.items.single.photoUrl, isNotNull);
  });

  test('failed background refresh keeps same-user visible history and URL',
      () async {
    captures.byOwner[f.ownerA] = [remote(path: path)];
    await controller.loadForUser(f.ownerA);
    final before = controller.items;
    captures.failRead = true;
    await controller.refresh();
    expect(controller.items, same(before));
    expect(controller.error, isNotNull);
    captures.currentUserId = f.ownerB;
    final switchUser = controller.loadForUser(f.ownerB);
    expect(controller.items, isEmpty);
    await switchUser;
  });

  test('query error is recoverable with refresh', () async {
    captures.failRead = true;
    await controller.loadForUser(f.ownerA);
    expect(controller.error, isNotNull);
    expect(controller.loading, isFalse);
    captures.failRead = false;
    captures.byOwner[f.ownerA] = [remote()];
    await controller.refresh();
    expect(controller.error, isNull);
    expect(controller.captureCount, 1);
  });

  test('photo requests are bounded while all capture rows are visible',
      () async {
    captures.byOwner[f.ownerA] = List.generate(
        8,
        (index) => remote(
            id: '00000000-0000-4000-8000-00000000000$index',
            path:
                '${f.ownerA}/00000000-0000-4000-8000-00000000000$index/original.jpg'));
    photos.wait = Completer<String>();
    final load = controller.loadForUser(f.ownerA);
    while (photos.calls.length < 3) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(photos.calls, hasLength(3));
    expect(controller.captureCount, 8);
    expect(controller.loading, isFalse);
    photos.wait!.complete('https://example.invalid/temporary');
    await load;
    expect(photos.calls, hasLength(8));
  });

  testWidgets('temporary URLs renew before expiry and clear on logout',
      (tester) async {
    captures.byOwner[f.ownerA] = [remote(path: path)];
    await controller.loadForUser(f.ownerA);
    final previous = controller.items.single.photoUrl;
    now = now.add(const Duration(minutes: 25));
    await tester.pump(const Duration(minutes: 25));
    await tester.pump();
    expect(controller.items.single.photoUrl, isNot(previous));
    await controller.loadForUser(null);
    expect(controller.items, isEmpty);
    await tester.pump(const Duration(minutes: 30));
    expect(photos.calls, hasLength(2));
  });

  testWidgets('Journey renders remote count, rank, photo-less card and Retry',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final authService = auth.FakeAuth(auth.session());
    final authController = AuthController(authService, auth.FakeProfiles());
    await tester.pump();
    authController.profile =
        const AppProfile(id: f.ownerA, username: 'owner', displayName: 'Owner');
    captures.byOwner[f.ownerA] = [
      remote(),
      remote(id: f.otherSpotUuid),
      remote(id: f.clientUuid)
    ];
    Widget app(int tick) => AuthScope(
        controller: authController,
        child: MaterialApp(
            home: Scaffold(
                body:
                    JourneyScreen(controller: controller, refreshTick: tick))));
    await tester.pumpWidget(app(0));
    await tester.pumpAndSettle();
    expect(find.text('3 captures'), findsOneWidget);
    expect(find.text('Explorer'), findsOneWidget);
    expect(find.byType(JourneyPhoto), findsNWidgets(3));
    final photo = find.byWidgetPredicate((widget) =>
        widget is JourneyPhoto && widget.capture.id == f.captureUuid);
    expect(
        tester.widget<JourneyPhoto>(photo).key, const ValueKey(f.captureUuid));
    final photoState = tester.state(photo);
    captures.readWait = Completer<List<RemoteCapture>>();
    await tester.pumpWidget(app(1));
    expect(find.text('3 captures'), findsOneWidget);
    expect(tester.state(photo), same(photoState));
    captures.readWait!.complete(captures.byOwner[f.ownerA]!);
    await tester.pumpAndSettle();
    expect(tester.state(photo), same(photoState));
    captures.readWait = null;
    captures.failRead = true;
    await controller.refresh();
    await tester.pumpAndSettle();
    expect(find.text('Retry'), findsOneWidget);
    captures.failRead = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('3 captures'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await controller.loadForUser(null);
    authController.dispose();
    await authService.events.close();
  });

  testWidgets(
      'private URL uses network representation; missing photo placeholder',
      (tester) async {
    final item = JourneyCapture(
        id: 'id',
        spotId: 'spot',
        spotSlug: 'slug',
        spotName: 'Name',
        capturedAt: DateTime.utc(2026),
        photoUrl: 'https://example.invalid/private');
    await tester.pumpWidget(MaterialApp(home: JourneyPhoto(capture: item)));
    final image = tester.widget<Image>(find.byType(Image));
    expect(image.image, isA<NetworkImage>());
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.image_not_supported_outlined), findsOneWidget);
  });

  testWidgets(
      'search uses remote own-history and clears results on account change',
      (tester) async {
    final serviceA = auth.FakeAuth(auth.session());
    final serviceB = auth.FakeAuth(auth.session());
    final authA = AuthController(serviceA, auth.FakeProfiles());
    final authB = AuthController(serviceB, auth.FakeProfiles());
    await tester.pump();
    authA.profile = f.profile;
    authB.profile = const AppProfile(
        id: f.ownerB, username: 'second', displayName: 'Second');
    final delegate =
        AppSearchDelegate(repository: JourneyRepository(captures: captures))
          ..query = 'Server spot name';
    captures.byOwner[f.ownerA] = [remote()];
    Widget app(AuthController owner) => AuthScope(
        controller: owner,
        child: MaterialApp(
            home: Scaffold(body: Builder(builder: delegate.buildResults))));
    await tester.pumpWidget(app(authA));
    await tester.pumpAndSettle();
    expect(find.text('Captured by you'), findsOneWidget);
    expect(captures.reads, 1);
    captures.currentUserId = f.ownerB;
    captures.readWait = Completer<List<RemoteCapture>>();
    await tester.pumpWidget(app(authB));
    expect(find.text('Captured by you'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    captures.readWait!.complete([]);
    await tester.pumpAndSettle();
    expect(find.text('Captured by you'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    delegate.dispose();
    authA.dispose();
    authB.dispose();
    await serviceA.events.close();
    await serviceB.events.close();
  });

  test(
      'private signing validates namespace, expires in 30 min, never persists URL',
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
    final paths = <String>[];
    final bodies = <Map<String, dynamic>>[];
    server.listen((request) async {
      request.response.headers.contentType = ContentType.json;
      if (request.uri.path.startsWith('/auth/')) {
        request.response.write(jsonEncode({
          'access_token': 'test-token',
          'refresh_token': 'refresh',
          'token_type': 'bearer',
          'expires_in': 3600,
          'user': {
            'id': f.ownerA,
            'aud': 'authenticated',
            'app_metadata': {},
            'user_metadata': {},
            'created_at': '2026-09-15T00:00:00Z'
          }
        }));
      } else {
        paths.add(request.uri.path);
        bodies.add(jsonDecode(await utf8.decoder.bind(request).join())
            as Map<String, dynamic>);
        expect(request.headers.value('authorization'), 'Bearer test-token');
        request.response.write(jsonEncode({
          'signedURL': '/object/sign/capture-photos/$path?token=temporary'
        }));
      }
      await request.response.close();
    });
    await client.auth.signInWithPassword(
        email: 'test@example.invalid', password: 'test-password');
    final service = SupabasePrivateCapturePhotos(client: client);
    final url = await service.getUrl(f.ownerA, f.captureUuid, path);
    expect(url, contains('token=temporary'));
    expect(paths.single, '/storage/v1/object/sign/capture-photos/$path');
    expect(bodies.single['expiresIn'], 1800);
    for (final invalid in [
      '${f.ownerB}/${f.captureUuid}/original.jpg',
      '${f.ownerA}/${f.otherSpotUuid}/original.jpg',
      '${f.ownerA}/../original.jpg'
    ]) {
      await expectLater(service.getUrl(f.ownerA, f.captureUuid, invalid),
          throwsA(isA<CapturePhotoException>()));
    }
    expect(paths, hasLength(1));
    expect((await SharedPreferences.getInstance()).getKeys(), isEmpty);
  });
}
