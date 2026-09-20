-- =========================================================
-- Immortal Cultivation: Supabase setup, part 14 — CODE TITLES
-- Run after part 13: SQL Editor > New query ("14 - code titles")
-- > paste > Run. Safe to run again.
--
-- Lets a redeem code carry a title, which is how the tester titles
-- are handed out: you give alpha testers a code rather than keeping
-- a list of who they are.
--
-- The title is awarded server-side, into profiles.titles, so it
-- survives a wiped save and cannot be granted by editing one. The
-- code's other rewards work exactly as before.
--
--   insert into public.redeem_codes (code, rewards, max_uses, note)
--   values ('ALPHA2026',
--           '{"jade": 1000, "title": "tester_alpha"}'::jsonb,
--           50, 'Alpha testers');
--
-- The title id must be one Titles.LIST knows (see docs/titles.md);
-- anything else is ignored by the client.
-- =========================================================

create or replace function public.redeem_code(p_code text)
returns json language plpgsql security definer set search_path = public as $$
declare
  c redeem_codes%rowtype;
  v_code text := upper(btrim(coalesce(p_code, '')));
  v_recent int;
  v_title text;
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

  -- A "title" key awards the title as well as returning it, so the
  -- server holds it even if the client never applies anything.
  v_title := c.rewards ->> 'title';
  if coalesce(v_title, '') <> '' then
    perform award_title(auth.uid(), v_title);
  end if;

  return json_build_object('ok', true, 'error', '', 'code', c.code, 'rewards', c.rewards);
end $$;

revoke all on function public.redeem_code(text) from public, anon;
grant execute on function public.redeem_code(text) to authenticated;
