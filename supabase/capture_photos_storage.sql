-- BeenPin capture-photo foundation. MANUAL deployment only; not executed by app.
-- Run as trusted postgres administrator after captures_schema.sql is deployed.
-- Existing private capture-photos bucket is a prerequisite; never altered here.
-- Only our named photo constraints/policies and attach RPC are managed.
-- Capture rows are not updated by deployment. The UPDATE inside the RPC only
-- runs when the function is subsequently called by an authenticated owner.
--
-- Before running: record the bottom capture count/fingerprint query as baseline.
-- Compare after deployment while capture traffic is paused. No GPS is displayed.
begin;

alter table public.captures
  drop constraint if exists captures_photo_pending_check;

-- Re-runnable; validate existing rows and roll back the whole migration on failure.
alter table public.captures
  drop constraint if exists captures_photo_storage_path_check;
alter table public.captures
  add constraint captures_photo_storage_path_check check (
    photo_storage_path is null
    or photo_storage_path in (
      user_id::text || '/' || id::text || '/original.jpg',
      user_id::text || '/' || id::text || '/original.jpeg',
      user_id::text || '/' || id::text || '/original.png',
      user_id::text || '/' || id::text || '/original.webp'
    )
  );

-- Storage already supplies table privileges and RLS. Do not revoke global
-- storage.objects privileges or touch other buckets' policies.
-- Exact name equality enforces three components, canonical UUIDs and filename.
drop policy if exists capture_photos_insert_own on storage.objects;
create policy capture_photos_insert_own
on storage.objects for insert to authenticated
with check (
  bucket_id = 'capture-photos'
  and owner_id = (select auth.uid())::text
  and exists (
    select 1
    from public.captures as c
    where c.user_id = (select auth.uid())
      -- Compare against UUID columns as text; malformed names never get cast.
      and storage.objects.name in (
        c.user_id::text || '/' || c.id::text || '/original.jpg',
        c.user_id::text || '/' || c.id::text || '/original.jpeg',
        c.user_id::text || '/' || c.id::text || '/original.png',
        c.user_id::text || '/' || c.id::text || '/original.webp'
      )
  )
);

drop policy if exists capture_photos_select_own on storage.objects;
create policy capture_photos_select_own
on storage.objects for select to authenticated
using (
  bucket_id = 'capture-photos'
  and owner_id = (select auth.uid())::text
  and exists (
    select 1
    from public.captures as c
    where c.user_id = (select auth.uid())
      -- Compare against UUID columns as text; malformed names never get cast.
      and storage.objects.name in (
        c.user_id::text || '/' || c.id::text || '/original.jpg',
        c.user_id::text || '/' || c.id::text || '/original.jpeg',
        c.user_id::text || '/' || c.id::text || '/original.png',
        c.user_id::text || '/' || c.id::text || '/original.webp'
      )
  )
);

drop policy if exists capture_photos_update_own on storage.objects;
create policy capture_photos_update_own
on storage.objects for update to authenticated
using (
  bucket_id = 'capture-photos'
  and owner_id = (select auth.uid())::text
  and exists (
    select 1
    from public.captures as c
    where c.user_id = (select auth.uid())
      -- Compare against UUID columns as text; malformed names never get cast.
      and storage.objects.name in (
        c.user_id::text || '/' || c.id::text || '/original.jpg',
        c.user_id::text || '/' || c.id::text || '/original.jpeg',
        c.user_id::text || '/' || c.id::text || '/original.png',
        c.user_id::text || '/' || c.id::text || '/original.webp'
      )
  )
)
with check (
  bucket_id = 'capture-photos'
  and owner_id = (select auth.uid())::text
  and exists (
    select 1
    from public.captures as c
    where c.user_id = (select auth.uid())
      -- Compare against UUID columns as text; malformed names never get cast.
      and storage.objects.name in (
        c.user_id::text || '/' || c.id::text || '/original.jpg',
        c.user_id::text || '/' || c.id::text || '/original.jpeg',
        c.user_id::text || '/' || c.id::text || '/original.png',
        c.user_id::text || '/' || c.id::text || '/original.webp'
      )
  )
);

-- No DELETE policy. No anonymous/public read policy.

create or replace function public.attach_capture_photo(
  p_capture_id uuid,
  p_storage_path text
)
returns table (
  capture_id uuid,
  photo_storage_path text
)
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_user_id uuid;
  v_existing_path text;
  v_prefix text;
