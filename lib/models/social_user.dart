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

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'city': city,
        'levelName': levelName,
        'handle': handle,
        'avatarPath': avatarPath,
        'tagline': tagline,
      };

  factory SocialUser.fromJson(Map<String, dynamic> json) => SocialUser(
        id: json['id'] as String,
        name: json['name'] as String,
        city: json['city'] as String? ?? '',
        levelName: json['levelName'] as String? ?? '',
        handle: json['handle'] as String? ?? '',
        avatarPath: json['avatarPath'] as String?,
        tagline: json['tagline'] as String? ?? '',
      );
}
