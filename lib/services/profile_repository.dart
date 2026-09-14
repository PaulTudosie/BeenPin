import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:been/models/app_profile.dart';

class ProfileRepository {
  ProfileRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;
  final SupabaseClient _client;
  static const _columns =
      'id,username,display_name,avatar_url,bio,created_at,updated_at';

  Future<AppProfile?> getProfile(String userId) async {
    final row = await _client
        .schema('public')
        .from('profiles')
        .select(_columns)
        .eq('id', userId)
        .maybeSingle();
    return row == null ? null : AppProfile.fromJson(row);
  }

  Future<AppProfile?> updateOwnProfile(
      {required String username, required String displayName}) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw const AuthException('No active session');
    // UPDATE only: the database trigger owns INSERT. RLS remains authoritative.
    final row = await _client
        .schema('public')
        .from('profiles')
        .update({
          'username': username.trim(),
          'display_name': displayName.trim(),
        })
        .eq('id', userId)
        .select(_columns)
        .maybeSingle();
    return row == null ? null : AppProfile.fromJson(row);
  }
}
