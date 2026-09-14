# BeenPin capture audit and Supabase migration design

Audit date: 2026-09-15. Scope: repository inspection and design only. No app execution, device-data reads/writes, production source edits, SQL execution, migrations, or dependency changes. The working tree was clean at the start. Supabase Auth/profiles and the deployed 15-spot catalog are accepted as the supplied current state; the live database was not inspected. Proposed database details below require verification against deployed DDL before implementation.

## 1. Current architecture and file inventory

There is no capture repository or remote capture service. `CaptureStore` is a static SharedPreferences store. The successful normal capture path is:

```text
SupabaseSpotRepository.getActiveSpots -> public.get_active_spots()
  -> Spot(remoteId UUID, slug, compatibility id)
  -> SpotService.useRemoteSpots -> Map markers
  -> Map capture action / SpotDetailScreen callback
  -> Map._verifyCaptureAccess (GPS before camera)
  -> CaptureScreen.takePicture -> preview -> Been confirmation returns file path
  -> CaptureStore.saveCapture -> capture_records, then captured_spot_ids
  -> Map reloads ID set and rebuilds markers
  -> RewardSelectionSheet -> choose -> persisted UserReward -> reward details/QR

Journey and Pins reload the same capture_records when their tabs are recreated.
My Rewards reads selected_rewards_by_proof independently of capture_records.
Partner Mode validates saved QR/proof and uses the local redemption ledger.
```

Capture cancellation returns no record. A capture is already saved before reward selection: dismissing the sheet, having no eligible offers, or reward persistence failure does not undo capture. There is no transaction spanning these steps or normal captured-pin UI to resume a dismissed selection.

| Area | Files inspected and responsibility |
| --- | --- |
| Capture and camera | `lib/services/capture_store.dart` (`CaptureRecord`, serialization, save, marker IDs, avatar/bio); `lib/capture_screen.dart` (camera/preview/confirmation) |
| Spot identity and gate | `lib/models/spot.dart`, `spot_identity.dart`; `lib/services/spot_repository.dart`, `spot_service.dart`; `lib/features/map/map_screen.dart`; `lib/features/spot/spot_detail_screen.dart`; `supabase/seed_spots.sql` |
| Journey | `lib/features/journey/journey_screen.dart`; `lib/widgets/polaroid_tile.dart`; `lib/features/level/level_path_screen.dart`, `level_details_screen.dart`; `lib/widgets/level_sheet.dart` |
| Pins and social | `lib/features/pins/pins_screen.dart`; `lib/features/profile/user_profile_screen.dart`; `lib/features/search/app_search_delegate.dart`; `lib/services/engagement_store.dart`, `saved_spot_store.dart`, `mock_social_service.dart`, `follow_store.dart`, `profile_about_store.dart`; `lib/models/social_user.dart` |
| Rewards | `lib/models/reward.dart`, `user_reward.dart`, `pilot_partner_offer.dart`; `lib/services/pilot_partner_service.dart`, `reward_selection_store.dart`, `reward_redemption_store.dart`, `reward_redemption_service.dart`, `reward_qr_codec.dart`; `lib/features/reward/reward_selection_sheet.dart`, `reward_detail_screen.dart`, `my_rewards_screen.dart`; `lib/features/map/reward_popup.dart` |
| Partner Mode | `lib/features/partner/partner_mode_screen.dart`, `partner_scanner_screen.dart`; `lib/services/partner_mode_config.dart` |
| Hidden captures | `lib/services/hidden_capture_store.dart`, `hidden_spot_service.dart`; `lib/models/hidden_spot.dart`; `lib/features/hidden/hidden_spots_screen.dart`; demo writer in `lib/features/shell/home_shell.dart` |
| Authentication and refresh | `lib/services/current_user_profile.dart`, `auth_service.dart`, `auth_controller.dart`, `profile_repository.dart`; `lib/models/app_profile.dart`; `lib/features/auth/auth_gate.dart`, `auth_scope.dart`, `account_dialog.dart`; `lib/features/shell/home_shell.dart`, `lib/widgets/top_header.dart`, `lib/main.dart`, `lib/app/app.dart` |
| Related notifications | `lib/services/notification_store.dart`, `lib/models/app_notification.dart`, `lib/features/notifications/notifications_screen.dart` |
| Tests | `test/capture_author_test.dart`, `spots_test.dart`, `user_rewards_test.dart`, `partner_mode_test.dart`, `pilot_mvp_test.dart`, `auth_test.dart` |
| Prior context | `docs/spots_audit.md`, `supabase_auth.md`, `partner_mode.md`, `partner_pilot_process.md`, `first_partner_demo_checklist.md`; dependency versions in `pubspec.lock` and generated plugin registration metadata |

Key source anchors: `CaptureStore.getCaptures`, `saveCapture`, `_buildProofId`; Map `_runVerifiedCapture`, `_verifyCaptureAccess`, `_rebuildMarkers`; `Reward.availableForSpot`, `_fromOffer`; `RewardSelectionStore._snapshot`, `_loadAndReconcile`; `LocalRewardRedemptionService.validateRewardQr`.

## 2. Effective capture model

