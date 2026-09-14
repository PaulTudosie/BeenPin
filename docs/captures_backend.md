# BeenPin captures database foundation

Prepared 2026-09-15. **SQL artifact only: not executed.** Manually run `supabase/captures_schema.sql` as the trusted `postgres` administrator in Supabase SQL Editor after review, preferably against the development project first. The file wraps deployment in a transaction and finishes with read-only metadata verification queries. It does not connect to Supabase automatically.

This implementation follows the fixed product decisions supplied after `captures_audit.md`; that earlier document remains the historical audit. In particular, this stage uses the smaller schema, mandatory proof coordinates, Auth-user deletion cascade, server timestamps, and no import fields. No Flutter, spots, profiles, local capture, rewards/QR, Partner Mode or Hidden behavior changes.

## Schema

`public.captures` has exactly these columns:

| Column | Type | Null/default/reference |
| --- | --- | --- |
| `id` | uuid | NOT NULL, primary key, `pg_catalog.gen_random_uuid()` |
| `user_id` | uuid | NOT NULL, `auth.users(id) ON DELETE CASCADE` |
| `spot_id` | uuid | NOT NULL, `public.spots(id) ON DELETE RESTRICT` |
| `client_capture_id` | uuid | NOT NULL, supplied retry identity |
| `captured_at` | timestamptz | NOT NULL, server `pg_catalog.now()` |
| `capture_location` | extensions.geography(Point,4326) | NOT NULL, private proof |
| `distance_from_spot_m` | double precision | NOT NULL, computed server-side |
| `spot_slug_snapshot` | text | NOT NULL, copied from validated spot |
| `spot_name_snapshot` | text | NOT NULL, copied from validated spot |
| `photo_storage_path` | text | NULL; this stage enforces NULL |
| `created_at` | timestamptz | NOT NULL, server `pg_catalog.now()` |

There is no captured boolean, display-author ownership, reward/QR/redemption data, social engagement, or device photo path. Snapshots survive spot renaming. A user's deletion cascades their remote capture rows; deletion of a referenced spot is blocked. Neither operation affects current local rewards or captures through this script.

## Constraints and indexes

- `captures_user_spot_key`: unique `(user_id, spot_id)`, one capture per user/spot.
- `captures_user_client_capture_key`: unique `(user_id, client_capture_id)`, one result per owner's retry key. Different users can reuse the same UUID without sharing records.
- `captures_distance_check`: nonnegative finite distance, excluding positive/negative infinity and NaN.
- `captures_location_check`: nonempty point and latitude/longitude bounds; geography typmod supplies Point/SRID restriction.
- `captures_slug_check` and `captures_name_check`: snapshots cannot be blank.
- `captures_photo_pending_check`: path must remain NULL until an explicit future Storage migration replaces this check.

The primary key and two unique constraints create their own B-tree indexes. `captures_user_captured_at_idx (user_id, captured_at DESC, id DESC)` supports owner-scoped chronological lists and stable pagination. `captures_spot_id_idx (spot_id)` supports FK and administrative spot lookups. No redundant standalone `user_id` index, global `captured_at` index, or GPS GiST index is needed for the current private owner-list workload.

## RLS and grants

