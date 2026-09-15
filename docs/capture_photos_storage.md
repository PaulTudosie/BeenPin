# Capture photo Storage foundation

Status: **Storage backend deployed, confirmed by the user; Flutter upload integration implemented**. This integration does not execute or edit SQL, change policies/bucket settings, upload to the live project during development, or migrate existing captures/photos. The deployment section below documents the original SQL artifact for other environments; this environment does not need it rerun.

## Deployment

Manually run **`supabase/capture_photos_storage.sql`** in the Supabase SQL Editor as the trusted `postgres` administrator, after the existing captures foundation is deployed. This is an incremental migration for the existing table, not a replacement for `captures_schema.sql`.

Before running it, record the capture count/fingerprint query at the bottom of the script. Compare the same query after deployment during a period without capture writes. The aggregate fingerprint covers every row value without displaying coordinates; an after-only count cannot prove rows stayed unchanged.

The migration is transactional and re-runnable for its declared objects. It drops only `captures_photo_pending_check` and its own replacement `captures_photo_storage_path_check`, validates the replacement, recreates only three explicitly named policies, and creates/replaces one RPC. A validation failure rolls back the migration; it does not repair or rewrite capture rows. Constraint validation takes a table lock, so deploy during a quiet period.

The bottom read-only queries inspect the bucket, configuration, policies, Storage RLS flag, constraint, function configuration and ACL, and capture counts/fingerprint. Expect Storage RLS to be enabled and the function to have a trusted administrator owner, empty search path, SECURITY DEFINER, and authenticated execution. PUBLIC and anon must have no execution privilege. The service_role grant is also explicitly revoked; administrator/owner privileges are inherently outside client isolation.

No global Storage table privileges are revoked. Other buckets' policies are untouched. Existing permissive policies can combine with these policies to broaden access, so inspect the separate policy inventory for unscoped or overlapping grants, including ALL/DELETE or anonymous access. Unrelated policies are normal and do not block deployment. The assumed starting state is the supplied deployed capture permissions plus zero policies granting access to this bucket.

## Existing bucket and path

| Setting | Required existing configuration |
| --- | --- |
| Bucket ID/name | `capture-photos` |
| Public | OFF |
| File size limit | 15 MB; verification reports the actual byte value |
| Allowed MIME types | `image/jpeg`, `image/png`, `image/webp` |

The script does not create or alter the bucket. Size/MIME restrictions remain the Storage service's bucket configuration. The path check validates naming, not image contents or agreement between bytes, MIME and extension.

Use exactly:

```text
<authenticated-user-uuid>/<server-capture-uuid>/original.<extension>
```

The four allowed filenames are `original.jpg`, `original.jpeg`, `original.png`, and `original.webp`. UUID text must match PostgreSQL's canonical lowercase form. Choose one extension for the capture and persist that choice across retries. Do not use usernames, emails, spot IDs, local Android paths or `client_capture_id` in this path.

The replacement table CHECK accepts NULL or one of four exact strings constructed from that row's `user_id` and `id`. This rejects wrong owners, wrong captures, blank/absolute paths, extra folders, arbitrary filenames and suffixes. It does not cast untrusted path fragments to UUID. Existing NULL paths remain valid; `create_capture` continues creating captures with NULL photo paths.

## Storage policies

Every policy requires the fixed bucket, `owner_id = auth.uid()::text`, and an existing `public.captures` row owned by that user whose UUIDs generate the exact object name. Thus neither ownership metadata alone nor a plausible folder is sufficient. Exact equality ensures three path components and a real server capture UUID without unsafe UUID parsing.

| Policy | Operation | Validation |
| --- | --- | --- |
| `capture_photos_insert_own` | INSERT | WITH CHECK validates the new object |
| `capture_photos_select_own` | SELECT | USING validates the visible object |
| `capture_photos_update_own` | UPDATE | USING validates the old object; WITH CHECK validates the resulting object |

All three target only `authenticated`. Cross-user reads, uploads, overwrites and ownership changes are excluded by these predicates. No DELETE or anonymous-read policy is added. Existing capture RLS and direct-write restrictions are unchanged.

