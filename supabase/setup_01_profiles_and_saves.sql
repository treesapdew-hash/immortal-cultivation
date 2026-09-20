-- =========================================================
-- Immortal Cultivation: Supabase setup, part 1
-- Player profiles and cloud saves.
--
-- Run once: Supabase dashboard > SQL Editor > New query >
-- paste this whole file > Run. Safe to run again.
--
-- Works with "Automatically expose new tables" OFF: access is
-- granted explicitly below (GRANT), only to signed-in players.
--
-- Row Level Security (RLS) makes sure every player can only
-- read and write their OWN save. Profiles are readable by all
-- signed-in players (needed for sect member lists, rankings).
-- =========================================================

-- ---------------------------------------------------------
-- PROFILES: the public face of a player
-- ---------------------------------------------------------
create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  display_name text not null default 'Cultivator',
  realm int not null default 0,
  highest_stage int not null default 1,
  power bigint not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

drop policy if exists "profiles readable by players" on public.profiles;
create policy "profiles readable by players" on public.profiles
  for select to authenticated using (true);

drop policy if exists "players create own profile" on public.profiles;
create policy "players create own profile" on public.profiles
  for insert to authenticated with check ((select auth.uid()) = id);

drop policy if exists "players update own profile" on public.profiles;
create policy "players update own profile" on public.profiles
  for update to authenticated
  using ((select auth.uid()) = id) with check ((select auth.uid()) = id);

-- ---------------------------------------------------------
-- SAVES: one cloud save per player
-- ---------------------------------------------------------
create table if not exists public.saves (
  user_id uuid primary key references auth.users (id) on delete cascade,
  data jsonb not null,
  version int not null default 1,
  updated_at timestamptz not null default now()
);

alter table public.saves enable row level security;

drop policy if exists "read own save" on public.saves;
create policy "read own save" on public.saves
  for select to authenticated using ((select auth.uid()) = user_id);

drop policy if exists "create own save" on public.saves;
create policy "create own save" on public.saves
  for insert to authenticated with check ((select auth.uid()) = user_id);

drop policy if exists "update own save" on public.saves;
create policy "update own save" on public.saves
  for update to authenticated
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);

-- ---------------------------------------------------------
-- ACCESS: signed-in players (including anonymous accounts) may
-- use these tables through the Data API. RLS above still limits
-- every row to what that player is allowed to see or change.
-- Nothing is granted to logged-out visitors (anon).
-- ---------------------------------------------------------
grant usage on schema public to authenticated;
grant select, insert, update on public.profiles to authenticated;
grant select, insert, update on public.saves to authenticated;
