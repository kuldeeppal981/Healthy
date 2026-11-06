-- Social safety: block, mute, report, private profile, activity status (opt-in).
-- Paste this whole file into the Supabase SQL editor and run it once.
-- It is safe to run again.

alter table public.social_profiles add column if not exists private_profile boolean not null default false;
alter table public.social_profiles add column if not exists show_activity boolean not null default false;
alter table public.social_profiles add column if not exists last_active timestamptz;

create table if not exists public.blocks (
  blocker uuid not null references auth.users(id) on delete cascade,
  blocked uuid not null references auth.users(id) on delete cascade,
  mute boolean not null default false,
  created_at timestamptz not null default now(),
  primary key (blocker, blocked)
);
alter table public.blocks enable row level security;

create table if not exists public.reports (
  id uuid primary key default gen_random_uuid(),
  reporter uuid not null references auth.users(id) on delete cascade,
  reported uuid not null references auth.users(id) on delete cascade,
  post_id uuid,
  reason text,
  created_at timestamptz not null default now()
);
alter table public.reports enable row level security;
-- No policies on purpose: only the functions below (and you, in the dashboard) can touch these tables.

-- ---------- helpers ----------
create or replace function public.is_blocked_pair(p_other uuid)
returns boolean language sql stable security definer set search_path to 'public' as $$
  select exists (
    select 1 from public.blocks b
    where not b.mute
      and ((b.blocker = auth.uid() and b.blocked = p_other) or (b.blocker = p_other and b.blocked = auth.uid()))
  );
$$;

create or replace function public.is_muted(p_other uuid)
returns boolean language sql stable security definer set search_path to 'public' as $$
  select exists (select 1 from public.blocks b where b.blocker = auth.uid() and b.blocked = p_other);
$$;

-- Blocked people are no longer friends in any check.
create or replace function public.are_friends(u uuid)
returns boolean language sql stable security definer set search_path to 'public' as $$
  select exists(select 1 from public.friendships f where f.status = 'accepted'
    and ((f.a = auth.uid() and f.b = u) or (f.b = auth.uid() and f.a = u)))
    and not public.is_blocked_pair(u);
$$;

create or replace function public.is_friend(p_other uuid)
returns boolean language sql stable security definer set search_path to 'public' as $$
  select exists (
    select 1 from public.friendships f
    where f.status = 'accepted'
      and ((f.a = auth.uid() and f.b = p_other) or (f.b = auth.uid() and f.a = p_other))
  ) and not public.is_blocked_pair(p_other);
$$;

-- ---------- feed and board: hide muted people and private profiles ----------
create or replace function public.get_feed(p_limit integer default 50)
returns table(id uuid, user_id uuid, name text, kind text, title text, body text, created_at timestamptz,
              is_me boolean, my_reaction text, fire integer, clap integer, muscle integer, heart integer)
language sql stable security definer set search_path to 'public' as $$
  select p.id, p.user_id, coalesce(sp.name, 'Friend'), p.kind, p.title, p.body,
         p.created_at, p.user_id = auth.uid(),
         (select r.emoji from feed_reactions r where r.post_id = p.id and r.user_id = auth.uid()),
         (select count(*)::int from feed_reactions r where r.post_id = p.id and r.emoji = 'fire'),
         (select count(*)::int from feed_reactions r where r.post_id = p.id and r.emoji = 'clap'),
         (select count(*)::int from feed_reactions r where r.post_id = p.id and r.emoji = 'muscle'),
         (select count(*)::int from feed_reactions r where r.post_id = p.id and r.emoji = 'heart')
  from feed_posts p
  left join social_profiles sp on sp.user_id = p.user_id
  where auth.uid() is not null
    and (p.user_id = auth.uid()
         or (public.is_friend(p.user_id)
             and not public.is_muted(p.user_id)
             and not coalesce(sp.private_profile, false)))
    and p.created_at > now() - interval '30 days'
  order by p.created_at desc
  limit least(greatest(p_limit, 1), 100);
$$;

create or replace function public.friends_board(p_today date)
returns table(user_id uuid, name text, steps_today integer, steps_week integer, workout_days_30 integer,
              workout_streak integer, food_streak integer, is_me boolean)