All ten `CaptureRecord` fields are serialized into each JSON string in `capture_records`. Constructor-required does not mean validated: the store accepts a caller-supplied image path, coordinates, and distance without checking them. Legacy deserialization permits missing proof/GPS and supplies defaults for some display fields.

| Field | Dart type | Creation/source | Persistence | Consumers | Needed after restart? | Future destination |
| --- | --- | --- | --- | --- | --- | --- |
| `author` | `SocialUser` | `CurrentUserProfile.snapshot`, using saved avatar | Nested JSON in capture record; missing authors are backfilled on read | Pins author/profile routing; mock social filtering | Yes, for attribution | Real owner FK plus profile lookup; retain legacy snapshot in migration archive |
| `spotId` | `String` | `spot.id`; legacy fallback resolves name or keeps name itself | Record JSON and separate marker ID set | Map, deduplication, engagement, saved spots, profile/search, reward source | Yes | UUID FK plus preserved local compatibility mapping |
| `spotName` | `String` | Spot name at save | Record JSON | Journey/Pins labels, previews, legacy resolution | Yes for offline/historical labels | `spot_name_snapshot` plus catalog join |
| `spotType` | `String` | Spot type at save | Record JSON | Journey/Pins presentation | Yes for current display | `spot_type_snapshot` |
| `imagePath` | `String` | `CameraController.takePicture().path` returned by Been | Record JSON, not image bytes | Journey, Pins, profile, avatar picker | Yes; file must also survive | Local manifest now; private bucket/object key later |
| `capturedAt` | `DateTime` | `DateTime.now()` inside save, after confirmation | ISO-8601 string in JSON | Sort/date labels; reward expiry/proof creation | Yes | Server `captured_at`; separate client time; preserve raw legacy time |
| `userLatitude` | `double?` | Map gate position before camera; new save requires double | Record JSON | Stored private evidence; not rendered as coordinates in reward details | Needed to retain proof, not ordinary cards | Private geography point latitude |
| `userLongitude` | `double?` | Same position | Record JSON | Same | Same | Private geography point longitude |
| `distanceMeters` | `double?` | Map user-to-spot calculation | Record JSON, copied into Reward | Reward selection/detail GPS proof | Yes for historical proof | Server-computed distance; imported value unverified |
| `proofId` | `String?` | `BP-<spot.id>-<UTC millisecondsSinceEpoch>` | Record JSON, reward key/payload, ledger | Reward selection, UserReward, QR, redemption | Essential when reward exists | Immutable compatibility alias; never replace with capture UUID |

Nested `SocialUser` fields are individually serialized under `author`:

| Field/type | Created from | Restart consumers / need | Supabase treatment |
| --- | --- | --- | --- |
| `id: String` | Fixed `camil` | Author filtering/routing; yes | Not an Auth UUID; archive only, never infer ownership |
| `name: String` | Fixed `Camil` | Pins/profile attribution; yes | Profile display name; preserve historical snapshot |
| `city: String` | Fixed Bucharest label | Profile; yes for snapshot | Profile data, not private capture proof |
| `levelName: String` | Fixed `Walker` | Social profile; yes for current snapshot | Profile/progress projection, not authority |
| `handle: String` | Fixed `@camil.frames` | Social profile; yes | Profile username |
| `avatarPath: String?` | `journey_avatar_path` at save | Pins/profile image; yes if selected | Local path preserved; future profile media reference |
| `tagline: String` | Fixed tagline | Social profile; yes for snapshot | Profile data |

Absent fields: no dedicated capture ID, Supabase user ID, persisted spot UUID/slug, independent feed post ID, reaction/comment FK, selected reward ID, spot coordinate snapshot, GPS accuracy/sample time, photo hash, sync status, remote photo reference, or capture schema version. `Spot.remoteId: String?` and `Spot.slug: String?` exist on remote catalog objects but are discarded by capture serialization. `_CaptureGateProof` is transient (`LatLng latLng`, `double distanceMeters`); camera `_capturedPath: String?` is also transient until saved. These absences must not be filled with invented historical evidence.

Hidden data is a separate representation: `HiddenCaptureRecord` persists `spotId: String`, `spotName: String`, `imagePath: String`, `discoveredAt: DateTime` (ISO string). The shell's demo QR selection creates it with an empty image path and current device time. The store replaces records by hidden spot ID and sorts newest first. It has no owner, GPS, proof, camera invocation, or normal reward-selection linkage. Do not import it into normal `public.captures` or map its IDs to the 15 normal spots.

## 3. Persistence keys and storage locations

Keys below are literal Dart-level SharedPreferences keys. Their native backing path/prefix is plugin/platform controlled; no preferences database was read from the phone. None is scoped by authenticated Supabase user.

