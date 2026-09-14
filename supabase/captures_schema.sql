-- BeenPin captures foundation. MANUAL deployment only; not run by Flutter.
-- Run as the trusted postgres administrator in Supabase SQL Editor.
-- Prerequisites: auth.users, public.spots, PostGIS in extensions.
-- Re-runnable for this exact schema; not a repair script for schema drift.
-- No historical import, spot changes, reward changes, or photo uploads.
begin;

create table if not exists public.captures (
  id uuid primary key default pg_catalog.gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  spot_id uuid not null references public.spots(id) on delete restrict,
  client_capture_id uuid not null,
  captured_at timestamptz not null default pg_catalog.now(),
  capture_location extensions.geography(Point, 4326) not null,
  distance_from_spot_m double precision not null,
  spot_slug_snapshot text not null,
  spot_name_snapshot text not null,
  photo_storage_path text null,
  created_at timestamptz not null default pg_catalog.now(),

  constraint captures_user_spot_key unique (user_id, spot_id),
  constraint captures_user_client_capture_key unique (user_id, client_capture_id),
  -- PostgreSQL orders NaN above Infinity; the upper bound rejects both.
  constraint captures_distance_check check (
    distance_from_spot_m >= 0
    and distance_from_spot_m < 'Infinity'::double precision
  ),
  constraint captures_location_check check (
    not extensions.st_isempty(capture_location::extensions.geometry)
    and extensions.st_y(capture_location::extensions.geometry) between -90 and 90
    and extensions.st_x(capture_location::extensions.geometry) between -180 and 180
  ),
  constraint captures_slug_check check (pg_catalog.btrim(spot_slug_snapshot) <> ''),
  constraint captures_name_check check (pg_catalog.btrim(spot_name_snapshot) <> ''),
  -- Storage is not enabled in this stage. Prevent accidental local path uploads,
  -- including administrative writes. Replace this check in the Storage stage.
  constraint captures_photo_pending_check check (photo_storage_path is null)
);

-- The unique indexes already cover owner lookups. These add chronological
-- owner pagination and spot FK/administrative lookups without redundant indexes.
create index if not exists captures_user_captured_at_idx
  on public.captures (user_id, captured_at desc, id desc);
create index if not exists captures_spot_id_idx
  on public.captures (spot_id);

alter table public.captures enable row level security;

-- Stop instead of silently retaining an unexpected permissive policy on rerun.
do $policy_guard$
begin
  if exists (
    select 1 from pg_catalog.pg_policies as p
    where p.schemaname = 'public' and p.tablename = 'captures'
      and p.policyname <> 'captures_select_own'
  ) then
    raise exception 'captures_unexpected_policy: review existing policies before deployment';
  end if;
end;
$policy_guard$;

drop policy if exists captures_select_own on public.captures;
create policy captures_select_own on public.captures
  for select to authenticated
  using ((select auth.uid()) = user_id);

revoke all on table public.captures from public, anon, authenticated, service_role;
grant select on table public.captures to authenticated;
grant all on table public.captures to service_role;

create or replace function public.create_capture(
  p_spot_id uuid,
  p_latitude double precision,
  p_longitude double precision,
  p_client_capture_id uuid
)
returns table (
  capture_id uuid,
  spot_id uuid,
  client_capture_id uuid,
  captured_at timestamptz,
  distance_from_spot_m double precision,
  spot_slug text,
  spot_name text
)
language plpgsql
volatile
security definer
set search_path = ''
as $create_capture$
declare
  v_user_id uuid := auth.uid();
  v_spot public.spots%rowtype;
  v_capture public.captures%rowtype;
  v_location extensions.geography(Point, 4326);
  v_distance double precision;
