-- =========================================================
-- Immortal Cultivation: Supabase setup, part 7 — SOCIAL
-- Run after parts 1-6: SQL Editor > New query ("07 - social")
-- > paste > Run. Safe to run again.
--
-- World chat, whispers, friends, daily friend gifts, plus the
-- blocking and reporting that Google Play expects for any app
-- with player-to-player messaging.
--
-- Blocking applies to ALL channels: a blocked player's world
-- messages are hidden AND their whispers are refused. A block
-- that only hid public chat would be worse than none.
--
-- As in parts 2-5, players can read but never write these tables
-- directly: every action goes through a function that checks the
-- rules on the server.
-- =========================================================

-- ---------------------------------------------------------
-- BLOCKING (declared first: chat reads filter on it)
-- ---------------------------------------------------------
create table if not exists public.player_blocks (
  user_id uuid not null references public.profiles (id) on delete cascade,
  blocked_id uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, blocked_id)
);
create index if not exists player_blocks_user_idx on public.player_blocks (user_id);

alter table public.player_blocks enable row level security;
drop policy if exists "own blocks readable" on public.player_blocks;
create policy "own blocks readable" on public.player_blocks for select to authenticated
  using (user_id = (select auth.uid()));

-- True if the caller has blocked p_other, or p_other has blocked
-- the caller. Mutual: a blocked player can't reach you either.
create or replace function public.is_blocked(p_other uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from player_blocks
    where (user_id = auth.uid() and blocked_id = p_other)
       or (user_id = p_other and blocked_id = auth.uid()))
$$;

