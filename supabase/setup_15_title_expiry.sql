-- =========================================================
-- Immortal Cultivation: Supabase setup, part 15 — TITLE EXPIRY
-- Run after part 14: SQL Editor > New query ("15 - title expiry")
-- > paste > Run. Safe to run again.
--
-- Standing titles are meant to last a week or a month, not forever:
-- holding rank one last week should not be a permanent stat. The
-- jsonb array from part 13 had nowhere to put an expiry, so titles
-- move to a table with one row each.
--
-- Anything already awarded is carried over and kept for good, so no
-- tester loses what they were given.
-- =========================================================

create table if not exists public.player_titles (
  user_id uuid not null references public.profiles (id) on delete cascade,
  title text not null,
  granted_at timestamptz not null default now(),
  -- null = kept for good
  expires_at timestamptz,
  primary key (user_id, title)
);
create index if not exists player_titles_user_idx
  on public.player_titles (user_id);

alter table public.player_titles enable row level security;
drop policy if exists "own titles readable" on public.player_titles;
create policy "own titles readable" on public.player_titles
  for select to authenticated using (user_id = (select auth.uid()));

-- Carry across whatever part 13 already handed out. Permanent,
-- because there is no telling now when those were earned.
insert into public.player_titles (user_id, title, expires_at)
select p.id, t.value #>> '{}', null
from public.profiles p
cross join lateral jsonb_array_elements(coalesce(p.titles, '[]'::jsonb)) as t(value)
on conflict (user_id, title) do nothing;

-- ---------------------------------------------------------
-- AWARDING
-- ---------------------------------------------------------
-- p_days 0 (or null) means it is kept for good. Re-awarding a title
-- someone already holds pushes its expiry out rather than refusing,
-- which is what should happen when they place again.
create or replace function public.award_title(
  p_user uuid, p_title text, p_days int default 0)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_until timestamptz := case
    when coalesce(p_days, 0) > 0 then now() + make_interval(days => p_days)
    else null end;
begin
  if p_user is null or coalesce(p_title, '') = '' then
    return;
  end if;
  insert into player_titles (user_id, title, expires_at)
    values (p_user, p_title, v_until)
  on conflict (user_id, title) do update set
    granted_at = now(),
    -- A permanent award always wins over a timed one.
    expires_at = case
      when v_until is null or player_titles.expires_at is null then null
      else greatest(player_titles.expires_at, v_until)
    end;
end $$;

-- What this player holds that is still in date, as
-- [{"id": "...", "expires": <unix seconds, 0 = never>}, ...]
create or replace function public.my_titles()
returns json language sql stable security definer set search_path = public as $$
  select coalesce(json_agg(json_build_object(
      'id', t.title,
      'expires', coalesce(extract(epoch from t.expires_at)::bigint, 0))), '[]'::json)
  from player_titles t
  where t.user_id = auth.uid()
    and (t.expires_at is null or t.expires_at > now())
$$;

-- ---------------------------------------------------------
-- ARENA PLACEMENTS, NOW WITH A CLOCK
-- ---------------------------------------------------------
-- A week at the top is worth a week of the title. Sovereign of the
-- Ring runs a month, because holding rank one three weeks running is
-- a far longer errand. These match `days` in systems/titles.gd.
create or replace function public.award_arena_titles(p_period date)
returns void language plpgsql security definer set search_path = public as $$
declare
  r record;
begin
  for r in
    select s.user_id, s.rank
    from arena_standings s
    join (
      select bracket, count(*) filter (where duels > 0) as n
      from arena_standings where kind = 'weekly' and period = p_period
      group by bracket
    ) b on b.bracket = s.bracket
    where s.kind = 'weekly' and s.period = p_period and s.duels > 0
      and b.n >= arena_min_bracket()
  loop
    if r.rank = 1 then
      perform award_title(r.user_id, 'arena_champion', 7);
      -- Three weeks at the top, counting this one.
      if (select count(*) from arena_standings s2
          where s2.kind = 'weekly' and s2.user_id = r.user_id and s2.rank = 1
            and s2.period > p_period - 21) >= 3 then
        perform award_title(r.user_id, 'arena_sovereign', 30);
      end if;
    end if;
    if r.rank <= 10 then
      perform award_title(r.user_id, 'arena_top_ten', 7);
    end if;
  end loop;
end $$;

-- ---------------------------------------------------------
-- ACCESS
-- ---------------------------------------------------------
grant select on public.player_titles to authenticated;

revoke all on function public.award_title(uuid, text, int) from public, anon, authenticated;
revoke all on function public.award_arena_titles(date) from public, anon, authenticated;
revoke all on function public.my_titles() from public, anon;

grant execute on function public.my_titles() to authenticated;

-- The two-argument award_title from part 13 is gone, replaced by the
-- three-argument one above. Dropped so nothing keeps calling it and
-- quietly awarding permanent titles.
drop function if exists public.award_title(uuid, text);
