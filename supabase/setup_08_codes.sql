-- =========================================================
-- Immortal Cultivation: Supabase setup, part 8 — REDEEM CODES
-- Run after parts 1-7: SQL Editor > New query ("08 - codes")
-- > paste > Run. Safe to run again.
--
-- Codes live on the server, so the client never decides what a
-- code is worth or whether it has been used. You add codes by
-- hand in the Table Editor (or with the INSERT example below).
--
-- redeem_code() RETURNS a result instead of raising: a raised
-- exception would roll back the failed-attempt log in the same
-- transaction, and that log is what stops codes being brute
-- forced. So the client reads .ok / .error from the JSON.
-- =========================================================

create table if not exists public.redeem_codes (
  code text primary key,
  -- rewards uses the same keys as the ad chests:
  --   {"jade": 100, "stones_hours": 2, "summon_scroll": 1}
  rewards jsonb not null,
  -- 0 = unlimited
  max_uses int not null default 0,
  uses int not null default 0,
  starts_at timestamptz,
  expires_at timestamptz,
  active boolean not null default true,
  note text not null default '',
  created_at timestamptz not null default now()
);

create table if not exists public.redeem_claims (
  code text not null references public.redeem_codes (code) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  claimed_at timestamptz not null default now(),
  primary key (code, user_id)
);

-- Every attempt, right or wrong, so guessing can be throttled.
create table if not exists public.redeem_attempts (
  id bigint generated always as identity primary key,
  user_id uuid not null references public.profiles (id) on delete cascade,
  code text not null,
  ok boolean not null,
  attempted_at timestamptz not null default now()
);
create index if not exists redeem_attempts_user_idx
  on public.redeem_attempts (user_id, attempted_at desc);

alter table public.redeem_codes enable row level security;
alter table public.redeem_claims enable row level security;
alter table public.redeem_attempts enable row level security;

-- No select policy on redeem_codes: players must never be able to
-- list the codes. Everything goes through redeem_code().
drop policy if exists "own claims readable" on public.redeem_claims;
create policy "own claims readable" on public.redeem_claims for select to authenticated
  using (user_id = (select auth.uid()));

-- Wrong guesses allowed per hour before the player is told to wait.
create or replace function public.redeem_attempt_limit() returns int
language sql immutable as $$ select 10 $$;

create or replace function public.redeem_code(p_code text)
returns json language plpgsql security definer set search_path = public as $$
declare
  c redeem_codes%rowtype;
  v_code text := upper(btrim(coalesce(p_code, '')));
  v_recent int;
begin
  if auth.uid() is null then
    return json_build_object('ok', false, 'error', 'Sign in to redeem a code.');
  end if;
  if v_code = '' then
    return json_build_object('ok', false, 'error', 'Enter a code.');
  end if;

  select count(*) into v_recent from redeem_attempts
    where user_id = auth.uid() and not ok
      and attempted_at > now() - interval '1 hour';
  if v_recent >= redeem_attempt_limit() then
    return json_build_object('ok', false, 'error', 'Too many wrong codes. Try again later.');
  end if;

  select * into c from redeem_codes where code = v_code for update;

  if not found or not c.active then
    insert into redeem_attempts (user_id, code, ok) values (auth.uid(), v_code, false);
    return json_build_object('ok', false, 'error', 'That code is not valid.');
  end if;
  if c.starts_at is not null and now() < c.starts_at then
    insert into redeem_attempts (user_id, code, ok) values (auth.uid(), v_code, false);
    return json_build_object('ok', false, 'error', 'That code is not active yet.');
  end if;
  if c.expires_at is not null and now() > c.expires_at then
    insert into redeem_attempts (user_id, code, ok) values (auth.uid(), v_code, false);
    return json_build_object('ok', false, 'error', 'That code has expired.');
  end if;
  if c.max_uses > 0 and c.uses >= c.max_uses then
    insert into redeem_attempts (user_id, code, ok) values (auth.uid(), v_code, false);
    return json_build_object('ok', false, 'error', 'That code has been fully claimed.');
  end if;
  if exists (select 1 from redeem_claims where code = v_code and user_id = auth.uid()) then
    insert into redeem_attempts (user_id, code, ok) values (auth.uid(), v_code, false);
    return json_build_object('ok', false, 'error', 'You have already used that code.');
  end if;

  insert into redeem_claims (code, user_id) values (v_code, auth.uid());
  update redeem_codes set uses = uses + 1 where code = v_code;
  insert into redeem_attempts (user_id, code, ok) values (auth.uid(), v_code, true);

  return json_build_object('ok', true, 'error', '', 'code', c.code, 'rewards', c.rewards);
end $$;

-- ---------------------------------------------------------
-- ACCESS
-- ---------------------------------------------------------
grant select on public.redeem_claims to authenticated;

revoke all on function public.redeem_attempt_limit() from public, anon;
revoke all on function public.redeem_code(text) from public, anon;

grant execute on function public.redeem_attempt_limit() to authenticated;
grant execute on function public.redeem_code(text) to authenticated;

-- ---------------------------------------------------------
-- ADDING CODES
-- ---------------------------------------------------------
-- Codes are matched uppercase, so store them uppercase.
--
--   insert into public.redeem_codes (code, rewards, max_uses, expires_at, note)
--   values ('WELCOME2026',
--           '{"jade": 100, "summon_scroll": 1, "stones_hours": 2}'::jsonb,
--           0, now() + interval '30 days', 'Launch code');
--
-- Reward keys are the ones Ads.give_fortune() understands:
--   "jade"          Immortal Jade
--   "stones_hours"  Spirit Stones worth that many hours offline
--   anything else   an item id, e.g. "summon_scroll", "beast_core"
