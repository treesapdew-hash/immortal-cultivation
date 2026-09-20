-- =========================================================
-- Immortal Cultivation: Supabase setup, part 2 — SECTS
-- Run once after part 1: SQL Editor > New query ("02 - sects") >
-- paste > Run. Safe to run again.
--
-- Players can READ sects, members, their own requests and their
-- sect's chat, but can't write to these tables directly: every
-- action goes through a function below, which checks the rules
-- (one sect per player, roles, member limits...) on the server.
-- =========================================================

-- ---------------------------------------------------------
-- TABLES
-- ---------------------------------------------------------
create table if not exists public.sects (
  id uuid primary key default gen_random_uuid(),
  name text not null unique check (char_length(name) between 2 and 16),
  notice text not null default '' check (char_length(notice) <= 200),
  emblem int not null default 0,
  join_mode text not null default 'open' check (join_mode in ('open', 'approval')),
  min_realm int not null default 0,
  level int not null default 1,
  exp bigint not null default 0,
  leader_id uuid references public.profiles (id) on delete set null,
  member_count int not null default 0,
  created_at timestamptz not null default now()
);

-- One sect per player: user_id is the primary key
create table if not exists public.sect_members (
  user_id uuid primary key references public.profiles (id) on delete cascade,
  sect_id uuid not null references public.sects (id) on delete cascade,
  role text not null default 'member' check (role in ('leader', 'elder', 'member')),
  contribution bigint not null default 0,
  joined_at timestamptz not null default now()
);
create index if not exists sect_members_sect_idx on public.sect_members (sect_id);

