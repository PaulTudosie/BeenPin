# BeenPin normal spots audit and migration

## Scope and inventory (audit before implementation)

Found **15 normal Map spots**, defined only in `lib/services/spot_service.dart` in the original repository. Map consumes `SpotService.getSpots()`; it did not own the literal list. Existing model: `lib/models/spot.dart`. Repository-wide searches covered Spot constructors, IDs, coordinates, assets, services, capture, navigation, rewards, QR, partner mode, social data, tests and documentation. No second production normal-spot coordinate catalog was found.

Every row below has an effective **10,000 m** capture radius, from Map's global testing gate, not the database default of 120 m. Coordinates are copied exactly; no corrections are proposed. Description source refers to `_descriptionForSpot` in `lib/features/spot/spot_detail_screen.dart`. Image filenames are under `assets/spots/`.

| Local ID | Immutable slug | Name | Latitude | Longitude | Category | Description source | Image |
|---|---|---|---|---|---|---|---|
| 1 | hidden-graffiti | Hidden Graffiti | 44.4325 | 26.1039 | graffiti | type:graffiti | obor_market.jpg |
| 2 | abandoned-factory | Abandoned Factory | 44.4300 | 26.1065 | urban | type:urban | obor_market.jpg |
| 3 | old-staircase | Old Staircase | 44.4352 | 26.0987 | architecture | type:architecture | obor_market.jpg |
| 4 | arcul-de-triumf | Arcul de Triumf | 44.467 | 26.0781 | monument | name | arcul_de_triumf.jpg |
| 5 | ateneul-roman | Ateneul Român | 44.4413 | 26.0966 | culture | name | ateneul_roman.jpg |
| 6 | parcul-herastrau | Parcul Herăstrău | 44.4663 | 26.0858 | nature | name | obor_market.jpg |
| 7 | palatul-parlamentului | Palatul Parlamentului | 44.4273 | 26.0873 | monument | name | obor_market.jpg |
| 8 | hanul-lui-manuc | Hanul lui Manuc | 44.4318 | 26.1030 | history | name | obor_market.jpg |
| 9 | cismigiu-garden | Cișmigiu Garden | 44.4370 | 26.0915 | nature | name | obor_market.jpg |
| 10 | piata-unirii | Piața Unirii | 44.4268 | 26.1025 | urban | type:urban | obor_market.jpg |
| 11 | curtea-veche | Curtea Veche | 44.4318 | 26.1048 | history | type:history | obor_market.jpg |
| 12 | piata-victoriei | Piața Victoriei | 44.4521 | 26.0857 | urban | type:urban | obor_market.jpg |
| 13 | therme-bucuresti | Therme București | 44.5773 | 26.0685 | leisure | default | obor_market.jpg |
| 14 | floreasca-park | Floreasca Park | 44.4663 | 26.1018 | nature | type:nature | Parcul_Floreasca.jpg |
| 15 | obor-market | Obor Market | 44.4512 | 26.1153 | urban | type:urban | obor_market.jpg |

Description text is existing editorial/demo copy, with six name-specific descriptions and type/default fallbacks. The seed preserves that text. Images remain local; all seeded `image_url` values are NULL. The Obor image is an existing generic fallback for eleven spots, not an accurate photo of each location.

## Identity decision

Preserve `Spot.id` as the original numeric string for all 15 spots. Store the actual database UUID separately as `remoteId`; use the immutable slug as the cross-system key. A fixed, explicit slug-to-local-ID mapping is sufficient: no `legacy_key` column is needed. Never derive IDs from list position, mutable names, or UUIDs. Slug renames are identity changes and require an explicit compatibility migration.

Only these audited slugs are supported during this bounded migration. Unknown active slugs fail the fetch visibly rather than guessing an ID that could accidentally match saved data or select the wrong partner. Add an explicit mapping and audit rewards before extending this catalog.

## Dependencies and breakage assessment

