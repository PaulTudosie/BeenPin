# Remote Journey

## Audit and scope

Journey previously loaded `CaptureStore.getUserCaptures(auth profile id)` once
per screen instance. Records were newest first and each grid card, full-screen
preview and avatar picker assumed a local file. The header capture count and
rank consumed that local list. Profile identity comes from authenticated
`AppProfile`; avatar path and bio overrides remain separate user-scoped local
preferences. Search also used local captures for its own captured-place results.
The shell originally recreated Journey on tab selection. The blink fix below
retains its state and forwards the tab refresh tick instead.

This migration changes Flutter presentation/read logic, tests and documentation.
SQL, policies, bucket settings, RPCs, spots, Auth, splash, Map styling, Hidden,
Pins/feed, reward ownership, QR, redemption and Partner Mode are unchanged.

## Source of truth and architecture

- `public.captures` is the authenticated user's authoritative history, including
  captures with no photo. A fresh install needs no compatibility records.
- `CaptureRepository.getOwnCaptures` uses RLS and the initiating session token.
  Its exact SELECT is
  `capture_id:id,spot_id,client_capture_id,captured_at,spot_slug:spot_slug_snapshot,spot_name:spot_name_snapshot,photo_storage_path`.
  No geography or distance proof is requested. Reads retain the existing
  500-row pagination, ordered by `captured_at DESC, id ASC`.
- `RemoteCapture` retains its RPC fields. Distance is nullable for list reads;
  create RPC parsing still requires and validates distance for the existing
  capture/reward flow.
- `JourneyRepository` composes a presentation-safe `JourneyCapture` list using
  remote UUID, spot UUID, slug/name snapshots, server timestamp and photo path.
  It has no precise coordinates, proof IDs, QR or rewards. Local cache read/file
  errors do not invalidate the remote list.
- `JourneyController` owns loading, empty/success, recoverable query error,
  photo resolution and refresh. Widgets never query Supabase directly.
- Remote UUIDs are deduplicated; local records cannot add cards. Ordering uses
  server time with UUID as a deterministic tie-breaker.

## Private photos and URL lifetime

`SupabasePrivateCapturePhotos` uses the authenticated client to request a
30-minute signed URL from private `capture-photos`. Before sending a request it
requires the current owner and validates the exact canonical path
`<owner UUID>/<capture UUID>/original.<jpg|jpeg|png|webp>`. It pins the request to
the initiating session token and checks the owner again after completion.

`photo_storage_path` is the identity. Signed URLs exist only in controller
memory, with no serialization, SharedPreferences write or shared permanent URL
cache. Tab re-entry and resume reuse cached URLs younger than 25 minutes while
refreshing capture rows. Renewal replaces URLs without clearing the visible
image; pull-to-refresh/Retry explicitly invalidate URL entries. Disposal or account changes
discard items/URLs. Image widgets use Flutter's normal in-memory image cache;
no disk image cache is introduced. Previously issued signed URLs remain valid
until their server expiry, but are never reused for another account.

Rows/counts render before URL requests finish. Three workers resolve photos
concurrently. URL failure affects only that photo. Network image load/decode
failure also falls back safely. Pull down to retry photos, including images
whose URL resolved but whose download failed.

| Remote photo | Matching usable local file | Display |
| --- | --- | --- |
| Available | Either | Remote image, local/placeholder while loading |
| Missing/pending | Yes | Temporary local image |
| Missing/pending | No | Capture card with image placeholder |
| Access/download failed | Yes | Local fallback |
| Access/download failed | No | Capture card with image placeholder |

## Local fallback and legacy data

Only `capture_records_v2:<auth UUID>` is read, and each record's author must
match that UUID. The remote capture UUID must equal `remoteCaptureId`. Names,
approximate timestamps, usernames and local spot IDs never establish ownership.
The file must exist. An unrelated local record never contributes a card/count.

Legacy device-wide keys are neither read, claimed, deleted nor migrated by
Journey. Old JSON remains readable by the existing compatibility parser. No
Storage path is manufactured and no historical photo upload is performed.

## Account isolation, refresh and metrics

AuthScope changes clear the controller list synchronously before loading the
new account. Generation guards reject late capture/photo results, including
A-to-B-to-A races. Query failure displays Retry instead of local history.

The existing shell refresh-on-tab-selection reconciles history after a new
capture, even if local persistence/upload failed. The controller also listens
to the existing `CapturePhotoStorage.changes` notifier (200 ms debounce). Photo
queue activity and successful attachment refresh the same remote item. Resume,
tab selection and pull-to-refresh provide further reconciliation paths. Same-user
refresh keeps existing rows/photos visible, including on a recoverable query
error. Simultaneous loads share one future; queue changes during a load request
one follow-up query. No
refresh operation creates captures or grants rewards.

Capture count and rank now use the remote list length. The exact existing
thresholds remain 3, 6, 10, 20, 30 and 45. Rank-detail navigation receives that
same remote count. Local engagement indicators keep their existing spot-key
mapping when the remote spot catalog is available; they are not migrated.

Avatar selection remains local: choose from valid local fallback photos already
matched to remote Journey entries. On a fresh device without such files, the
existing neutral avatar stays visible and tapping it explains that a local
capture is needed. Avatar storage and local bio overrides are not synchronized
by this task; authenticated profile identity remains unchanged.

## Search and future public feed boundary

Only search's own captured-place source changes to `JourneyRepository`. It
loads once per account/search surface, supports Retry and keys async state by
owner. Own-history results open private Journey. Mock/public profile navigation
receives no private captures. Spot and mock-user searching remain in place.
Pins remains the separate local compatibility/social implementation. A future
public feed requires `public.posts` and deliberate public/social photo access;
other users must never SELECT this private capture history.

