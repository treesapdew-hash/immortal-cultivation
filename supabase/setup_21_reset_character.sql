-- =========================================================
-- Immortal Cultivation: Supabase setup, part 21 — RESET CHARACTER
-- Run after part 20: SQL Editor > New query ("21 - reset character")
-- > paste > Run. Safe to run again.
--
-- Settings > Reset account wipes the save but keeps the Supabase
-- account, and everything the server remembered went on standing:
-- a brand new character walked into the Arena holding the old one's
-- rank, its team snapshot was still there to be duelled, and the
-- cloud save was waiting to restore the character they had just
-- deleted.
--
-- This lets go of what belonged to the character. It deliberately
-- keeps what belongs to the PERSON: the tester and founding titles
-- were given to them, not to a save file.
--
-- Destructive and meant to be. The player confirms twice before the
-- client calls it.
-- =========================================================

create or replace function public.reset_my_character()
returns json language plpgsql security definer set search_path = public as $$
declare
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    return json_build_object('ok', false, 'error', 'Not signed in');
  end if;

  -- Redeem codes: claims and the wrong-code throttle, with the uses
  -- handed back so a limited code is not spent twice by one player.
  update redeem_codes c
    set uses = greatest(0, c.uses - 1)
  from redeem_claims r
  where r.user_id = v_uid and r.code = c.code;
  delete from redeem_claims where user_id = v_uid;
  delete from redeem_attempts where user_id = v_uid;

  -- The cloud save itself, or the next sync restores the character
  -- that was just deleted.
  delete from saves where user_id = v_uid;

  -- Arena: standing, the team others duelled, and anything owed.
  -- arena_standings is left alone: it is the record of a period that
  -- really happened, and settlement reads it.
  delete from arena_profiles where user_id = v_uid;
  delete from arena_rewards where user_id = v_uid;
  delete from arena_shop_buys where user_id = v_uid;

  -- Leaderboards.
  delete from dungeon_scores where user_id = v_uid;
  delete from fallen_god_scores where user_id = v_uid;

  -- Titles the character earned. The ones given to the person stay.
  delete from player_titles
  where user_id = v_uid
    and title not in ('tester_alpha', 'tester_beta', 'founding');

  -- The public face goes back to a fresh cultivator.
  update profiles set
    realm = 0,
    highest_stage = 1,
    power = 0,
    title = '',
    titles = '[]'::jsonb,
    showcase = '{}'::jsonb,
    flags = 0,
    flagged = false,
    updated_at = now()
  where id = v_uid;

  return json_build_object('ok', true, 'error', '');
end $$;

revoke all on function public.reset_my_character() from public, anon;
grant execute on function public.reset_my_character() to authenticated;
