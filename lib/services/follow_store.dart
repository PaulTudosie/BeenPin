import 'package:shared_preferences/shared_preferences.dart';

class FollowStore {
  static const _followedUsersKey = 'followed_users';

  static Future<Set<String>> getFollowedUserIds() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_followedUsersKey) ?? const <String>[])
        .toSet();
  }

  static Future<bool> isFollowing(String userId) async {
    final followed = await getFollowedUserIds();
    return followed.contains(userId);
  }

  static Future<bool> toggleFollow(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final followed = await getFollowedUserIds();

    if (followed.contains(userId)) {
      followed.remove(userId);
    } else {
      followed.add(userId);
    }

    await prefs.setStringList(_followedUsersKey, followed.toList());
    return followed.contains(userId);
  }
}
