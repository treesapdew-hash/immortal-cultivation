-- =========================================================
-- Immortal Cultivation: Supabase setup, part 19 — CHAT WINDOW
-- Run after part 18: SQL Editor > New query ("19 - chat window")
-- > paste > Run. Safe to run again.
--
-- Chat handed back the newest fifty messages however old they were,
-- so opening it after a quiet night showed yesterday's conversation
-- as though it had just happened. Only the last few hours now.
--
-- Whispers are deliberately left whole: a private conversation is
-- worth keeping, and nobody wants half of one.
--
-- This filters on read and deletes nothing, so the history is still
-- there if it is ever wanted.
--
-- Also gives sect chat the title column World chat and Whispers got
-- in part 13, so a worn title shows in all three rather than two.
-- =========================================================

-- How far back chat reaches. One place to change it.
create or replace function public.chat_window_hours() returns int
language sql immutable as $$ select 6 $$;

-- ---------------------------------------------------------
-- WORLD
-- ---------------------------------------------------------
-- Unchanged from part 7 but for the age test. Blocked cultivators
-- stay hidden, and `p_after` still works for polling: a new message
-- is both newer than the last id and inside the window.
create or replace function public.get_world_messages(p_after bigint default 0, p_limit int default 50)
returns setof public.world_messages
language sql stable security definer set search_path = public as $$
  select * from (
    select m.* from world_messages m
    where m.id > coalesce(p_after, 0)
      and m.created_at > now() - make_interval(hours => chat_window_hours())
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
-- SECT
-- ---------------------------------------------------------
-- Sect chat is read straight off the table rather than through a
-- function, so the window is applied by the client. What it needs
-- from here is the title column, which it never had.
alter table public.sect_messages
  add column if not exists title text not null default '';

create index if not exists sect_messages_recent_idx
  on public.sect_messages (sect_id, created_at desc);

create or replace function public.send_sect_message(p_body text)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_sect uuid := my_sect_id();
  v_name text;
  v_title text;
  v_body text := btrim(p_body);
  v_last timestamptz;
begin
  if v_sect is null then raise exception 'You are not in a sect'; end if;
  if char_length(v_body) < 1 or char_length(v_body) > 200 then raise exception 'Messages need 1 to 200 characters'; end if;
  select max(created_at) into v_last from sect_messages where user_id = auth.uid();
  if v_last is not null and v_last > now() - interval '3 seconds' then
    raise exception 'Slow down a little';
  end if;
  select display_name, title into v_name, v_title from profiles where id = auth.uid();
  insert into sect_messages (sect_id, user_id, name, title, body)
    values (v_sect, auth.uid(), coalesce(v_name, 'Cultivator'), coalesce(v_title, ''), v_body);
end $$;

-- ---------------------------------------------------------
-- ACCESS
-- ---------------------------------------------------------
revoke all on function public.chat_window_hours() from public, anon;
revoke all on function public.get_world_messages(bigint, int) from public, anon;
revoke all on function public.send_sect_message(text) from public, anon;

grant execute on function public.get_world_messages(bigint, int) to authenticated;
grant execute on function public.send_sect_message(text) to authenticated;
