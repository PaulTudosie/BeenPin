import 'package:been/models/social_user.dart';
import 'package:been/services/capture_store.dart';

class MockSocialService {
  static const List<SocialUser> users = [
    SocialUser(
      id: 'camil',
      name: 'Camil',
      city: 'Bucharest, Romania',
      levelName: 'Walker',
      handle: '@camil.frames',
      avatarPath: null,
      tagline: 'Quiet city corners, street textures, and coffee-fuelled walks.',
    ),
    SocialUser(
      id: 'abel',
      name: 'Abel',
      city: 'Bucharest, Romania',
      levelName: 'Traveler',
      handle: '@abel.afterrain',
      avatarPath: null,
      tagline:
          'I collect soft light, messy facades, and places worth returning to.',
    ),
    SocialUser(
      id: 'georgiana',
      name: 'Georgiana',
      city: 'Cluj-Napoca, Romania',
      levelName: 'Explorer',
      handle: '@georgiana.cityfilm',
      avatarPath: null,
      tagline: 'Urban film energy, late sunsets, and spots with attitude.',
    ),
    SocialUser(
      id: 'Paul',
      name: 'Paul',
      city: 'Timișoara, Romania',
      levelName: 'Pathfinder',
      handle: '@paul.wanders',
      avatarPath: null,
      tagline:
          'Design-minded wandering with a thing for hidden entries and old signs.',
    ),
  ];

  static SocialUser userForCapture(CaptureRecord record, int index) {
    final seed = int.tryParse(record.spotId) ?? index;
    return users[seed % users.length];
  }

  static List<CaptureRecord> capturesForUser(
    List<CaptureRecord> captures,
    SocialUser user,
  ) {
    return captures.where((capture) {
      final assigned = userForCapture(capture, captures.indexOf(capture));
      return assigned.id == user.id;
    }).toList();
  }

  static List<SocialUser> searchUsers(String query) {
    final normalized = query.toLowerCase().trim();
    if (normalized.isEmpty) return users;

    return users.where((user) {
      return user.name.toLowerCase().contains(normalized) ||
          user.handle.toLowerCase().contains(normalized) ||
          user.city.toLowerCase().contains(normalized) ||
          user.levelName.toLowerCase().contains(normalized);
    }).toList();
  }
}
