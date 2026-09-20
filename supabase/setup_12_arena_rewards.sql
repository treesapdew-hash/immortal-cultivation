-- =========================================================
-- Immortal Cultivation: Supabase setup, part 12 — ARENA REWARDS
-- Run after part 11: SQL Editor > New query ("12 - arena rewards")
-- > paste > Run. Safe to run again.
--
-- Replaces the claim buttons from part 10. Standing rewards are now
-- settled by the server at the end of each period and posted to the
-- player's mailbox, rather than claimed on demand.
--
-- Part 10 paid out on the rank you held AT THE MOMENT YOU PRESSED
-- CLAIM, to anyone holding an arena profile — which you get merely
-- by opening the Arena. So a brand-new cultivator could collect
-- both a daily and a weekly reward instantly, having never fought,
-- and a patient one could sit on the button until their rank peaked.
--
-- Here the standing is frozen when the period ends, only cultivators
-- who actually duelled that period are paid, and each reward can be
-- collected exactly once.
-- =========================================================

-- ---------------------------------------------------------
-- FROZEN STANDINGS
-- ---------------------------------------------------------
-- What each bracket looked like when a period closed. Written once
-- and never revised, so a rank cannot drift after the fact.
create table if not exists public.arena_standings (
  kind text not null check (kind in ('daily', 'weekly')),
  period date not null,
  bracket int not null,
  user_id uuid not null references public.profiles (id) on delete cascade,
  rank int not null,
  points int not null,
  duels int not null,
  primary key (kind, period, user_id)
);
create index if not exists arena_standings_period_idx
  on public.arena_standings (kind, period, bracket);

-- One row per cultivator per period. `delivered` is the ledger: the
-- mailbox lives in the player's save, so this is what stops a reward
-- being posted twice.
create table if not exists public.arena_rewards (
  user_id uuid not null references public.profiles (id) on delete cascade,
  kind text not null check (kind in ('daily', 'weekly')),
  period date not null,
  rank_at int not null,
  bracket_size int not null,
  tokens int not null,
  jade int not null,
  delivered boolean not null default false,
  created_at timestamptz not null default now(),
  primary key (user_id, kind, period)
);

alter table public.arena_standings enable row level security;
alter table public.arena_rewards enable row level security;

drop policy if exists "own standings readable" on public.arena_standings;
create policy "own standings readable" on public.arena_standings
  for select to authenticated using (true);

drop policy if exists "own arena rewards readable" on public.arena_rewards;
create policy "own arena rewards readable" on public.arena_rewards
  for select to authenticated using (user_id = (select auth.uid()));

-- ---------------------------------------------------------
-- WHAT A STANDING IS WORTH
-- ---------------------------------------------------------
-- A bracket needs this many cultivators who actually fought before
-- the top places pay more than the floor. Without it, the first
-- player into an empty realm bracket is rank 1 every single day:
-- 600 tokens daily plus 3000 weekly, against a 9000-token Premium
-- Scroll. That is a free Premium Red in under three weeks for
-- turning the game on.
create or replace function public.arena_min_bracket() returns int
language sql immutable as $$ select 5 $$;

create or replace function public.arena_reward_for(p_rank int, p_weekly boolean)
returns json language sql immutable as $$
  select case
    when p_rank <= 1   then json_build_object('tokens', 600, 'jade', 300)
    when p_rank <= 3   then json_build_object('tokens', 450, 'jade', 200)
    when p_rank <= 10  then json_build_object('tokens', 320, 'jade', 140)
    when p_rank <= 30  then json_build_object('tokens', 220, 'jade', 90)
    when p_rank <= 100 then json_build_object('tokens', 140, 'jade', 50)
    else                    json_build_object('tokens', 80, 'jade', 25)
  end
$$;

-- ---------------------------------------------------------
-- SETTLEMENT
-- ---------------------------------------------------------
-- Freezes one period and writes the rewards for it. Idempotent: the
-- advisory lock plus the standings check mean that if fifty players
-- open the Arena at once the morning after, exactly one settles it.
create or replace function public.arena_settle(p_kind text, p_period date)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_from timestamptz := p_period::timestamptz;
  v_to timestamptz := case when p_kind = 'weekly'
    then (p_period + 7)::timestamptz else (p_period + 1)::timestamptz end;
  v_mult int := case when p_kind = 'weekly' then 5 else 1 end;
