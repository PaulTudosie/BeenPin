import 'dart:async';
import 'package:been/app/opening/opening_screen.dart';
import 'package:been/features/auth/auth_gate.dart';
import 'package:been/models/app_profile.dart';
import 'package:been/services/auth_controller.dart';
import 'package:been/services/auth_messages.dart';
import 'package:been/services/auth_service.dart';
import 'package:been/services/profile_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const profile = AppProfile(
    id: 'user-1', username: 'remote_name', displayName: 'Remote Name');
Session session({bool pending = false}) => Session(
    accessToken: 'test-token',
    tokenType: 'bearer',
    user: User(
        id: 'user-1',
        appMetadata: {},
        userMetadata: {'beenpin_profile_setup_pending': pending},
        aud: 'authenticated',
        createdAt: '2026-09-14T00:00:00Z'));

class FakeAuth extends AuthService {
  FakeAuth(this.sessionValue)
      : super(
            client: SupabaseClient('https://example.invalid', 'test-key',
                authOptions: const AuthClientOptions(autoRefreshToken: false)));
  Session? sessionValue;
  final events = StreamController<AuthState>.broadcast(sync: true);
  Completer<void>? signupWait;
  Object? signInError;
  bool confirmationRequired = false;
  @override
  Session? get currentSession => sessionValue;
  @override
  User? get currentUser => sessionValue?.user;
  @override
  Stream<AuthState> get authStateChanges => events.stream;
  @override
  Future<AuthResponse> signInWithEmailAndPassword(
      String email, String password) async {
    if (signInError != null) throw signInError!;
    sessionValue = session();
    events.add(AuthState(AuthChangeEvent.signedIn, sessionValue));
    return AuthResponse(session: sessionValue);
  }

  @override
  Future<AuthResponse> signUpWithEmailAndPassword(
      {required String email,
      required String password,
      required String username,
      required String displayName}) async {
    if (confirmationRequired) return AuthResponse();
    sessionValue = session(pending: true);
    events.add(AuthState(AuthChangeEvent.signedIn, sessionValue));
    await signupWait?.future;
    return AuthResponse(session: sessionValue);
  }

  @override
  Future<void> finishProfileSetup() async {
    sessionValue = session();
  }

  @override
  Future<void> signOut() async {
    sessionValue = null;
    events.add(AuthState(AuthChangeEvent.signedOut, null));
  }
}

class FakeProfiles extends ProfileRepository {
  FakeProfiles()
      : super(
            client: SupabaseClient('https://example.invalid', 'test-key',
                authOptions: const AuthClientOptions(autoRefreshToken: false)));
  AppProfile? value = profile;
  Object? updateError;
  Completer<AppProfile?>? fetch;
  int reads = 0;
  @override
  Future<AppProfile?> getProfile(String userId) async {
    reads++;
    return fetch == null ? value : await fetch!.future;
  }

  @override
  Future<AppProfile?> updateOwnProfile(
      {required String username, required String displayName}) async {
    if (updateError != null) throw updateError!;
    return value;
  }
}

