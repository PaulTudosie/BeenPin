class SocialUser {
  final String id;
  final String name;
  final String city;
  final String levelName;
  final String handle;
  final String? avatarPath;
  final String tagline;

  const SocialUser({
    required this.id,
    required this.name,
    required this.city,
    required this.levelName,
    required this.handle,
    required this.avatarPath,
    required this.tagline,
  });
}