language sql stable security definer set search_path to 'public' as $$
with ppl as (
  select auth.uid() as uid
  union
  select x.o from (
    select case when f.a = auth.uid() then f.b else f.a end as o
    from public.friendships f where f.status = 'accepted' and auth.uid() in (f.a, f.b)
  ) x
  where not public.is_muted(x.o)
    and not exists (select 1 from public.social_profiles q where q.user_id = x.o and q.private_profile)
),
w as (select s.user_id as uid, s.day, s.day - (row_number() over (partition by s.user_id order by s.day))::int as grp from public.daily_stats s where s.workouts > 0 and s.user_id in (select uid from ppl) and s.day > p_today - 120 and s.day <= p_today),
ws as (select uid, count(*) as len, max(day) as last_day from w group by uid, grp),
l as (select s.user_id as uid, s.day, s.day - (row_number() over (partition by s.user_id order by s.day))::int as grp from public.daily_stats s where s.logged and s.user_id in (select uid from ppl) and s.day > p_today - 120 and s.day <= p_today),
ls as (select uid, count(*) as len, max(day) as last_day from l group by uid, grp)
select p.uid, sp.name,
  coalesce((select d.steps from public.daily_stats d where d.user_id = p.uid and d.day = p_today), 0)::int,
  coalesce((select sum(d.steps) from public.daily_stats d where d.user_id = p.uid and d.day > p_today - 7 and d.day <= p_today), 0)::int,
  coalesce((select count(*) from public.daily_stats d where d.user_id = p.uid and d.workouts > 0 and d.day > p_today - 30 and d.day <= p_today), 0)::int,
  coalesce((select max(len) from ws where ws.uid = p.uid and ws.last_day >= p_today - 1), 0)::int,
  coalesce((select max(len) from ls where ls.uid = p.uid and ls.last_day >= p_today - 1), 0)::int,
  p.uid = auth.uid()
from ppl p left join public.social_profiles sp on sp.user_id = p.uid;
$$;

-- ---------- search and suggestions: skip blocked and private ----------
create or replace function public.search_people(p_q text)
returns table(user_id uuid, name text, tag text)
language sql stable security definer set search_path to 'public' as $$
select sp.user_id, sp.name, right(sp.code, 3)
from public.social_profiles sp
where length(trim(p_q)) >= 2
  and sp.discoverable
  and not sp.private_profile
  and sp.user_id <> auth.uid()
  and not public.is_blocked_pair(sp.user_id)
  and sp.name ilike '%' || replace(replace(trim(p_q), '%', ''), '_', '') || '%'
  and not exists (select 1 from public.friendships f where (f.a = auth.uid() and f.b = sp.user_id) or (f.b = auth.uid() and f.a = sp.user_id))
order by sp.name
limit 20;
$$;

create or replace function public.suggested_people()
returns table(user_id uuid, name text, tag text)
language sql stable security definer set search_path to 'public' as $$
select sp.user_id, sp.name, right(sp.code, 3)
from public.social_profiles sp
where sp.discoverable
  and not sp.private_profile
  and sp.user_id <> auth.uid()
  and not public.is_blocked_pair(sp.user_id)
  and exists (select 1 from public.social_profiles me where me.user_id = auth.uid())
  and not exists (select 1 from public.friendships f where (f.a = auth.uid() and f.b = sp.user_id) or (f.b = auth.uid() and f.a = sp.user_id))
order by random()
limit 10;
$$;

-- ---------- friend requests: refuse when blocked ----------
create or replace function public.request_friend(p_code text)
returns text language plpgsql security definer set search_path to 'public' as $$
declare t uuid; me uuid := auth.uid();
begin
  if me is null then raise exception 'not signed in'; end if;
  if not exists(select 1 from public.social_profiles where user_id = me) then return 'no_profile'; end if;
  select user_id into t from public.social_profiles where code = upper(trim(p_code));
  if t is null then return 'not_found'; end if;
  if t = me then return 'self'; end if;
  if public.is_blocked_pair(t) then return 'not_found'; end if;
  if exists(select 1 from public.friendships where a = t and b = me) then
    update public.friendships set status = 'accepted' where a = t and b = me;
    return 'accepted';
  end if;
  if exists(select 1 from public.friendships where a = me and b = t) then return 'exists'; end if;
  insert into public.friendships(a, b) values (me, t);
  return 'sent';
end $$;

create or replace function public.request_friend_id(p_user uuid)
returns text language plpgsql security definer set search_path to 'public' as $$
declare me uuid := auth.uid();
begin
  if me is null then raise exception 'not signed in'; end if;
  if not exists(select 1 from public.social_profiles where user_id = me) then return 'no_profile'; end if;
  if p_user = me then return 'self'; end if;
  if public.is_blocked_pair(p_user) then return 'not_found'; end if;
  if exists(select 1 from public.friendships where a = p_user and b = me) then
    update public.friendships set status = 'accepted' where a = p_user and b = me;
    return 'accepted';
  end if;
  if exists(select 1 from public.friendships where a = me and b = p_user) then return 'exists'; end if;
  if not exists(select 1 from public.social_profiles where user_id = p_user and discoverable and not private_profile) then return 'not_found'; end if;
  insert into public.friendships(a, b) values (me, p_user);
  return 'sent';