begin
  -- Ownership is always the authenticated subject, never a request parameter.
  if v_user_id is null or not exists (
    select 1 from auth.users as u where u.id = v_user_id
  ) then
    raise exception using errcode = 'P0001', message = 'not_authenticated';
  end if;
  if p_client_capture_id is null then
    raise exception using errcode = 'P0001', message = 'invalid_client_capture_id';
  end if;

  -- Serialize this user's calls until transaction end. A hash collision only
  -- serializes unrelated users; it never affects ownership or uniqueness.
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended('beenpin:create_capture:' || v_user_id::text, 0)
  );

  select c.* into v_capture from public.captures as c
  where c.user_id = v_user_id and c.client_capture_id = p_client_capture_id;

  if not found then
    -- Retry lookup deliberately precedes validation of new capture inputs.
    -- A committed capture remains retrievable after a rename/deactivation or
    -- after the caller moves away. Reusing its key never edits the old row.
    if p_latitude is null or p_longitude is null
      or not (p_latitude between -90 and 90)
      or not (p_longitude between -180 and 180) then
      raise exception using errcode = 'P0001', message = 'invalid_coordinates';
    end if;

    -- SHARE also prevents a concurrent catalog edit/deactivation while this
    -- transaction validates and snapshots the spot. It does not modify spots.
    select s.* into v_spot from public.spots as s
    where s.id = p_spot_id and s.is_active = true
    for share;
    if not found then
      raise exception using errcode = 'P0001', message = 'spot_unavailable';
    end if;
    if v_spot.location is null or v_spot.capture_radius_m is null
      or v_spot.capture_radius_m <= 0
      or extensions.st_isempty(v_spot.location::extensions.geometry)
      or v_spot.slug is null or pg_catalog.btrim(v_spot.slug) = ''
      or v_spot.name is null or pg_catalog.btrim(v_spot.name) = '' then
      raise exception using errcode = 'P0001', message = 'spot_unavailable';
    end if;

    if exists (
      select 1 from public.captures as c
      where c.user_id = v_user_id and c.spot_id = p_spot_id
    ) then
      raise exception using errcode = 'P0001', message = 'already_captured';
    end if;

    v_location := extensions.st_setsrid(
      extensions.st_makepoint(p_longitude, p_latitude), 4326
    )::extensions.geography;
    -- Geography ST_Distance returns spheroidal meters. Never accept a client
    -- distance/radius; the catalog's current 10000 m configuration works as-is.
    v_distance := extensions.st_distance(v_location, v_spot.location);
    if v_distance is null or not (v_distance >= 0
      and v_distance < 'Infinity'::double precision) then
      raise exception using errcode = 'P0001', message = 'spot_unavailable';
    end if;
    if v_distance > v_spot.capture_radius_m then
      raise exception using errcode = 'P0001', message = 'outside_capture_radius';
    end if;

    insert into public.captures as c (
      user_id, spot_id, client_capture_id, capture_location,
      distance_from_spot_m, spot_slug_snapshot, spot_name_snapshot,
      photo_storage_path
    ) values (
      v_user_id, v_spot.id, p_client_capture_id, v_location,
      v_distance, v_spot.slug, v_spot.name, null
    )
    -- Both unique constraints remain the final safeguard, including against
    -- administrative writes that do not participate in the advisory lock.
    on conflict do nothing
    returning c.* into v_capture;

    if not found then
      -- Separate statement sees the committed winner at READ COMMITTED.
      select c.* into v_capture from public.captures as c
      where c.user_id = v_user_id and c.client_capture_id = p_client_capture_id;
      if not found then
        if exists (
          select 1 from public.captures as c
          where c.user_id = v_user_id and c.spot_id = p_spot_id
        ) then
          raise exception using errcode = 'P0001', message = 'already_captured';
        end if;
        -- Unexpected concurrent administrative deletion / UUID collision.
        -- Retry the whole transaction with the same client_capture_id.
        raise exception using errcode = '40001', message = 'capture_retry_required';
      end if;
    end if;
  end if;

  return query select
    v_capture.id, v_capture.spot_id, v_capture.client_capture_id,
    v_capture.captured_at, v_capture.distance_from_spot_m,
    v_capture.spot_slug_snapshot, v_capture.spot_name_snapshot;
