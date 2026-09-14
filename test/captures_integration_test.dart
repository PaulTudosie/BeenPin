import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:been/capture_screen.dart';
import 'package:been/models/app_profile.dart';
import 'package:been/models/remote_capture.dart';
import 'package:been/models/reward.dart';
import 'package:been/models/spot.dart';
import 'package:been/services/capture_draft.dart';
import 'package:been/services/capture_repository.dart';
import 'package:been/services/capture_state.dart';
import 'package:been/services/capture_store.dart';
import 'package:been/services/reward_selection_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const ownerA = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const ownerB = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
const spotUuid = '11111111-1111-4111-8111-111111111111';
const otherSpotUuid = '22222222-2222-4222-8222-222222222222';
const captureUuid = '33333333-3333-4333-8333-333333333333';
const clientUuid = '44444444-4444-4444-8444-444444444444';
const profile = AppProfile(
    id: ownerA,
    username: 'remote_abel',
    displayName: 'Abel Remote',
    bio: 'Explorer');

Spot spot({String id = '12', String remoteId = spotUuid}) => Spot(
      id: id,
      remoteId: remoteId,
      slug: 'piata-victoriei',
      name: 'Piața Victoriei',
      lat: 44.4521,
      lng: 26.0857,
      type: 'urban',
    );
Map<String, dynamic> row(
        {String spotId = spotUuid, String clientId = clientUuid}) =>
    {
      'capture_id': captureUuid,
      'spot_id': spotId,
      'client_capture_id': clientId,
      'captured_at': '2026-09-15T10:00:00+00:00',
      'distance_from_spot_m': 24,
      'spot_slug': 'piata-victoriei',
      'spot_name': 'Server spot name',
    };

class FakeCaptures implements CaptureRepository {
  @override
  String? currentUserId = ownerA;
  Object? failure;
  Completer<RemoteCapture>? createWait;
  Completer<List<RemoteCapture>>? readWait;
  final attempts = <Map<String, Object>>[];
  final byOwner = <String, List<RemoteCapture>>{};
  int reads = 0;

  @override
  Future<List<RemoteCapture>> getOwnCaptures() async {
    reads++;
    return readWait?.future ?? byOwner[currentUserId] ?? [];
  }

  @override
  Future<RemoteCapture> createCapture(
      {required String spotId,
      required double latitude,
      required double longitude,
      required String clientCaptureId}) async {
    attempts.add({
      'spotId': spotId,
      'latitude': latitude,
      'longitude': longitude,
      'clientCaptureId': clientCaptureId
    });
    if (failure != null) throw failure!;
    return createWait?.future ??
        RemoteCapture.fromJson({
          ...row(spotId: spotId, clientId: clientCaptureId),
          'captured_at': DateTime.now().toUtc().toIso8601String(),
        });
  }
}

