-- Social part 2: groups, invites (codes), group challenges, accountability partner,
-- weekly league, buddy matching. All access through SECURITY DEFINER RPCs; tables have RLS and no policies.

create table if not exists public.groups (
  id uuid primary key default gen_random_uuid(),
  owner uuid not null references auth.users(id) on delete cascade,
  name text not null check (char_length(name) between 2 and 40),
  code text not null unique,
  created_at timestamptz not null default now()
);
create table if not exists public.group_members (
  group_id uuid not null references public.groups(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  joined_at timestamptz not null default now(),
  primary key (group_id, user_id)
);
create table if not exists public.partners (
  a uuid not null references auth.users(id) on delete cascade,   -- requester
  b uuid not null references auth.users(id) on delete cascade,
  status text not null default 'pending' check (status in ('pending','active')),
  created_at timestamptz not null default now(),
  primary key (a, b)
);
create table if not exists public.buddy_profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  goal text not null,
  level text not null default 'any',
  slot text not null default 'any',
  looking boolean not null default true,
  updated_at timestamptz not null default now()
);
alter table public.challenges add column if not exists group_id uuid references public.groups(id) on delete cascade;

alter table public.groups enable row level security;
alter table public.group_members enable row level security;
alter table public.partners enable row level security;
alter table public.buddy_profiles enable row level security;