Supabase assigns `owner_id` from the uploading user's JWT; the deprecated `owner` field is not used. Dashboard/service-key uploads may lack this ownership, so they are not a substitute for the future authenticated upload flow. See [Supabase Storage ownership](https://supabase.com/docs/guides/storage/security/ownership).

INSERT plus SELECT and UPDATE support Storage upsert. Requests must use the current authenticated user's session. See [Supabase Storage access control](https://supabase.com/docs/guides/storage/security/access-control).

Upsert deliberately allows replacing bytes at the same valid object key. The attachment RPC makes the **attached path** immutable through that RPC; it does not enforce immutable image contents. These policies validate old and new paths independently, so Storage move/rename between two valid paths belonging to the same user is also permitted. Future Flutter must use upload/upsert at the chosen key, not move/rename attached objects. A permanent reference/content invariant across later Storage mutations would require additional design.

The four permitted extensions also mean more than one candidate object can exist for a capture if callers change the filename. Only one can be attached through the RPC. Retry with the same extension/key to avoid orphan objects. Client deletion, account-deletion cleanup and replacement workflows remain separate; no cleanup is performed here.

## Attachment RPC

```sql
public.attach_capture_photo(
  p_capture_id uuid,
  p_storage_path text
)
returns table (
  capture_id uuid,
  photo_storage_path text
)
```

The RPC accepts no owner or bucket parameter. SECURITY DEFINER is needed because clients cannot directly UPDATE captures. It uses `set search_path = ''`, qualified database objects/functions, a fixed bucket, and explicit ownership checks. Only authenticated receives an execution grant; PUBLIC and anon are revoked. This is a narrowly scoped photo attachment operation, not a generic capture updater.

Validation order:

1. Derive the owner from `auth.uid()`; a missing identity raises `not_authenticated`.
2. Fetch and lock the caller's capture with FOR UPDATE. Missing IDs, NULL IDs and another user's IDs all raise `capture_unavailable`.
3. Require one exact allowed path constructed from that owner and capture UUID; otherwise raise `invalid_photo_path`.
4. Require a `storage.objects` record with bucket `capture-photos`, the exact name and matching `owner_id`; otherwise raise `photo_not_uploaded`. FOR SHARE holds the matched metadata row against mutation/deletion until the transaction ends.
5. If no path is attached, update only `photo_storage_path`. If the same path is attached, return success without an UPDATE. A different existing path raises `photo_already_attached`.

All listed application errors use SQLSTATE `P0001` with the stable token as the message. Object verification precedes the already-attached comparison, so a nonexistent alternate path yields `photo_not_uploaded`. Same-path retries also require the object to still exist and belong to the caller.

The capture lock serializes competing attachments: after one succeeds, another uploaded path cannot silently replace it. Return values contain only capture UUID and storage path. User/spot ownership, GPS, distance, timestamps, snapshots and client capture ID are unchanged.

Object verification checks Storage's database record, which is the SQL boundary available to this RPC; it is not a separate download or blob integrity check. Upload bytes through the Storage API, never by inserting metadata rows directly. Trusted administrators can bypass client policies, and later administrative deletion can leave a stale attachment; cleanup and reconciliation are not implemented here.

## Implemented Flutter flow

1. `CaptureDraft` calls `create_capture` and receives the server capture UUID. Map accepts it immediately, even if later photo work fails.
2. `CapturePhotoStorage.enqueue` persists the capture UUID, owner UUID and local image path in SharedPreferences before photo inspection or upload. The draft saves the existing local compatibility record before uploading, so temporary photo failure does not remove Journey/Pins data.
3. The service inspects the file, constructs and persists its deterministic path/MIME, then calls the existing initialized Supabase client's `storage.from('capture-photos').upload(File, fileOptions: FileOptions(contentType: ..., upsert: true))`.
4. After upload succeeds, the service persists `uploaded: true` and calls `attach_capture_photo` with only `p_capture_id` and `p_storage_path`. It validates the returned capture UUID and path, updates local photo metadata, then clears the pending record.
5. The draft returns completion to the existing reward flow. Only the original camera completion can claim that transition, once. Photo recovery never calls `create_capture`, opens reward selection or writes rewards.