| Key | Stored form / purpose |
| --- | --- |
| `capture_records` | `List<String>` of CaptureRecord JSON objects; one retained record per local spot on normal saves |
| `captured_spot_ids` | `List<String>`, treated as `Set<String>`; independent source of Map captured status |
| `journey_avatar_path` | String pointing at an existing capture photo; image is not copied |
| `journey_user_bio` | String; Journey header biography |
| `hidden_captures` | `List<String>` of HiddenCaptureRecord JSON |
| `capture_reaction_counts` | JSON string map: local spot ID -> integer |
| `capture_reacted_spot_ids` | String list/set: local spot IDs with current local reaction |
| `capture_reaction_types` | JSON string map: spot ID -> reaction type (`like`, `love`, `wow`, `save`, `fun`) |
| `capture_comments` | JSON string map: spot ID -> comment objects (`authorName: String`, `text: String`, `createdAt: DateTime` as ISO); no comment ID/auth owner |
| `saved_spot_ids` | String list/set; separate saved/bookmarked status. On absent key, initialized from old reactions of type `save` |
| `selected_rewards_by_proof` | JSON string object keyed by Proof ID; versioned UserReward snapshot, or legacy flat Reward object |
| `selected_rewards_by_proof_unreadable_backup` | Preserves original malformed top-level reward bytes before later writes |
| `reward_redemptions` | JSON string map keyed by Proof ID -> `{proofId, redeemedAt}` |
| `followed_users` | String list of social user IDs; local follower state |
| `profile_about_<userId>` | String keyed by viewed social user identity, not signed-in owner |
| `app_notifications` | String list of notification JSON; includes spot ID/name and optional image path, not capture FK. Reaction/comment helper APIs exist; no capture-save invocation found |

Other state: Map `_capturedIds`, marker icon choices, active `SpotService` catalog, Futures in screens and reward version notifiers are in memory. Supabase session persistence is SDK-managed authentication state and does not namespace these keys. `public.spots` stores definitions, `public.profiles` stores account profiles; no repository capture table/write or Supabase Storage capture upload was found.

Map `_rebuildMarkers` checks `_capturedIds.contains(spot.id)` first, then saved membership, then uncaptured; captured styling takes precedence over saved styling. Notifications can open spot details with `isCaptured: true` from notification context; this is a presentation flag, not another persisted capture. Search can open details with `isCaptured: false` without supplying a capture callback. Neither route creates a second capture store.

`CaptureStore.getCaptures()` is not strictly read-only: it permanently backfills absent authors as the local Camil snapshot. Reward reads similarly migrate legacy selections/reconcile expiry and redemption. A future raw-data export must run before invoking these loaders. `CaptureStore.clearAll()` removes four capture/profile preference keys only, not photos, engagement, rewards, redemption, or hidden data; it is not called by logout. Capture writes are whole-list read/modify/write, unsequenced and nontransactional; the two preference writes ignore returned success booleans. Crashes/concurrent saves can leave records and marker IDs inconsistent. `markCaptured` can create ID-only state; no production caller was found.

## 4. Capture and spot identity

The effective retained-record key is `spotId`. There is no universal stable capture ID. New saves also generate a stable persisted Proof ID, but old records can have none. The proof is an event alias, not globally collision-proof: it includes no user/device identity and uses device milliseconds. Re-saving a spot replaces its record and normally generates another proof; older rewards can remain associated with the older proof.

Dependencies differ: Map/deduplication/social use local spot IDs; rewards/QR/redemption use Proof IDs; UserReward ID is `UR-<proofId>`. The QR codec accepts arbitrary nonempty whitespace-free proofs, including historical/test formats; do not impose today's `BP-...` pattern on imported rewards.

Remote spot identity is deliberately split: `Spot.remoteId` is the database UUID, `slug` is the immutable catalog mapping key, and `Spot.id` remains strings `1` through `15`. `SpotIdentity.localIdsBySlug` is the authoritative compatibility mapping, e.g. `piata-victoriei -> 12`. `SpotService` holds definitions and resolves historical names; it does not hold captured flags. Legacy missing/blank IDs may resolve by normalized display name or remain an unresolved name. Known IDs win over conflicting names; test fixtures themselves contain historical name/ID mismatches. Never guess an unknown spot UUID from a similar name or parse it from a QR.

Future UUID coexistence: create one server capture UUID, keep every original local ID, raw timestamp, Proof ID and QR unchanged, and maintain a separate versioned migration manifest mapping archived local entries to UUIDs. Use persisted request UUIDs for new retries, not timestamps. For legacy entries without proofs, allocate a manifest entry ID once; do not invent a replacement proof or reward. Scope import uniqueness by archive and entry, detect proof collisions across archives, and quarantine ambiguous mappings. Catalog lookup for imports must include inactive historical spots through a privileged path, since `get_active_spots()` cannot supply those UUIDs.

## 5. User ownership and account switching

`CurrentUserProfile.user` is still a constant local SocialUser with ID `camil`. It is not updated by `AuthController`, `AppProfile`, or sign-in. New captures and selected rewards use it. `CaptureStore.getCaptures()` and `getCapturedIds()` have no owner filter. `RewardSelectionStore.getUserRewards()` filters on this same constant, not Auth UUID.

Today, if Camil captures spot 12, then logs out, and Abel logs in on the same phone:

1. The capture record and `'12'` marker key remain in preferences.
2. Logout removes the authenticated UI/profile and protected routes, but does not clear these stores or files.
3. Abel receives a fresh auth-keyed subtree; Map reloads the same IDs, so spot 12 is captured and its capture action disabled.
4. Journey and Pins show the same local captures. Journey's local header still uses Camil; Pins uses the stored Camil snapshot. The account dialog's real Abel profile does not correct capture ownership.
5. My Rewards continues to load rewards tagged `camil`. Abel's subsequent normal capture also gets local author `camil`.