begin
  v_user_id := auth.uid();
  if v_user_id is null then
    raise exception using errcode = 'P0001', message = 'not_authenticated';
  end if;

  -- Serialize attachments to this capture. Foreign and missing IDs are identical.
  select c.photo_storage_path into v_existing_path
  from public.captures as c
  where c.id = p_capture_id and c.user_id = v_user_id
  for update;
  if not found then
    raise exception using errcode = 'P0001', message = 'capture_unavailable';
  end if;

  v_prefix := v_user_id::text || '/' || p_capture_id::text || '/original.';
  if p_storage_path is null or p_storage_path not in (
    v_prefix || 'jpg',
    v_prefix || 'jpeg',
    v_prefix || 'png',
    v_prefix || 'webp'
  ) then
    raise exception using errcode = 'P0001', message = 'invalid_photo_path';
  end if;

  -- Verify Storage's object record, not just a caller-supplied plausible name.
  -- Hold it against concurrent metadata mutation/deletion until this transaction
  -- ends. Upload through Storage API; never insert storage.objects rows manually.
  perform 1
  from storage.objects as o
  where o.bucket_id = 'capture-photos'
    and o.name = p_storage_path
    and o.owner_id = v_user_id::text
  for share;
  if not found then
    raise exception using errcode = 'P0001', message = 'photo_not_uploaded';
  end if;

  if v_existing_path is not null and v_existing_path <> p_storage_path then
    raise exception using errcode = 'P0001', message = 'photo_already_attached';
  end if;

  if v_existing_path is null then
    update public.captures as c
    set photo_storage_path = p_storage_path
    where c.id = p_capture_id and c.user_id = v_user_id;
  end if;

  -- Same-path retries succeed without another UPDATE; no private GPS is returned.
  return query select p_capture_id, p_storage_path;
end;
$function$;

-- Definer authority is limited to this checked operation; no direct client
-- captures UPDATE grant. Function owner/admin retains inherent execution rights.
revoke all on function public.attach_capture_photo(uuid, text)
  from public, anon, authenticated, service_role;
grant execute on function public.attach_capture_photo(uuid, text)
  to authenticated;

commit;

-- SAFE READ-ONLY VERIFICATION (run as administrator).
-- 1/2. Expect one row, is_private=true, configured 15 MB and three allowed MIME
-- types. Size is reported in bytes so the Dashboard's MB setting can be checked.
select b.id, not b.public as is_private,
  b.file_size_limit as max_file_size_bytes, b.allowed_mime_types
from storage.buckets as b
where b.id = 'capture-photos';

-- 3. Expect INSERT, SELECT, UPDATE to authenticated; UPDATE has both predicates.
select p.policyname, p.permissive, p.roles, p.cmd, p.qual, p.with_check
from pg_catalog.pg_policies as p
where p.schemaname = 'storage' and p.tablename = 'objects'
  and p.policyname in (
    'capture_photos_insert_own',
    'capture_photos_select_own',
    'capture_photos_update_own'
  )
order by p.policyname;

-- Review other policies for overlap, particularly unscoped ALL/DELETE/public
-- grants. Unrelated bucket policies are expected and are never rejected/dropped.
select p.policyname, p.permissive, p.roles, p.cmd, p.qual, p.with_check
from pg_catalog.pg_policies as p
where p.schemaname = 'storage' and p.tablename = 'objects'
  and p.policyname not in (
    'capture_photos_insert_own',
    'capture_photos_select_own',
    'capture_photos_update_own'
  )
order by p.policyname;

select c.relrowsecurity as storage_objects_rls_enabled
from pg_catalog.pg_class as c
where c.oid = 'storage.objects'::pg_catalog.regclass;

-- 4. Expect only the new validated constraint, no pending NULL-only constraint.
select c.conname, c.convalidated, pg_catalog.pg_get_constraintdef(c.oid) as definition
from pg_catalog.pg_constraint as c
where c.conrelid = 'public.captures'::pg_catalog.regclass
  and c.conname in (
    'captures_photo_pending_check', 'captures_photo_storage_path_check'
  );

-- 5/6. Expect SECURITY DEFINER, empty search_path, two typed output columns,
-- trusted administrator owner; explicit EXECUTE grant only for authenticated.
select p.oid::pg_catalog.regprocedure as signature,
  pg_catalog.pg_get_function_result(p.oid) as result_type,
  p.prosecdef as security_definer, p.proconfig,
  pg_catalog.pg_get_userbyid(p.proowner) as function_owner, p.proacl
from pg_catalog.pg_proc as p
where p.oid = 'public.attach_capture_photo(uuid,text)'::pg_catalog.regprocedure;

select r.role_name,
  pg_catalog.has_function_privilege(
    r.role_name, 'public.attach_capture_photo(uuid,text)', 'EXECUTE'
  ) as can_execute
from (values ('anon'), ('authenticated'), ('service_role')) as r(role_name);

-- Expanded ACL: PUBLIC must have no EXECUTE entry; owner rights are expected.
select case when a.grantee = 0 then 'PUBLIC'
    else pg_catalog.pg_get_userbyid(a.grantee) end as grantee,
  a.privilege_type, a.is_grantable
from pg_catalog.pg_proc as p
cross join lateral pg_catalog.aclexplode(
  coalesce(p.proacl, pg_catalog.acldefault('f', p.proowner))
) as a
where p.oid = 'public.attach_capture_photo(uuid,text)'::pg_catalog.regprocedure;

-- 7. Run before AND after deployment without concurrent capture writes.
-- Matching counts/fingerprints provide a before/after check of all row values.
-- Only an aggregate hash is output, never coordinates or individual capture rows.
-- A post-deployment count alone does not prove that rows remained unchanged.
select pg_catalog.count(*) as capture_count,
  pg_catalog.count(*) filter (where c.photo_storage_path is null) as without_photo,
  pg_catalog.count(*) filter (where c.photo_storage_path is not null) as with_photo,
  pg_catalog.md5(coalesce(pg_catalog.string_agg(
    pg_catalog.md5(pg_catalog.row_to_json(c)::text), '' order by c.id
  ), '')) as capture_rows_fingerprint
from public.captures as c;
