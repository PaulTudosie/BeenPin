/// The authenticated public.profiles row, separate from local demo identity.
class AppProfile {
  final String id;
  final String username;
  final String displayName;
  final String? avatarUrl;
  final String? bio;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const AppProfile(
      {required this.id,
      required this.username,
      required this.displayName,
      this.avatarUrl,
      this.bio,
      this.createdAt,
      this.updatedAt});

  factory AppProfile.fromJson(Map<String, dynamic> json) => AppProfile(
        id: json['id'] as String,
        username: json['username'] as String? ?? '',
        displayName: json['display_name'] as String? ?? '',
        avatarUrl: json['avatar_url'] as String?,
        bio: json['bio'] as String?,
        createdAt: DateTime.tryParse(json['created_at'] as String? ?? ''),
        updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? ''),
      );
}
