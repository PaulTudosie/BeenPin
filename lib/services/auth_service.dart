import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  AuthService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;
  User? get currentUser => _client.auth.currentUser;
  Session? get currentSession => _client.auth.currentSession;
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  Future<AuthResponse> signInWithEmailAndPassword(
          String email, String password) =>
      _client.auth.signInWithPassword(email: email.trim(), password: password);

  Future<AuthResponse> signUpWithEmailAndPassword(
          {required String email,
          required String password,
          required String username,
          required String displayName}) =>
      _client.auth.signUp(email: email.trim(), password: password, data: {
        'username': username.trim(),
        'display_name': displayName.trim(),
        // Recovery across confirmation, failed profile writes, and restarts.
        // This is onboarding state only, never an authorization claim.
        'beenpin_profile_setup_pending': true,
      });

  Future<void> finishProfileSetup() async {
    await _client.auth.updateUser(UserAttributes(data: {
      'beenpin_profile_setup_pending': false,
    }));
  }

  Future<void> signOut() => _client.auth.signOut();
}
