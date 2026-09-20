-- =========================================================
-- Immortal Cultivation: Supabase setup, part 10 — ARENA SHOP
-- Run after part 9: SQL Editor > New query ("10 - arena shop")
-- > paste > Run. Safe to run again.
--
-- The Arena Exchange and the daily/weekly standing rewards.
--
-- Prices and limits live here, not in the client, and the server
-- decides what a purchase gives — the same shape as the Sect Shop
-- in part 5. Rank rewards are paid from the standing the server
-- already holds, so a client cannot claim a rank it never had.
-- =========================================================

-- ---------------------------------------------------------
-- THE EXCHANGE
-- ---------------------------------------------------------
create table if not exists public.arena_shop_items (
  item_id text primary key,
  amount int not null check (amount > 0),
  cost int not null check (cost > 0),
  weekly_limit int not null check (weekly_limit > 0),
  sort int not null default 0,
  active boolean not null default true
);

-- Premium Selection Scrolls are the headline: the Arena becomes a
-- second route to a Premium Red for players who never summon one.
insert into public.arena_shop_items (item_id, amount, cost, weekly_limit, sort) values
  ('premium_scroll', 1, 9000, 1, 1),
  ('premium_essence', 25, 1200, 5, 2),
  ('select_scroll_purple', 1, 2500, 2, 3),
  ('summon_scroll', 1, 600, 10, 4),
  ('starup_pill', 200, 400, 10, 5),
  ('beast_core', 60, 300, 10, 6)
on conflict (item_id) do update set
  amount = excluded.amount, cost = excluded.cost,
  weekly_limit = excluded.weekly_limit, sort = excluded.sort;

create table if not exists public.arena_shop_buys (
  user_id uuid not null references public.profiles (id) on delete cascade,
  item_id text not null references public.arena_shop_items (item_id) on delete cascade,
  week date not null,
  bought int not null default 0,
  primary key (user_id, item_id)
);

alter table public.arena_shop_items enable row level security;
alter table public.arena_shop_buys enable row level security;
drop policy if exists "arena shop readable" on public.arena_shop_items;
create policy "arena shop readable" on public.arena_shop_items for select to authenticated
  using (true);
drop policy if exists "own arena buys readable" on public.arena_shop_buys;
create policy "own arena buys readable" on public.arena_shop_buys for select to authenticated
  using (user_id = (select auth.uid()));

-- The stock, with this week's purchase counts.
create or replace function public.arena_shop_state()
returns json language sql stable security definer set search_path = public as $$
  select coalesce(json_agg(json_build_object(
      'item_id', i.item_id, 'amount', i.amount, 'cost', i.cost,
      'weekly_limit', i.weekly_limit,
      'bought', case when b.week = date_trunc('week', now() at time zone 'utc')::date
                     then b.bought else 0 end)
    order by i.sort), '[]'::json)
  from arena_shop_items i
  left join arena_shop_buys b on b.item_id = i.item_id and b.user_id = auth.uid()
  where i.active
$$;

-- Buys one. The client spends the Tokens first and refunds them if
-- this refuses, the same dance the Sect Shop uses.
create or replace function public.buy_arena_item(p_item text)
returns json language plpgsql security definer set search_path = public as $$
declare
  it arena_shop_items%rowtype;
  v_week date := date_trunc('week', now() at time zone 'utc')::date;
  v_bought int;
begin
  if auth.uid() is null then
    return json_build_object('ok', false, 'error', 'Not signed in');
  end if;
  select * into it from arena_shop_items where item_id = p_item and active;
  if not found then
    return json_build_object('ok', false, 'error', 'That is not sold here.');
  end if;

  select case when week = v_week then bought else 0 end into v_bought
    from arena_shop_buys where user_id = auth.uid() and item_id = p_item for update;
  v_bought := coalesce(v_bought, 0);
  if v_bought >= it.weekly_limit then
    return json_build_object('ok', false, 'error', 'Weekly limit reached.');
  end if;

  insert into arena_shop_buys (user_id, item_id, week, bought)
    values (auth.uid(), p_item, v_week, 1)
  on conflict (user_id, item_id) do update set week = v_week, bought = v_bought + 1;

  return json_build_object('ok', true, 'error', '',
    'item_id', it.item_id, 'amount', it.amount, 'cost', it.cost,
    'bought', v_bought + 1);
