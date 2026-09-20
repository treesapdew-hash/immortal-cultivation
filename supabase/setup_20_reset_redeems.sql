-- =========================================================
-- Immortal Cultivation: Supabase setup, part 20 — RESET REDEEMS
-- Run after part 19: SQL Editor > New query ("20 - reset redeems")
-- > paste > Run. Safe to run again.
--
-- Settings has a "Reset account" that wipes the save but keeps the
-- Supabase account, so redeem claims survived it: a player who
-- started over could never use their welcome code again. Deleting
-- the account outright was always fine, because the claims cascade
-- with the profile; it was only this path.
--
-- Not a way to farm a code: a reset destroys every partner, stage
-- and item the player had. Nobody comes out ahead.
-- =========================================================

create or replace function public.reset_my_redeems()
returns json language plpgsql security definer set search_path = public as $$
declare
  v_freed int := 0;
begin
  if auth.uid() is null then
    return json_build_object('ok', false, 'error', 'Not signed in');
  end if;

  -- Hand the uses back first, while the claims still say which codes
  -- to credit. Without this a limited code would be counted twice
  -- against one player who started over.
  update redeem_codes c
    set uses = greatest(0, c.uses - 1)
  from redeem_claims r
  where r.user_id = auth.uid() and r.code = c.code;

  delete from redeem_claims where user_id = auth.uid();
  get diagnostics v_freed = row_count;

  -- The wrong-code throttle goes too, or a fresh start could begin
  -- already most of the way to being locked out for an hour.
  delete from redeem_attempts where user_id = auth.uid();

  return json_build_object('ok', true, 'error', '', 'freed', v_freed);
end $$;

revoke all on function public.reset_my_redeems() from public, anon;
grant execute on function public.reset_my_redeems() to authenticated;
