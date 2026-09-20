-- =========================================================
-- Immortal Cultivation: Supabase setup, part 9 — ARENA
-- Run after parts 1-8: SQL Editor > New query ("09 - arena")
-- > paste > Run. Safe to run again.
--
-- Asynchronous PvP. You fight a stored snapshot of another
-- cultivator's team, so nobody has to be online.
--
-- Brackets are the four major realms: you only ever meet people
-- in your own. Empty brackets are filled by the client with
-- generated cultivators (see arena.gd); those never reach this
-- table, so they cannot take or give points.
--
-- The server owns points, attempts and rewards. arena_report()
-- also refuses results a real battle could not produce, which is
-- the cheapest useful guard short of simulating fights here.
-- =========================================================

-- ---------------------------------------------------------
-- PROFILES
-- ---------------------------------------------------------
create table if not exists public.arena_profiles (
  user_id uuid primary key references public.profiles (id) on delete cascade,
  -- 0 Mortal, 1 Spirit, 2 Sovereign, 3 Immortal (Realms.Major)
  bracket int not null default 0,
  points int not null default 1000,
  wins int not null default 0,
  losses int not null default 0,
  power bigint not null default 0,
  -- The team you defend with: [{partner_id, stars, level, power}, ...]
  team jsonb not null default '[]'::jsonb,
  attacks_today int not null default 0,
  extra_attacks int not null default 0,
  last_day date,
  updated_at timestamptz not null default now()
);
create index if not exists arena_bracket_idx
  on public.arena_profiles (bracket, points desc);

-- Every fight, so a cheated run can be traced and rolled back.
create table if not exists public.arena_matches (
  id bigint generated always as identity primary key,
  attacker uuid references public.profiles (id) on delete set null,
  defender uuid references public.profiles (id) on delete set null,
  attacker_power bigint not null default 0,
  defender_power bigint not null default 0,
  attacker_won boolean not null,
  points_delta int not null default 0,
  fought_at timestamptz not null default now()
);
create index if not exists arena_matches_attacker_idx
  on public.arena_matches (attacker, fought_at desc);

alter table public.arena_profiles enable row level security;
alter table public.arena_matches enable row level security;

drop policy if exists "arena profiles readable" on public.arena_profiles;
create policy "arena profiles readable" on public.arena_profiles
  for select to authenticated using (true);

-- No select policy on arena_matches: it is an audit log for you.

-- ---------------------------------------------------------
-- TUNING (keep in sync with arena.gd)
-- ---------------------------------------------------------
create or replace function public.arena_free_attacks() returns int
language sql immutable as $$ select 10 $$;

-- Most extra attacks buyable per day, on top of the free ones.
create or replace function public.arena_max_extra() returns int
language sql immutable as $$ select 10 $$;

-- Elo K-factor. 32 moves a rank meaningfully without wild swings.
create or replace function public.arena_k() returns int
language sql immutable as $$ select 32 $$;

-- A win by someone this much weaker than the defender is refused.
-- Battles are not simulated here, so this is the plausibility
-- guard: 0.25 means the winner must have at least a quarter of the
-- loser's power. Upsets stay possible, absurdities do not.
create or replace function public.arena_min_power_ratio() returns numeric
language sql immutable as $$ select 0.25 $$;


-- Attacks left today, resetting at 00:00 UTC.
create or replace function public.arena_attacks_left(p_user uuid) returns int
language sql stable security definer set search_path = public as $$
  select greatest(0, arena_free_attacks() + coalesce(a.extra_attacks, 0)
      - case when a.last_day = (now() at time zone 'utc')::date
             then a.attacks_today else 0 end)
  from arena_profiles a where a.user_id = p_user
$$;

-- ---------------------------------------------------------
-- JOINING AND SYNCING
-- ---------------------------------------------------------
-- Called when the Arena opens: records your bracket, power and the
-- team you defend with. Creates the profile on first visit.
create or replace function public.arena_sync(p_bracket int, p_power bigint, p_team jsonb)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_today date := (now() at time zone 'utc')::date;
begin
  if auth.uid() is null then raise exception 'Not signed in'; end if;

  insert into arena_profiles (user_id, bracket, power, team, last_day)
    values (auth.uid(), greatest(0, least(3, coalesce(p_bracket, 0))),
            greatest(0, coalesce(p_power, 0)), coalesce(p_team, '[]'::jsonb), v_today)
  on conflict (user_id) do update set
    bracket = greatest(0, least(3, coalesce(p_bracket, 0))),
    power = greatest(0, coalesce(p_power, 0)),
    team = coalesce(p_team, '[]'::jsonb),
    -- A new day clears the counters
    attacks_today = case when arena_profiles.last_day = v_today
                         then arena_profiles.attacks_today else 0 end,
    extra_attacks = case when arena_profiles.last_day = v_today
                         then arena_profiles.extra_attacks else 0 end,
    last_day = v_today,
    updated_at = now();