end $$;

-- ---------------------------------------------------------
-- STANDING REWARDS
-- ---------------------------------------------------------
create table if not exists public.arena_reward_claims (
  user_id uuid not null references public.profiles (id) on delete cascade,
  kind text not null check (kind in ('daily', 'weekly')),
  period date not null,
  rank_at int not null,
  tokens int not null,
  jade int not null,
  claimed_at timestamptz not null default now(),
  primary key (user_id, kind, period)
);

alter table public.arena_reward_claims enable row level security;
drop policy if exists "own arena claims readable" on public.arena_reward_claims;
create policy "own arena claims readable" on public.arena_reward_claims
  for select to authenticated using (user_id = (select auth.uid()));

-- Tokens and Jade for a standing. Daily pays every day; weekly is
-- the same shape, several times larger.
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

-- Claims yesterday's standing, or last week's. Rank comes from the
-- server's own table, so it cannot be inflated by the client.
-- Returns {ok, error, kind, rank, tokens, jade}.
create or replace function public.arena_claim_reward(p_weekly boolean default false)
returns json language plpgsql security definer set search_path = public as $$
declare
  me arena_profiles%rowtype;
  v_today date := (now() at time zone 'utc')::date;
  v_period date;
  v_kind text := case when p_weekly then 'weekly' else 'daily' end;
  v_rank int;
  v_reward json;
  v_mult int := case when p_weekly then 5 else 1 end;
begin
  select * into me from arena_profiles where user_id = auth.uid();
  if not found then
    return json_build_object('ok', false, 'error', 'Enter the Arena first.');
  end if;

  -- Yesterday, or the week that just ended.
  v_period := case when p_weekly
    then (date_trunc('week', now() at time zone 'utc') - interval '7 days')::date
    else v_today - 1 end;

  if exists (select 1 from arena_reward_claims
             where user_id = auth.uid() and kind = v_kind and period = v_period) then
    return json_build_object('ok', false, 'error', 'Already claimed.');
  end if;

  select count(*) + 1 into v_rank from arena_profiles a
    where a.bracket = me.bracket and a.points > me.points;

  v_reward := arena_reward_for(v_rank, p_weekly);

  insert into arena_reward_claims (user_id, kind, period, rank_at, tokens, jade)
    values (auth.uid(), v_kind, v_period, v_rank,
            (v_reward ->> 'tokens')::int * v_mult,
            (v_reward ->> 'jade')::int * v_mult);

  return json_build_object('ok', true, 'error', '', 'kind', v_kind, 'rank', v_rank,
    'tokens', (v_reward ->> 'tokens')::int * v_mult,
    'jade', (v_reward ->> 'jade')::int * v_mult);
end $$;

-- What is waiting to be claimed.
create or replace function public.arena_rewards_pending()
returns json language sql stable security definer set search_path = public as $$
  select json_build_object(
    'daily', not exists (
      select 1 from arena_reward_claims
      where user_id = auth.uid() and kind = 'daily'
        and period = (now() at time zone 'utc')::date - 1),
    'weekly', not exists (
      select 1 from arena_reward_claims
      where user_id = auth.uid() and kind = 'weekly'
        and period = (date_trunc('week', now() at time zone 'utc')
                      - interval '7 days')::date))
$$;

-- ---------------------------------------------------------
-- ACCESS
-- ---------------------------------------------------------
grant select on public.arena_shop_items, public.arena_shop_buys,
                public.arena_reward_claims to authenticated;

revoke all on function public.arena_shop_state() from public, anon;
revoke all on function public.buy_arena_item(text) from public, anon;
revoke all on function public.arena_reward_for(int, boolean) from public, anon;
revoke all on function public.arena_claim_reward(boolean) from public, anon;
revoke all on function public.arena_rewards_pending() from public, anon;

grant execute on function public.arena_shop_state() to authenticated;
grant execute on function public.buy_arena_item(text) to authenticated;
grant execute on function public.arena_reward_for(int, boolean) to authenticated;
grant execute on function public.arena_claim_reward(boolean) to authenticated;
grant execute on function public.arena_rewards_pending() to authenticated;
