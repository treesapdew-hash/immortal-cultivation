-- =========================================================
-- Immortal Cultivation: Supabase setup, part 6 — DELETE ACCOUNT
-- Run after parts 1-5: SQL Editor > New query ("06 - delete account")
-- > paste > Run. Safe to run again.
--
-- Google Play requires apps with accounts to let players delete
-- their account and data. delete_my_account() does it in one step:
--   - a sect they lead passes to another member (elders first,
--     then the longest-serving member), or is removed if empty
--   - their sect chat messages stay, shown as "Departed Cultivator"
--   - their login, profile, cloud save, membership, requests and
--     trial damage are deleted (all linked rows cascade)
-- =========================================================

create or replace function public.delete_my_account()
returns void language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid();
  m sect_members%rowtype;
  v_heir uuid;
begin
  if v_uid is null then raise exception 'Not signed in'; end if;

  select * into m from sect_members where user_id = v_uid for update;
  if found then
    if m.role = 'leader' then
      select user_id into v_heir from sect_members
        where sect_id = m.sect_id and user_id <> v_uid
        order by case role when 'elder' then 0 else 1 end, joined_at
        limit 1;
      if v_heir is null then
        delete from sects where id = m.sect_id;
      else
        update sect_members set role = 'leader' where user_id = v_heir;
        update sects set leader_id = v_heir, member_count = member_count - 1 where id = m.sect_id;
      end if;
    else
      update sects set member_count = member_count - 1 where id = m.sect_id;
    end if;
  end if;

  -- Chat history stays, but no longer points to this player
  update sect_messages set name = 'Departed Cultivator', user_id = null where user_id = v_uid;

  -- Deleting the login removes the profile, save, membership,
  -- requests, shop purchases and trial damage (foreign keys cascade)
  delete from auth.users where id = v_uid;
end $$;

revoke all on function public.delete_my_account() from public, anon;
grant execute on function public.delete_my_account() to authenticated;