| Feature / files | ID dependency and effect of replacing IDs |
|---|---|
| Map (`features/map/map_screen.dart`) | Marker IDs, captured/saved lookup, capture callbacks and proof fallback use `spot.id`; replacing IDs would make old captures look uncaptured. Coordinates drive markers and GPS gate. Marker assets are `assets/pins/pin_captured.png`, `pin_uncaptured.png`, and saved asset/generated fallback; size 40, anchor (0.5, 1.0). |
| Capture (`capture_screen.dart`, `services/capture_store.dart`) | Camera accepts Spot; persisted `captured_spot_ids` and `capture_records` store IDs. Missing legacy IDs resolve from normalized names. Proof format `BP-<spotId>-<UTC milliseconds>`. Photos remain device file paths. |
| Journey and Profile (`features/journey/journey_screen.dart`, `features/profile/user_profile_screen.dart`) | Render capture snapshots; engagement is keyed by record.spotId. Existing names/photos remain snapshots. |
| Pins (`features/pins/pins_screen.dart`) | Resolves ID/name through SpotService, uses the result for reactions, comments and saves. Changing keys disconnects engagement. |
| Saved/engagement (`services/saved_spot_store.dart`, `services/engagement_store.dart`) | SharedPreferences saved IDs, reacted IDs, reaction counts/types and comments keyed by ID; no rewrite is performed. |
| Detail (`features/spot/spot_detail_screen.dart`) | ID determines saved state, partner offer and specific bundled image. Go to spot uses the supplied latitude/longitude; capture callback comes from Map. |
| Rewards (`models/reward.dart`, `services/pilot_partner_service.dart`) | Partner spotIds, fallback proof construction, normalized name lookup and distance ranking depend on identities/coordinates. |
| Earned rewards (`models/user_reward.dart`, `services/reward_selection_store.dart`) | Persists sourceSpotId, proofId, immutable reward snapshot and QR. Older source IDs may resolve from spot names. |
| QR / Partner Mode (`services/reward_qr_codec.dart`, `reward_redemption_service.dart`, `reward_redemption_store.dart`, `features/partner/`) | QR is `BEEN-yyyyMMdd-partnerId-proofId`; proof indirectly contains the spot ID. Redemption uses existing saved rewards/proof ledger. Replacing/rebuilding proofs could invalidate redemption. No edits or regeneration. |
| Notifications (`models/app_notification.dart`, `services/notification_store.dart`, `features/notifications/notifications_screen.dart`) | Stored spotId/name resolve detail navigation. |
| Search (`features/search/app_search_delegate.dart`) | Uses SpotService catalog and passes the selected Spot to details. |
| Tests | `pilot_mvp_test.dart` expects spot 12's partner; capture/reward/partner tests persist IDs/proofs. `capture_author_test.dart` has an intentionally synthetic ID 2 / Floreasca Park fixture, unlike production ID 14. Do not rewrite that persisted fixture as catalog data. |

Partner catalog associations remain: Old Town Coffee = 8,10,11; Victoriei Bistro = 5,12; Park Kiosk = 4,6,14; Museum Shop = 7,13; Street Art Studio = 1,2,3,15. Nearby reward ranking also uses partner coordinates, which are separate data and are not spot definitions.

## Hidden Spots and data quality

`HiddenSpotService` / `HiddenSpot` define two separate entities: `hidden-sticker-01` (Blue Door Sticker) and `hidden-window-02` (Quiet Window Mark). They use clues, a separate hidden capture store and shell demo scanning. They are not migrated. Normal spot 1's name "Hidden Graffiti" does not make it a HiddenSpot.

No duplicate normal IDs, names or coordinate pairs were found. Generic names (1–3), English/Romanian naming, editorial demo descriptions and shared placeholder imagery are preserved. Therme is outside central Bucharest; its coordinates remain exact. Social mock service defines users, not another normal spot catalog. Partner coordinates and synthetic tests are not additional normal spots.

Capture state is currently **device-local, not isolated by Supabase auth user**: `captured_spot_ids` is a global preferences key. This migration preserves that pre-existing behavior and does not claim to fix account isolation. Ownership reconciliation is required before the later captures migration.

## SQL and geography contract

Run **`C:\src\BeenPin\supabase\seed_spots.sql` manually in Supabase SQL Editor** using the project containing the existing table. It is not executed by this task. Assumes the user-described table, PostGIS in extensions, authenticated SELECT grant and active-only RLS already exist.

The transaction upserts by slug, preserves existing UUIDs/created_at, and copies longitude then latitude into SRID 4326 geography. Inserts specify 10000, never the default 120. Re-running deliberately restores the audited definitions and active status; do not rerun after editorial changes without reviewing the seed. No captures, rewards, policies, photos, secrets or client write grants are included.

No table-column change is required. The file adds `public.get_active_spots()`, a STABLE SECURITY INVOKER SQL function with empty search_path and fully qualified references, execution restricted to authenticated. It SELECTs active rows through existing table RLS. It does not grant any table writes.

Supabase's [PostGIS documentation](https://supabase.com/docs/guides/database/extensions/postgis) states that direct geography queries return hexadecimal representations. No live project response was inspected. Instead of guessing a binary decoder, the RPC explicitly returns `ST_Y(location::extensions.geometry)` as latitude and `ST_X(...)` as longitude. [Invoker semantics](https://supabase.com/docs/guides/database/functions) retain caller privileges and RLS. Flutter receives ordinary numeric coordinates.

## Implementation contract and fallback