create table if not exists public.sect_requests (
  sect_id uuid not null references public.sects (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (sect_id, user_id)
);

create table if not exists public.sect_messages (
  id bigint generated always as identity primary key,
  sect_id uuid not null references public.sects (id) on delete cascade,
  user_id uuid references public.profiles (id) on delete set null,
  name text not null,
  body text not null check (char_length(body) between 1 and 200),
  created_at timestamptz not null default now()
);
create index if not exists sect_messages_sect_idx on public.sect_messages (sect_id, id desc);

-- ---------------------------------------------------------
-- HELPERS
-- ---------------------------------------------------------
-- Max members for a sect level: 20, +5 per level, up to 50
create or replace function public.sect_capacity(p_level int) returns int
language sql immutable as $$ select least(50, 20 + 5 * (p_level - 1)) $$;

-- The caller's sect id (or null)
create or replace function public.my_sect_id() returns uuid
language sql stable security definer set search_path = public as $$
  select sect_id from sect_members where user_id = auth.uid()
$$;

-- The caller's role in their sect (or null)
create or replace function public.my_sect_role() returns text
language sql stable security definer set search_path = public as $$
  select role from sect_members where user_id = auth.uid()
$$;

-- ---------------------------------------------------------
-- ROW LEVEL SECURITY: reading
-- ---------------------------------------------------------
alter table public.sects enable row level security;
alter table public.sect_members enable row level security;
alter table public.sect_requests enable row level security;
alter table public.sect_messages enable row level security;

drop policy if exists "sects readable" on public.sects;
create policy "sects readable" on public.sects for select to authenticated using (true);

drop policy if exists "members readable" on public.sect_members;
create policy "members readable" on public.sect_members for select to authenticated using (true);

-- Your own requests, and the requests to your sect if you're leader/elder
drop policy if exists "requests readable" on public.sect_requests;
create policy "requests readable" on public.sect_requests for select to authenticated
  using (user_id = (select auth.uid())
    or (sect_id = public.my_sect_id() and public.my_sect_role() in ('leader', 'elder')));

-- Chat: members of that sect only
drop policy if exists "chat readable by members" on public.sect_messages;
create policy "chat readable by members" on public.sect_messages for select to authenticated
  using (sect_id = public.my_sect_id());

-- ---------------------------------------------------------
-- ACTIONS (the only way to change sect data)
-- ---------------------------------------------------------

create or replace function public.create_sect(p_name text, p_notice text default '',
    p_join_mode text default 'open', p_min_realm int default 0)
returns uuid language plpgsql security definer set search_path = public as $$
declare
  v_id uuid;
  v_name text := btrim(p_name);
begin
  if auth.uid() is null then raise exception 'Not signed in'; end if;
  if exists (select 1 from sect_members where user_id = auth.uid()) then
    raise exception 'You are already in a sect';
  end if;
  if not exists (select 1 from profiles where id = auth.uid()) then
    raise exception 'Profile not found, try again in a moment';
  end if;
  if char_length(v_name) < 2 or char_length(v_name) > 16 then
    raise exception 'Sect names need 2 to 16 characters';
  end if;
  if exists (select 1 from sects where lower(name) = lower(v_name)) then
    raise exception 'That sect name is taken';
  end if;
  insert into sects (name, notice, join_mode, min_realm, leader_id, member_count)
    values (v_name, left(coalesce(p_notice, ''), 200),
            case when p_join_mode = 'approval' then 'approval' else 'open' end,
            greatest(0, coalesce(p_min_realm, 0)), auth.uid(), 1)
    returning id into v_id;
  insert into sect_members (user_id, sect_id, role) values (auth.uid(), v_id, 'leader');
  delete from sect_requests where user_id = auth.uid();
  return v_id;
end $$;

-- Open sects: join straight away. Approval sects: send a request.
create or replace function public.join_sect(p_sect uuid)
returns text language plpgsql security definer set search_path = public as $$
declare
  s sects%rowtype;
  v_realm int;
begin
  if auth.uid() is null then raise exception 'Not signed in'; end if;
  if exists (select 1 from sect_members where user_id = auth.uid()) then
    raise exception 'You are already in a sect';
  end if;
  select * into s from sects where id = p_sect for update;
  if not found then raise exception 'Sect not found'; end if;
  select realm into v_realm from profiles where id = auth.uid();
  if coalesce(v_realm, 0) < s.min_realm then
    raise exception 'Your realm is too low for this sect';
  end if;
  if s.member_count >= sect_capacity(s.level) then
    raise exception 'This sect is full';
  end if;
  if s.join_mode = 'approval' then
    insert into sect_requests (sect_id, user_id) values (p_sect, auth.uid())
      on conflict do nothing;
    return 'applied';
  end if;
  insert into sect_members (user_id, sect_id, role) values (auth.uid(), p_sect, 'member');
  update sects set member_count = member_count + 1 where id = p_sect;
  delete from sect_requests where user_id = auth.uid();
  return 'joined';
end $$;

create or replace function public.cancel_request(p_sect uuid)
returns void language sql security definer set search_path = public as $$
  delete from sect_requests where sect_id = p_sect and user_id = auth.uid()
$$;

-- Leader / elders accept or reject a request
create or replace function public.review_request(p_user uuid, p_accept boolean)
returns text language plpgsql security definer set search_path = public as $$
declare
  v_sect uuid := my_sect_id();
  s sects%rowtype;
begin
  if my_sect_role() not in ('leader', 'elder') then raise exception 'Only the leader or elders can do that'; end if;
  if not exists (select 1 from sect_requests where sect_id = v_sect and user_id = p_user) then
    raise exception 'That request is gone';
  end if;
  delete from sect_requests where sect_id = v_sect and user_id = p_user;
  if not p_accept then return 'rejected'; end if;
  if exists (select 1 from sect_members where user_id = p_user) then
    return 'already in a sect';
  end if;
  select * into s from sects where id = v_sect for update;
  if s.member_count >= sect_capacity(s.level) then raise exception 'The sect is full'; end if;
  insert into sect_members (user_id, sect_id, role) values (p_user, v_sect, 'member');
  update sects set member_count = member_count + 1 where id = v_sect;
  delete from sect_requests where user_id = p_user;
  return 'accepted';
end $$;

-- Leave. A leader must hand over leadership first, unless they're alone
-- (then the sect is disbanded).
create or replace function public.leave_sect()
returns text language plpgsql security definer set search_path = public as $$
declare
  v_sect uuid := my_sect_id();
  v_role text := my_sect_role();
  v_count int;
begin
  if v_sect is null then raise exception 'You are not in a sect'; end if;
  select member_count into v_count from sects where id = v_sect for update;
  if v_role = 'leader' then
    if v_count > 1 then raise exception 'Pass leadership to someone else first'; end if;
    delete from sects where id = v_sect;
    return 'disbanded';
  end if;
  delete from sect_members where user_id = auth.uid();
  update sects set member_count = member_count - 1 where id = v_sect;
  return 'left';
end $$;

-- Leader can remove anyone; elders can remove ordinary members
create or replace function public.kick_member(p_user uuid)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_sect uuid := my_sect_id();
  v_role text := my_sect_role();
  v_target text;
begin
  select role into v_target from sect_members where user_id = p_user and sect_id = v_sect;
  if v_target is null then raise exception 'Not a member of your sect'; end if;
  if p_user = auth.uid() then raise exception 'Use Leave instead'; end if;
  if not (v_role = 'leader' or (v_role = 'elder' and v_target = 'member')) then
    raise exception 'You can''t remove that member';
  end if;
  delete from sect_members where user_id = p_user;
  update sects set member_count = member_count - 1 where id = v_sect;
end $$;

-- Leader only: make elder (max 4), back to member, or hand over leadership
create or replace function public.set_member_role(p_user uuid, p_role text)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_sect uuid := my_sect_id();
begin
  if my_sect_role() <> 'leader' then raise exception 'Only the leader can do that'; end if;
  if not exists (select 1 from sect_members where user_id = p_user and sect_id = v_sect) then
    raise exception 'Not a member of your sect';
  end if;
  if p_user = auth.uid() then raise exception 'Choose another member'; end if;
  if p_role = 'leader' then
    update sect_members set role = 'elder' where user_id = auth.uid();
    update sect_members set role = 'leader' where user_id = p_user;
    update sects set leader_id = p_user where id = v_sect;
  elsif p_role = 'elder' then
    if (select count(*) from sect_members where sect_id = v_sect and role = 'elder') >= 4 then
      raise exception 'A sect can have at most 4 elders';
    end if;
    update sect_members set role = 'elder' where user_id = p_user;
  elsif p_role = 'member' then
    update sect_members set role = 'member' where user_id = p_user;
  else
    raise exception 'Unknown role';
  end if;
end $$;

-- Leader / elders edit the notice and joining rules
create or replace function public.update_sect(p_notice text, p_join_mode text, p_min_realm int)
returns void language plpgsql security definer set search_path = public as $$
begin
  if my_sect_role() not in ('leader', 'elder') then raise exception 'Only the leader or elders can do that'; end if;
  update sects set
    notice = left(coalesce(p_notice, ''), 200),
    join_mode = case when p_join_mode = 'approval' then 'approval' else 'open' end,
    min_realm = greatest(0, coalesce(p_min_realm, 0))
  where id = my_sect_id();
end $$;

-- Sect chat
create or replace function public.send_sect_message(p_body text)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_sect uuid := my_sect_id();
  v_name text;
  v_body text := btrim(p_body);
begin
  if v_sect is null then raise exception 'You are not in a sect'; end if;
  if char_length(v_body) < 1 or char_length(v_body) > 200 then raise exception 'Messages need 1 to 200 characters'; end if;
  select display_name into v_name from profiles where id = auth.uid();
  insert into sect_messages (sect_id, user_id, name, body)
    values (v_sect, auth.uid(), coalesce(v_name, 'Cultivator'), v_body);
end $$;

-- ---------------------------------------------------------
-- ACCESS: read the tables, call the actions. Signed-in only.
-- ---------------------------------------------------------
grant select on public.sects, public.sect_members, public.sect_requests, public.sect_messages to authenticated;

revoke all on function public.sect_capacity(int) from public, anon;
revoke all on function public.my_sect_id() from public, anon;
revoke all on function public.my_sect_role() from public, anon;
revoke all on function public.create_sect(text, text, text, int) from public, anon;
revoke all on function public.join_sect(uuid) from public, anon;
revoke all on function public.cancel_request(uuid) from public, anon;
revoke all on function public.review_request(uuid, boolean) from public, anon;
revoke all on function public.leave_sect() from public, anon;
revoke all on function public.kick_member(uuid) from public, anon;
revoke all on function public.set_member_role(uuid, text) from public, anon;
revoke all on function public.update_sect(text, text, int) from public, anon;
revoke all on function public.send_sect_message(text) from public, anon;

grant execute on function public.sect_capacity(int) to authenticated;
grant execute on function public.my_sect_id() to authenticated;
grant execute on function public.my_sect_role() to authenticated;
grant execute on function public.create_sect(text, text, text, int) to authenticated;
grant execute on function public.join_sect(uuid) to authenticated;
grant execute on function public.cancel_request(uuid) to authenticated;
grant execute on function public.review_request(uuid, boolean) to authenticated;
grant execute on function public.leave_sect() to authenticated;
grant execute on function public.kick_member(uuid) to authenticated;
grant execute on function public.set_member_role(uuid, text) to authenticated;
grant execute on function public.update_sect(text, text, int) to authenticated;
grant execute on function public.send_sect_message(text) to authenticated;