void main() {
  Future<void> settle() => Future<void>.delayed(Duration.zero);

  for (final restored in [false, true]) {
    testWidgets('authenticated splash plays once (restored session: $restored)',
        (tester) async {
      final auth = FakeAuth(restored ? session() : null);
      final controller = AuthController(auth, FakeProfiles());
      addTearDown(controller.dispose);
      await tester.pump();
      await tester.pumpWidget(MaterialApp(
        builder: (_, child) => AuthGate(controller: controller, child: child!),
        home: const BeenPinOpeningScreen(
            child: Scaffold(body: Text('Authenticated home'))),
      ));
      if (!restored) {
        expect(find.byType(BeenPinOpeningScreen), findsNothing);
        await controller.signIn('test@example.invalid', 'password');
        await tester.pump();
      }
      expect(find.text('Authenticated home'), findsNothing);
      expect(find.byType(BeenPinOpeningScreen), findsOneWidget);
      await tester.runAsync(() => precacheImage(
          const AssetImage('assets/branding/beenpin_pin.png'),
          tester.element(find.byType(BeenPinOpeningScreen))));
      // Explicit frames advance both the original delayed beats and tickers.
      for (var frame = 0; frame < 25; frame++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('Authenticated home'), findsOneWidget);
      expect(find.byType(Image), findsNothing);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      auth.events
          .add(AuthState(AuthChangeEvent.tokenRefreshed, auth.currentSession));
      await tester.pump();
      expect(find.text('Authenticated home'), findsOneWidget);
      expect(find.byType(Image), findsNothing);

      await controller.signOut();
      await tester.pumpAndSettle();
      expect(find.byType(BeenPinOpeningScreen), findsNothing);
      await controller.signIn('test@example.invalid', 'password');
      await tester.pump();
      expect(find.text('Authenticated home'), findsNothing);
      expect(find.byType(BeenPinOpeningScreen), findsOneWidget);
      for (var frame = 0; frame < 25; frame++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('Authenticated home'), findsOneWidget);
    });
  }

  test('restored session reloads the real profile and sign out clears it',
      () async {
    final auth = FakeAuth(session());
    final repo = FakeProfiles();
    final controller = AuthController(auth, repo);
    addTearDown(controller.dispose);
    await settle();
    expect(controller.profile?.username, 'remote_name');
    expect(repo.reads, 1);
    await controller.signOut();
    expect(controller.profile, isNull);
    expect(controller.signedIn, isFalse);
  });

  test('late profile response cannot restore a signed out user', () async {
    final auth = FakeAuth(session());
    final repo = FakeProfiles()..fetch = Completer<AppProfile?>();
    final controller = AuthController(auth, repo);
    addTearDown(controller.dispose);
    await controller.signOut();
    repo.fetch!.complete(profile);
    await settle();
    expect(controller.profile, isNull);
    expect(controller.loading, isFalse);
  });

  test('signup waits for profile update and duplicate username is recoverable',
      () async {
    final auth = FakeAuth(null)..signupWait = Completer<void>();
    final repo = FakeProfiles()
      ..updateError =
          const PostgrestException(message: 'private detail', code: '23505');
    final controller = AuthController(auth, repo);
    addTearDown(controller.dispose);
    final signup = controller.signUp(
        email: 'test@example.invalid',
        password: 'password',
        username: 'taken',
        displayName: 'Name');
    expect(controller.profile, isNull);
    expect(repo.reads, 0);
    auth.signupWait!.complete();
    await signup;
    expect(controller.profile, isNull);
    expect(controller.needsSetup, isTrue);
    expect(controller.errorMessage, contains('username is already taken'));
    repo.updateError = null;
    await controller.completeProfile('available', 'Name');
    expect(controller.profile, profile);
    expect(controller.needsSetup, isFalse);
  });

  test('missing profile is recoverable and never invents identity', () async {
    final repo = FakeProfiles()..value = null;
    final controller = AuthController(FakeAuth(session()), repo);
    addTearDown(controller.dispose);
    await settle();
    expect(controller.profile, isNull);
    expect(controller.errorMessage, contains('profile is missing'));
    repo.value = profile;
    await controller.loadProfile();
    expect(controller.profile, profile);
  });

  test('confirmation-required signup stays signed out without profile writes',
      () async {
    final auth = FakeAuth(null)..confirmationRequired = true;
    final repo = FakeProfiles()..updateError = StateError('Must not write');
    final controller = AuthController(auth, repo);
    addTearDown(controller.dispose);
    await controller.signUp(
        email: 'test@example.invalid',
        password: 'password',
        username: 'name',
        displayName: 'Name');
    expect(controller.signedIn, isFalse);
    expect(controller.profile, isNull);
    expect(controller.errorMessage, isNull);
    expect(controller.notice, contains('confirm your account'));
    expect(repo.reads, 0);
  });

  test('auth stream errors are handled without exposing exception text',
      () async {
    final auth = FakeAuth(null);
    final controller = AuthController(auth, FakeProfiles());
    addTearDown(controller.dispose);
    auth.events.addError(Exception('sensitive details'));
    expect(controller.errorMessage, isNot(contains('sensitive')));
    expect(
        authErrorMessage(
            const AuthException('private detail', code: 'invalid_credentials')),
        contains('Email or password is incorrect'));
  });

  testWidgets('sign out removes pushed protected routes and returns to sign in',
      (tester) async {
    final controller = AuthController(FakeAuth(session()), FakeProfiles());
    addTearDown(controller.dispose);
    await tester.pump();
    await tester.pumpWidget(MaterialApp(
      builder: (_, child) => AuthGate(controller: controller, child: child!),
      home: Builder(
          builder: (context) => Scaffold(
              body: TextButton(
                  onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                          builder: (_) =>
                              const Scaffold(body: Text('Protected detail')))),
                  child: const Text('Open detail')))),
    ));
    await tester.tap(find.text('Open detail'));
    await tester.pumpAndSettle();
    expect(find.text('Protected detail'), findsOneWidget);
    await controller.signOut();
    await tester.pumpAndSettle();
    expect(find.text('Protected detail'), findsNothing);
    expect(find.text('Welcome back'), findsOneWidget);
    await tester.tap(find.text('Sign in'));
    await tester.pump();
    expect(find.text('Enter your email.'), findsOneWidget);
  });
}