`SpotRepository.getActiveSpots()` is implemented by `SupabaseSpotRepository`. One RPC fetch maps and validates typed Spot rows, filters inactive rows defensively and rejects malformed/duplicate/unknown identities atomically. Map fetches definitions during bootstrap and retry; widgets contain no Supabase queries.

SpotService retains the frozen original catalog as the explicit temporary migration fallback and historical name/ID resolver. Successful remote definitions replace its active in-memory catalog (including a valid empty result), so existing synchronous search/notification/reward lookups can use the same definitions. Historical lookup can still resolve old names/IDs from the frozen catalog.

A failed or timed-out request retains the last in-memory catalog, or the original 15 spots on a cold start. A visible Map notice offers Retry. A successful empty result displays no markers and an explicit empty-state notice; it never resurrects inactive rows. The fallback is not a durable cache and can be stale on a cold offline launch. Remove it after backend rollout and a separate offline-cache decision. This is an MVP continuity mechanism, not offline access control.

Map keeps the explicit global 10000 m gate during this testing migration, even if an operator edits the backend radius. The model exposes the remote radius, and all seeded values are 10000. Production radius enforcement is a separate task.

## Manual verification after running SQL

1. Run the SQL, then its final verification SELECT: expect 15 audited rows, unique slugs, original coordinates, 10000 radii. Run again and confirm no duplicate rows and UUIDs unchanged.
2. Launch BeenPin authenticated. Map loads 15 markers at the same positions, with unchanged sizes, anchors, appearance and initial/location zoom behavior.
3. Confirm previously captured markers remain captured and uncaptured markers remain uncaptured; check saved marker precedence.
4. Tap representative markers (4, 5, 12, 14, 15 and a generic-image spot), open details and verify the same bundled images and descriptions.
5. Test Go to spot navigation and the camera flow. Test inside the current 10000 m threshold, including a distance greater than 120 m. Capture once and verify the marker updates.
6. Verify existing Journey, Profile, Pins, reactions/comments and saved pins remain. Check search and notification detail links.
7. Open existing My Rewards items and compare proof IDs and QR strings against their pre-migration values. Test Partner Mode validation/redemption with a suitable unused reward.
8. Kill/relaunch and repeat Map checks. Disable networking: confirm the visible fallback notice and working original/last-loaded markers. Restore networking and tap Retry.
9. In a controlled backend test, deactivate one spot: after reload it must disappear without deleting its local capture. Restore it. A successful empty active catalog must show an empty notice, not fallback markers.
10. Check RPC as authenticated versus unauthenticated: only authenticated callers may execute; active-only RLS still applies. Verify normal clients still cannot write public.spots.

## Remaining work before public.captures

Run and verify the SQL and device checklist; validate actual remote RLS/RPC privileges. Decide ownership of existing device-global captures when accounts change, map each legacy ID through immutable slug to actual UUID, preserve proofs and reward snapshots, plan photo durability/Storage separately, and define production radius/offline behavior. Nothing here migrates captures or uploads images.

## Delivery and validation

Created:
- `docs/spots_audit.md`: inventory, compatibility audit, rollout and device checklist.
- `supabase/seed_spots.sql`: repeatable 15-spot seed and authenticated read RPC.
- `lib/models/spot_identity.dart`: immutable slug-to-local-ID mapping.
- `lib/services/spot_repository.dart`: repository interface, Supabase reader, validation and meaningful failures.
- `test/spots_test.dart`: seven focused regression tests.

Modified:
- `lib/models/spot.dart`: backward-compatible remote metadata and validated RPC mapping.
- `lib/services/spot_service.dart`: active remote catalog plus frozen historical/fallback definitions.
- `lib/features/map/map_screen.dart`: repository loading, failure/empty notice and retry; original capture gate and marker logic preserved.
- `lib/features/spot/spot_detail_screen.dart`: use remote description with existing local fallback; image mapping untouched.

Validation completed on 2026-09-15:
- Dart format on all seven modified/new Dart files: passed. Used the installed SDK executable directly after the wrapper stalled on the sandboxed SDK lock; formatting required access to the SDK's user cache.
- `flutter analyze`: no issues found.
- `flutter test test/spots_test.dart`: all 7 tests passed.
- `flutter test`: all 33 tests passed, including existing authentication, capture, reward, QR and Partner Mode coverage.
- `git diff --check`: passed (Git emitted only existing Windows line-ending notices).

Tests validate all 15 SQL coordinate pairs against the original catalog, immutable identity mapping, nullable metadata, local capture/proof compatibility, inactive and empty catalogs, historical aliases and atomic rejection of malformed/duplicate rows. Actual Google Maps rendering, GPS/camera operation and deployed RPC/RLS require the manual checks above; no live database or device validation is claimed.

Pre-existing authentication, profile, shell and splash changes in the worktree were left untouched. No dependencies were added or upgraded.
