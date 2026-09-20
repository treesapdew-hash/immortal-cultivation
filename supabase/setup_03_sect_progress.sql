-- =========================================================
-- Immortal Cultivation: Supabase setup, part 3 — SECT PROGRESS
-- Run after parts 1 and 2: SQL Editor > New query
-- ("03 - sect progress") > paste > Run. Safe to run again.
--
-- Daily sign-in and donations give Sect EXP (sect level, member
-- cap), Treasury funds (spent on Sect Research) and Contribution
-- (each member's spendable balance for the Sect Shop).
-- The day resets at 00:00 UTC.
-- =========================================================

-- ---------------------------------------------------------
-- NEW COLUMNS AND TABLES
-- ---------------------------------------------------------
alter table public.sects add column if not exists funds bigint not null default 0;

alter table public.sect_members add column if not exists balance bigint not null default 0;
alter table public.sect_members add column if not exists last_signin date;
alter table public.sect_members add column if not exists last_donate date;

create table if not exists public.sect_research (
  sect_id uuid not null references public.sects (id) on delete cascade,
  node text not null check (node in ('hp', 'atk', 'def', 'crit')),
  level int not null default 0,
  primary key (sect_id, node)
);
alter table public.sect_research enable row level security;
drop policy if exists "research readable" on public.sect_research;
create policy "research readable" on public.sect_research for select to authenticated using (true);

-- ---------------------------------------------------------
-- TUNING (keep in sync with sects.gd)
-- ---------------------------------------------------------
-- EXP for the next level: 500 x level^2, max level 10
create or replace function public.sect_exp_needed(p_level int) returns bigint
language sql immutable as $$ select (500 * p_level * p_level)::bigint $$;

-- Research cost for the next level of a node
create or replace function public.research_cost(p_node text, p_level int) returns bigint
language sql immutable as $$
  select (case p_node when 'def' then 200 when 'crit' then 400 else 300 end * (p_level + 1))::bigint
$$;

-- Adds EXP (and levels up) — internal, not callable by players
create or replace function public.sect_add_exp(p_sect uuid, p_exp bigint)
returns void language plpgsql security definer set search_path = public as $$
declare
  s sects%rowtype;
begin
  select * into s from sects where id = p_sect for update;
  s.exp := s.exp + p_exp;
  while s.level < 10 and s.exp >= sect_exp_needed(s.level) loop
    s.exp := s.exp - sect_exp_needed(s.level);
    s.level := s.level + 1;
  end loop;
  if s.level >= 10 then s.exp := least(s.exp, sect_exp_needed(10)); end if;
  update sects set exp = s.exp, level = s.level where id = p_sect;
end $$;

-- ---------------------------------------------------------
-- ACTIONS
-- ---------------------------------------------------------

-- Once a day: +10 Sect EXP, +20 Contribution
create or replace function public.sect_signin()
returns json language plpgsql security definer set search_path = public as $$
declare
  v_sect uuid := my_sect_id();
  v_today date := (now() at time zone 'utc')::date;
begin
  if v_sect is null then raise exception 'You are not in a sect'; end if;
  if (select last_signin from sect_members where user_id = auth.uid()) = v_today then
    raise exception 'Already signed in today';
  end if;
  update sect_members set last_signin = v_today, balance = balance + 20, contribution = contribution + 20
    where user_id = auth.uid();
  perform sect_add_exp(v_sect, 10);
  return json_build_object('exp', 10, 'contribution', 20);
end $$;

-- Once a day, one of three tiers (the game takes the payment first):
--   0 = Spirit Stones: +20 EXP / funds, +30 Contribution
--   1 = 50 Jade:       +60,              +80
--   2 = 200 Jade:      +200,             +250
create or replace function public.sect_donate(p_tier int)
returns json language plpgsql security definer set search_path = public as $$
declare
  v_sect uuid := my_sect_id();
  v_today date := (now() at time zone 'utc')::date;
  v_exp int;
  v_contrib int;
begin
  if v_sect is null then raise exception 'You are not in a sect'; end if;
  if (select last_donate from sect_members where user_id = auth.uid()) = v_today then
    raise exception 'Already donated today';
  end if;
  case p_tier
    when 0 then v_exp := 20; v_contrib := 30;
    when 1 then v_exp := 60; v_contrib := 80;
    when 2 then v_exp := 200; v_contrib := 250;
    else raise exception 'Unknown donation';
  end case;
  update sect_members set last_donate = v_today, balance = balance + v_contrib,
      contribution = contribution + v_contrib
    where user_id = auth.uid();
  update sects set funds = funds + v_exp where id = v_sect;
  perform sect_add_exp(v_sect, v_exp);
  return json_build_object('exp', v_exp, 'contribution', v_contrib);
end $$;

-- Sect Shop: spend Contribution. Returns the new balance.
create or replace function public.spend_contribution(p_amount int)
returns bigint language plpgsql security definer set search_path = public as $$
declare
  v_balance bigint;
begin
  if p_amount <= 0 then raise exception 'Invalid amount'; end if;
  select balance into v_balance from sect_members where user_id = auth.uid() for update;
  if v_balance is null then raise exception 'You are not in a sect'; end if;
  if v_balance < p_amount then raise exception 'Not enough Contribution'; end if;
  update sect_members set balance = balance - p_amount where user_id = auth.uid();
  return v_balance - p_amount;
end $$;

-- Leader / elders spend Treasury funds on research (max level 10,
-- and never above the sect's own level)
create or replace function public.upgrade_research(p_node text)
returns int language plpgsql security definer set search_path = public as $$
declare
  v_sect uuid := my_sect_id();
  v_level int;
  v_cost bigint;
  s sects%rowtype;
begin
  if my_sect_role() not in ('leader', 'elder') then raise exception 'Only the leader or elders can do that'; end if;
  if p_node not in ('hp', 'atk', 'def', 'crit') then raise exception 'Unknown research'; end if;
  select * into s from sects where id = v_sect for update;
  select level into v_level from sect_research where sect_id = v_sect and node = p_node;
  v_level := coalesce(v_level, 0);
  if v_level >= 10 then raise exception 'Already at max level'; end if;
  if v_level >= s.level then raise exception 'Raise the sect level first'; end if;
  v_cost := research_cost(p_node, v_level);
  if s.funds < v_cost then raise exception 'Not enough Treasury funds'; end if;
  update sects set funds = funds - v_cost where id = v_sect;
  insert into sect_research (sect_id, node, level) values (v_sect, p_node, v_level + 1)
    on conflict (sect_id, node) do update set level = v_level + 1;
  return v_level + 1;
end $$;

-- ---------------------------------------------------------
-- ACCESS
-- ---------------------------------------------------------
grant select on public.sect_research to authenticated;

revoke all on function public.sect_exp_needed(int) from public, anon;
revoke all on function public.research_cost(text, int) from public, anon;
revoke all on function public.sect_add_exp(uuid, bigint) from public, anon, authenticated;
revoke all on function public.sect_signin() from public, anon;
revoke all on function public.sect_donate(int) from public, anon;
revoke all on function public.spend_contribution(int) from public, anon;
revoke all on function public.upgrade_research(text) from public, anon;

grant execute on function public.sect_exp_needed(int) to authenticated;
grant execute on function public.research_cost(text, int) to authenticated;
grant execute on function public.sect_signin() to authenticated;
grant execute on function public.sect_donate(int) to authenticated;
grant execute on function public.spend_contribution(int) to authenticated;
grant execute on function public.upgrade_research(text) to authenticated;
