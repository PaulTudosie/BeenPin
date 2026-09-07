import 'dart:convert';

import 'package:been/models/spot.dart';
import 'package:been/services/capture_store.dart';
import 'package:been/services/current_user_profile.dart';
import 'package:been/services/mock_social_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'new capture keeps Journey author and avatar after storage reload',
    () async {
      await CaptureStore.saveAvatarPath('/profile/camil.jpg');
      final capture = await CaptureStore.saveCapture(
        spot: Spot(
          id: '2',
          name: 'Floreasca Park',
          lat: 44,
          lng: 26,
          type: 'park',
        ),
        imagePath: '/captures/park.jpg',
        userLatitude: 44,
        userLongitude: 26,
        distanceMeters: 0,
      );
      expect(capture.author.id, CurrentUserProfile.user.id);
      expect(capture.author.name, 'Camil');
      final prefs = await SharedPreferences.getInstance();
      final persisted = prefs.getStringList('capture_records')!;
      // Recreate preferences using only persisted bytes, as on a fresh launch.
      SharedPreferences.setMockInitialValues({'capture_records': persisted});
      final restored = (await CaptureStore.getCaptures()).single;
      expect(restored.author.name, 'Camil');
      expect(restored.author.avatarPath, '/profile/camil.jpg');
      expect(restored.proofId, capture.proofId);
      expect(
        MockSocialService.capturesForUser([restored], CurrentUserProfile.user),
        [restored],
      );
      expect(
        MockSocialService.capturesForUser([
          restored,
        ], MockSocialService.users[2]),
        isEmpty,
      );
    },
  );

  test(
    'legacy local captures are backfilled once; explicit demo authors survive',
    () async {
      final legacy = {
        'spotId': '2',
        'spotName': 'Floreasca Park',
        'spotType': 'park',
        'imagePath': '/captures/park.jpg',
        'capturedAt': '2026-09-08T10:00:00.000',
      };
      final demo = {
        ...legacy,
        'spotId': 'demo',
        'author': MockSocialService.users[2].toJson(),
      };
      SharedPreferences.setMockInitialValues({
        'capture_records': [jsonEncode(legacy), jsonEncode(demo)],
        'journey_avatar_path': '/profile/old.jpg',
      });
      final records = await CaptureStore.getCaptures();
      expect(records.firstWhere((r) => r.spotId == '2').author.name, 'Camil');
      expect(
        records.firstWhere((r) => r.spotId == 'demo').author.name,
        'Georgiana',
      );
      final prefs = await SharedPreferences.getInstance();
      final persisted = prefs.getStringList('capture_records')!;
      expect(
        persisted.map((v) => jsonDecode(v)['author']),
        everyElement(isNotNull),
      );
      SharedPreferences.setMockInitialValues({'capture_records': persisted});
      final reloaded = await CaptureStore.getCaptures();
      expect(
        reloaded.firstWhere((r) => r.spotId == '2').author.avatarPath,
        '/profile/old.jpg',
      );
      expect(
        reloaded.firstWhere((r) => r.spotId == 'demo').author.id,
        'georgiana',
      );
    },
  );
}
