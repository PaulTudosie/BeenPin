import 'package:been/models/social_user.dart';
import 'package:been/services/capture_store.dart';
import 'package:been/services/current_user_profile.dart';

class MockSocialService {
  static const List<SocialUser> users = [
    CurrentUserProfile.user,
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

  static List<CaptureRecord> capturesForUser(
    List<CaptureRecord> captures,
    SocialUser user,
  ) {
    return captures.where((capture) => capture.author.id == user.id).toList();
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
