-- =========================================================
-- Immortal Cultivation: Supabase setup, part 16 — SECT TITLES
-- Run after part 15: SQL Editor > New query ("16 - sect titles")
-- > paste > Run. Safe to run again.
--
-- The four sect titles, worked out from membership rather than
-- handed out.
--
-- Awarding them would have meant a call in join_sect, review_request,
-- set_member_role, leave_sect and kick_member, and a matching
-- revoke in each - five places to keep in step, and a promotion
-- missed anywhere would leave someone wearing a rank they had lost.
-- Reading the answer from sect_members instead means there is only
-- ever one truth, and it is the membership table.
--
-- They still carry a clock, renewed on every sync, so someone who
-- stops playing loses the rank rather than holding it forever.
-- =========================================================

create or replace function public.my_titles()
returns json language sql stable security definer set search_path = public as $$
  with stored as (
    -- Awarded and kept: placements, tester codes, Founding.
    select t.title as id,
           coalesce(extract(epoch from t.expires_at)::bigint, 0) as expires
    from player_titles t
    where t.user_id = auth.uid()
      and (t.expires_at is null or t.expires_at > now())
  ),
  me as (
    select m.sect_id, m.role
    from sect_members m
    where m.user_id = auth.uid()
  ),
  derived as (
    -- In a sect at all.
    select 'sect_disciple' as id,
           extract(epoch from now() + interval '30 days')::bigint as expires
    from me
    union all
    select 'sect_elder', extract(epoch from now() + interval '30 days')::bigint
    from me where role = 'elder'
    union all
    -- The table calls the top rank 'leader'; the title reads Sect Master.
    select 'sect_master', extract(epoch from now() + interval '30 days')::bigint
    from me where role = 'leader'
    union all
    -- Most might into the Sect Trial this week, among their sect.
    -- Compared against the same `week` value their own row carries,
    -- so this does not need to know how the week is worked out.
    select 'sect_vanguard', extract(epoch from now() + interval '7 days')::bigint
    from sect_trial_damage d
    join me on me.sect_id = d.sect_id
    where d.user_id = auth.uid()
      and d.might > 0
      and d.might = (select max(d2.might) from sect_trial_damage d2
                     where d2.sect_id = d.sect_id and d2.week = d.week)
  ),
  -- A title can be both stored and derived. Kept-for-good wins over
  -- any clock; otherwise the later expiry does.
  final as (
    select id,
           case when bool_or(expires = 0) then 0 else max(expires) end as expires
    from (select * from stored union all select * from derived) u
    group by id
  )
  select coalesce(json_agg(json_build_object(
      'id', final.id, 'expires', final.expires)), '[]'::json)
  from final
$$;

revoke all on function public.my_titles() from public, anon;
grant execute on function public.my_titles() to authenticated;