end $$;

-- ---------- block, mute, report ----------
create or replace function public.block_user(p_user uuid, p_mute boolean default false)
returns text language plpgsql security definer set search_path to 'public' as $$
declare me uuid := auth.uid();
begin
  if me is null or p_user is null or p_user = me then return 'invalid'; end if;
  insert into public.blocks(blocker, blocked, mute) values (me, p_user, coalesce(p_mute, false))
  on conflict (blocker, blocked) do update set mute = excluded.mute, created_at = now();
  if not coalesce(p_mute, false) then
    delete from public.friendships where (a = me and b = p_user) or (a = p_user and b = me);
  end if;
  return 'ok';
end $$;

create or replace function public.unblock_user(p_user uuid)
returns text language plpgsql security definer set search_path to 'public' as $$
begin
  if auth.uid() is null then return 'invalid'; end if;
  delete from public.blocks where blocker = auth.uid() and blocked = p_user;
  return 'ok';
end $$;

create or replace function public.my_blocks()
returns table(user_id uuid, name text, mute boolean)
language sql stable security definer set search_path to 'public' as $$
  select b.blocked, coalesce(sp.name, 'Someone'), b.mute
  from public.blocks b left join public.social_profiles sp on sp.user_id = b.blocked
  where b.blocker = auth.uid()
  order by b.created_at desc;
$$;

create or replace function public.report_user(p_user uuid, p_post uuid, p_reason text)
returns text language plpgsql security definer set search_path to 'public' as $$
declare me uuid := auth.uid();
begin
  if me is null or p_user is null or p_user = me then return 'invalid'; end if;
  if (select count(*) from public.reports where reporter = me and created_at > now() - interval '1 day') >= 10 then
    return 'limit';
  end if;
  insert into public.reports(reporter, reported, post_id, reason)
  values (me, p_user, p_post, left(coalesce(p_reason, ''), 300));
  return 'ok';
end $$;

-- ---------- private profile and activity status ----------
create or replace function public.set_privacy(p_private boolean, p_activity boolean)
returns text language plpgsql security definer set search_path to 'public' as $$
begin
  if auth.uid() is null then return 'invalid'; end if;
  update public.social_profiles
  set private_profile = coalesce(p_private, false),
      show_activity = coalesce(p_activity, false),
      discoverable = case when coalesce(p_private, false) then false else discoverable end,
      last_active = case when coalesce(p_activity, false) then now() else null end
  where user_id = auth.uid();
  return 'ok';
end $$;

create or replace function public.get_privacy()
returns table(private_profile boolean, show_activity boolean)
language sql stable security definer set search_path to 'public' as $$
  select sp.private_profile, sp.show_activity from public.social_profiles sp where sp.user_id = auth.uid();
$$;

create or replace function public.touch_activity()
returns void language sql security definer set search_path to 'public' as $$
  update public.social_profiles set last_active = now() where user_id = auth.uid() and show_activity;
$$;

-- Friends who chose to show it and were active in the last 10 minutes.
create or replace function public.friends_activity()
returns table(user_id uuid, last_active timestamptz)
language sql stable security definer set search_path to 'public' as $$
  select sp.user_id, sp.last_active
  from public.social_profiles sp
  where sp.show_activity and not sp.private_profile
    and sp.last_active > now() - interval '10 minutes'
    and public.is_friend(sp.user_id)
    and not public.is_muted(sp.user_id);
$$;

-- Only signed-in users may call the new functions.
revoke all on function public.is_blocked_pair(uuid), public.is_muted(uuid), public.block_user(uuid, boolean),
  public.unblock_user(uuid), public.my_blocks(), public.report_user(uuid, uuid, text),
  public.set_privacy(boolean, boolean), public.get_privacy(), public.touch_activity(),
  public.friends_activity() from public, anon;
grant execute on function public.is_blocked_pair(uuid), public.is_muted(uuid), public.block_user(uuid, boolean),
  public.unblock_user(uuid), public.my_blocks(), public.report_user(uuid, uuid, text),
  public.set_privacy(boolean, boolean), public.get_privacy(), public.touch_activity(),
  public.friends_activity() to authenticated;