RLS is enabled. The sole policy, `captures_select_own`, permits authenticated SELECT where `(select auth.uid()) = user_id`. There are no client INSERT/UPDATE/DELETE policies. The script revokes table privileges from PUBLIC, anon, authenticated and service_role, then grants authenticated SELECT only and service_role ALL for trusted administration. Service-role credentials must remain server-side; they bypass RLS. Owners/admins are privileged exceptions to client restrictions. Grants and RLS are separate controls. [Supabase RLS reference](https://supabase.com/docs/guides/database/postgres/row-level-security).

Function execution is revoked from PUBLIC, anon, authenticated and service_role, then granted only to authenticated. The trusted function owner retains implicit administrative execution. No client can set ownership/time/distance via direct table writes or this RPC's input parameters.

## RPC contract

```text
public.create_capture(
  p_spot_id uuid,
  p_latitude double precision,
  p_longitude double precision,
  p_client_capture_id uuid
)

RETURNS TABLE (
  capture_id uuid,
  spot_id uuid,
  client_capture_id uuid,
  captured_at timestamptz,
  distance_from_spot_m double precision,
  spot_slug text,
  spot_name text
)
```

Success returns exactly one row, including for a retry. The response contains no raw geography, photo path, or reward identity. Future Flutter code must retain a client UUID before submission and reuse it after network ambiguity; this task does not add that code.

The function is `VOLATILE SECURITY DEFINER` because the caller has no table INSERT privilege. It derives `auth.uid()` itself, verifies the user exists, uses an empty `search_path`, schema-qualifies referenced objects/functions, and exposes no dynamic SQL or arbitrary write parameters. Deploy with a trusted owner (`postgres`), never a client role. SECURITY DEFINER requires careful privilege and search-path configuration. [PostgreSQL function security documentation](https://www.postgresql.org/docs/current/sql-createfunction.html).

## Exact validation and write order

1. Obtain `auth.uid()`. Reject NULL or absent `auth.users` identity as `not_authenticated`.
2. Reject NULL `p_client_capture_id` as `invalid_client_capture_id`. Invalid UUID syntax is rejected by PostgreSQL argument parsing before the function body.
3. Acquire a transaction-scoped advisory lock derived from the authenticated user's UUID and a BeenPin namespace. This serializes that user's capture calls, including retries; it cannot confer access to another user's rows. Locks release at transaction end.
4. Look up `(user_id, client_capture_id)`. If found, return that saved result without changing anything or revalidating the current spot/GPS inputs.
5. For a new request, require non-NULL latitude in [-90,90] and longitude in [-180,180]. NaN and infinities fail these bounds. Otherwise raise `invalid_coordinates`.
6. Load the requested active spot with `FOR SHARE`, holding its catalog values stable until transaction end. Missing/NULL spot UUID, inactive spot, missing/empty location, nonpositive/missing radius, or blank name/slug yields `spot_unavailable`.
7. If this owner already captured this spot using another key, raise `already_captured`.
8. Construct `extensions.st_setsrid(extensions.st_makepoint(longitude, latitude),4326)::extensions.geography`.
9. Compute `extensions.st_distance(user_point, spot.location)`. Reject invalid computed distance as `spot_unavailable`, or distance greater than the spot's radius as `outside_capture_radius`.
10. Insert owner, validated spot UUID, retry key, point, computed distance, spot snapshots and NULL photo path. ID and both timestamps come from database defaults.
11. On a uniqueness conflict, do not update. Re-read this owner's retry key and return it; otherwise an existing owner/spot yields `already_captured`. An unexpected conflict with no surviving matching row yields retryable SQLSTATE `40001`, message `capture_retry_required`.
12. Return the typed projection above.

Application errors use SQLSTATE `P0001` and the exact lower-case message tokens above. Clients should branch on message as well as code; all application errors intentionally share P0001. Permission denial (for example anon RPC execution) can occur before the body with `42501`; callers are not guaranteed to receive `not_authenticated` when they lack EXECUTE permission. Malformed typed arguments may produce PostgreSQL input errors such as `22P02`.

## Retry and concurrency semantics

The retry key identifies the first accepted request. Reusing it with changed coordinates or even a different spot returns the original row, not a new capture or an edit. Clients must inspect the returned spot and never intentionally reuse a key for another action. This behavior implements the requested unconditional same-owner/same-key recovery contract. It also works after a spot is renamed/deactivated or the user moves away. Distinct keys for an already captured active spot fail without changing its history.

Per-user transaction locks serialize RPC calls; uniqueness constraints remain the final protection, including against administrative writes that bypass those locks. `INSERT ... ON CONFLICT DO NOTHING` never overwrites a capture. The subsequent lookup is a separate statement so it can see a committed winner at READ COMMITTED. [PostgreSQL INSERT documentation](https://www.postgresql.org/docs/current/sql-insert.html).

Use the normal READ COMMITTED RPC transaction. At stronger isolation levels, PostgreSQL can raise serialization failures; retry the whole transaction with the same client key. Hash collisions in the advisory-lock namespace can delay unrelated requests but cannot mix ownership. Lock waits last until transaction end; do not wrap user RPCs in long-lived transactions. UUID uniqueness does not mean captured_at changes on retry: the original ID, timestamp, distance and snapshots are returned unchanged.

## Distance, time and privacy boundaries

PostGIS geography `ST_Distance` computes spheroidal distance in meters. [PostGIS ST_Distance reference](https://postgis.net/docs/ST_Distance.html). The RPC always reads `spots.capture_radius_m`; there is no hard-coded production or development radius. The current 10000 m (10 km) rows work unchanged. Distance equal to the radius is accepted; greater distances fail. The script neither edits the catalog nor the current Flutter gate. Small differences from Flutter's distance implementation near a boundary are possible; backend calculation is authoritative when the future integration uses it.

`now()` is PostgreSQL transaction time, not a client timestamp or guaranteed shutter time. A request waiting for a lock retains that transaction timestamp. No historical/client timestamp parameter exists. The server validates submitted GPS against its own spot/radius; this does not prove the GPS was genuine, fresh, or tied to a photograph. Device attestation, GPS freshness/accuracy and upload verification are not implemented here.

Precise GPS is stored privately. An authenticated user can SELECT their own raw capture row; other users and anon cannot. Future Map should select only required columns from these own rows. Public Pins/feed will use a separate model later; no public feed policy or view is created.

## Historical data, photos and rewards

Historical local records remain legacy/device-local until manually reviewed or discarded during development. They cannot reliably be assigned to a Supabase account, including Camil's. There is no import/backfill SQL, no automatic owner assignment, and no deletion of historical data in this task.

`photo_storage_path` is future-facing. The RPC always inserts NULL and the table currently rejects any non-NULL path, including `/data/user/0/...`, `cache/...` or other device paths. A later Storage migration must replace the pending check with validated object-key rules and provide a controlled upload-completion operation. Store an object key rather than a local filesystem path or expiring signed URL then. No bucket/upload/policy is created now.

Existing reward Proof IDs, exact QR tokens, selected reward snapshots and redemption state remain untouched. Capture UUIDs are not replacements for old Proof IDs; rewards will migrate separately. No reward can be minted by replaying this schema file.

## Manual deployment and verification

Prerequisites are the supplied `public.spots` definition, `auth.users`, PostGIS in `extensions`, Supabase roles, and a trusted PostgreSQL owner. These have not been queried live. Review the entire SQL file, then manually run it in the intended development Supabase project. Do not rerun `seed_spots.sql` as part of captures deployment.

The script is re-runnable over the exact schema it creates: table/index creation uses IF NOT EXISTS, its own policy is replaced, function body and ACLs are reapplied, and existing capture rows are retained. Unexpected other capture policies abort the transaction. It intentionally does not repair an unrelated/drifted table or index. Before deploying over any pre-existing `captures` table, inspect columns, constraints, ownership, column grants, triggers and function overloads. IF NOT EXISTS does not validate an existing definition, table-level revocation does not remove custom column privileges, and this script does not delete unknown overloads or repair custom role inheritance. Do not proceed over such drift without a separate reviewed migration.

Bottom-of-file read-only queries verify table/column presence, RLS, policy expressions, constraints, indexes, function signature/return type/owner/search_path, table privilege matrix, column grants, function privilege matrix and explicit function ACLs. Expected client access: authenticated own-row SELECT plus RPC EXECUTE; anon neither; no authenticated direct DML. The service role has table administration but is not granted RPC execution. Privileged owners remain exceptions. These queries do not invoke the capture RPC or display user coordinates.

Metadata inspection is not runtime validation. Before Flutter integration, manually validate in the development project with real authenticated test accounts:

| Scenario | Expected |
| --- | --- |
| Valid active spot at its coordinates | One row, server timestamp, approximately zero distance |
| Same owner/key retried, including concurrent calls | Same capture ID/time/snapshots, one row |
| Same owner/key, changed payload or later inactive spot | Original result, no new row |
| Same owner/spot, different keys, including concurrency | One winner; others `already_captured` |
| Different owners, same spot or retry UUID | Independent captures; no cross-user SELECT |
| NULL/out-of-range/NaN/infinite coordinates for a new key | `invalid_coordinates` |
| Missing/inactive spot or invalid catalog metadata | `spot_unavailable` |
| Just inside/at/outside catalog radius | Accept/accept/reject using server distance |
| Current 10 km test catalog | Radius read from row, no 120 m override |
| Anonymous / authenticated direct DML | Permission denied |
| Account removed / missing auth identity | No new orphan row; auth validation/FK protection |
| Spot renamed after capture | Existing capture snapshots unchanged |

No runtime tests or SQL execution were performed in this task, including these write-producing acceptance scenarios. Validation performed locally: static SQL/security/concurrency review, `git diff --check`, and whitespace checks on both new files. Flutter formatting, analysis and tests are unrelated to these SQL/documentation changes and were not run.
