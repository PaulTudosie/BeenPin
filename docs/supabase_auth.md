# Supabase authentication foundation

`main.dart` keeps the existing dart-define configuration and initializes Supabase
before building the app. No extra dependencies, keys, or custom session storage
were added.

`AuthService` wraps the initialized client. `ProfileRepository` reads
`public.profiles` by authenticated user ID and updates only the current user's
row. It never inserts a profile. Existing database triggers and RLS remain in
charge of creation and authorization.

`AuthController` is the single authenticated profile source. Widgets can use
`AuthScope.of(context)` for the controller or `AuthScope.profileOf(context)` for
the loaded `AppProfile`. This is intentionally separate from `CurrentUserProfile`
and all local demo identity and persistence.

`AuthGate`, installed through `MaterialApp.builder`, surrounds the root Navigator.
It shows sign-in when signed out, a progress indicator during profile loading,
recoverable errors for missing/unreadable profiles, and the existing HomeShell
after loading succeeds, following the original animated BeenPin launch splash.
The splash runs once per authenticated app entry, including restored sessions;
tab changes, normal navigation, and brief background/resume do not replay it.
Removing the Navigator on sign-out also removes pushed
screens and dialogs. Stale profile responses cannot reinstate a signed-out user.

Signup sends username and display_name metadata, waits for the trigger-created
row, and updates that row with the submitted names. A
`beenpin_profile_setup_pending` metadata flag is cleared after a successful
update. The flag only tracks setup, never grants permission. Failed updates can
be retried with another username; confirmation and restart can resume setup.
If confirmation is enabled and signup has no session, the UI asks the user to
confirm their email and sign in. No profile write occurs without a session.

The header menu's **Account** dialog shows the fetched display name and username
and offers **Sign out**. Local captures, rewards, profiles, and preferences are
not deleted. Journey/feed still use the local Camil identity intentionally.

Supabase Flutter's existing default storage persists sessions and restores them
at initialization. Each fresh app instance fetches its profile again. The old
opening-screen preferences are no longer consulted; old local data is retained.

## Device acceptance checks

Run the same Android build/config with
`flutter run --dart-define-from-file=config/supabase.local.json`.

1. Sign in with the existing test account. Open header menu > Account and verify
   the database values `Camil` and `@camil`.
2. Force-close and relaunch. Verify the app opens without sign-in and Account
   shows the same fetched profile.
3. Sign out, force-close, and relaunch. Verify sign-in remains visible and local
   feature data has not been deleted.
4. Submit an incorrect password and empty fields. Verify friendly errors.
5. Create a new account. Verify its trigger-created profile has the submitted
   names and its session survives restart.
6. Try an existing username. Verify a clean error and retry with another name.
7. Test offline profile loading and retry after reconnecting.

Automated tests cover state transitions and route removal using fakes. They do
not verify the live database trigger, RLS, credentials, or Android process-restart
persistence. Those require the device checks above. No backend schema changes
are part of this slice.
