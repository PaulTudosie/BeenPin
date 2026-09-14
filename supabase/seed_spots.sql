-- Run manually in Supabase SQL Editor. Requires the existing public.spots
-- table, extensions PostGIS, and authenticated active-spot SELECT RLS.
-- Re-running restores this audited catalog; UUIDs and created_at are preserved.
begin;

insert into public.spots
  (slug, name, description, category, location, capture_radius_m, image_url, is_active)
values
  ('hidden-graffiti', 'Hidden Graffiti', 'A more hidden, discovery-led stop designed to make exploration feel less obvious and more personal.', 'graffiti', extensions.st_setsrid(extensions.st_makepoint(26.1039, 44.4325), 4326)::extensions.geography, 10000, NULL, true),
  ('abandoned-factory', 'Abandoned Factory', 'An urban spot that gives the map energy and helps demonstrate varied city exploration routes.', 'urban', extensions.st_setsrid(extensions.st_makepoint(26.1065, 44.4300), 4326)::extensions.geography, 10000, NULL, true),
  ('old-staircase', 'Old Staircase', 'A visually interesting place with strong framing potential for mobile photography.', 'architecture', extensions.st_setsrid(extensions.st_makepoint(26.0987, 44.4352), 4326)::extensions.geography, 10000, NULL, true),
  ('arcul-de-triumf', 'Arcul de Triumf', 'A strong landmark spot with clear recognition value and a premium city-exploration feel. Good for a first-wave Bucharest demo because it is instantly understandable.', 'monument', extensions.st_setsrid(extensions.st_makepoint(26.0781, 44.467), 4326)::extensions.geography, 10000, NULL, true),
  ('ateneul-roman', 'Ateneul Român', 'One of the city’s most recognizable cultural icons. A very strong hero spot for photography, urban discovery, and partner storytelling.', 'culture', extensions.st_setsrid(extensions.st_makepoint(26.0966, 44.4413), 4326)::extensions.geography, 10000, NULL, true),
  ('parcul-herastrau', 'Parcul Herăstrău', 'A relaxed green area that balances landmark-heavy spots with a more lifestyle-oriented exploration moment.', 'nature', extensions.st_setsrid(extensions.st_makepoint(26.0858, 44.4663), 4326)::extensions.geography, 10000, NULL, true),
  ('palatul-parlamentului', 'Palatul Parlamentului', 'A visually imposing landmark that gives the app more weight and makes the city exploration proposition feel broader and more serious.', 'monument', extensions.st_setsrid(extensions.st_makepoint(26.0873, 44.4273), 4326)::extensions.geography, 10000, NULL, true),
  ('hanul-lui-manuc', 'Hanul lui Manuc', 'A recognizable historic location that works well for a more local, atmospheric, and Old Town-oriented experience.', 'history', extensions.st_setsrid(extensions.st_makepoint(26.1030, 44.4318), 4326)::extensions.geography, 10000, NULL, true),
  ('cismigiu-garden', 'Cișmigiu Garden', 'A softer city stop that adds variety to the demo and shows that exploration does not need to be limited to monuments.', 'nature', extensions.st_setsrid(extensions.st_makepoint(26.0915, 44.4370), 4326)::extensions.geography, 10000, NULL, true),
  ('piata-unirii', 'Piața Unirii', 'An urban spot that gives the map energy and helps demonstrate varied city exploration routes.', 'urban', extensions.st_setsrid(extensions.st_makepoint(26.1025, 44.4268), 4326)::extensions.geography, 10000, NULL, true),
  ('curtea-veche', 'Curtea Veche', 'A place with local identity that supports a richer and more memorable exploration flow.', 'history', extensions.st_setsrid(extensions.st_makepoint(26.1048, 44.4318), 4326)::extensions.geography, 10000, NULL, true),
  ('piata-victoriei', 'Piața Victoriei', 'An urban spot that gives the map energy and helps demonstrate varied city exploration routes.', 'urban', extensions.st_setsrid(extensions.st_makepoint(26.0857, 44.4521), 4326)::extensions.geography, 10000, NULL, true),
  ('therme-bucuresti', 'Therme București', 'A curated urban spot designed for exploration, capture, and a nearby real-world reward.', 'leisure', extensions.st_setsrid(extensions.st_makepoint(26.0685, 44.5773), 4326)::extensions.geography, 10000, NULL, true),
  ('floreasca-park', 'Floreasca Park', 'A calmer exploration point that adds breathing space to the overall city journey.', 'nature', extensions.st_setsrid(extensions.st_makepoint(26.1018, 44.4663), 4326)::extensions.geography, 10000, NULL, true),
  ('obor-market', 'Obor Market', 'An urban spot that gives the map energy and helps demonstrate varied city exploration routes.', 'urban', extensions.st_setsrid(extensions.st_makepoint(26.1153, 44.4512), 4326)::extensions.geography, 10000, NULL, true)
on conflict (slug) do update set
  name = excluded.name,
  description = excluded.description,
  category = excluded.category,
  location = excluded.location,
  capture_radius_m = excluded.capture_radius_m,
  image_url = excluded.image_url,
  is_active = excluded.is_active,
  updated_at = now();

-- Caller privileges/RLS apply. No SECURITY DEFINER and no write grants.
create or replace function public.get_active_spots()
returns table (
  id uuid,
  slug text,
  name text,
  description text,
  category text,
  latitude double precision,
  longitude double precision,
  capture_radius_m integer,
  image_url text,
  is_active boolean
)
language sql
stable
security invoker
set search_path = ''
as $$
  select s.id, s.slug, s.name, s.description, s.category,
    extensions.st_y(s.location::extensions.geometry) as latitude,
    extensions.st_x(s.location::extensions.geometry) as longitude,
    s.capture_radius_m, s.image_url, s.is_active
  from public.spots as s
  where s.is_active = true
  order by s.slug;
$$;

revoke all on function public.get_active_spots() from public, anon;
grant execute on function public.get_active_spots() to authenticated;

commit;

-- Administrative verification (also record UUIDs before a repeat run).
select id, slug, name,
  extensions.st_y(location::extensions.geometry) as latitude,
  extensions.st_x(location::extensions.geometry) as longitude,
  capture_radius_m, is_active
from public.spots
where slug in (
  'hidden-graffiti',
  'abandoned-factory',
  'old-staircase',
  'arcul-de-triumf',
  'ateneul-roman',
  'parcul-herastrau',
  'palatul-parlamentului',
  'hanul-lui-manuc',
  'cismigiu-garden',
  'piata-unirii',
  'curtea-veche',
  'piata-victoriei',
  'therme-bucuresti',
  'floreasca-park',
  'obor-market'
)
order by slug;