end $$;

-- ---------------------------------------------------------
-- OPPONENTS
-- ---------------------------------------------------------
-- Real cultivators in your bracket, nearest in points first. The
-- client tops the list up with generated opponents when this
-- returns fewer than it wants.
create or replace function public.arena_opponents(p_limit int default 5)
returns json language sql stable security definer set search_path = public as $$
  select coalesce(json_agg(json_build_object(
      'id', o.user_id, 'name', p.display_name, 'points', o.points,
      'power', o.power, 'wins', o.wins, 'losses', o.losses,
      'realm', p.realm, 'team', o.team)
    order by o.gap), '[]'::json)
  from (
    select a.*, abs(a.points - me.points) as gap
    from arena_profiles a
    cross join (select bracket, points from arena_profiles where user_id = auth.uid()) me
    where a.user_id <> auth.uid()
      and a.bracket = me.bracket
      and not exists (
        select 1 from player_blocks b
        where (b.user_id = auth.uid() and b.blocked_id = a.user_id)
           or (b.user_id = a.user_id and b.blocked_id = auth.uid()))
    order by abs(a.points - me.points)
    limit least(greatest(coalesce(p_limit, 5), 1), 20)
  ) o
  join profiles p on p.id = o.user_id
$$;

-- ---------------------------------------------------------
-- FIGHTING
-- ---------------------------------------------------------
-- Reports a fight against a REAL opponent. Generated opponents are
-- resolved on the client and never come here, so they cannot move
-- anyone's rank.
--
-- Returns {ok, error, points, delta, attacks_left}.
create or replace function public.arena_report(p_defender uuid, p_won boolean)
returns json language plpgsql security definer set search_path = public as $$
declare
  me arena_profiles%rowtype;
  foe arena_profiles%rowtype;
  v_today date := (now() at time zone 'utc')::date;
  v_used int;
  v_left int;
  v_expected numeric;
  v_delta int;
begin
  if auth.uid() is null then
    return json_build_object('ok', false, 'error', 'Not signed in');
  end if;

  select * into me from arena_profiles where user_id = auth.uid() for update;
  if not found then
    return json_build_object('ok', false, 'error', 'Enter the Arena first.');
  end if;
  select * into foe from arena_profiles where user_id = p_defender for update;
  if not found then
    return json_build_object('ok', false, 'error', 'That cultivator has left the Arena.');
  end if;
  if p_defender = auth.uid() then
    return json_build_object('ok', false, 'error', 'You cannot fight yourself.');
  end if;
  if foe.bracket <> me.bracket then
    return json_build_object('ok', false, 'error', 'They are not in your realm bracket.');
  end if;

  v_used := case when me.last_day = v_today then me.attacks_today else 0 end;
  v_left := arena_free_attacks() + me.extra_attacks - v_used;
  if v_left <= 0 then
    return json_build_object('ok', false, 'error', 'No Arena attempts left today.');
  end if;

  -- Plausibility guard. Not a simulation, but it refuses the
  -- results a tampered client would report.
  if p_won and foe.power > 0
     and me.power < (foe.power::numeric * arena_min_power_ratio()) then
    insert into arena_matches (attacker, defender, attacker_power, defender_power,
                               attacker_won, points_delta)
      values (auth.uid(), p_defender, me.power, foe.power, false, 0);
    return json_build_object('ok', false, 'error', 'That result could not be verified.');
  end if;

  -- Elo. A win over someone stronger is worth more.
  v_expected := 1.0 / (1.0 + power(10.0, (foe.points - me.points)::numeric / 400.0));
  v_delta := round(arena_k() * ((case when p_won then 1 else 0 end) - v_expected));
  if p_won and v_delta < 1 then v_delta := 1; end if;
  if not p_won and v_delta > -1 then v_delta := -1; end if;

  update arena_profiles set
    points = greatest(0, points + v_delta),
    wins = wins + (case when p_won then 1 else 0 end),
    losses = losses + (case when p_won then 0 else 1 end),
    attacks_today = v_used + 1,
    last_day = v_today,
    updated_at = now()
  where user_id = auth.uid();

  -- The defender moves the opposite way, but never loses a life:
  -- being attacked while offline should not cost attempts.
  update arena_profiles set
    points = greatest(0, points - v_delta),
    wins = wins + (case when p_won then 0 else 1 end),
    losses = losses + (case when p_won then 1 else 0 end),
    updated_at = now()
  where user_id = p_defender;

  insert into arena_matches (attacker, defender, attacker_power, defender_power,
                             attacker_won, points_delta)
    values (auth.uid(), p_defender, me.power, foe.power, p_won, v_delta);

  return json_build_object('ok', true, 'error', '',
    'points', greatest(0, me.points + v_delta),
    'delta', v_delta,
    'attacks_left', arena_free_attacks() + me.extra_attacks - v_used - 1);
