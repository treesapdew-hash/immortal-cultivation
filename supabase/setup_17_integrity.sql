-- =========================================================
-- Immortal Cultivation: Supabase setup, part 17 — INTEGRITY
-- Run after part 16: SQL Editor > New query ("17 - integrity")
-- > paste > Run. Safe to run again.
--
-- Two things that a server can honestly protect in an idle game.
--
-- WHAT THIS DOES NOT DO. It does not make the economy
-- server-authoritative. Qi, stage clears, drops and offline rewards
-- are all worked out on the device, so a determined cheat can still
-- edit their own save. Making that impossible means simulating the
-- idle loop up here, which is a different game architecture.
--
-- What it does instead:
--   1. Makes a purchase worth real money impossible to replay or to
--      inflate, because the server decides what a SKU grants and a
--      receipt can only ever be claimed once.
--   2. Makes a tampered save visible. Impossible values are refused
--      outright; merely improbable ones are written to an audit
--      table, and an account that keeps tripping it is flagged and
--      drops out of the Arena board.
--
-- A flag is not a ban. It is a list to look at.
-- =========================================================

-- ---------------------------------------------------------
-- WHAT THE STORE SELLS
-- ---------------------------------------------------------
-- Server-owned, like the Sect and Arena shops. The device says which
-- SKU was bought; it never says what that is worth.
create table if not exists public.store_products (
  sku text primary key,
  jade int not null check (jade >= 0),
  bonus_jade int not null default 0,
  active boolean not null default true,
  sort int not null default 0
);

alter table public.store_products enable row level security;
drop policy if exists "store readable" on public.store_products;
create policy "store readable" on public.store_products
  for select to authenticated using (true);

-- ---------------------------------------------------------
-- PURCHASES
-- ---------------------------------------------------------
-- purchase_token is unique across the whole table, not per player:
-- that is what stops one receipt being passed around and claimed by
-- several accounts.
create table if not exists public.purchases (
  id bigint generated always as identity primary key,
  user_id uuid not null references public.profiles (id) on delete cascade,
  sku text not null,
  purchase_token text not null unique,
  platform text not null default 'android',
  -- Set by the receipt check once Play Billing is live. Until then a
  -- purchase is recorded and granted but stays unverified, so there
  -- is a list to reconcile against the store's own reporting.
  verified boolean not null default false,
  jade_granted int not null default 0,
  created_at timestamptz not null default now()
);
create index if not exists purchases_user_idx on public.purchases (user_id, created_at desc);

alter table public.purchases enable row level security;
drop policy if exists "own purchases readable" on public.purchases;
create policy "own purchases readable" on public.purchases
  for select to authenticated using (user_id = (select auth.uid()));

-- Claims a store purchase. Returns {ok, error, sku, jade}.
-- Claiming the same receipt twice gives nothing the second time,
-- whoever asks.
create or replace function public.claim_purchase(
  p_sku text, p_token text, p_platform text default 'android')
returns json language plpgsql security definer set search_path = public as $$
declare
  p store_products%rowtype;
  v_total int;
  v_first boolean;
begin
  if auth.uid() is null then
    return json_build_object('ok', false, 'error', 'Not signed in');
  end if;
  if coalesce(btrim(p_token), '') = '' then
    return json_build_object('ok', false, 'error', 'Missing receipt.');
  end if;

  select * into p from store_products where sku = p_sku and active;
  if not found then
    return json_build_object('ok', false, 'error', 'That is not sold here.');
  end if;

  if exists (select 1 from purchases where purchase_token = btrim(p_token)) then
    return json_build_object('ok', false, 'error', 'That purchase was already claimed.');
  end if;

  -- First buy of a given pack pays double, which the shop advertises.
  -- Worked out from the purchase history rather than taken from the
  -- device, so "first time" cannot be claimed over and over.
  v_first := not exists (
    select 1 from purchases where user_id = auth.uid() and sku = p_sku);
  v_total := p.jade + p.bonus_jade;
  if v_first then
    v_total := v_total * 2;
  end if;

  insert into purchases (user_id, sku, purchase_token, platform, jade_granted)
    values (auth.uid(), p_sku, btrim(p_token), coalesce(p_platform, 'android'), v_total);

  return json_build_object('ok', true, 'error', '', 'sku', p.sku,
    'jade', v_total, 'first', v_first);
exception when unique_violation then
  -- Two devices racing on the same receipt.
  return json_build_object('ok', false, 'error', 'That purchase was already claimed.');
end $$;

-- ---------------------------------------------------------
-- SAVE INTEGRITY
-- ---------------------------------------------------------
-- Tunables in one place, so thresholds can be moved without touching
-- the checks. Deliberately generous: a false accusation costs a real
-- player far more than a missed cheat costs the game.
create or replace function public.max_stage() returns bigint
language sql immutable as $$ select 100000::bigint $$;

create or replace function public.max_currency() returns bigint
language sql immutable as $$ select 1000000000000000::bigint $$;

-- Stages per second, and Jade per second, beyond which an upload is
-- merely noted. Offline rewards arrive in one lump, so these have to
-- allow for a long absence.
create or replace function public.sus_stages_per_sec() returns numeric
language sql immutable as $$ select 20.0 $$;

create or replace function public.sus_jade_per_sec() returns numeric
language sql immutable as $$ select 5000.0 $$;

-- How many notes before an account is flagged.
create or replace function public.flag_after() returns int
language sql immutable as $$ select 3 $$;

create table if not exists public.save_audit (
  id bigint generated always as identity primary key,
  user_id uuid not null references public.profiles (id) on delete cascade,
  reason text not null,
  detail jsonb not null default '{}'::jsonb,
  noted_at timestamptz not null default now()
);
create index if not exists save_audit_user_idx on public.save_audit (user_id, noted_at desc);