The service separates the durable queue (`CapturePhotoStorage`), upload/RPC transport (`SupabaseCapturePhotoRemote`) and file/path validation (`CapturePhotoType`). Widgets contain no Storage API calls. `CapturePhotos` and `CapturePhotoRemote` permit tests with fake transports; normal code uses the shared service and existing Supabase client. No dependencies, conversion, compression, new buckets, public URLs or persisted signed URLs are introduced.

### Camera audit and MIME handling

`CaptureScreen` uses `CameraController` at `ResolutionPreset.high`, calls `takePicture()` and retains the resulting `XFile.path`. It neither copies nor transforms the file. The locked Android CameraX plugin (0.6.27) creates `CAP*.jpg` in the Android application cache directory. No existing conversion/compression pipeline was found. The draft retains the first selected path and disables retake once submission starts; code does not delete it after upload.

Uploads require a supported filename extension and matching header signature: JPEG (`FF D8 FF`), PNG (eight-byte PNG signature), or WebP (`RIFF` and `WEBP`). JPEG `.jpg` and `.jpeg` normalize to `original.jpg` / `image/jpeg`; PNG uses `original.png` / `image/png`; WebP uses `original.webp` / `image/webp`. Unsupported or mismatched files are rejected without relabeling/conversion. This checks the format signature, not a full image decode. A local 15 MiB upper guard avoids oversized uploads; the deployed bucket's actual byte limit remains authoritative and may reject a smaller file.

The central helper constructs `<auth UUID>/<server capture UUID>/original.<ext>` using canonical lowercase UUIDs. No username, email, spot ID, client capture ID or local filename becomes remote ownership identity. The path/MIME are persisted before upload and cannot change silently during retries.

### Recovery, persistence and account switches

Pending keys are `capture_photo_pending_v1:<auth UUID>:<capture UUID>`, one JSON entry per capture. Fields are `userId`, `captureId`, `localPath`, nullable `storagePath`/`mimeType` until successful inspection, and `uploaded`. No token, GPS or profile snapshot is added to this queue. Each record has its own key, preventing concurrent captures from overwriting a shared pending list. Simultaneous retries for the same record share one Future in the production singleton.

On upload failure, the capture and compatibility record remain valid. Camera shows a friendly error, **Retry Upload**, and **Continue to rewards**. Continue leaves photo recovery pending; it does not claim an uploaded photo. Closing the camera without completing the reward transition also leaves pending photos available, but does not create a reward retrospectively.

The shell displays a compact pending-photo banner above the existing tab bar. It reloads the current user's pending metadata on account change, app resume and queue changes. After restart, tap **Retry Upload** to process that user's queue. This is explicit foreground recovery, not automatic background uploading. Tab mapping and Map styling are unchanged.

An ambiguous upload retries an upsert at the **same path**. Once upload success is recorded, retries reuse that object and call attachment only, including after a lost attachment response or restart. `photo_not_uploaded` resets that record to permit re-uploading at the same path. Successful attachment synchronizes any existing local record before clearing pending state, so a local save failure can retry attachment safely.

Every processing stage checks the current auth UUID. Old-account results cannot continue into attachment or rewards after a switch. Each individual upload/RPC also pins its Authorization header to the initiating session token in memory, without changing shared headers: SDK file reads/auth refresh cannot substitute Abel's credentials into Camil's request. Work already sent can finish under Camil's original authorization; later stages stop. Returning to Camil restores his pending entry. No service-role credential is used.

Uploads have a 45-second wait timeout, attachment RPCs 15 seconds, and implicit Storage retries are disabled in favor of the visible queue. A Dart Future timeout does not cancel an already-sent request; fixed ownership and deterministic paths make subsequent retries safe. No raw Storage/PostgREST text or tokens are shown/logged. Named attachment errors and permission, size, format and generic network failures map to friendly photo-specific messages. `photo_already_attached` does not overwrite the attached path or local metadata; the pending entry remains for explicit resolution.

If the local file is missing before upload, recovery removes that pending entry and reports that the capture remains valid without an available local photo. If upload success was already recorded, attachment can finish even after the local file disappears. Cache eviction/reinstall can still lose unuploaded bytes; metadata persistence does not make Android cache durable. A lost upload response followed by cache loss may leave an unattached object. No destructive cleanup or automatic photo substitution is attempted.

