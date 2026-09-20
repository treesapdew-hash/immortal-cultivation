-- =========================================================
-- Immortal Cultivation: Supabase setup, part 5 — SERVER LOCKS
-- Run after parts 1-4: SQL Editor > New query ("05 - server locks")
-- > paste > Run. Safe to run again.
--
-- Moves decisions from the app to the server:
--   - Sect Shop: the item list, prices and weekly limits live here;
--     the server decides what a purchase gives.
--   - Sect Trial: the server calculates each cleared stage's items.
--   - Chat: at most one message every 3 seconds per player.
-- =========================================================

-- ---------------------------------------------------------
-- SECT SHOP (edit prices/limits here: the game reads them)
-- ---------------------------------------------------------
create table if not exists public.sect_shop_items (
  item_id text primary key,
  amount int not null check (amount > 0),
  cost int not null check (cost > 0),
  weekly_limit int not null check (weekly_limit > 0),
  sort int not null default 0,
  active boolean not null default true
);

insert into public.sect_shop_items (item_id, amount, cost, weekly_limit, sort) values
  ('summon_scroll', 1, 300, 5, 1),
  ('beast_core', 50, 150, 10, 2),
  ('array_flag', 5, 200, 5, 3),
  ('divinity_essence', 20, 250, 5, 4),
  ('select_scroll_purple', 1, 1000, 1, 5),
  ('select_scroll_red', 1, 3500, 1, 6)
on conflict (item_id) do update set
  amount = excluded.amount, cost = excluded.cost,
  weekly_limit = excluded.weekly_limit, sort = excluded.sort;

create table if not exists public.sect_shop_buys (
  user_id uuid not null references public.profiles (id) on delete cascade,
  item_id text not null references public.sect_shop_items (item_id) on delete cascade,
  week date not null,
  bought int not null default 0,
  primary key (user_id, item_id)
);

alter table public.sect_shop_items enable row level security;
alter table public.sect_shop_buys enable row level security;
drop policy if exists "shop items readable" on public.sect_shop_items;
create policy "shop items readable" on public.sect_shop_items for select to authenticated using (true);
drop policy if exists "own purchases readable" on public.sect_shop_buys;
create policy "own purchases readable" on public.sect_shop_buys for select to authenticated
  using (user_id = (select auth.uid()));

-- The shop with this week's purchase counts
create or replace function public.sect_shop_state()
returns json language sql stable security definer set search_path = public as $$
  select coalesce(json_agg(json_build_object(
      'item_id', i.item_id, 'amount', i.amount, 'cost', i.cost, 'weekly_limit', i.weekly_limit,
      'bought', case when b.week = date_trunc('week', now() at time zone 'utc')::date then b.bought else 0 end)
    order by i.sort), '[]'::json)
  from sect_shop_items i
  left join sect_shop_buys b on b.item_id = i.item_id and b.user_id = auth.uid()
  where i.active
$$;

-- Buy: checks the limit and balance, returns exactly what to give
create or replace function public.buy_sect_item(p_item text)
returns json language plpgsql security definer set search_path = public as $$
declare
  it sect_shop_items%rowtype;
  v_week date := date_trunc('week', now() at time zone 'utc')::date;
  v_bought int;
  v_balance bigint;
begin
  select * into it from sect_shop_items where item_id = p_item and active;
  if not found then raise exception 'That item isn''t sold here'; end if;
  select balance into v_balance from sect_members where user_id = auth.uid() for update;
  if v_balance is null then raise exception 'You are not in a sect'; end if;
  select case when week = v_week then bought else 0 end into v_bought
    from sect_shop_buys where user_id = auth.uid() and item_id = p_item for update;
  v_bought := coalesce(v_bought, 0);
  if v_bought >= it.weekly_limit then raise exception 'Weekly limit reached'; end if;
  if v_balance < it.cost then raise exception 'Not enough Contribution'; end if;
  update sect_members set balance = balance - it.cost where user_id = auth.uid();
  insert into sect_shop_buys (user_id, item_id, week, bought) values (auth.uid(), p_item, v_week, 1)
    on conflict (user_id, item_id) do update set week = v_week, bought = v_bought + 1;
  return json_build_object('item_id', it.item_id, 'amount', it.amount,
    'balance', v_balance - it.cost, 'bought', v_bought + 1);
