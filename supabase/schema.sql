-- Fuse · Supabase schema
-- Paste into the SQL editor of a fresh project. Safe to re-run.
--
-- One row per fold-to-fuse result. `artifact` holds the FuseArtifact JSON exactly as the
-- app encodes it (e.g. {"type":"itinerary", ...}) so a community row can be reopened.
-- Users are signed in anonymously (Auth › Providers › Anonymous sign-ins), which gives
-- every row an owner in auth.users without an account flow.

create table if not exists public.fuses (
  id          uuid        primary key default gen_random_uuid(),
  created_at  timestamptz not null default now(),
  user_id     uuid        references auth.users (id) on delete set null,
  device      text,
  left_kind   text        not null default 'unknown',
  left_title  text        not null default '',
  right_kind  text        not null default 'unknown',
  right_title text        not null default '',
  instruction text,
  recipe      text        not null default 'fuse',
  title       text        not null default 'Fused',
  summary     text        not null default '',
  artifact    jsonb,
  is_public   boolean     not null default false
);

comment on table  public.fuses            is 'Fuse results. One row per fold.';
comment on column public.fuses.left_kind  is 'SurfaceKind raw value of the left screen (web, maps, notes, photo, document, calendar, clipboard).';
comment on column public.fuses.right_kind is 'SurfaceKind raw value of the right screen.';
comment on column public.fuses.recipe     is 'Machine name of what the model decided to do (travel_plan, quiz, ...).';
comment on column public.fuses.artifact   is 'FuseArtifact JSON as encoded by the iOS app; "type" selects the renderer.';
comment on column public.fuses.is_public  is 'Shown in the community feed when true.';

-- Feed and history are both "newest first".
create index if not exists fuses_created_at_idx
  on public.fuses (created_at desc);

-- Partial index for the public feed (small, hot).
create index if not exists fuses_public_created_at_idx
  on public.fuses (created_at desc)
  where is_public;

-- Owner lookups (fetchMine + RLS checks).
create index if not exists fuses_user_id_idx
  on public.fuses (user_id);

-- ---------------------------------------------------------------------------
-- Row Level Security
-- ---------------------------------------------------------------------------

alter table public.fuses enable row level security;

-- Table privileges (RLS still decides which rows). Anonymous sign-ins use the
-- `authenticated` role with an `is_anonymous` JWT claim; `anon` is the key without a session.
grant select                         on public.fuses to anon;
grant select, insert, update, delete on public.fuses to authenticated;

drop policy if exists "fuses: insert own"   on public.fuses;
drop policy if exists "fuses: select own"   on public.fuses;
drop policy if exists "fuses: select public" on public.fuses;
drop policy if exists "fuses: update own"   on public.fuses;
drop policy if exists "fuses: delete own"   on public.fuses;

-- Any signed-in user (anonymous included) may insert rows they own.
create policy "fuses: insert own"
  on public.fuses
  for insert
  to authenticated
  with check ((select auth.uid()) = user_id);

-- Owners can read everything they made, public or not.
create policy "fuses: select own"
  on public.fuses
  for select
  to authenticated
  using ((select auth.uid()) = user_id);

-- Everyone can read the public feed, with or without a session.
create policy "fuses: select public"
  on public.fuses
  for select
  to anon, authenticated
  using (is_public);

-- Owners may toggle visibility or remove their own rows.
create policy "fuses: update own"
  on public.fuses
  for update
  to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

create policy "fuses: delete own"
  on public.fuses
  for delete
  to authenticated
  using ((select auth.uid()) = user_id);