Thus even an explicit stored Camil author is not evidence that a particular Supabase Camil account made the capture. UI isolation on logout is working independently of data ownership isolation.

## 6. One capture or multiple captures per spot?

Recommendation: one accepted capture per authenticated user per normal spot, with `UNIQUE(user_id, spot_id)`, subject to explicit product approval before DDL.

Evidence: marker set membership is boolean; the captured sheet omits Capture; detail passes a null photo callback when captured; `saveCapture` removes all existing entries for that spot before inserting; Journey counts retained records as progress. There is no visit-history list or normal recapture control. This is one retained capture per device today, not a correctly enforced once-per-user invariant.

Important limits: the store replaces rather than rejects a duplicate; `_runVerifiedCapture` has no duplicate lock/check; reward uniqueness is per proof, not per spot. Tests verify legacy IDs and proof formats and permit multiple reward proofs for the same spot; they do not establish a repeat-visit product feature or test duplicate CaptureStore saves/account separation. Do not mistake reward fixtures for support for multiple visits. If repeat visits are later approved, separate visit events from unique spot completion and define reward cooldown/progress rules first.

## 7. Journey dependencies

Journey loads `CaptureStore.getCaptures()` in `initState`. HomeShell recreates its keyed subtree when selecting/reselecting that tab, causing reload. Records sort by descending `capturedAt` in the store; equal-time ordering has no explicit tie-breaker. Cards use stored name/type, file path, and formatted capture date; previews use the same file. No catalog join is required for the basic card. Progress/level calculations derive from total returned record count, without authenticated author filtering.

Header name/city use `CurrentUserProfile.user`; avatar and bio use separate preference keys. The avatar picker selects a capture's existing path, with no copy. Per-card engagement comes from `record.spotId`; comment display includes three demo seed comments. Migrating captures alone will not migrate header identity, biography, avatar media, or social engagement. A remote Journey also needs a deliberate missing-photo state because another device cannot load a local path.

## 8. Pins / feed / social dependencies

Pins directly reads the same CaptureRecord list, in the same order, on tab recreation. No second post object, post store, publish request, or post identity is created. A successful local capture becomes a card on the next reload. It renders `record.imagePath` with `Image.file`, uses `record.author`, and resolves the spot ID/name through SpotService where possible.

Reactions/comments attach to the resolved spot ID, not capture/proof/author. Journey/profile generally use the stored spot ID directly, so unresolved legacy identities can disagree. Replacing a capture leaves the spot's existing engagement attached to the replacement. This key cannot distinguish two users capturing the same spot. Comments store only author display name/text/time, defaulting to `You`, and Pins also displays three static seed comments. Neither represents authenticated social authorship. Saved spots and old `save` reactions have their own compatibility migration.

UserProfile receives captures and filters by stored SocialUser ID through MockSocialService; search reads local captures and the mock user directory. Follow/about/notification state is adjacent local data, not a remote feed. Future public post separation is a privacy requirement, not a feed rewrite in this audit.

## 9. Rewards, Proof IDs, QR and Partner Mode

The selection sheet calls `Reward.availableForSpot`: active pilot offers within 500 m of the spot, ranked by partner tier, distance and quality, penalizing repeated categories, capped at three. This spot-to-partner distance is distinct from capture user-to-spot GPS distance. `Reward.generate` additionally has a mapped-offer fallback; the normal selection sheet uses `availableForSpot`, not that fallback.

Choosing persists one complete immutable offer snapshot per proof. Concurrent selection writes are serialized; subsequent selection of that proof returns the existing reward. Expiry is device-local end of capture day at 23:59:59; status becomes expired only after that instant. My Rewards lists current fixed-local-owner rewards newest selected first, reconciles redeemed/expired state, and reopens saved QR rather than regenerating it.

| Capture-related value | Persisted reward content |
| --- | --- |
| Capture UUID | Absent |
| Spot local ID | `UserReward.sourceSpotId`; legacy conversion resolves `Reward.unlockedFromSpot` by name or uses empty string |
| Spot name | `Reward.unlockedFromSpot` snapshot |
| Spot slug / remote UUID | Absent |
| User ID | `UserReward.userId = 'camil'`; not Supabase UUID |
| Capture timestamp | Nested `Reward.capturedAt` |
| User capture GPS | Absent; `partnerLatitude/partnerLongitude` are partner coordinates, not capture coordinates |
| Capture distance | Nested nullable `Reward.distanceMeters` |
| Partner distance | Nested `Reward.distance` |
| Proof ID | Nested `Reward.proofId`, outer map key, derived UserReward ID |
| QR | Exact saved `Reward.qrCode = BEEN-<yyyyMMdd>-<partnerId>-<proofId>` |

Other UserReward fields: schemaVersion 1, id, offerId, selectedAt, status, redeemedAt, partner coordinates, and complete nested Reward (partner identity/address/URL, offer text/conditions/staff instructions/daily limit, expiry, ranking metadata). Preserve the entire snapshot, not only linkage fields.