end $$;

-- The old "spend any amount" shop function is no longer needed
revoke all on function public.spend_contribution(int) from public, anon, authenticated;

-- ---------------------------------------------------------
-- SECT TRIAL: rewards calculated here
-- ---------------------------------------------------------
-- Items for clearing one stage (keep SectTrial.stage_rewards() in sync
-- for the preview text)
create or replace function public.trial_stage_items(p_stage int) returns jsonb
language sql immutable as $$
  select jsonb_strip_nulls(jsonb_build_object(
    'beast_core', 20 + 2 * p_stage,
    'summon_scroll', case when p_stage % 5 = 0 then 1 end,
    'divinity_essence', case when p_stage % 10 = 0 then 10 end))
$$;

create or replace function public.sect_trial_claim()
returns json language plpgsql security definer set search_path = public as $$
declare
  v_sect uuid := my_sect_id();
  t sect_trial%rowtype;
  v_claimed int;
  v_from int;
  v_to int;
  v_contrib bigint := 0;
  v_items jsonb := '{}'::jsonb;
  v_stage_items jsonb;
  k text;
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
    v_stage_items := trial_stage_items(s);
    for k in select jsonb_object_keys(v_stage_items) loop
      v_items := v_items || jsonb_build_object(k,
        coalesce((v_items ->> k)::int, 0) + (v_stage_items ->> k)::int);
    end loop;
  end loop;
  update sect_members set trial_claimed = v_to, balance = balance + v_contrib,
      contribution = contribution + v_contrib
    where user_id = auth.uid();
  return json_build_object('from', v_from, 'to', v_to, 'contribution', v_contrib, 'items', v_items);
end $$;

-- ---------------------------------------------------------
-- CHAT: one message every 3 seconds per player
-- ---------------------------------------------------------
create index if not exists sect_messages_user_idx on public.sect_messages (user_id, created_at desc);

create or replace function public.send_sect_message(p_body text)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_sect uuid := my_sect_id();
  v_name text;
  v_body text := btrim(p_body);
  v_last timestamptz;
begin
  if v_sect is null then raise exception 'You are not in a sect'; end if;
  if char_length(v_body) < 1 or char_length(v_body) > 200 then raise exception 'Messages need 1 to 200 characters'; end if;
  select max(created_at) into v_last from sect_messages where user_id = auth.uid();
  if v_last is not null and v_last > now() - interval '3 seconds' then
    raise exception 'Slow down a little';
  end if;
  select display_name into v_name from profiles where id = auth.uid();
  insert into sect_messages (sect_id, user_id, name, body)
    values (v_sect, auth.uid(), coalesce(v_name, 'Cultivator'), v_body);
end $$;

-- ---------------------------------------------------------
-- ACCESS
-- ---------------------------------------------------------
grant select on public.sect_shop_items, public.sect_shop_buys to authenticated;

revoke all on function public.sect_shop_state() from public, anon;
revoke all on function public.buy_sect_item(text) from public, anon;
revoke all on function public.trial_stage_items(int) from public, anon;
revoke all on function public.sect_trial_claim() from public, anon;
revoke all on function public.send_sect_message(text) from public, anon;

grant execute on function public.sect_shop_state() to authenticated;
grant execute on function public.buy_sect_item(text) to authenticated;
grant execute on function public.trial_stage_items(int) to authenticated;
grant execute on function public.sect_trial_claim() to authenticated;
grant execute on function public.send_sect_message(text) to authenticated;
