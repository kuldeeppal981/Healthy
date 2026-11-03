-- Friend nudge: send a push "X nudged you". Limits: 1 per friend per day, 10 per day total.
create table if not exists public.nudges (
  id bigserial primary key,
  sender uuid not null references auth.users(id) on delete cascade,
  receiver uuid not null references auth.users(id) on delete cascade,
  sent_at timestamptz not null default now()
);
alter table public.nudges enable row level security;  -- no policies: only the function below writes
create index if not exists nudges_sender_idx on public.nudges (sender, sent_at);

create or replace function public.send_nudge(p_user uuid) returns text
language plpgsql security definer set search_path = public as $$
declare me uuid := auth.uid(); nm text; ok boolean;
begin
  if me is null then return 'not_signed_in'; end if;
  select exists(select 1 from friendships
    where status = 'accepted' and ((a = me and b = p_user) or (a = p_user and b = me))) into ok;
  if not ok then return 'not_friends'; end if;
  if exists(select 1 from nudges where sender = me and receiver = p_user
            and sent_at > now() - interval '1 day') then return 'already_today'; end if;
  if (select count(*) from nudges where sender = me and sent_at > now() - interval '1 day') >= 10
    then return 'limit'; end if;
  insert into nudges(sender, receiver) values (me, p_user);
  select coalesce(name, 'A friend') into nm from social_profiles where user_id = me;
  perform notify_push(p_user, 'Nudge from ' || coalesce(nm, 'a friend'),
    'Time to log your meals or move a bit today!');
  return 'ok';
end $$;
revoke all on function public.send_nudge(uuid) from public, anon;
grant execute on function public.send_nudge(uuid) to authenticated;