end;
$create_capture$;

revoke all on function public.create_capture(uuid, double precision, double precision, uuid)
  from public, anon, authenticated, service_role;
grant execute on function public.create_capture(uuid, double precision, double precision, uuid)
  to authenticated;

commit;

-- SAFE READ-ONLY VERIFICATION. These inspect metadata, not users' GPS records.
-- Expected: table exists, RLS true; owner should be trusted postgres admin.
select c.oid::pg_catalog.regclass as table_name, c.relrowsecurity as rls_enabled,
  pg_catalog.pg_get_userbyid(c.relowner) as owner
from pg_catalog.pg_class as c
where c.oid = pg_catalog.to_regclass('public.captures');

select column_name, data_type, udt_schema, udt_name, is_nullable, column_default
from information_schema.columns
where table_schema = 'public' and table_name = 'captures'
order by ordinal_position;

-- Expected: only captures_select_own, SELECT for authenticated, auth.uid owner check.
select policyname, roles, cmd, qual, with_check
from pg_catalog.pg_policies
where schemaname = 'public' and tablename = 'captures';

select conname, pg_catalog.pg_get_constraintdef(oid) as definition
from pg_catalog.pg_constraint
where conrelid = pg_catalog.to_regclass('public.captures')
order by conname;

select indexname, indexdef from pg_catalog.pg_indexes
where schemaname = 'public' and tablename = 'captures'
order by indexname;

-- Expected: one create_capture overload, SECURITY DEFINER, empty search_path.
select p.oid::pg_catalog.regprocedure as signature, p.prosecdef as security_definer,
  p.proconfig, pg_catalog.pg_get_userbyid(p.proowner) as owner,
  pg_catalog.pg_get_function_result(p.oid) as result_type, p.proacl
from pg_catalog.pg_proc as p
join pg_catalog.pg_namespace as n on n.oid = p.pronamespace
where n.nspname = 'public' and p.proname = 'create_capture';

-- Expected: anon all false; authenticated SELECT only; service_role all true.
select r.role_name,
  pg_catalog.has_table_privilege(r.role_name::pg_catalog.name, 'public.captures', 'SELECT') as can_select,
  pg_catalog.has_table_privilege(r.role_name::pg_catalog.name, 'public.captures', 'INSERT') as can_insert,
  pg_catalog.has_table_privilege(r.role_name::pg_catalog.name, 'public.captures', 'UPDATE') as can_update,
  pg_catalog.has_table_privilege(r.role_name::pg_catalog.name, 'public.captures', 'DELETE') as can_delete
from (values ('anon'), ('authenticated'), ('service_role')) as r(role_name);

-- Check for unexpected retained column grants if deploying over a custom table.
select grantee, column_name, privilege_type
from information_schema.column_privileges
where table_schema = 'public' and table_name = 'captures'
  and grantee in ('PUBLIC', 'anon', 'authenticated')
order by grantee, column_name, privilege_type;

-- Expected: authenticated true; anon/service_role false (admin owner excepted).
select r.role_name, pg_catalog.has_function_privilege(
  r.role_name::pg_catalog.name,
  'public.create_capture(uuid,double precision,double precision,uuid)', 'EXECUTE'
) as can_execute
from (values ('anon'), ('authenticated'), ('service_role')) as r(role_name);

-- Confirm explicit ACLs, including PUBLIC (grantee OID 0). No PUBLIC entry expected.
select case when a.grantee = 0 then 'PUBLIC'
  else pg_catalog.pg_get_userbyid(a.grantee) end as grantee, a.privilege_type
from pg_catalog.pg_proc as p
cross join lateral pg_catalog.aclexplode(p.proacl) as a
where p.oid = pg_catalog.to_regprocedure(
  'public.create_capture(uuid,double precision,double precision,uuid)'
);