`RewardQrCodec` uses known partner IDs, longest first, to disambiguate hyphens. Local validation requires exact saved QR and partner match, correct selected partner, and active/unredeemed status. The service revalidates on confirmation and serializes redemption. `reward_redemptions` is the one-use proof ledger, written before the reward lifecycle update; reads reconcile an interrupted second write. Corrupt individual ledger entries remain treated as redeemed. External well-formed QR codes are only `validExternalDemo` and cannot be redeemed by this implementation. Partner Mode is a local demo service, not a server-authoritative multi-device redemption network.

Migration can invalidate rewards by regenerating proof/QR, changing partner IDs used by the parser, dropping the ledger, switching the fixed-owner filter prematurely, or requiring a non-null capture FK for old/orphaned rewards. Keep exact tokens, validity instants, offer snapshots and redemption entries. Expired rewards must stay expired and redeemed rewards redeemed: “remain valid” means preserve original verification/lifecycle, not extend validity. Attach a nullable capture UUID to a future reward migration only after deterministic matching; old rewards can outlive a replaced or missing capture. Never issue rewards again on import/retry.

Partner access uses a hard-coded development PIN in `PartnerModeConfig`, not authenticated partner roles. The scanner returns barcode text; the mode screen delegates validation and redemption to the local service. Its proof display uses the saved reward snapshot where present. Neither scanning nor displaying a QR re-reads the capture photograph or verifies capture GPS afresh.

## 10. Photo storage behavior

`CaptureScreen` saves the camera-returned path verbatim. No `copy`, `saveTo`, documents-directory move, byte encoding in preferences, gallery save, or remote upload exists in the normal flow. Retake merely clears `_capturedPath`; it does not delete the discarded file.

The registered Android implementation is `camera_android_camerax-0.6.27`. Its installed `android/src/main/java/io/flutter/plugins/camerax/ImageCaptureProxyApi.java:89-92` explicitly uses `getCacheDir()` and `File.createTempFile(..., outputDir)`. This confirms app-private Android cache, not durable app documents. The exact phone path was not observed; it is determined by Android application/user storage. iOS output directory/lifecycle was not verified and should not be inferred from Android.

Restart preserves preference paths; pictures remain visible only if cache files still exist. Logout neither deletes nor copies them. Cache eviction can break photos and chosen avatars while leaving markers/records intact. Reinstall normally removes app-private files/data; platform restoration may restore preferences without the cache image, so reinstall is not a recovery strategy.

