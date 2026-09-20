-- =========================================================
-- Immortal Cultivation: Supabase setup, part 4 — SECT TRIAL
-- Run after parts 1-3: SQL Editor > New query ("04 - sect trial")
-- > paste > Run. Safe to run again.
--
-- An endless ladder of guardians. Each stage has a shared HP pool
-- (in "Might"); members attack 3 times a day, and when the pool
-- is empty the sect advances. Each cleared stage gives every
-- member a claimable reward. Damage is ranked weekly.
-- Days and weeks reset at 00:00 UTC (weeks on Monday).
-- =========================================================

create table if not exists public.sect_trial (
  sect_id uuid primary key references public.sects (id) on delete cascade,
  stage int not null default 1,
  hp_left bigint not null,
  hp_max bigint not null,
  updated_at timestamptz not null default now()
);

create table if not exists public.sect_trial_damage (
  sect_id uuid not null references public.sects (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  week date not null,
  might bigint not null default 0,
  attacks_today int not null default 0,
  last_day date,
  primary key (sect_id, user_id)
);

-- -1 = not set yet (set to the current stage on first look, so
-- new members don't collect stages cleared before they joined)
alter table public.sect_members add column if not exists trial_claimed int not null default -1;

alter table public.sect_trial enable row level security;
alter table public.sect_trial_damage enable row level security;

drop policy if exists "trial readable" on public.sect_trial;
create policy "trial readable" on public.sect_trial for select to authenticated using (true);

drop policy if exists "trial damage readable by members" on public.sect_trial_damage;
create policy "trial damage readable by members" on public.sect_trial_damage for select to authenticated
  using (sect_id = public.my_sect_id());

-- ---------------------------------------------------------
-- TUNING (keep in sync with sect_trial.gd)
-- ---------------------------------------------------------
-- Shared HP of a stage: 300 x 1.15^(stage - 1)
create or replace function public.trial_hp(p_stage int) returns bigint
language sql immutable as $$ select round(300 * power(1.15, p_stage - 1))::bigint $$;

-- Most Might one attack can add (the game sends it; this caps cheats)
create or replace function public.trial_might_cap() returns int
language sql immutable as $$ select 60 $$;

-- The sect's trial row (created at stage 1 if missing)
create or replace function public.trial_row(p_sect uuid) returns public.sect_trial
language plpgsql security definer set search_path = public as $$
declare
  t sect_trial%rowtype;
begin
  select * into t from sect_trial where sect_id = p_sect for update;
  if not found then
    insert into sect_trial (sect_id, stage, hp_left, hp_max) values (p_sect, 1, trial_hp(1), trial_hp(1))
      returning * into t;
  end if;
  return t;
end $$;

-- ---------------------------------------------------------
-- ACTIONS
-- ---------------------------------------------------------

-- Everything the Trial tab needs, in one call
create or replace function public.sect_trial_state()
returns json language plpgsql security definer set search_path = public as $$
declare
  v_sect uuid := my_sect_id();
  v_today date := (now() at time zone 'utc')::date;
  v_week date := date_trunc('week', now() at time zone 'utc')::date;
  t sect_trial%rowtype;
  d sect_trial_damage%rowtype;
  v_claimed int;
begin
  if v_sect is null then raise exception 'You are not in a sect'; end if;
  t := trial_row(v_sect);
  select trial_claimed into v_claimed from sect_members where user_id = auth.uid();
  if v_claimed < 0 then
    v_claimed := t.stage - 1;
    update sect_members set trial_claimed = v_claimed where user_id = auth.uid();
  end if;
  select * into d from sect_trial_damage where sect_id = v_sect and user_id = auth.uid();
  return json_build_object(
    'stage', t.stage, 'hp_left', t.hp_left, 'hp_max', t.hp_max,
    'attacks_used', case when d.last_day = v_today then d.attacks_today else 0 end,
    'my_might', case when d.week = v_week then d.might else 0 end,
    'claimed', v_claimed, 'cleared', t.stage - 1);
end $$;

-- An attack: p_might is the game's measured score (capped here).
-- Advances the stage when the shared pool empties.
create or replace function public.sect_trial_attack(p_might int)
returns json language plpgsql security definer set search_path = public as $$
declare
  v_sect uuid := my_sect_id();
  v_today date := (now() at time zone 'utc')::date;
  v_week date := date_trunc('week', now() at time zone 'utc')::date;
  v_might int := greatest(0, least(coalesce(p_might, 0), trial_might_cap()));
  t sect_trial%rowtype;
  d sect_trial_damage%rowtype;
  v_used int;
  v_cleared boolean := false;
begin
  if v_sect is null then raise exception 'You are not in a sect'; end if;
  select * into d from sect_trial_damage where sect_id = v_sect and user_id = auth.uid() for update;
  v_used := case when found and d.last_day = v_today then d.attacks_today else 0 end;
  if v_used >= 3 then raise exception 'No attacks left today'; end if;

  insert into sect_trial_damage (sect_id, user_id, week, might, attacks_today, last_day)
    values (v_sect, auth.uid(), v_week, v_might, 1, v_today)
  on conflict (sect_id, user_id) do update set
    might = case when sect_trial_damage.week = v_week then sect_trial_damage.might + v_might else v_might end,
    week = v_week,
    attacks_today = v_used + 1,
    last_day = v_today;

  t := trial_row(v_sect);
  t.hp_left := t.hp_left - v_might;
  if t.hp_left <= 0 then
    t.stage := t.stage + 1;
    t.hp_max := trial_hp(t.stage);
    t.hp_left := t.hp_max;
    v_cleared := true;
  end if;
  update sect_trial set stage = t.stage, hp_left = t.hp_left, hp_max = t.hp_max, updated_at = now()
    where sect_id = v_sect;
  return json_build_object('might', v_might, 'stage', t.stage, 'hp_left', t.hp_left,
    'hp_max', t.hp_max, 'cleared', v_cleared);
end $$;

-- Claim the rewards of every stage cleared since the last claim.
-- Gives Contribution (30 + 5 x stage per stage) and returns the
-- range so the game can hand out the items.
create or replace function public.sect_trial_claim()
returns json language plpgsql security definer set search_path = public as $$
declare
  v_sect uuid := my_sect_id();
  t sect_trial%rowtype;
  v_claimed int;
  v_from int;
  v_to int;
  v_contrib bigint := 0;
begin
  if v_sect is null then raise exception 'You are not in a sect'; end if;
  t := trial_row(v_sect);
  select trial_claimed into v_claimed from sect_members where user_id = auth.uid() for update;
  if v_claimed < 0 then v_claimed := t.stage - 1; end if;
  v_from := v_claimed + 1;
  v_to := t.stage - 1;
  if v_to < v_from then raise exception 'Nothing to claim yet'; end if;
  for s in v_from .. v_to loop
    v_contrib := v_contrib + 30 + 5 * s;
  end loop;
  update sect_members set trial_claimed = v_to, balance = balance + v_contrib,
      contribution = contribution + v_contrib
    where user_id = auth.uid();
  return json_build_object('from', v_from, 'to', v_to, 'contribution', v_contrib);
end $$;

-- ---------------------------------------------------------
-- ACCESS
-- ---------------------------------------------------------
grant select on public.sect_trial, public.sect_trial_damage to authenticated;

revoke all on function public.trial_hp(int) from public, anon;
revoke all on function public.trial_might_cap() from public, anon;
revoke all on function public.trial_row(uuid) from public, anon, authenticated;
revoke all on function public.sect_trial_state() from public, anon;
revoke all on function public.sect_trial_attack(int) from public, anon;
revoke all on function public.sect_trial_claim() from public, anon;

grant execute on function public.trial_hp(int) to authenticated;
grant execute on function public.trial_might_cap() to authenticated;
grant execute on function public.sect_trial_state() to authenticated;
grant execute on function public.sect_trial_attack(int) to authenticated;
grant execute on function public.sect_trial_claim() to authenticated;
