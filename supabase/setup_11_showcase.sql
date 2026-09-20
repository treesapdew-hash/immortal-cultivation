-- =========================================================
-- Immortal Cultivation: Supabase setup, part 11 — SHOWCASE
-- Run after parts 1-10: SQL Editor > New query ("11 - showcase")
-- > paste > Run. Safe to run again.
--
-- A public snapshot of what a cultivator is fielding: their team,
-- and what each of them is wearing. One column serves every
-- surface that shows a name — World chat, Whispers, the friends
-- list, sect member lists, the Arena and its board.
--
-- This is display data only. Nothing here is read back into the
-- owner's save, so a tampered showcase makes someone look
-- impressive and changes nothing else.
-- =========================================================

alter table public.profiles
  add column if not exists showcase jsonb not null default '{}'::jsonb;

-- The client writes this column in the same upsert that keeps the
-- rest of the profile fresh (Backend.update_profile), so there is
-- no function to call. The cap lives here instead: a public column
-- anyone can write needs a ceiling, or a modified client could park
-- megabytes in it. 32 KB is roughly ten times a full six-partner
-- team with all its gear.
create or replace function public.cap_showcase()
returns trigger language plpgsql as $$
begin
  if pg_column_size(new.showcase) > 32768 then
    raise exception 'Showcase too large';
  end if;
  return new;
end $$;

drop trigger if exists cap_showcase on public.profiles;
create trigger cap_showcase
  before insert or update of showcase on public.profiles
  for each row execute function public.cap_showcase();

-- Anyone signed in can look at anyone, which is the point. Reading
-- goes through this rather than the table so blocked cultivators
-- stay hidden, matching chat and the Arena.
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
        'showcase', p.showcase)
      from profiles p where p.id = p_user), '{}'::json)
  end
$$;

-- ---------------------------------------------------------
-- ACCESS
-- ---------------------------------------------------------
revoke all on function public.get_showcase(uuid) from public, anon;
grant execute on function public.get_showcase(uuid) to authenticated;
