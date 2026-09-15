# Capture photo Storage foundation

Status: **prepared for manual deployment; SQL has not been executed**. Flutter remains unchanged and does not upload photos or call the new RPC. Existing captures, local photos and the bucket have not been modified.

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

## Future Flutter flow and downloads

1. Call `create_capture` and receive the server capture UUID.
2. Construct and retain the deterministic owner/capture path and chosen extension.
3. Upload/upsert the local file to the private bucket with the authenticated session.
4. Call `attach_capture_photo` with that capture UUID and path.

If upload fails, the capture remains valid and its photo path remains NULL. Retain the local photo for retry. Current photos are Android cache files, so eviction/reinstall can remove that retry source; this migration does not add durable local file storage or a retry queue.

If upload succeeds but attachment fails or its response is lost, retry upload/attach with the **same path**. Upsert addresses the same object key, and the attachment RPC is idempotent. Do not create another capture or generate a random photo filename for the retry.

The bucket stays private. Future Journey can fetch the owner's remote capture path and use authenticated Storage download/read access, including on another device. NULL paths represent valid captures without an attached remote photo and must remain supported. Do not generate permanent public URLs.

Public Pins/feed access needs a separate publication/access design. This foundation does not grant other users access, publish capture rows, expose capture GPS or implement a social feed. Existing Flutter Map, Journey, Pins, rewards, QR, Partner Mode, Auth, profiles and spots are untouched.

Legacy device-wide photos have no trustworthy per-user ownership mapping and are not migrated. Current account-scoped records still reference local cache paths; this SQL does not backfill their photos or reconstruct Journey history. Existing remote captures remain unchanged until a future authenticated client explicitly uploads and attaches.

## Validation and remaining runtime checks

Preparation includes static SQL/security review and `git diff --check`; no SQL, RPC, upload or live Storage permission test is executed in this task. Flutter validation is unnecessary because no Flutter files or dependencies change.

After manual deployment, separately validate with two authenticated accounts and an unauthenticated client: own upload/read/upsert succeeds; wrong owner/capture, malformed filename and missing capture fail; foreign reads/overwrites and client DELETE fail; attaching before upload fails; same-path retry succeeds; a different uploaded path is rejected; concurrent attachments preserve the first path. Check size/MIME enforcement through the Storage API. These are future runtime acceptance checks, not evidence claimed by this preparation.