create or replace function public.block_player(p_user uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Not signed in'; end if;
  if p_user = auth.uid() then raise exception 'You cannot block yourself'; end if;
  insert into player_blocks (user_id, blocked_id) values (auth.uid(), p_user)
    on conflict do nothing;
  -- Blocking also severs any friendship, both ways.
  delete from friends where (user_id = auth.uid() and friend_id = p_user)
                         or (user_id = p_user and friend_id = auth.uid());
  delete from friend_requests where (from_id = auth.uid() and to_id = p_user)
                                 or (from_id = p_user and to_id = auth.uid());
end $$;

create or replace function public.unblock_player(p_user uuid)
returns void language sql security definer set search_path = public as $$
  delete from player_blocks where user_id = auth.uid() and blocked_id = p_user
$$;

-- ---------------------------------------------------------
-- REPORTING
-- ---------------------------------------------------------
-- The message body is copied in, so a report survives the message
-- being deleted and can be reviewed in the dashboard.
create table if not exists public.player_reports (
  id bigint generated always as identity primary key,
  reporter_id uuid references public.profiles (id) on delete set null,
  reported_id uuid references public.profiles (id) on delete set null,
  channel text not null check (channel in ('world', 'sect', 'whisper')),
  body text not null,
  reason text not null default '',
  created_at timestamptz not null default now()
);

alter table public.player_reports enable row level security;
-- Deliberately no select policy: reports are staff-only, read in
-- the Supabase dashboard. Players can file but never read them.

create or replace function public.report_message(
    p_reported uuid, p_channel text, p_body text, p_reason text default '')
returns void language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Not signed in'; end if;
  if p_channel not in ('world', 'sect', 'whisper') then raise exception 'Unknown channel'; end if;
  -- One report per player per target per hour, so reporting can't
  -- itself be used to spam.
  if exists (select 1 from player_reports
             where reporter_id = auth.uid() and reported_id = p_reported
               and created_at > now() - interval '1 hour') then
    raise exception 'You already reported that cultivator recently';
  end if;
  insert into player_reports (reporter_id, reported_id, channel, body, reason)
    values (auth.uid(), p_reported, p_channel, left(coalesce(p_body, ''), 400),
            left(coalesce(p_reason, ''), 100));
end $$;

-- ---------------------------------------------------------
-- WORLD CHAT
-- ---------------------------------------------------------
create table if not exists public.world_messages (
  id bigint generated always as identity primary key,
  user_id uuid references public.profiles (id) on delete set null,
  name text not null,
  body text not null check (char_length(body) between 1 and 200),
  created_at timestamptz not null default now()
);
create index if not exists world_messages_recent_idx on public.world_messages (id desc);

alter table public.world_messages enable row level security;
-- Read through get_world_messages() instead, so blocks are applied.
drop policy if exists "world readable" on public.world_messages;

create or replace function public.send_world_message(p_body text)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_name text;
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
  select display_name into v_name from profiles where id = auth.uid();
  insert into world_messages (user_id, name, body)
    values (auth.uid(), coalesce(v_name, 'Cultivator'), v_body);
end $$;

-- Newest messages, oldest first, with blocked players removed.
-- Pass the last id you have to fetch only what's new.
create or replace function public.get_world_messages(p_after bigint default 0, p_limit int default 50)
returns setof public.world_messages
language sql stable security definer set search_path = public as $$
  select * from (
    select m.* from world_messages m
    where m.id > coalesce(p_after, 0)
      and not exists (
        select 1 from player_blocks b
        where (b.user_id = auth.uid() and b.blocked_id = m.user_id)
           or (b.user_id = m.user_id and b.blocked_id = auth.uid()))
    order by m.id desc
    limit least(greatest(coalesce(p_limit, 50), 1), 100)
  ) recent
  order by recent.id
$$;

-- ---------------------------------------------------------
-- WHISPERS (private 1-to-1)
-- ---------------------------------------------------------
create table if not exists public.whispers (
  id bigint generated always as identity primary key,
  from_id uuid not null references public.profiles (id) on delete cascade,
  to_id uuid not null references public.profiles (id) on delete cascade,
  from_name text not null,
  body text not null check (char_length(body) between 1 and 200),
  seen boolean not null default false,
  created_at timestamptz not null default now()
);
create index if not exists whispers_inbox_idx on public.whispers (to_id, id desc);
create index if not exists whispers_pair_idx on public.whispers (from_id, to_id, id desc);

alter table public.whispers enable row level security;
drop policy if exists "own whispers readable" on public.whispers;
create policy "own whispers readable" on public.whispers for select to authenticated
  using (to_id = (select auth.uid()) or from_id = (select auth.uid()));

create or replace function public.send_whisper(p_to uuid, p_body text)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_name text;
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
  select display_name into v_name from profiles where id = auth.uid();
  insert into whispers (from_id, to_id, from_name, body)
    values (auth.uid(), p_to, coalesce(v_name, 'Cultivator'), v_body);
end $$;

-- One conversation, oldest first. Marks the other side's messages seen.
create or replace function public.get_whispers(p_with uuid, p_after bigint default 0, p_limit int default 50)
returns setof public.whispers
language plpgsql security definer set search_path = public as $$
begin
  update whispers set seen = true
    where to_id = auth.uid() and from_id = p_with and not seen;
  return query
    select * from (
      select w.* from whispers w
      where w.id > coalesce(p_after, 0)
        and ((w.from_id = auth.uid() and w.to_id = p_with)
          or (w.from_id = p_with and w.to_id = auth.uid()))
      order by w.id desc
      limit least(greatest(coalesce(p_limit, 50), 1), 100)
    ) recent
    order by recent.id;
end $$;

-- Unread count per sender, for the chat tab's red dot.
-- The grouping happens in the subquery: json_agg() cannot wrap
-- max()/count() directly, that would nest aggregates.
create or replace function public.whisper_unread()
returns json language sql stable security definer set search_path = public as $$
  select coalesce(json_agg(json_build_object(
      'from_id', u.from_id, 'from_name', u.from_name, 'unread', u.unread)), '[]'::json)
  from (
    select w.from_id, max(w.from_name) as from_name, count(*) as unread
    from whispers w
    where w.to_id = auth.uid() and not w.seen
    group by w.from_id
  ) u
$$;

-- ---------------------------------------------------------
-- FRIENDS
-- ---------------------------------------------------------
-- Stored in both directions, so "my friends" is a single lookup.
create table if not exists public.friends (
  user_id uuid not null references public.profiles (id) on delete cascade,
  friend_id uuid not null references public.profiles (id) on delete cascade,
  since timestamptz not null default now(),
  primary key (user_id, friend_id)
);

create table if not exists public.friend_requests (
  from_id uuid not null references public.profiles (id) on delete cascade,
  to_id uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (from_id, to_id)
);

alter table public.friends enable row level security;
alter table public.friend_requests enable row level security;

drop policy if exists "own friends readable" on public.friends;
create policy "own friends readable" on public.friends for select to authenticated
  using (user_id = (select auth.uid()));

drop policy if exists "own requests readable" on public.friend_requests;
create policy "own requests readable" on public.friend_requests for select to authenticated
  using (to_id = (select auth.uid()) or from_id = (select auth.uid()));

-- Max friends per player
create or replace function public.friend_limit() returns int
language sql immutable as $$ select 50 $$;

create or replace function public.request_friend(p_user uuid)
returns text language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'Not signed in'; end if;
  if p_user = auth.uid() then raise exception 'You cannot befriend yourself'; end if;
  if is_blocked(p_user) then raise exception 'You cannot add that cultivator'; end if;
  if exists (select 1 from friends where user_id = auth.uid() and friend_id = p_user) then
    raise exception 'Already friends';
  end if;
  if (select count(*) from friends where user_id = auth.uid()) >= friend_limit() then
    raise exception 'Your friend list is full';
  end if;
  -- They already asked you: accept instead of stacking requests.
  if exists (select 1 from friend_requests where from_id = p_user and to_id = auth.uid()) then
    perform accept_friend(p_user);
    return 'accepted';
  end if;
  insert into friend_requests (from_id, to_id) values (auth.uid(), p_user)
    on conflict do nothing;
  return 'requested';
end $$;

create or replace function public.accept_friend(p_user uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not exists (select 1 from friend_requests where from_id = p_user and to_id = auth.uid()) then
    raise exception 'That request is gone';
  end if;
  delete from friend_requests where from_id = p_user and to_id = auth.uid();
  if is_blocked(p_user) then raise exception 'You cannot add that cultivator'; end if;
  if (select count(*) from friends where user_id = auth.uid()) >= friend_limit() then
    raise exception 'Your friend list is full';
  end if;
  if (select count(*) from friends where user_id = p_user) >= friend_limit() then
    raise exception 'Their friend list is full';
  end if;
  insert into friends (user_id, friend_id) values (auth.uid(), p_user) on conflict do nothing;
  insert into friends (user_id, friend_id) values (p_user, auth.uid()) on conflict do nothing;
end $$;

create or replace function public.reject_friend(p_user uuid)
returns void language sql security definer set search_path = public as $$
  delete from friend_requests where from_id = p_user and to_id = auth.uid()
$$;

create or replace function public.remove_friend(p_user uuid)
returns void language sql security definer set search_path = public as $$
  delete from friends where (user_id = auth.uid() and friend_id = p_user)
                         or (user_id = p_user and friend_id = auth.uid())
$$;

-- Find cultivators by name, for the Add Friend box. Never returns
-- you, anyone you've blocked, or anyone who blocked you.
create or replace function public.find_players(p_name text, p_limit int default 20)
returns json language sql stable security definer set search_path = public as $$
  select coalesce(json_agg(json_build_object(
      'id', p.id, 'name', p.display_name, 'realm', p.realm,
      'power', p.power, 'stage', p.highest_stage)), '[]'::json)
  from (
    select * from profiles p2
    where p2.id <> auth.uid()
      and p2.display_name ilike '%' || btrim(coalesce(p_name, '')) || '%'
      and not exists (
        select 1 from player_blocks b
        where (b.user_id = auth.uid() and b.blocked_id = p2.id)
           or (b.user_id = p2.id and b.blocked_id = auth.uid()))
    order by p2.power desc
    limit least(greatest(coalesce(p_limit, 20), 1), 50)
  ) p
$$;

-- ---------------------------------------------------------
-- DAILY FRIEND GIFTS
-- ---------------------------------------------------------
-- One gift to each friend per UTC day; each gift is claimed once.
create table if not exists public.friend_gifts (
  from_id uuid not null references public.profiles (id) on delete cascade,
  to_id uuid not null references public.profiles (id) on delete cascade,
  day date not null,
  claimed boolean not null default false,
  created_at timestamptz not null default now(),
  primary key (from_id, to_id, day)
);
create index if not exists friend_gifts_inbox_idx on public.friend_gifts (to_id, claimed);

alter table public.friend_gifts enable row level security;
drop policy if exists "own gifts readable" on public.friend_gifts;
create policy "own gifts readable" on public.friend_gifts for select to authenticated
  using (to_id = (select auth.uid()) or from_id = (select auth.uid()));

-- What one claimed gift is worth. Keep in sync with friends.gd.
create or replace function public.gift_reward() returns json
language sql immutable as $$ select json_build_object('jade', 5, 'beast_core', 10) $$;

create or replace function public.send_gift(p_user uuid)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_today date := (now() at time zone 'utc')::date;
begin
  if not exists (select 1 from friends where user_id = auth.uid() and friend_id = p_user) then
    raise exception 'Not on your friend list';
  end if;
  if exists (select 1 from friend_gifts
             where from_id = auth.uid() and to_id = p_user and day = v_today) then
    raise exception 'Already sent today';
  end if;
  insert into friend_gifts (from_id, to_id, day) values (auth.uid(), p_user, v_today);
end $$;

-- Sends to every friend not yet sent to today. Returns how many.
create or replace function public.send_all_gifts()
returns int language plpgsql security definer set search_path = public as $$
declare
  v_today date := (now() at time zone 'utc')::date;
  v_count int;
begin
  with sent as (
    insert into friend_gifts (from_id, to_id, day)
      select auth.uid(), f.friend_id, v_today from friends f
      where f.user_id = auth.uid()
    on conflict do nothing
    returning 1)
  select count(*) into v_count from sent;
  return coalesce(v_count, 0);
end $$;

-- Claims every unclaimed gift. Returns the count and the total
-- reward, so the client grants it once.
create or replace function public.claim_gifts()
returns json language plpgsql security definer set search_path = public as $$
declare
  v_count int;
  v_reward json := gift_reward();
begin
  with taken as (
    update friend_gifts set claimed = true
    where to_id = auth.uid() and not claimed
    returning 1)
  select count(*) into v_count from taken;
  v_count := coalesce(v_count, 0);
  return json_build_object(
    'count', v_count,
    'jade', v_count * (v_reward ->> 'jade')::int,
    'beast_core', v_count * (v_reward ->> 'beast_core')::int);
end $$;

-- Friend list with today's gift state, in one call.
create or replace function public.friend_state()
returns json language sql stable security definer set search_path = public as $$
  select json_build_object(
    'friends', coalesce((
      select json_agg(json_build_object(
        'id', p.id, 'name', p.display_name, 'realm', p.realm, 'power', p.power,
        'sent_today', exists (
          select 1 from friend_gifts g where g.from_id = auth.uid()
            and g.to_id = p.id and g.day = (now() at time zone 'utc')::date))
        order by p.power desc)
      from friends f join profiles p on p.id = f.friend_id
      where f.user_id = auth.uid()), '[]'::json),
    'requests', coalesce((
      select json_agg(json_build_object('id', p.id, 'name', p.display_name, 'realm', p.realm))
      from friend_requests r join profiles p on p.id = r.from_id
      where r.to_id = auth.uid()), '[]'::json),
    'unclaimed', (select count(*) from friend_gifts where to_id = auth.uid() and not claimed))
$$;

-- ---------------------------------------------------------
-- ACCESS
-- ---------------------------------------------------------
grant select on public.player_blocks, public.whispers, public.friends,
                public.friend_requests, public.friend_gifts to authenticated;

revoke all on function public.is_blocked(uuid) from public, anon;
revoke all on function public.block_player(uuid) from public, anon;
revoke all on function public.unblock_player(uuid) from public, anon;
revoke all on function public.report_message(uuid, text, text, text) from public, anon;
revoke all on function public.send_world_message(text) from public, anon;
revoke all on function public.get_world_messages(bigint, int) from public, anon;
revoke all on function public.send_whisper(uuid, text) from public, anon;
revoke all on function public.get_whispers(uuid, bigint, int) from public, anon;
revoke all on function public.whisper_unread() from public, anon;
revoke all on function public.friend_limit() from public, anon;
revoke all on function public.request_friend(uuid) from public, anon;
revoke all on function public.accept_friend(uuid) from public, anon;
revoke all on function public.reject_friend(uuid) from public, anon;
revoke all on function public.remove_friend(uuid) from public, anon;
revoke all on function public.find_players(text, int) from public, anon;
revoke all on function public.gift_reward() from public, anon;
revoke all on function public.send_gift(uuid) from public, anon;
revoke all on function public.send_all_gifts() from public, anon;
revoke all on function public.claim_gifts() from public, anon;
revoke all on function public.friend_state() from public, anon;

grant execute on function public.is_blocked(uuid) to authenticated;
grant execute on function public.block_player(uuid) to authenticated;
grant execute on function public.unblock_player(uuid) to authenticated;
grant execute on function public.report_message(uuid, text, text, text) to authenticated;
grant execute on function public.send_world_message(text) to authenticated;
grant execute on function public.get_world_messages(bigint, int) to authenticated;
grant execute on function public.send_whisper(uuid, text) to authenticated;
grant execute on function public.get_whispers(uuid, bigint, int) to authenticated;
grant execute on function public.whisper_unread() to authenticated;
grant execute on function public.friend_limit() to authenticated;
grant execute on function public.request_friend(uuid) to authenticated;
grant execute on function public.accept_friend(uuid) to authenticated;
grant execute on function public.reject_friend(uuid) to authenticated;
grant execute on function public.remove_friend(uuid) to authenticated;
grant execute on function public.find_players(text, int) to authenticated;
grant execute on function public.gift_reward() to authenticated;
grant execute on function public.send_gift(uuid) to authenticated;
grant execute on function public.send_all_gifts() to authenticated;
grant execute on function public.claim_gifts() to authenticated;
grant execute on function public.friend_state() to authenticated;