end $$;

-- Buys one more attempt. The client takes the Jade first and
-- refunds it if this refuses.
create or replace function public.arena_buy_attack()
returns json language plpgsql security definer set search_path = public as $$
declare
  me arena_profiles%rowtype;
  v_today date := (now() at time zone 'utc')::date;
begin
  select * into me from arena_profiles where user_id = auth.uid() for update;
  if not found then
    return json_build_object('ok', false, 'error', 'Enter the Arena first.');
  end if;
  if me.last_day <> v_today then
    update arena_profiles set attacks_today = 0, extra_attacks = 0, last_day = v_today
      where user_id = auth.uid();
    me.extra_attacks := 0;
  end if;
  if me.extra_attacks >= arena_max_extra() then
    return json_build_object('ok', false, 'error', 'No more attempts can be bought today.');
  end if;
  update arena_profiles set extra_attacks = extra_attacks + 1, updated_at = now()
    where user_id = auth.uid();
  return json_build_object('ok', true, 'error', '',
    'attacks_left', arena_attacks_left(auth.uid()));
end $$;

-- ---------------------------------------------------------
-- STANDING
-- ---------------------------------------------------------
-- Everything the Arena tab needs, in one call.
create or replace function public.arena_state()
returns json language sql stable security definer set search_path = public as $$
  select json_build_object(
    'joined', (select count(*) from arena_profiles where user_id = auth.uid()) > 0,
    'bracket', coalesce((select bracket from arena_profiles where user_id = auth.uid()), 0),
    'points', coalesce((select points from arena_profiles where user_id = auth.uid()), 0),
    'wins', coalesce((select wins from arena_profiles where user_id = auth.uid()), 0),
    'losses', coalesce((select losses from arena_profiles where user_id = auth.uid()), 0),
    'attacks_left', coalesce(arena_attacks_left(auth.uid()), arena_free_attacks()),
    'extra_bought', coalesce((select extra_attacks from arena_profiles where user_id = auth.uid()), 0),
    'rank', coalesce((
      select count(*) + 1 from arena_profiles a
      where a.bracket = (select bracket from arena_profiles where user_id = auth.uid())
        and a.points > (select points from arena_profiles where user_id = auth.uid())), 1),
    'in_bracket', coalesce((
      select count(*) from arena_profiles a
      where a.bracket = (select bracket from arena_profiles where user_id = auth.uid())), 0))
$$;

-- Top of your bracket, for the board.
create or replace function public.arena_board(p_limit int default 20)
returns json language sql stable security definer set search_path = public as $$
  select coalesce(json_agg(json_build_object(
      'id', t.user_id, 'name', p.display_name, 'points', t.points,
      'wins', t.wins, 'losses', t.losses, 'power', t.power)
    order by t.points desc), '[]'::json)
  from (
    select a.* from arena_profiles a
    where a.bracket = coalesce(
      (select bracket from arena_profiles where user_id = auth.uid()), 0)
    order by a.points desc
    limit least(greatest(coalesce(p_limit, 20), 1), 100)
  ) t
  join profiles p on p.id = t.user_id
$$;

-- ---------------------------------------------------------
-- ACCESS
-- ---------------------------------------------------------
grant select on public.arena_profiles to authenticated;

revoke all on function public.arena_free_attacks() from public, anon;
revoke all on function public.arena_max_extra() from public, anon;
revoke all on function public.arena_k() from public, anon;
revoke all on function public.arena_min_power_ratio() from public, anon;
revoke all on function public.arena_attacks_left(uuid) from public, anon;
revoke all on function public.arena_sync(int, bigint, jsonb) from public, anon;
revoke all on function public.arena_opponents(int) from public, anon;
revoke all on function public.arena_report(uuid, boolean) from public, anon;
revoke all on function public.arena_buy_attack() from public, anon;
revoke all on function public.arena_state() from public, anon;
revoke all on function public.arena_board(int) from public, anon;

grant execute on function public.arena_free_attacks() to authenticated;
grant execute on function public.arena_max_extra() to authenticated;
grant execute on function public.arena_k() to authenticated;
grant execute on function public.arena_min_power_ratio() to authenticated;
grant execute on function public.arena_attacks_left(uuid) to authenticated;
grant execute on function public.arena_sync(int, bigint, jsonb) to authenticated;
grant execute on function public.arena_opponents(int) to authenticated;
grant execute on function public.arena_report(uuid, boolean) to authenticated;
grant execute on function public.arena_buy_attack() to authenticated;
grant execute on function public.arena_state() to authenticated;
grant execute on function public.arena_board(int) to authenticated;
