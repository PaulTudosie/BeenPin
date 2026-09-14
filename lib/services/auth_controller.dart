import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:been/models/app_profile.dart';
import 'auth_service.dart';
import 'auth_messages.dart';
import 'profile_repository.dart';

class AuthController extends ChangeNotifier {
  AuthController(this.auth, this.profiles) {
    _subscription = auth.authStateChanges.listen((state) {
      // Signup emits signedIn before its profile UPDATE has completed.
      if (!_submitting) unawaited(loadProfile());
    }, onError: (Object error, StackTrace stack) {
      if (_disposed) return;
      errorMessage = authErrorMessage(error);
      loading = false;
      notifyListeners();
    });
    unawaited(loadProfile());
  }

  final AuthService auth;
  final ProfileRepository profiles;
  late final StreamSubscription<AuthState> _subscription;
  AppProfile? profile;
  bool loading = true;
  bool _submitting = false;
  bool _disposed = false;
  int _generation = 0;
  String? errorMessage;
  String? notice;
  bool get busy => _submitting;
  bool get signedIn => auth.currentSession != null;
  bool get needsSetup =>
      signedIn &&
      auth.currentUser?.userMetadata?['beenpin_profile_setup_pending'] == true;

  Future<void> loadProfile() async {
    final generation = ++_generation;
    final userId = auth.currentSession?.user.id;
    if (userId == null) {
      profile = null;
      loading = false;
      errorMessage = null;
      _notify();
      return;
    }
    if (profile?.id == userId && !needsSetup) return;
    profile = null;
    loading = true;
    errorMessage = null;
    _notify();
    try {
      final loaded = await profiles.getProfile(userId);
      if (!_isCurrent(generation, userId)) return;
      if (loaded == null) {
        errorMessage = 'Your account is signed in, but its profile is missing. '
            'Retry, or sign out and contact support if this continues.';
      } else if (!needsSetup) {
        profile = loaded;
      }
    } catch (_) {
      if (!_isCurrent(generation, userId)) return;
      errorMessage =
          'We could not load your profile. Check your connection and retry.';
    }
    if (!_isCurrent(generation, userId)) return;
    loading = false;
    _notify();
  }

  Future<void> signIn(String email, String password) => _submit(() async {
        await auth.signInWithEmailAndPassword(email, password);
      });

  Future<void> signUp(
          {required String email,
          required String password,
          required String username,
          required String displayName}) =>
      _submit(() async {
        final response = await auth.signUpWithEmailAndPassword(
            email: email,
            password: password,
            username: username,
            displayName: displayName);
        if (response.session == null) {
          notice = 'Check your email to confirm your account, then sign in. '
              'If you already have an account, sign in instead.';
          return;
        }
        await _saveProfile(username, displayName);
      });

  Future<void> completeProfile(String username, String displayName) =>
      _submit(() => _saveProfile(username, displayName));

  Future<void> _saveProfile(String username, String displayName) async {
    final saved = await profiles.updateOwnProfile(
        username: username, displayName: displayName);
    if (saved == null) {
      errorMessage = 'Your profile is not available yet. Retry in a moment. '
          'If this continues, sign out and contact support.';
      return;
    }
    await auth.finishProfileSetup();
    // Reload the database row before admitting the user to the app.
  }

  Future<void> signOut() => _submit(() async {
        await auth.signOut();
        profile = null;
      });

  Future<void> _submit(Future<void> Function() operation) async {
    if (_submitting) return;
    _submitting = true;
    ++_generation;
    errorMessage = null;
    notice = null;
    _notify();
    try {
      await operation();
    } catch (error) {
      errorMessage = authErrorMessage(error);
    } finally {
      _submitting = false;
      if (!_disposed) {
        // Preserve actionable signup errors while showing recoverable setup.
        final operationError = errorMessage;
        await loadProfile();
        if (operationError != null) errorMessage = operationError;
        _notify();
      }
    }
  }

  bool _isCurrent(int generation, String id) =>
      !_disposed &&
      generation == _generation &&
      auth.currentSession?.user.id == id;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    ++_generation;
    unawaited(_subscription.cancel());
    super.dispose();
  }
}