## Automated verification

Initial migration validation: modified Dart files formatted, `flutter analyze`
reported no issues, all 81 tests passed, and `git diff --check` passed.

`test/journey_remote_test.dart` covers remote reconstruction/order, photo path
mapping, remote image representation, missing/failed photos, safe local fallback,
deduplication, unchanged legacy JSON/storage, account-switch/list/photo races,
remote count/rank, photo notification refresh, query Retry and signed URL
namespace/expiration/non-persistence using a loopback fake Supabase service.
It also verifies bounded photo concurrency, renewal before URL expiration,
search account isolation and Journey count/rank/Retry at a phone-sized viewport.
The existing capture, photo queue, author/Pins, reward and partner suites remain
regression coverage. Automated tests do not verify deployed RLS or real Android
image rendering; the following device tests remain required.

## Exact manual Android tests remaining

### A — Current device / Camil
1. Sign in as Camil and open Journey.
2. Compare card UUIDs/count with Camil's own remote captures using authorized
   backend inspection; verify newest server timestamp is first.
3. Verify the known uploaded photo renders, including when opened full-size.
4. Verify an older NULL-photo capture remains visible with local fallback or
   placeholder. Verify no duplicate card and the rank matches remote count.

### B — Abel
1. Sign out Camil; sign in Abel on the same phone.
2. Open Journey while recording the transition if helpful.
3. Verify only Abel's remote captures/count/rank and own Storage photos appear;
   Camil's cards/photos must never flash under Abel's identity.
4. Search for a Camil-only captured-place name and verify it is absent from
   own captured results (a public location result can still exist).

### C — Switch back
1. Sign out Abel; sign in Camil.
2. Verify Camil's Journey restores and no Abel cards/photos flash while loading.
3. Repeat with a slow network and with a photo preview/avatar picker open.

### D — Cold start
1. Kill the app while authenticated, then reopen.
2. Verify the existing splash, remote Journey history and private photos load.
3. Background for over 30 minutes; resume and verify photos reload correctly.

### E — New capture and pending photo
1. Capture a new uncaptured spot, complete upload/attachment and the existing
   reward flow, then open Journey without restarting.
2. Verify exactly one new card with remote photo and incremented count.
3. For another capture, disconnect after remote creation and before upload;
   continue through the existing pending flow. Open Journey after connectivity
   returns; verify one capture with local fallback or placeholder.
4. Tap Retry Upload; verify that same card transitions to its Storage photo,
   without an extra card or reward. Confirm QR and Partner Mode are unchanged.

### F — Fresh device / simulated local loss
1. Prefer a fresh emulator/device; do not delete database/account data or legacy
   history on the existing phone.
2. Log in with an existing account, then open Journey.
3. Verify all remote captures return without previous preferences/cache.
4. Verify uploaded photos return and NULL-photo captures remain placeholders.
5. Verify avatar remains neutral if its local file is unavailable.

### G — Recovery
1. Disable networking and refresh Journey. Verify clear error and Retry.
2. Restore networking and tap Retry; verify the correct account history returns.
3. In a controlled test, make one photo inaccessible; verify other captures
   remain usable and pull-to-refresh retries the failed image.
4. Recheck Pins, My Rewards, reward selection/redemption and Partner Mode.

## Remaining limits

No durable offline remote-history cache, avatar migration, historical photo
backfill or public posts exists. All capture pages load before rendering;
future large histories can add incremental pagination behind the repository.
Private photo requests are bounded per active Journey controller. The current
small Bucharest dataset retains the existing city label and grid design.

## Tab-entry image blink fix

Code inspection found this sequence: tab tick changed the Journey subtree key,
disposing its controller and URLs; the new controller queried rows, displayed
local fallback, and signed URLs again. `Image.network` then replaced that local
widget. Its loading builder interpreted null chunk progress as image readiness,
although no decoded frame necessarily existed yet. `gaplessPlayback: false`
also cleared the previous image during replacement. Tab entry alone initiated
one query; resume and queue notifications could independently overlap it.

Journey now retains its screen/controller across tab ticks. Capture cards and
photos use stable UUID keys with grid index reconciliation. A persistent local
layer stays mounted until the network frame decodes; subsequent URL changes
retain the previous decoded remote frame with gapless playback. No fade or
layout redesign was introduced. URL caching remains controller-local, keyed by
Storage path, cleared on auth change, and renewed against the original request
deadline rather than postponed on every tab entry. Failed renewal backs off one
minute. Private signing, ownership and backend security are unchanged.

Regression coverage includes delayed first frames, local-to-remote handoff,
remote URL replacement, state identity on tab refresh, cached URL reuse,
same-user list retention, refresh deduplication, one queued follow-up and account
switch isolation.

Blink-fix validation: modified Dart files formatted, `flutter analyze` clean,
all 85 tests passed, and `git diff --check` passed.

Manual confirmation on Android (not performed by automated tests):
1. Sign in as Abel and open Journey; watch the latest Storage-backed capture
   that also has a local photo. It should go directly from local to decoded
   remote content with no blank frame.
2. Switch Map → Journey ten times and reselect Journey. The photo should remain
   stable with no loading-list flash; repeat on a slow network.
3. Pull to refresh while watching that photo. The old image should remain until
   its replacement decodes. Background/resume and repeat after 25 minutes.
4. Retry a pending photo upload while Journey is open; verify the existing card
   updates once with no duplicate and without clearing other photos.
5. Switch Abel → Camil → Abel. Previous-account cards must clear immediately;
   each account must restore only its own history/photos.
