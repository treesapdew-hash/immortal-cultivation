-- =========================================================
-- Immortal Cultivation: Supabase setup, part 18 — REAL BOARDS
-- Run after part 17: SQL Editor > New query ("18 - boards")
-- > paste > Run. Safe to run again.
--
-- The dungeon ranking and the Fallen God ranking were both lists of
-- invented cultivators with invented paces. They looked convincing,
-- and they cost real players rewards: both pay by rank, so thirty
-- fabricated rivals pushed everyone thirty places down the table.
--
-- These are the real ones. With few players a board is short and
-- everybody places well, which during an alpha is the honest
-- outcome rather than a problem to paper over.
--
-- Flagged accounts (see part 17) are left out, as with the Arena.
-- =========================================================

-- ---------------------------------------------------------
-- DUNGEON FLOORS
-- ---------------------------------------------------------
create table if not exists public.dungeon_scores (
  user_id uuid not null references public.profiles (id) on delete cascade,
  dungeon_id text not null,
  floor int not null default 0 check (floor >= 0),
  updated_at timestamptz not null default now(),
  primary key (user_id, dungeon_id)
);
create index if not exists dungeon_scores_board_idx
  on public.dungeon_scores (dungeon_id, floor desc);

alter table public.dungeon_scores enable row level security;
drop policy if exists "dungeon scores readable" on public.dungeon_scores;
create policy "dungeon scores readable" on public.dungeon_scores
  for select to authenticated using (true);

-- A high-water mark: it only ever goes up. Absurd values are
-- refused rather than recorded, so one bad client cannot sit at the
-- top of a board forever.
create or replace function public.max_dungeon_floor() returns int
language sql immutable as $$ select 10000 $$;

create or replace function public.submit_dungeon_floor(p_dungeon text, p_floor int)
returns json language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then
    return json_build_object('ok', false, 'error', 'Not signed in');
  end if;
  if coalesce(btrim(p_dungeon), '') = '' then
    return json_build_object('ok', false, 'error', 'Which dungeon?');
  end if;
  if p_floor is null or p_floor < 0 or p_floor > max_dungeon_floor() then
    return json_build_object('ok', false, 'error', 'That floor is out of range.');
  end if;

  insert into dungeon_scores (user_id, dungeon_id, floor)
    values (auth.uid(), btrim(p_dungeon), p_floor)
  on conflict (user_id, dungeon_id) do update
    set floor = greatest(dungeon_scores.floor, excluded.floor),
        updated_at = now();

  return json_build_object('ok', true, 'error', '');
end $$;

create or replace function public.dungeon_board(p_dungeon text, p_limit int default 20)
returns json language sql stable security definer set search_path = public as $$
  select coalesce(json_agg(json_build_object(
      'id', t.user_id, 'name', p.display_name, 'floor', t.floor)
    order by t.floor desc), '[]'::json)
  from (
    select d.* from dungeon_scores d
    join profiles pr on pr.id = d.user_id
    where d.dungeon_id = btrim(p_dungeon)
      and d.floor > 0
      and not pr.flagged
    order by d.floor desc
    limit least(greatest(coalesce(p_limit, 20), 1), 100)
  ) t
  join profiles p on p.id = t.user_id
$$;

-- ---------------------------------------------------------
-- THE FALLEN GOD
-- ---------------------------------------------------------
-- Scored by ratio (damage against an ordinary enemy's HP at your
-- stage), so it stays comparable between cultivators at wildly
-- different stages. One row per person per day.
create table if not exists public.fallen_god_scores (
  user_id uuid not null references public.profiles (id) on delete cascade,
  day date not null,
  ratio numeric(12, 3) not null default 0 check (ratio >= 0),
  updated_at timestamptz not null default now(),
  primary key (user_id, day)
);
create index if not exists fallen_god_board_idx
  on public.fallen_god_scores (day, ratio desc);

alter table public.fallen_god_scores enable row level security;
drop policy if exists "fallen god scores readable" on public.fallen_god_scores;
create policy "fallen god scores readable" on public.fallen_god_scores
  for select to authenticated using (true);

create or replace function public.max_god_ratio() returns numeric
language sql immutable as $$ select 100000.0 $$;

create or replace function public.submit_fallen_god(p_ratio numeric)
returns json language plpgsql security definer set search_path = public as $$
declare
  v_day date := (now() at time zone 'utc')::date;
begin
  if auth.uid() is null then
    return json_build_object('ok', false, 'error', 'Not signed in');
  end if;
  if p_ratio is null or p_ratio < 0 or p_ratio > max_god_ratio() then
    return json_build_object('ok', false, 'error', 'That score is out of range.');
  end if;

  insert into fallen_god_scores (user_id, day, ratio)
    values (auth.uid(), v_day, p_ratio)
  on conflict (user_id, day) do update
    set ratio = greatest(fallen_god_scores.ratio, excluded.ratio),
        updated_at = now();

  return json_build_object('ok', true, 'error', '');
end $$;

-- Today's table. Pass p_day to look at an earlier one.
create or replace function public.fallen_god_board(
  p_limit int default 30, p_day date default null)
returns json language sql stable security definer set search_path = public as $$
  select coalesce(json_agg(json_build_object(
      'id', t.user_id, 'name', p.display_name, 'ratio', t.ratio)
    order by t.ratio desc), '[]'::json)
  from (
    select f.* from fallen_god_scores f
    join profiles pr on pr.id = f.user_id
    where f.day = coalesce(p_day, (now() at time zone 'utc')::date)
      and f.ratio > 0
      and not pr.flagged
    order by f.ratio desc
    limit least(greatest(coalesce(p_limit, 30), 1), 100)
  ) t
  join profiles p on p.id = t.user_id
$$;

-- Yesterday's placing, which is what the rank reward is paid on.
create or replace function public.fallen_god_my_rank(p_day date default null)
returns int language sql stable security definer set search_path = public as $$
  select coalesce((
    select count(*) + 1 from fallen_god_scores f
    join profiles pr on pr.id = f.user_id
    where f.day = coalesce(p_day, (now() at time zone 'utc')::date)
      and not pr.flagged
      and f.ratio > (select ratio from fallen_god_scores
                     where user_id = auth.uid()
                       and day = coalesce(p_day, (now() at time zone 'utc')::date))
  ), 0)
$$;

-- ---------------------------------------------------------
-- ACCESS
-- ---------------------------------------------------------
grant select on public.dungeon_scores, public.fallen_god_scores to authenticated;

revoke all on function public.submit_dungeon_floor(text, int) from public, anon;
revoke all on function public.dungeon_board(text, int) from public, anon;
revoke all on function public.submit_fallen_god(numeric) from public, anon;
revoke all on function public.fallen_god_board(int, date) from public, anon;
revoke all on function public.fallen_god_my_rank(date) from public, anon;
revoke all on function public.max_dungeon_floor() from public, anon;
revoke all on function public.max_god_ratio() from public, anon;

grant execute on function public.submit_dungeon_floor(text, int) to authenticated;
grant execute on function public.dungeon_board(text, int) to authenticated;
grant execute on function public.submit_fallen_god(numeric) to authenticated;
grant execute on function public.fallen_god_board(int, date) to authenticated;
grant execute on function public.fallen_god_my_rank(date) to authenticated;
