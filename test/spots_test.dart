import 'dart:io';

import 'package:been/models/spot.dart';
import 'package:been/models/spot_identity.dart';
import 'package:been/services/capture_store.dart';
import 'package:been/services/spot_repository.dart';
import 'package:been/services/spot_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Map<String, dynamic> row({
  String slug = 'piata-victoriei',
  String uuid = 'b03db28a-4d50-41fb-aecd-9dd48b83e938',
}) =>
    {
      'id': uuid,
      'slug': slug,
      'name': 'Piața Victoriei',
      'description': 'Existing description',
      'category': 'urban',
      'latitude': 44.4521,
      'longitude': 26.0857,
      'capture_radius_m': 10000,
      'image_url': null,
      'is_active': true,
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final originalSpots = SpotService.getSpots();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SpotService.useRemoteSpots(originalSpots);
  });

  tearDown(() => SpotService.useRemoteSpots(originalSpots));

  test('RPC numeric coordinates, metadata and compatibility ID map correctly',
      () {
    final spot = Spot.fromJson(row());
    expect(spot.id, '12');
    expect(spot.remoteId, row()['id']);
    expect(spot.slug, 'piata-victoriei');
    expect(spot.lat, 44.4521);
    expect(spot.lng, 26.0857);
    expect(spot.captureRadiusMeters, 10000);
    expect(spot.description, 'Existing description');
    expect(spot.type, 'urban');
    expect(spot.imageUrl, isNull);
    expect(spot.isActive, isTrue);
    final nullable = Spot.fromJson(row()..['category'] = null);
    expect(nullable.type, '');
  });

  test('all 15 immutable slugs preserve original keys and seed coordinates',
      () {
    final seed = File('supabase/seed_spots.sql').readAsStringSync();
    expect(SpotIdentity.localIdsBySlug.length, 15);
    expect(SpotIdentity.localIdsBySlug.values.toSet().length, 15);
    for (final entry in SpotIdentity.localIdsBySlug.entries) {
      final local = originalSpots.singleWhere((s) => s.id == entry.value);
      final remote = Spot.fromJson(row(slug: entry.key)..['name'] = 'Renamed');
      expect(remote.id, local.id);
      final seedRow = seed.split('\n').singleWhere(
            (line) => line.startsWith("  ('${entry.key}',"),
          );
      final point =
          RegExp(r'st_makepoint\(([\d.]+), ([\d.]+)\)').firstMatch(seedRow)!;
      expect(double.parse(point[1]!), local.lng);
      expect(double.parse(point[2]!), local.lat);
      expect(seedRow, contains('10000, NULL, true)'));
    }
  });

  test('remote definitions retain persisted captured/uncaptured keys',
      () async {
    SharedPreferences.setMockInitialValues({
      'captured_spot_ids': ['12'],
    });
    final captured = Spot.fromJson(row());
    final uncaptured = Spot.fromJson(row(slug: 'arcul-de-triumf'));
    final ids = await CaptureStore.getCapturedIds();
    // These are the exact IDs used by Map's existing marker icon selection.
    expect(ids.contains(captured.id), isTrue);
    expect(ids.contains(uncaptured.id), isFalse);
    expect(await CaptureStore.isCaptured(captured.id), isTrue);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList('captured_spot_ids'), ['12']);
  });

  test('new capture from remote spot keeps local identity and proof format',
      () async {
    final capture = await CaptureStore.saveCapture(
      spot: Spot.fromJson(row()),
      imagePath: '/local/capture.jpg',
      userLatitude: 44.4521,
      userLongitude: 26.0857,
      distanceMeters: 500,
    );
    expect(capture.spotId, '12');
    expect(capture.proofId, startsWith('BP-12-'));
    expect((await CaptureStore.getCaptures()).single.imagePath,
        '/local/capture.jpg');
    expect(await CaptureStore.isCaptured('12'), isTrue);
  });

  test('inactive rows are excluded; successful empty catalog stays empty', () {
    expect(SupabaseSpotRepository.decodeRows([row()..['is_active'] = false]),
        isEmpty);
    SpotService.useRemoteSpots(SupabaseSpotRepository.decodeRows([]));
    expect(SpotService.getSpots(), isEmpty);
    // Historical records can still resolve without creating active markers.
    expect(SpotService.resolveSpotId(spotName: 'Piața Victoriei'), '12');
  });

  test('active catalog changes atomically and retains historical name aliases',
      () {
    final renamed = row()..['name'] = 'New name';
    SpotService.useRemoteSpots(SupabaseSpotRepository.decodeRows([renamed]));
    expect(SpotService.getSpots().single.name, 'New name');
    expect(SpotService.findSpotByIdOrName(spotId: '12')!.name, 'New name');
    expect(SpotService.resolveSpotId(spotName: 'Piața Victoriei'), '12');
    expect(() {
      SpotService.useRemoteSpots(SupabaseSpotRepository.decodeRows([
        row(),
        row()..['latitude'] = null,
      ]));
    }, throwsA(isA<SpotLoadException>()));
    expect(SpotService.getSpots().single.name, 'New name');
  });

  test('malformed/unknown rows and duplicate identities fail safely', () {
    final invalidValues = <String, dynamic>{
      'id': '12',
      'slug': 'unknown-spot',
      'name': '',
      'latitude': double.nan,
      'longitude': 181,
      'capture_radius_m': 0,
      'is_active': 'true',
      'category': 3,
      'description': [],
      'image_url': 5,
    };
    for (final entry in invalidValues.entries) {
      expect(
          () => SupabaseSpotRepository.decodeRows([
                row()..[entry.key] = entry.value,
              ]),
          throwsA(isA<SpotLoadException>()),
          reason: entry.key);
    }
    for (final invalid in [
      null,
      {},
      ['invalid'],
      [row(), row()]
    ]) {
      expect(() => SupabaseSpotRepository.decodeRows(invalid),
          throwsA(isA<SpotLoadException>()));
    }
  });
}