alter table public.save_audit enable row level security;
-- Deliberately no select policy: this is for you, not for players.

alter table public.profiles
  add column if not exists flags int not null default 0,
  add column if not exists flagged boolean not null default false;

-- Runs on every cloud save. Refuses the impossible, notes the
-- improbable, and lets everything else through untouched.
create or replace function public.guard_save()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_stage bigint := coalesce((new.data ->> 'highest_stage')::bigint, 0);
  v_jade bigint := coalesce((new.data ->> 'immortal_jade')::bigint, 0);
  v_stones bigint := coalesce((new.data ->> 'spirit_stones')::bigint, 0);
  v_old_stage bigint := 0;
  v_old_jade bigint := 0;
  v_secs numeric := 0;
  v_notes int := 0;
begin
  -- Impossible: refuse. These are beyond anything the game can
  -- produce, so there is no honest save on the other side of them.
  if v_stage < 0 or v_stage > max_stage() then
    raise exception 'Save rejected: stage out of range';
  end if;
  if v_jade < 0 or v_jade > max_currency()
     or v_stones < 0 or v_stones > max_currency() then
    raise exception 'Save rejected: currency out of range';
  end if;

  if tg_op = 'UPDATE' then
    v_old_stage := coalesce((old.data ->> 'highest_stage')::bigint, 0);
    v_old_jade := coalesce((old.data ->> 'immortal_jade')::bigint, 0);
    v_secs := greatest(extract(epoch from (now() - old.updated_at))::numeric, 1.0);

    -- Highest stage is a high-water mark and cannot fall.
    if v_stage < v_old_stage then
      insert into save_audit (user_id, reason, detail)
        values (new.user_id, 'stage went backwards',
                json_build_object('from', v_old_stage, 'to', v_stage)::jsonb);
      v_notes := v_notes + 1;
    elsif (v_stage - v_old_stage)::numeric / v_secs > sus_stages_per_sec() then
      insert into save_audit (user_id, reason, detail)
        values (new.user_id, 'stage rose too fast',
                json_build_object('gain', v_stage - v_old_stage, 'seconds', v_secs)::jsonb);
      v_notes := v_notes + 1;
    end if;

    if (v_jade - v_old_jade)::numeric / v_secs > sus_jade_per_sec() then
      insert into save_audit (user_id, reason, detail)
        values (new.user_id, 'jade rose too fast',
                json_build_object('gain', v_jade - v_old_jade, 'seconds', v_secs)::jsonb);
      v_notes := v_notes + 1;
    end if;
  end if;

  if v_notes > 0 then
    update profiles
      set flags = flags + v_notes,
          flagged = (flags + v_notes) >= flag_after()
      where id = new.user_id;
  end if;

  return new;
end $$;

drop trigger if exists guard_save on public.saves;
create trigger guard_save
  before insert or update on public.saves
  for each row execute function public.guard_save();

-- ---------------------------------------------------------
-- FLAGGED ACCOUNTS LEAVE THE BOARD
-- ---------------------------------------------------------
-- They can still duel and still earn; they simply stop being held up
-- as an example. Quieter than a ban, and reversible if it was wrong.
-- Unchanged from part 9 but for the `not pr.flagged` line. The
-- `order by` inside json_agg is what numbers the board, and the
-- coalesce keeps it working for someone who has not entered yet.
create or replace function public.arena_board(p_limit int default 20)
returns json language sql stable security definer set search_path = public as $$
  select coalesce(json_agg(json_build_object(
      'id', t.user_id, 'name', p.display_name, 'points', t.points,
      'wins', t.wins, 'losses', t.losses, 'power', t.power)
    order by t.points desc), '[]'::json)
  from (
    select a.* from arena_profiles a
    join profiles pr on pr.id = a.user_id
    where a.bracket = coalesce(
        (select bracket from arena_profiles where user_id = auth.uid()), 0)
      and not pr.flagged
    order by a.points desc
    limit least(greatest(coalesce(p_limit, 20), 1), 100)
  ) t
  join profiles p on p.id = t.user_id
$$;

-- ---------------------------------------------------------
-- ACCESS
-- ---------------------------------------------------------
grant select on public.store_products, public.purchases to authenticated;

revoke all on function public.claim_purchase(text, text, text) from public, anon;
revoke all on function public.guard_save() from public, anon, authenticated;
revoke all on function public.max_stage() from public, anon;
revoke all on function public.max_currency() from public, anon;
revoke all on function public.sus_stages_per_sec() from public, anon;
revoke all on function public.sus_jade_per_sec() from public, anon;
revoke all on function public.flag_after() from public, anon;

grant execute on function public.claim_purchase(text, text, text) to authenticated;
grant execute on function public.arena_board(int) to authenticated;

-- ---------------------------------------------------------
-- YOUR PRODUCTS
-- ---------------------------------------------------------
-- Fill these in to match the SKUs you create in Play Console. The
-- amounts here are what the server grants; whatever the device
-- claims a pack contains is ignored.
--
--   insert into public.store_products (sku, jade, bonus_jade, sort) values
--     ('jade_small',   300,    0, 1),
--     ('jade_medium', 1000,  100, 2),
--     ('jade_large',  3000,  500, 3)
--   on conflict (sku) do update set
--     jade = excluded.jade, bonus_jade = excluded.bonus_jade;
--
-- To review what has been noted:
--   select p.display_name, p.flags, p.flagged, a.reason, a.detail, a.noted_at
--   from save_audit a join profiles p on p.id = a.user_id
--   order by a.noted_at desc limit 50;
--
-- To clear a flag after looking into it:
--   update profiles set flags = 0, flagged = false where id = '<uuid>';
