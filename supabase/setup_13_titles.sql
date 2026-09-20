-- =========================================================
-- Immortal Cultivation: Supabase setup, part 13 — TITLES
-- Run after part 12: SQL Editor > New query ("13 - titles")
-- > paste > Run. Safe to run again.
--
-- Most titles are earned from counters in the player's own save and
-- never touch the server. These are the ones that cannot be: Arena
-- placements, tester titles and Founding Cultivator. The server
-- holds those, and the client merges them in.
--
-- The worn title also lives here, so it can be shown beside a name
-- in World chat, in Whispers and on the inspect page.
-- =========================================================

-- The worn title, and the set the server has awarded.
alter table public.profiles
  add column if not exists title text not null default '',
  add column if not exists titles jsonb not null default '[]'::jsonb;

-- Stamped onto each message as it is sent, the same way the sender's
-- name already is. Denormalising keeps get_world_messages() and
-- get_whispers() returning `setof` their table, so they pick the
-- column up without changing shape.
alter table public.world_messages
  add column if not exists title text not null default '';
alter table public.whispers
  add column if not exists title text not null default '';

-- ---------------------------------------------------------
-- SENDING, NOW CARRYING THE TITLE
-- ---------------------------------------------------------
create or replace function public.send_world_message(p_body text)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_name text;
  v_title text;
  v_body text := btrim(p_body);
  v_last timestamptz;
begin
  if auth.uid() is null then raise exception 'Not signed in'; end if;
  if char_length(v_body) < 1 or char_length(v_body) > 200 then
    raise exception 'Messages need 1 to 200 characters';
  end if;
  select max(created_at) into v_last from world_messages where user_id = auth.uid();
  if v_last is not null and v_last > now() - interval '5 seconds' then
    raise exception 'Slow down a little';
  end if;
  select display_name, title into v_name, v_title from profiles where id = auth.uid();
  insert into world_messages (user_id, name, title, body)
    values (auth.uid(), coalesce(v_name, 'Cultivator'), coalesce(v_title, ''), v_body);
end $$;

create or replace function public.send_whisper(p_to uuid, p_body text)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_name text;
  v_title text;
  v_body text := btrim(p_body);
  v_last timestamptz;
begin
  if auth.uid() is null then raise exception 'Not signed in'; end if;
  if p_to = auth.uid() then raise exception 'You cannot whisper yourself'; end if;
  if is_blocked(p_to) then raise exception 'You cannot message that cultivator'; end if;
  if char_length(v_body) < 1 or char_length(v_body) > 200 then
    raise exception 'Messages need 1 to 200 characters';
  end if;
  select max(created_at) into v_last from whispers where from_id = auth.uid();
  if v_last is not null and v_last > now() - interval '3 seconds' then
    raise exception 'Slow down a little';
  end if;
  select display_name, title into v_name, v_title from profiles where id = auth.uid();
  insert into whispers (from_id, to_id, from_name, title, body)
    values (auth.uid(), p_to, coalesce(v_name, 'Cultivator'), coalesce(v_title, ''), v_body);
end $$;

-- ---------------------------------------------------------
-- AWARDING
-- ---------------------------------------------------------
-- Internal. Adds a title to someone's set if they don't hold it.
-- Not reachable by players: a title you could award yourself would
-- be worth nothing.
create or replace function public.award_title(p_user uuid, p_title text)
returns void language plpgsql security definer set search_path = public as $$
begin
  if p_user is null or coalesce(p_title, '') = '' then
    return;
  end if;
  update profiles
    set titles = case
      when titles @> to_jsonb(array[p_title]) then titles
      else titles || to_jsonb(array[p_title])
    end
  where id = p_user;
end $$;

-- What the server says this player has been awarded.
-- The column is jsonb, so the fallback must be too; the cast to json
-- happens after, on the result.
create or replace function public.my_titles()
returns json language sql stable security definer set search_path = public as $$
  select coalesce((select titles from profiles where id = auth.uid()), '[]'::jsonb)::json
$$;

-- ---------------------------------------------------------
-- ARENA PLACEMENTS
-- ---------------------------------------------------------
-- Hooked into settlement (part 12): when a period is frozen, the
-- cultivators who placed are awarded their titles. Weekly only —
-- a daily rank-one title would stop meaning anything within a week.
create or replace function public.award_arena_titles(p_period date)
returns void language plpgsql security definer set search_path = public as $$
declare
  r record;
begin
  for r in
    select s.user_id, s.rank, b.n
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
      perform award_title(r.user_id, 'arena_champion');
    end if;
    if r.rank <= 10 then
      perform award_title(r.user_id, 'arena_top_ten');
    end if;
  end loop;
end $$;

-- Settlement now awards placement titles as well as rewards.
create or replace function public.arena_settle_due()
returns void language plpgsql security definer set search_path = public as $$
declare
  v_today date := (now() at time zone 'utc')::date;
  v_week date := date_trunc('week', now() at time zone 'utc')::date;
begin
  perform arena_settle('daily', v_today - 1);
  perform arena_settle('weekly', v_week - 7);
  perform award_arena_titles(v_week - 7);
end $$;

-- ---------------------------------------------------------
-- SHOWCASE, NOW CARRYING THE TITLE
-- ---------------------------------------------------------
create or replace function public.get_showcase(p_user uuid)
returns json language sql stable security definer set search_path = public as $$
  select case
    when p_user is null then '{}'::json
    when exists (
      select 1 from player_blocks b
      where (b.user_id = auth.uid() and b.blocked_id = p_user)
         or (b.user_id = p_user and b.blocked_id = auth.uid()))
    then '{}'::json
    else coalesce((
      select json_build_object(
        'id', p.id,
        'name', p.display_name,
        'realm', p.realm,
        'stage', p.highest_stage,
        'power', p.power,
        'title', p.title,
        'showcase', p.showcase)
      from profiles p where p.id = p_user), '{}'::json)
  end
$$;

-- ---------------------------------------------------------
-- ACCESS
-- ---------------------------------------------------------
revoke all on function public.award_title(uuid, text) from public, anon, authenticated;
revoke all on function public.award_arena_titles(date) from public, anon, authenticated;
revoke all on function public.arena_settle_due() from public, anon, authenticated;
revoke all on function public.my_titles() from public, anon;

grant execute on function public.my_titles() to authenticated;