begin
  perform pg_advisory_xact_lock(hashtext('arena_settle:' || p_kind || ':' || p_period::text));
  if exists (select 1 from arena_standings where kind = p_kind and period = p_period) then
    return;
  end if;

  -- Rank everyone in their bracket, and count the duels they fought
  -- inside the window. Ties break on the older account, so a rank is
  -- always a single cultivator.
  insert into arena_standings (kind, period, bracket, user_id, rank, points, duels)
  select p_kind, p_period, a.bracket, a.user_id,
         rank() over (partition by a.bracket order by a.points desc, a.updated_at asc),
         a.points,
         coalesce((select count(*) from arena_matches m
                   where m.attacker = a.user_id
                     and m.fought_at >= v_from and m.fought_at < v_to), 0)
  from arena_profiles a
  on conflict do nothing;

  -- Only those who fought are paid, and the top places only pay out
  -- once a bracket has real competition in it.
  insert into arena_rewards (user_id, kind, period, rank_at, bracket_size, tokens, jade)
  select s.user_id, p_kind, p_period, s.rank, b.n,
         ((r.v ->> 'tokens')::int) * v_mult,
         ((r.v ->> 'jade')::int) * v_mult
  from arena_standings s
  join (
    select bracket, count(*) filter (where duels > 0) as n
    from arena_standings where kind = p_kind and period = p_period
    group by bracket
  ) b on b.bracket = s.bracket
  cross join lateral (
    select arena_reward_for(
      case when b.n >= arena_min_bracket() then s.rank else 999999 end,
      p_kind = 'weekly') as v
  ) r
  where s.kind = p_kind and s.period = p_period and s.duels > 0
  on conflict do nothing;
end $$;

-- Settles whatever has closed but not yet been dealt with: yesterday,
-- and the week that just ended.
--
-- This runs on demand rather than on a schedule. pg_cron would be the
-- tidier answer, but a Supabase free project pauses after about a
-- week idle and a paused project runs no cron — rewards would vanish
-- silently on exactly the quiet weeks nobody would notice. Settling
-- when someone shows up cannot miss, and since points only move by
-- duelling, the frozen standing is the same either way.
create or replace function public.arena_settle_due()
returns void language plpgsql security definer set search_path = public as $$
declare
  v_today date := (now() at time zone 'utc')::date;
  v_week date := date_trunc('week', now() at time zone 'utc')::date;
begin
  perform arena_settle('daily', v_today - 1);
  perform arena_settle('weekly', v_week - 7);
end $$;

-- ---------------------------------------------------------
-- COLLECTION
-- ---------------------------------------------------------
-- Hands over everything owed and marks it delivered in one statement,
-- so a dropped connection cannot pay twice. The client turns each row
-- into a letter in the mailbox.
create or replace function public.arena_collect_rewards()
returns json language plpgsql security definer set search_path = public as $$
declare v json;
begin
  if auth.uid() is null then
    return '[]'::json;
  end if;
  perform arena_settle_due();
  with taken as (
    update arena_rewards set delivered = true
    where user_id = auth.uid() and not delivered
    returning kind, period, rank_at, bracket_size, tokens, jade
  )
  select coalesce(json_agg(json_build_object(
    'kind', kind, 'period', period, 'rank', rank_at,
    'bracket_size', bracket_size, 'tokens', tokens, 'jade', jade)
    order by period), '[]'::json)
  into v from taken;
  return v;
end $$;

-- ---------------------------------------------------------
-- RETIRING THE OLD CLAIM PATH
-- ---------------------------------------------------------
-- Dropped rather than left in place: while these exist, a modified
-- client can still call them and pay itself.
drop function if exists public.arena_claim_reward(boolean);
drop function if exists public.arena_rewards_pending();

-- ---------------------------------------------------------
-- ACCESS
-- ---------------------------------------------------------
grant select on public.arena_standings, public.arena_rewards to authenticated;

-- Settlement is internal: players reach it only through collection,
-- so nobody can force a period to close early.
revoke all on function public.arena_settle(text, date) from public, anon, authenticated;
revoke all on function public.arena_settle_due() from public, anon, authenticated;
revoke all on function public.arena_min_bracket() from public, anon;
revoke all on function public.arena_reward_for(int, boolean) from public, anon;
revoke all on function public.arena_collect_rewards() from public, anon;

grant execute on function public.arena_collect_rewards() to authenticated;