CaptureDraft draft(FakeCaptures repository,
        {void Function(RemoteCapture)? onAccepted}) =>
    CaptureDraft(
      repository: repository,
      profile: profile,
      spot: spot(),
      latitude: 44.4521,
      longitude: 26.0857,
      onAccepted: onAccepted ?? (_) {},
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('RPC projection parses UUID identity, UTC time and integer distance',
      () {
    final capture = RemoteCapture.fromJson(row());
    expect(capture.id, captureUuid);
    expect(capture.spotId, spotUuid);
    expect(capture.capturedAt, DateTime.utc(2026, 9, 15, 10));
    expect(capture.distanceFromSpotMeters, 24.0);
    for (final invalid in [
      {...row(), 'spot_id': '12'},
      {...row(), 'distance_from_spot_m': double.nan},
      {...row(), 'distance_from_spot_m': -1},
      {...row(), 'captured_at': 'not-a-date'},
    ]) {
      expect(() => RemoteCapture.fromJson(invalid), throwsFormatException);
    }
  });

  test('friendly backend errors never expose raw database details', () {
    const messages = {
      'already_captured': "You've already Been here.",
      'outside_capture_radius': 'Move closer to the spot to capture it.',
      'spot_unavailable': "This spot isn't available right now.",
    };
    for (final entry in messages.entries) {
      expect(
          CaptureException.fromError(PostgrestException(message: entry.key))
              .message,
          entry.value);
    }
    for (final code in [
      'not_authenticated',
      'invalid_client_capture_id',
      'invalid_coordinates',
      'capture_retry_required'
    ]) {
      expect(CaptureException.fromError(PostgrestException(message: code)).code,
          code);
    }
    expect(
        CaptureException.fromError(
                const PostgrestException(message: 'secret SQL text'))
            .message,
        "Couldn't save your capture. Try again.");
  });

  test(
      'timeout retry keeps UUID, GPS and photo; no local success before acceptance',
      () async {
    final repo = FakeCaptures()..failure = TimeoutException('lost reply');
    var accepted = 0;
    final attempt = draft(repo, onAccepted: (_) => accepted++);
    await expectLater(
        attempt.submit('/cache/first.jpg'), throwsA(isA<CaptureException>()));
    expect(await CaptureStore.getUserCaptures(ownerA), isEmpty);
    expect(await RewardSelectionStore.getUserRewards(), isEmpty);
    expect(accepted, 0);
    repo.failure = null;
    final result = await attempt.submit('/cache/different.jpg');
    expect(repo.attempts.map((a) => a['clientCaptureId']).toSet(),
        {attempt.clientCaptureId});
    expect(
        RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')
            .hasMatch(attempt.clientCaptureId),
        isTrue);
    expect(repo.attempts.first['spotId'], spotUuid);
    expect(result.local!.imagePath, '/cache/first.jpg');
    expect(attempt.imagePath, '/cache/first.jpg');
    expect(accepted, 1);
  });

  test('duplicate Been submissions share one RPC and local record', () async {
    final repo = FakeCaptures()..createWait = Completer<RemoteCapture>();
    final attempt = draft(repo);
    final first = attempt.submit('/cache/photo.jpg');
    final second = attempt.submit('/cache/photo.jpg');
    expect(repo.attempts, hasLength(1));
    repo.createWait!.complete(
        RemoteCapture.fromJson(row(clientId: attempt.clientCaptureId)));
    final results = await Future.wait([first, second]);
    expect(results.first.local!.remoteCaptureId,
        results.last.local!.remoteCaptureId);
    expect(await CaptureStore.getUserCaptures(ownerA), hasLength(1));
    await attempt.submit('/cache/photo.jpg');
    expect(repo.attempts, hasLength(1));
  });

  test(
      'accepted capture uses AppProfile and preserves existing reward contract',
      () async {
    final result = await draft(FakeCaptures()).submit('/cache/new.jpg');
    final local = result.local!;
    expect(local.author.id, ownerA);
    expect(local.author.name, 'Abel Remote');
    expect(local.author.handle, '@remote_abel');
    expect(local.spotId, '12');
    expect(local.remoteSpotId, spotUuid);
    expect(local.spotName, 'Server spot name');
    expect(local.distanceMeters, 24);
    expect(local.capturedAt.toUtc(), result.remote.capturedAt);
    expect(local.proofId,
        'BP-12-${result.remote.capturedAt.millisecondsSinceEpoch}');
    // These are the same inputs Map hands to the existing selection flow.
    final offers = Reward.availableForSpot(
        spot: spot(),
        capturedAt: local.capturedAt,
        distanceMeters: local.distanceMeters,
        proofId: local.proofId);
    expect(offers, isNotEmpty);
    final selected = await RewardSelectionStore.saveSelectedReward(
        proofId: local.proofId!,
        reward: offers.first,
        sourceSpotId: local.spotId);
    expect(selected.reward.qrCode, endsWith(local.proofId!));
    expect(selected.reward.distanceMeters, 24);
    expect((await RewardSelectionStore.getUserRewards()).single.proofId,
        local.proofId);
  });

  test('rejection never creates compatibility data, markers or reward',
      () async {
    final repo = FakeCaptures()
      ..failure = const CaptureException('outside_capture_radius');
    final state = CaptureState(repo);
    await state.loadForUser(ownerA);
    await expectLater(
        draft(repo, onAccepted: (r) => state.accept(ownerA, r))
            .submit('/cache/photo.jpg'),
        throwsA(isA<CaptureException>()));
    expect(state.capturedLocalIds([spot()]), isEmpty);
    expect(await CaptureStore.getUserCaptures(ownerA), isEmpty);
    expect(await RewardSelectionStore.getUserRewards(), isEmpty);
    state.dispose();
  });

  test(
      'already captured reconciles remote marker without photo or proof creation',
      () async {
    final repo = FakeCaptures()
      ..failure = const CaptureException('already_captured');
    repo.byOwner[ownerA] = [RemoteCapture.fromJson(row())];
    final state = CaptureState(repo);
    await state.loadForUser(ownerA);
    final result = await draft(repo, onAccepted: (r) => state.accept(ownerA, r))
        .submit('/cache/not-the-original.jpg');
    expect(result.local, isNull);
    expect(result.remote.id, captureUuid);
    expect(state.capturedLocalIds([spot()]), {'12'});
    expect(await CaptureStore.getUserCaptures(ownerA), isEmpty);
    expect(await RewardSelectionStore.getUserRewards(), isEmpty);
    state.dispose();
  });

  test(
      'remote success/local failure can retry just local save with original identity',
      () async {
    final repo = FakeCaptures();
    var writes = 0;
    var accepted = false;
    final attempt = CaptureDraft(
        repository: repo,
        profile: profile,
        spot: spot(),
        latitude: 44,
        longitude: 26,
        onAccepted: (_) => accepted = true,
        persist: (
            {required profile,
            required spot,
            required remote,
            required imagePath,
            required latitude,
            required longitude}) async {
          if (++writes == 1) throw StateError('disk failed');
          return CaptureStore.saveRemoteCapture(
              profile: profile,
              spot: spot,
              remote: remote,
              imagePath: imagePath,
              latitude: latitude,
              longitude: longitude);
        });
    await expectLater(
        attempt.submit('/cache/photo.jpg'),
        throwsA(isA<CaptureException>()
            .having((e) => e.code, 'code', 'local_save_failed')));
    expect(accepted, isTrue);
    expect(await RewardSelectionStore.getUserRewards(), isEmpty);
    final recovered = await attempt.submit('/cache/photo.jpg');
    expect(repo.attempts, hasLength(1));
    expect(recovered.local, isNotNull);
  });

  test(
      'new records are scoped; legacy global JSON and marker keys remain byte-for-byte',
      () async {
    const legacy = '{"spotId":"12","spotName":"Old","spotType":"urban",'
        '"imagePath":"/old.jpg","capturedAt":"2026-09-01T10:00:00"}';
    SharedPreferences.setMockInitialValues({
      'capture_records': [legacy],
      'captured_spot_ids': ['12'],
      'journey_avatar_path': '/old-avatar.jpg'
    });
    final old = CaptureRecord.fromJson(jsonDecode(legacy));
    expect(old.remoteCaptureId, isNull);
    expect(old.imagePath, '/old.jpg');
    await draft(FakeCaptures()).submit('/cache/new.jpg');
    expect(await CaptureStore.getUserCaptures(ownerA), hasLength(1));
    expect(await CaptureStore.getUserCaptures(ownerB), isEmpty);
    expect(await CaptureStore.getUserCaptures(null), isEmpty);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList('capture_records'), [legacy]);
    expect(prefs.getStringList('captured_spot_ids'), ['12']);
    final persisted = {for (final key in prefs.getKeys()) key: prefs.get(key)!};
    SharedPreferences.setMockInitialValues(persisted);
    final restored = (await CaptureStore.getUserCaptures(ownerA)).single;
    expect(restored.author.id, ownerA);
    expect(restored.author.avatarPath, isNull);
    expect(restored.remoteCaptureId, captureUuid);
  });

  test(
      'owner change clears markers immediately, ignores late reads, and reloads on return',
      () async {
    SharedPreferences.setMockInitialValues({
      'captured_spot_ids': ['12', '4']
    });
    final repo = FakeCaptures();
    final state = CaptureState(repo);
    final spots = [spot(), spot(id: '4', remoteId: otherSpotUuid)];
    repo.byOwner[ownerA] = [RemoteCapture.fromJson(row())];
    await state.loadForUser(ownerA);
    expect(state.capturedLocalIds(spots), {'12'});
    final late = Completer<List<RemoteCapture>>();
    repo.readWait = late;
    final oldLoad = state.loadForUser(ownerA);
    repo.currentUserId = null;
    await state.loadForUser(null);
    expect(state.capturedLocalIds(spots), isEmpty);
    repo.currentUserId = ownerB;
    repo.readWait = null;
    await state.loadForUser(ownerB);
    expect(state.capturedLocalIds(spots), isEmpty);
    late.complete([RemoteCapture.fromJson(row())]);
    await oldLoad;
    expect(state.capturedLocalIds(spots), isEmpty);
    repo.byOwner[ownerB] = [RemoteCapture.fromJson(row(spotId: otherSpotUuid))];
    await state.loadForUser(ownerB);
    expect(state.capturedLocalIds(spots), {'4'});
    repo.currentUserId = ownerA;
    await state.loadForUser(ownerA);
    expect(state.capturedLocalIds(spots), {'12'});
    state.dispose();
  });

  test(
      'late create response after account change cannot persist or unlock rewards',
      () async {
    final repo = FakeCaptures()..createWait = Completer<RemoteCapture>();
    var accepted = false;
    final attempt = draft(repo, onAccepted: (_) => accepted = true);
    final save = attempt.submit('/cache/photo.jpg');
    final expectation = expectLater(save, throwsA(isA<CaptureException>()));
    repo.currentUserId = ownerB;
    repo.createWait!.complete(
        RemoteCapture.fromJson(row(clientId: attempt.clientCaptureId)));
    await expectation;
    expect(accepted, isFalse);
    expect(await CaptureStore.getUserCaptures(ownerA), isEmpty);
    expect(await CaptureStore.getUserCaptures(ownerB), isEmpty);
  });

  test(
      'acceptance updates marker immediately and supersedes an older in-flight list',
      () async {
    final repo = FakeCaptures();
    final state = CaptureState(repo);
    await state.loadForUser(ownerA);
    repo.readWait = Completer<List<RemoteCapture>>();
    final refresh = state.loadForUser(ownerA);
    state.accept(ownerA, RemoteCapture.fromJson(row()));
    expect(state.capturedLocalIds([spot()]), {'12'});
    repo.readWait!.complete([]);
    await refresh;
    expect(state.capturedLocalIds([spot()]), {'12'});
    state.dispose();
  });

  testWidgets(
      'camera preview restores draft photo and waits for acceptance before returning',
      (tester) async {
    final repo = FakeCaptures()
      ..failure = TimeoutException('first response lost');
    final attempt = draft(repo);
    await expectLater(attempt.submit('/cache/original.jpg'),
        throwsA(isA<CaptureException>()));
    repo.failure = null;
    repo.createWait = Completer<RemoteCapture>();
    CaptureCompletion? returned;
    await tester.pumpWidget(MaterialApp(
        home: Builder(
            builder: (context) => Scaffold(
                  body: TextButton(
                      onPressed: () async {
                        returned = await Navigator.of(context)
                            .push<CaptureCompletion>(MaterialPageRoute(
                          builder: (_) =>
                              CaptureScreen(spot: spot(), draft: attempt),
                        ));
                      },
                      child: const Text('Open draft')),
                ))));
    await tester.tap(find.text('Open draft'));
    await tester.pumpAndSettle();
    expect(find.byType(Image), findsOneWidget);
    await tester.tap(find.text('Been ✅'));
    await tester.tap(find.text('Been ✅'));
    await tester.pump();
    expect(find.text('Saving…'), findsOneWidget);
    expect(returned, isNull);
    expect(repo.attempts, hasLength(2)); // Initial timeout, then one UI retry.
    repo.createWait!.complete(
        RemoteCapture.fromJson(row(clientId: attempt.clientCaptureId)));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Saving…'), findsNothing);
    await tester.pumpAndSettle();
    expect(returned!.local!.imagePath, '/cache/original.jpg');
    expect(returned!.remote.clientCaptureId, attempt.clientCaptureId);
    expect(find.text('Open draft'), findsOneWidget);
  });

  test(
      'real Supabase client sends only four RPC parameters and reads the safe projection',
      () async {
    // Loopback fake HTTP transport, never the deployed Supabase project.
    final oldOverrides = HttpOverrides.current;
    HttpOverrides.global = null;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final bodies = <Map<String, dynamic>>[];
    final selects = <String>[];
    final client = SupabaseClient('http://127.0.0.1:${server.port}', 'test-key',
        authOptions: const AuthClientOptions(autoRefreshToken: false));
    addTearDown(() async {
      await client.dispose();
      await server.close(force: true);
      HttpOverrides.global = oldOverrides;
    });
    server.listen((request) async {
      request.response.headers.contentType = ContentType.json;
      if (request.uri.path.startsWith('/auth/')) {
        request.response.write(jsonEncode({
          'access_token': 'test-token',
          'refresh_token': 'test-refresh',
          'token_type': 'bearer',
          'expires_in': 3600,
          'user': {
            'id': ownerA,
            'aud': 'authenticated',
            'app_metadata': {},
            'user_metadata': {},
            'created_at': '2026-09-15T00:00:00Z'
          },
        }));
      } else if (request.uri.path.endsWith('/rpc/create_capture')) {
        bodies.add(jsonDecode(await utf8.decoder.bind(request).join()));
        request.response.write(jsonEncode([row()]));
      } else {
        selects.add(request.uri.queryParameters['select'] ?? '');
        request.response.write(jsonEncode([row()]));
      }
      await request.response.close();
    });
    await client.auth.signInWithPassword(
        email: 'test@example.invalid', password: 'test-password');
    final repo = SupabaseCaptureRepository(client: client);
    final capture = await repo.createCapture(
        spotId: spotUuid,
        latitude: 44.4,
        longitude: 26.1,
        clientCaptureId: clientUuid);
    expect(capture.id, captureUuid);
    expect(bodies.single, {
      'p_spot_id': spotUuid,
      'p_latitude': 44.4,
      'p_longitude': 26.1,
      'p_client_capture_id': clientUuid
    });
    expect(bodies.single.containsKey('user_id'), isFalse);
    expect(bodies.single.containsKey('photo_storage_path'), isFalse);
    expect(await repo.getOwnCaptures(), hasLength(1));
    expect(selects.single, contains('capture_id:id'));
    expect(selects.single, isNot(contains('capture_location')));
  });
}