Future: first preserve existing available bytes through an explicitly authorized backup/import step. For new photos, stage durable local files before acknowledging a queued save. Later store a private Storage bucket and object key such as `<user_uuid>/<capture_uuid>/original.jpg`; keep local paths only in device-local manifests. Do not persist expiring signed URLs as canonical identity. Private buckets require authorized access or signed URLs. [Supabase Storage bucket documentation](https://supabase.com/docs/guides/storage/buckets/fundamentals).

## 11. GPS / proof behavior

Map checks location service and permission, requests high-accuracy current location, and falls back to cached `_userLatLng` if acquisition throws. It computes `Geolocator.distanceBetween(userLat, userLng, spot.lat, spot.lng)` before opening the camera. It accepts distances at or below the global **10,000 m testing gate**. Remote `Spot.captureRadiusMeters` is loaded but intentionally not used by this gate.

Only lat/lng/distance enter `_CaptureGateProof` and then CaptureRecord. Spot coordinates remain catalog data, not a capture snapshot. No GPS sample timestamp, accuracy, mock-provider flag, elapsed time limit, or second location check at confirmation is persisted/enforced. Device `capturedAt` is later than the GPS reading. The fallback can be stale. Reward detail displays Proof ID, formatted capture timestamp, rounded “m from the pin when captured,” and separate partner distance; it does not display raw user coordinates. Its wording is stronger than the actual pre-camera sampling guarantee. This audit changes none of that behavior.

## 12. Proposed public.captures schema (design only)

Use one immutable accepted normal capture per user/spot, with private proof and optional media reference. No SQL file or migration is created here. Geography types/functions must use the installed extension schema (repository seed uses `extensions`); verify deployed configuration. Geography supports meter-based distance and spatial indexing. [Supabase PostGIS documentation](https://supabase.com/docs/guides/database/extensions/postgis).

| Column | PostgreSQL type / nullability | Purpose and authority |
| --- | --- | --- |
| `id` | uuid, PK, NOT NULL, server default UUID | Canonical capture identity |
| `user_id` | uuid NOT NULL, FK `auth.users(id)` | Caller from validated auth context, not supplied owner text |
| `spot_id` | uuid NOT NULL, FK `public.spots(id)` | Real remote spot, never local numeric string |
| `captured_at` | timestamptz NOT NULL | Server acceptance instant for new online capture; approved historical time for imports |
| `client_captured_at` | timestamptz NULL | Untrusted device observation time, retained separately |
| `capture_location` | extensions.geography(Point,4326) NULL | Private submitted coordinates; nullable for legacy evidence gaps |
| `location_observed_at` | timestamptz NULL | New client GPS sample time; never invented for history |
| `location_accuracy_m` | double precision NULL | Client accuracy evidence, not currently stored |
| `spot_location_snapshot` | extensions.geography(Point,4326) NULL | Server catalog coordinates used at validation; history may be unknown |
| `distance_from_spot_m` | double precision NULL | Server distance for new captures; legacy supplied value explicitly unverified |
| `capture_radius_m_snapshot` | integer NULL | Actual server policy radius applied, not inferred for old records |
| `spot_name_snapshot` | text NOT NULL | Server catalog name; retain approved historical label on import |
| `spot_type_snapshot` | text NOT NULL default empty string | Historical/current display compatibility |
| `legacy_proof_id` | text NULL | Exact existing proof alias or compatibility token for staged new writes |
| `source` | text NOT NULL | Restricted values `online` or `legacy_import` |
| `validation_status` | text NOT NULL | `server_checked` or `legacy_unverified`; clients cannot choose |
| `client_request_id` | uuid NULL | Required for online requests; retry key scoped to owner |
| `legacy_import_batch_id` | uuid NULL | Approved private archive/import batch reference |
| `legacy_entry_id` | uuid NULL | Stable archived entry identity, not a generated proof |
| `photo_bucket` | text NULL | Private bucket name, populated after upload verification |
| `photo_object_path` | text NULL | Durable object key; no local path or signed URL |
| `created_at` | timestamptz NOT NULL default server now | Row creation/import instant |
| `updated_at` | timestamptz NOT NULL default server now | Server maintained for controlled media updates |

Use `auth.users` for ownership independent of editable profile fields. Profile hydration can use its existing UUID mapping; verify profiles.id contract without modifying profiles. Initially use FK `ON DELETE RESTRICT` for spots and users to avoid accidental loss of capture/reward evidence; account deletion must be a designed privileged purge/anonymization workflow, not permanently blocked without recourse. Deactivate spots instead of deleting them. Do not add reward FK requirements during captures rollout.

Unknown-owner local history stays outside this table in its preserved archive; `user_id` must never be nullable as an excuse for automatic claiming. A reviewed legacy import requires known account and resolvable spot. Archive raw author/local-ID/slug lookup result/timestamp bytes separately; no unbounded public JSON bag carrying private legacy data. A future private import-batch table would support the batch FK, but is a separate design/implementation item.

## 13. Constraints and indexes

- Primary key `id`; unique `(user_id, spot_id)` for once-per-user completion.
- Unique partial `(user_id, client_request_id)` where request ID is non-null. A retry with changed spot/payload must fail, not silently replace existing proof/media.
- Unique partial `(legacy_import_batch_id, legacy_entry_id)` for imports, with a batch owned/authorized by the importer. Proof IDs receive a non-unique lookup index initially because historical cross-device collisions are possible; ambiguity blocks automatic linkage. Do not assume global proof uniqueness retroactively.
- B-tree `(user_id, captured_at DESC, id DESC)` for owner listing/pagination; B-tree `(spot_id)` for FK/administrative lookup. The composite uniqueness index already serves owner/spot membership.
- No public “nearby captures” query is required. Add a GiST capture-location index only if a private spatial workload justifies it; do not index/expose precise coordinates for feed browsing by default.
- Both photo columns must be null together or nonempty together. Only a verified upload-completion operation may set them; bucket/key must belong to row owner/capture.
- Distances/accuracy, when present, must be finite and nonnegative (explicitly reject NaN and infinities); radius, when present, positive. Reject non-finite/out-of-range lat/lng before point construction; construct Point(longitude, latitude) at SRID 4326. Require nonempty valid point geometries.
- Check allowed source/status values and pairing: online/server_checked versus legacy_import/legacy_unverified. Online rows require request ID, location, sample time, spot snapshot, radius and distance; import rows require batch/entry and may lack GPS. Legacy source/status are privileged-import-only.
- Enforce online distance <= applied radius, timestamps/freshness, spot activity, owner and catalog-derived snapshots in the transaction/function. Cross-table checks belong there, not a CHECK that queries spots. Historical times may be old; do not reject them through an online-only freshness rule or fabricate sample times.

## 14. Proposed RLS and public/private separation

Enable RLS at table creation. Authenticated SELECT uses `(select auth.uid()) = user_id`; anon receives no capture access. Revoke unnecessary grants; policies and grants must both permit an operation. A direct INSERT design would require `WITH CHECK ((select auth.uid()) = user_id)`, but this alone cannot establish valid GPS proof. Views need deliberate RLS handling. [Supabase RLS documentation](https://supabase.com/docs/guides/database/postgres/row-level-security).

Recommended BeenPin contract: authenticated clients SELECT own captures and create their own capture through a narrow `create_capture` RPC; revoke direct INSERT/UPDATE/DELETE. The RPC must reject null auth, derive owner itself, and run all validations. If SECURITY DEFINER is needed, pin an empty search_path, fully qualify objects, revoke PUBLIC/anon execution, grant only authenticated execution, and explicitly enforce ownership because its privileged role can bypass RLS. Photo completion/import operations have separate narrow permissions; a service-role secret never belongs in Flutter.

Own-capture RLS is not a feed policy. Keep private proof columns, Proof IDs, reward tokens, original GPS and photo metadata out of public reads. Future posts should be a separate allowlisted projection/table with post UUID, capture linkage internally, author public-profile identity, spot identity, approved display time/photo and publication visibility. Do not select `captures.*` in a public view. Sanitize public photo derivatives, including EXIF location. Public profiles must not make all associated private captures readable. Whether posts are public, signed-in-only or opt-in remains a product decision.

## 15. Server authority

| Validation | Today | Backend recommendation |
| --- | --- | --- |
| Authenticated owner | Auth gate protects UI, store writes fixed local author | Validated auth context; derive immutable owner; account-scoped retries |
| Spot existence/activity | Loaded catalog/RPC filters active spots; store accepts any Spot | FK plus recheck active spot during online transaction; privileged import can reference inactive history |
| Coordinates/distance/radius | Flutter gate only, cached fallback; 10,000 m constant | Finite/range checks, server PostGIS distance from server catalog, policy radius snapshot |
| GPS freshness | Not checked; location before camera | Sample age/accuracy rules and confirmation timing policy; server cannot prove physical presence solely from client GPS |
| Duplicates | UI blocks; store replaces | Atomic unique owner/spot constraint, idempotent request handling, never overwrite accepted capture |
| Time | Device DateTime.now | Server receipt/acceptance time plus separate claimed device time; explicit offline/historical policy |
| Photo | Any returned nonempty path | Verified owned upload/key and media readiness; phase before Storage must be explicitly local-photo-only |
| Reward eligibility/redemption | Flutter ranking, unsigned QR, device ledger | Eventually server offer selection/limits/expiry/one-use transaction; separate rollout preserving legacy tokens |

Server distance checking is not anti-spoofing or photographic proof of presence. Name `server_checked` accordingly. Preserve the 10,000 m testing configuration during compatibility rollout; reducing it or adopting per-spot production radii is a separate approved behavior change. Do not retroactively mark imported test captures as production verified.

## 16. Safe staged migration

**Stage 0 — prepare identity and recovery contracts.** Approve once-per-user rule, historical ownership process, offline behavior and reward compatibility. Before any loader-driven conversion, provide an explicitly invoked export of exact raw preference values, capture/reward/redemption maps and available image bytes with a manifest. Keep unresolved/ID-only/corrupt entries. Inventory photos without deleting anything. This audit did not access the device or perform that export.

**Stage A — isolated backend foundation.** Verify existing spots/auth/profile DDL read-only; implement reviewed captures schema, grants/RLS and create RPC in a separate development environment only in the next authorized task. Test owner isolation, inactive spots, distance boundary, duplicate/concurrent requests, timestamp policy and retries. Keep production reads/writes local until this passes.

**Stage B — authenticated new writes with durable local compatibility.** Introduce a capture repository behind the existing flow and a versioned owner-scoped local cache/outbox/manifest. Bind each operation to the initiating Auth UUID and persist one request UUID before network submission. Prefer remote acceptance then idempotent local projection; persist retry state so remote success plus local failure does not create another reward/capture. Never use the old global store as the new multi-user cache: same-spot saves would overwrite another user's record. Maintain old capture field/Proof ID/QR representations in adapters, while leaving original archive keys intact. Compatibility reward ownership needs a scoped adapter or cohort restriction before multiple-account rollout; blindly changing CurrentUserProfile would orphan existing rewards. If offline capture is allowed, show explicit pending status, defer reward unlock until accepted, and do not submit one user's queue under another session.

**Stage C — Map ownership cutover.** Derive markers from authenticated user's accepted captures; map UUIDs to frozen local IDs for existing marker logic. Cache by Auth UUID; cancel/discard stale responses on account changes. Never union global historical `captured_spot_ids` into every signed-in account. Keep unassigned history accessible only through a clearly labeled local archive/review experience, not as an implied private account record. Stage B/C should ship behind one coherent rollout switch to avoid remote captures that Map cannot see.

**Stage D — Journey.** Read owner-scoped remote rows through a compatibility adapter, preserve date/snapshot/progress behavior, and explicitly migrate header/profile/avatar/bio ownership separately. Support absent remote photos before Storage: do not pretend another device can open the originating file. Keep Pins on a scoped compatibility view until its own migration; do not solve Map isolation while leaving a cross-account global Journey/feed visible in the released experience.

**Stage E — Storage.** Copy/upload available photos with deterministic owner/capture keys, verify uploads, then populate object references. Handle missing files as missing, retain local data until verified, and resume interrupted uploads. Maintain a separate durable local-photo manifest. Storage and database updates are not one transaction: completion and cleanup must be retryable. Migrate selected avatar references independently.

**Stage F — Pins/social and later rewards.** Introduce post identity/visibility and public photo derivatives. Legacy engagement keyed only by spot cannot be distributed among future users' posts: keep it archived or require an explicit mapping decision. Do not import demo reactions/comments as real users. Migrate reward ownership, stable token lookup and one-use ledger as a separate compatibility project, using nullable capture links for unresolved old rewards. Hidden discoveries remain outside this migration.

For this test device, default to preserving all old records as **unassigned local history**, not assigning them to whichever user next signs in. A user/admin may explicitly review entries and associate selected records with a verified Supabase account; the `camil` string, avatar and sign-in timing are insufficient evidence. Preserve consent/decision and original bytes in a private manifest. Resolve UUIDs from immutable slug mapping; quarantine unknowns, proof collisions and duplicate owner/spot imports. Keep the unimported archive instead of dropping the losing record. ID-only captured markers are not evidence of a photo/time/proof and must not become fabricated capture rows. Import never grants fresh rewards.

Rollback means feature flags plus retained raw stores/manifests and resumable queues, not deleting accepted remote rows or restoring stale redemption status. Once owner-scoped writes exist, never roll back to exposing all accounts through the old global keys. Establish compatibility versioning before release.

## 17. Exact persisted-data risks

1. Replacing local IDs with UUIDs breaks marker membership, overwrite matching, engagement, saved spots, name fallback and reward source mapping.
2. Regenerating Proof IDs or QR strings breaks selection/lookup/redemption; timestamp parsing/timezone conversion can change token dates or milliseconds. Legacy local ISO times lack offset; preserve raw bytes and resolve timezone explicitly on import.
3. Automatic owner backfill assigns another account's captures/rewards to the wrong person. Existing loaders can rewrite bytes before inspection.
4. Nontransactional capture writes, ID-only markers and replaced records mean record/marker/reward sets need not match. CaptureStore has no per-entry corruption recovery.
5. Photos/avatars can disappear from cache independently of preferences. Remote-only rows cannot recover those bytes.
6. Old rewards can reference lost/replaced capture proofs. A mandatory new capture FK or global proof uniqueness can reject valid historical rewards.
7. Social spot-only identities merge unrelated captures; static author/demo comments cannot be authenticated retrospectively.
8. Importing unverified testing GPS as verified production evidence or re-running reward generation can mint unjustified rewards.
9. Account switches during async saves/retries can mix owners unless operations, responses and caches are bound to original Auth UUID.
10. Catalog renames/deactivation and partner-ID/parser changes can disrupt historical lookup. Preserve snapshots and legacy parser compatibility.

## 18. Tests inspected and coverage gaps

`capture_author_test.dart` verifies fixed local Camil/selected avatar/proof survive preference reload and one-time author backfill preserves explicit demo authors. `spots_test.dart` verifies all 15 frozen mappings, local captured IDs survive remote definitions, new remote-spot capture retains `12` and `BP-12-`, malformed/duplicate catalog rows fail and inactive rows are excluded. These are compatibility guarantees, not user isolation.

`user_rewards_test.dart` covers complete snapshot persistence, idempotent/concurrent selections, multiple proofs, expiry boundary, one-use redemption/reload, legacy token and ledger preservation, malformed backup, My Rewards reopening exact QR and expired QR hiding. `partner_mode_test.dart` covers parsing, token tampering/wrong partner/external rejection for redemption, concurrent one-use redemption, expiry revalidation and partner UI. `pilot_mvp_test.dart` covers pilot offer mapping and local proof redemption. `auth_test.dart` covers session/profile/sign-out route behavior, not capture ownership.

No current tests establish cross-auth-user capture isolation, database RLS, capture duplicate races, camera file durability, GPS freshness/fallback validity, real device cache eviction, offline reconciliation or Storage upload recovery. Future migration must add these targeted tests. No tests were executed for this documentation-only change, per request.

## 19. Open product decisions

- Confirm one accepted capture per user/spot, and whether photo replacement/deletion/revisit rewards are ever allowed.
- Decide who can assign historical device entries, what evidence/consent is required, and how to resolve duplicate claimed spots.
- Decide offline pending-capture behavior, when reward eligibility begins, timezone policy, and GPS freshness/accuracy requirements.
- Decide when the 10,000 m testing gate changes, and how test/imported captures affect progress versus production rewards.
- Decide feed visibility/public timestamp precision and photo publication consent; precise proof remains private.
- Decide dismissal/retry UX for reward selection, and how legacy local rewards are presented after real account scoping.
- Decide account deletion, proof retention and missing-photo behavior; do not silently purge old records.
- Decide separate schedules for Hidden, social identity/engagement, avatar/bio and partner redemption migration.

## 20. Exact next implementation step and audit validation

Next task: after resolving the capture cardinality and legacy-ownership decisions, implement and test the private captures schema/RLS/create RPC in an isolated development database, with a reviewed migration artifact and no production Flutter cutover. First verify deployed spot UUID/FK and PostGIS schema contracts. Include tests for Camil-versus-Abel isolation, denied anonymous/other-owner writes, inactive/missing spots, duplicate request and duplicate spot races, 10,000 m compatibility boundary, invalid GPS/time and immutable proof fields. Then build the owner-scoped repository/cache adapter in a separate phase. Do not start by bulk-uploading existing local records.

Only `docs/captures_audit.md` was added. Validation: `git diff --check`, documentation whitespace check including the untracked new file, and git status/source-diff review. No formatter/analyzer/test run was needed because no Dart files changed. Database and runtime verification remain future implementation work.