create or replace function public.is_group_member(p_group uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists(select 1 from public.group_members where group_id = p_group and user_id = auth.uid());
$$;

-- ---------- groups ----------
create or replace function public.create_group(p_name text) returns table(id uuid, code text)
language plpgsql security definer set search_path = public as $$
declare me uuid := auth.uid(); c text; gid uuid; n int;
begin
  if me is null then raise exception 'auth'; end if;
  if not exists(select 1 from social_profiles where user_id = me) then raise exception 'no_profile'; end if;
  select count(*) into n from groups where owner = me;
  if n >= 5 then raise exception 'too_many'; end if;
  loop
    c := upper(substr(md5(random()::text || clock_timestamp()::text), 1, 6));
    exit when not exists(select 1 from groups g where g.code = c);
  end loop;
  insert into groups(owner, name, code) values (me, trim(p_name), c) returning groups.id into gid;
  insert into group_members(group_id, user_id) values (gid, me);
  return query select gid, c;
end $$;

create or replace function public.join_group(p_code text) returns text
language plpgsql security definer set search_path = public as $$
declare me uuid := auth.uid(); g record; n int;
begin
  if me is null then return 'auth'; end if;
  if not exists(select 1 from social_profiles where user_id = me) then return 'no_profile'; end if;
  select * into g from groups where code = upper(trim(p_code));
  if not found then return 'not_found'; end if;
  if exists(select 1 from blocks b where (b.blocker = g.owner and b.blocked = me) or (b.blocker = me and b.blocked = g.owner)) then return 'not_found'; end if;
  if exists(select 1 from group_members where group_id = g.id and user_id = me) then return 'already'; end if;
  select count(*) into n from group_members where group_id = g.id;
  if n >= 30 then return 'full'; end if;
  insert into group_members(group_id, user_id) values (g.id, me);
  return 'ok';
end $$;

create or replace function public.leave_group(p_group uuid) returns void
language plpgsql security definer set search_path = public as $$
declare me uuid := auth.uid(); o uuid; nxt uuid;
begin
  delete from group_members where group_id = p_group and user_id = me;
  select owner into o from groups where id = p_group;
  if o = me then
    select user_id into nxt from group_members where group_id = p_group order by joined_at limit 1;
    if nxt is null then delete from groups where id = p_group;
    else update groups set owner = nxt where id = p_group; end if;
  end if;
end $$;

create or replace function public.my_groups() returns table(id uuid, name text, code text, members int, is_owner boolean)
language sql stable security definer set search_path = public as $$
  select g.id, g.name, g.code, (select count(*)::int from group_members m where m.group_id = g.id), g.owner = auth.uid()
  from groups g where exists(select 1 from group_members x where x.group_id = g.id and x.user_id = auth.uid())
  order by g.created_at;
$$;

-- ---------- weekly league (points from last 7 days) ----------
-- points per day: 20 if a workout, 5 if food logged, 2 per 1000 steps (max 20000)
create or replace function public._league_points(p_users uuid[], p_today date)
returns table(user_id uuid, name text, points int, workouts int, steps int, is_me boolean)
language sql stable security definer set search_path = public as $$
  select u.uid, coalesce(sp.name, 'Friend'),
    coalesce(sum((case when d.workouts > 0 then 20 else 0 end) + (case when d.logged then 5 else 0 end) + (least(d.steps, 20000) / 1000) * 2), 0)::int,
    coalesce(sum(d.workouts), 0)::int, coalesce(sum(d.steps), 0)::int, u.uid = auth.uid()
  from unnest(p_users) as u(uid)
  left join social_profiles sp on sp.user_id = u.uid
  left join daily_stats d on d.user_id = u.uid and d.day > p_today - 7 and d.day <= p_today
  group by u.uid, sp.name
  order by 3 desc, 5 desc;
$$;
revoke all on function public._league_points(uuid[], date) from public, anon, authenticated;

create or replace function public.weekly_league(p_today date)
returns table(user_id uuid, name text, points int, workouts int, steps int, is_me boolean)
language sql stable security definer set search_path = public as $$
  select * from public._league_points(
    array(
      select auth.uid()
      union
      select case when f.a = auth.uid() then f.b else f.a end
      from friendships f
      where f.status = 'accepted' and auth.uid() in (f.a, f.b)
        and not exists(select 1 from blocks b where (b.blocker = f.a and b.blocked = f.b) or (b.blocker = f.b and b.blocked = f.a))
        and not exists(select 1 from blocks b where b.blocker = auth.uid() and b.mute and b.blocked = case when f.a = auth.uid() then f.b else f.a end)
        and not exists(select 1 from social_profiles q where q.user_id = case when f.a = auth.uid() then f.b else f.a end and q.private_profile)
    ), p_today);
$$;

create or replace function public.group_league(p_group uuid, p_today date)
returns table(user_id uuid, name text, points int, workouts int, steps int, is_me boolean)
language plpgsql stable security definer set search_path = public as $$
begin
  if not is_group_member(p_group) then return; end if;
  return query select * from public._league_points(
    array(select m.user_id from group_members m where m.group_id = p_group
          and not exists(select 1 from blocks b where (b.blocker = auth.uid() and b.blocked = m.user_id) or (b.blocker = m.user_id and b.blocked = auth.uid()))), p_today);
end $$;

-- ---------- group challenges ----------
create or replace function public.create_group_challenge(p_group uuid, p_name text, p_kind text, p_start date, p_end date)
returns table(id uuid, code text)
language plpgsql security definer set search_path = public as $$
declare me uuid := auth.uid(); c text; cid uuid;
begin
  if not is_group_member(p_group) then raise exception 'not_member'; end if;
  if p_kind not in ('steps','workouts','transform') then raise exception 'kind'; end if;
  loop
    c := upper(substr(md5(random()::text || clock_timestamp()::text), 1, 6));
    exit when not exists(select 1 from challenges x where x.code = c);
  end loop;
  insert into challenges(creator, name, kind, start_day, end_day, code, group_id)
  values (me, trim(p_name), p_kind, p_start, p_end, c, p_group) returning challenges.id into cid;
  insert into challenge_members(challenge_id, user_id) values (cid, me);
  return query select cid, c;
end $$;

create or replace function public.group_challenges(p_group uuid)
returns table(id uuid, name text, kind text, start_day date, end_day date, joined boolean)
language sql stable security definer set search_path = public as $$
  select c.id, c.name, c.kind, c.start_day, c.end_day,
    exists(select 1 from challenge_members m where m.challenge_id = c.id and m.user_id = auth.uid())
  from challenges c where c.group_id = p_group and is_group_member(p_group)
  order by c.end_day desc;
$$;

create or replace function public.join_group_challenge(p_cid uuid) returns text
language plpgsql security definer set search_path = public as $$
declare g uuid;
begin
  select group_id into g from challenges where id = p_cid;
  if g is null or not is_group_member(g) then return 'not_found'; end if;
  insert into challenge_members(challenge_id, user_id) values (p_cid, auth.uid()) on conflict do nothing;
  return 'ok';
end $$;

-- ---------- accountability partner ----------
create or replace function public.request_partner(p_user uuid) returns text
language plpgsql security definer set search_path = public as $$
declare me uuid := auth.uid();
begin
  if me is null or p_user = me then return 'not_found'; end if;
  if not is_friend(p_user) then return 'not_friends'; end if;
  if exists(select 1 from partners where status = 'active' and me in (a, b)) then return 'have_partner'; end if;
  if exists(select 1 from partners where status = 'active' and p_user in (a, b)) then return 'they_have_partner'; end if;
  delete from partners where status = 'pending' and a = me;
  insert into partners(a, b, status) values (me, p_user, 'pending') on conflict (a, b) do update set status = 'pending', created_at = now();
  return 'ok';
end $$;

create or replace function public.respond_partner(p_user uuid, p_accept boolean) returns text
language plpgsql security definer set search_path = public as $$
declare me uuid := auth.uid();
begin
  if not exists(select 1 from partners where a = p_user and b = me and status = 'pending') then return 'not_found'; end if;
  if p_accept then
    if exists(select 1 from partners where status = 'active' and (me in (a, b) or p_user in (a, b))) then return 'have_partner'; end if;
    update partners set status = 'active' where a = p_user and b = me;
    delete from partners where status = 'pending' and (a in (me, p_user) or b in (me, p_user));
    return 'ok';
  end if;
  delete from partners where a = p_user and b = me and status = 'pending';
  return 'declined';
end $$;

create or replace function public.end_partner() returns void
language sql security definer set search_path = public as $$
  delete from partners where auth.uid() in (a, b);
$$;

-- one row: my partner (active) or pending incoming/outgoing, with their last 7 days
create or replace function public.my_partner(p_today date)
returns table(other uuid, name text, status text, incoming boolean, logged_today boolean, workout_today boolean, steps_today int, active_days_7 int, my_active_days_7 int)
language sql stable security definer set search_path = public as $$
  select o.uid, coalesce(sp.name, 'Partner'), p.status, (p.b = auth.uid() and p.status = 'pending'),
    coalesce((select d.logged from daily_stats d where d.user_id = o.uid and d.day = p_today), false),
    coalesce((select d.workouts > 0 from daily_stats d where d.user_id = o.uid and d.day = p_today), false),
    coalesce((select d.steps from daily_stats d where d.user_id = o.uid and d.day = p_today), 0),
    (select count(*)::int from daily_stats d where d.user_id = o.uid and d.day > p_today - 7 and d.day <= p_today and (d.logged or d.workouts > 0)),
    (select count(*)::int from daily_stats d where d.user_id = auth.uid() and d.day > p_today - 7 and d.day <= p_today and (d.logged or d.workouts > 0))
  from partners p
  cross join lateral (select case when p.a = auth.uid() then p.b else p.a end as uid) o
  left join social_profiles sp on sp.user_id = o.uid
  where auth.uid() in (p.a, p.b)
    and is_friend(o.uid)
  order by (p.status = 'active') desc
  limit 1;
$$;

-- ---------- buddy matching (opt in) ----------
create or replace function public.set_buddy_profile(p_goal text, p_level text, p_slot text, p_looking boolean) returns void
language sql security definer set search_path = public as $$
  insert into buddy_profiles(user_id, goal, level, slot, looking, updated_at)
  values (auth.uid(), p_goal, p_level, p_slot, p_looking, now())
  on conflict (user_id) do update set goal = excluded.goal, level = excluded.level, slot = excluded.slot, looking = excluded.looking, updated_at = now();
$$;

create or replace function public.get_buddy_profile() returns table(goal text, level text, slot text, looking boolean)
language sql stable security definer set search_path = public as $$
  select goal, level, slot, looking from buddy_profiles where user_id = auth.uid();
$$;

create or replace function public.find_buddies() returns table(user_id uuid, name text, goal text, level text, slot text, score int)
language sql stable security definer set search_path = public as $$
  select b.user_id, sp.name, b.goal, b.level, b.slot,
    ((b.goal = m.goal)::int * 3 + (b.level = m.level or b.level = 'any' or m.level = 'any')::int * 2 + (b.slot = m.slot or b.slot = 'any' or m.slot = 'any')::int)
  from buddy_profiles m
  join buddy_profiles b on b.user_id <> m.user_id and b.looking
  join social_profiles sp on sp.user_id = b.user_id and sp.discoverable and not sp.private_profile
  where m.user_id = auth.uid() and m.looking
    and b.goal = m.goal
    and not exists(select 1 from blocks x where (x.blocker = auth.uid() and x.blocked = b.user_id) or (x.blocker = b.user_id and x.blocked = auth.uid()))
    and not exists(select 1 from friendships f where (f.a = auth.uid() and f.b = b.user_id) or (f.b = auth.uid() and f.a = b.user_id))
  order by 6 desc, b.updated_at desc
  limit 20;
$$;

-- cleanup when a user disables social: drop partner/group rows via cascade on account delete; leaving is manual.

do $$ declare f text; begin
  foreach f in array array[
    'is_group_member(uuid)','create_group(text)','join_group(text)','leave_group(uuid)','my_groups()',
    'weekly_league(date)','group_league(uuid,date)','create_group_challenge(uuid,text,text,date,date)',
    'group_challenges(uuid)','join_group_challenge(uuid)','request_partner(uuid)','respond_partner(uuid,boolean)',
    'end_partner()','my_partner(date)','set_buddy_profile(text,text,text,boolean)','get_buddy_profile()','find_buddies()']
  loop
    execute format('revoke all on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
end $$;