### Local compatibility and remaining Journey boundary

`RemoteCapture` and the safe own-capture projection now include optional `photoStoragePath`. `CaptureRecord` stores optional `photoStoragePath` alongside the existing optional `remoteCaptureId`, `remoteSpotId` and `clientCaptureId`. Old JSON with none of these fields still parses. Successful attachment propagates its returned path into the current draft and existing user-scoped local record without changing the Proof ID, timestamps, author or reward contract.

`public.captures.photo_storage_path` is the authoritative photo identity. The Android image path is only a cache/reference. Journey/Pins still render local images; a full remote history/download migration is not implemented.

The bucket stays private. Future Journey can fetch the owner's remote capture path and use authenticated Storage download/read access, including on another device. NULL paths represent valid captures without an attached remote photo and must remain supported. Do not generate permanent public URLs.

Public Pins/feed access needs a separate publication/access design. This integration grants no public access, publishes no capture rows and exposes no capture GPS. Rewards, QR, Partner Mode, auth architecture, profiles, spots and radius remain unchanged.

Legacy device-wide photos have no trustworthy ownership mapping and are not migrated. The two existing NULL-photo test captures are not queued, backfilled or assigned arbitrary current photos. Only new accepted capture attempts enqueue photos. Already-captured reconciliation still fabricates no image/proof/reward. Process death between remote acceptance and the first successful local queue write can still lose the photo link; full capture drafts are not persisted. Death between queue persistence and compatibility save can recover the remote photo without reconstructing a local Journey entry or reward. Those are boundaries for future remote Journey/draft recovery.

## Validation and remaining runtime checks

Automated tests use mock SharedPreferences, temporary local images, fake capture/Storage transports and a loopback HTTP server exercising the real Supabase SDK multipart upload and RPC. They do not contact the live Supabase project. Coverage includes signatures/MIME, deterministic paths, exact attachment parameters, capture validity after upload failure, stable retries across restart, account switching, conflict handling, queue cleanup, compatible old JSON, photo metadata propagation, camera recovery controls and a single reward transition. Validation commands: format modified Dart files, `flutter analyze`, `flutter test`, `git diff --check`.

Integration validation: `flutter analyze` reported no issues; the full `flutter test` suite passed all 66 tests (19 added in this task); modified Dart files were formatted and whitespace checks passed. SQL, policies, bucket configuration and dependencies were not changed.

### Manual Android tests remaining

**TEST A — NEW PHOTO**

1. Sign in as Camil.
2. Pick an uncaptured spot.
3. Capture photo.
4. Tap Been.
5. Confirm `create_capture` succeeds.
6. Confirm photo uploads.
7. Confirm `attach_capture_photo` succeeds.
8. Confirm reward flow continues.

In Supabase, verify `public.captures.photo_storage_path` is `<Camil UUID>/<capture UUID>/original.<ext>`. In Storage, verify `capture-photos` → Camil UUID → capture UUID → `original.<ext>`.

**TEST B — PRIVATE OWNERSHIP**

1. Sign out Camil.
2. Sign in Abel.
3. Abel must not obtain/read Camil's capture photo through normal app access. For an explicit RLS download check, use authenticated Storage access with Abel's session in a controlled test; remote download UI is not implemented here.
4. Abel's own future photo must upload to Abel's own folder.

**TEST C — RESTART**

1. Create another capture or simulate a pending photo upload by disconnecting after remote capture success.
2. Kill/restart the app.
3. Verify the pending banner belongs to the same authenticated user; switching accounts hides the other user's pending work.
4. Restore connectivity and tap Retry Upload. Verify no second capture is created.
5. Verify the same Storage path is reused and the pending entry disappears after attachment. Also test a lost attachment response and cache eviction.

**TEST D — NORMAL SUCCESS**

After successful attachment, verify Map still shows the correct captured state, Journey and Pins retain the local entry, the reward appears once, and QR/Partner Mode remain unchanged. Test Retry Upload and Continue to rewards after a temporary upload failure; later shell recovery must not award another reward.

These device/live permission tests remain unexecuted by this implementation task. Existing user-reported Camil/Abel capture isolation tests predate photo upload integration.
