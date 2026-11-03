-- Push notifications (Firebase Cloud Messaging). Run once in the Supabase SQL editor.
-- Nothing to edit: the shared password is generated here and stored in the vault;
-- the edge function reads it through get_push_secret() (service role only).

create extension if not exists pg_net with schema extensions;

create table if not exists public.device_tokens (
  token text primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  updated_at timestamptz not null default now()
);
create index if not exists device_tokens_user_idx on public.device_tokens(user_id);
alter table public.device_tokens enable row level security;
-- No policies: the app only uses the RPCs below, the edge function uses the service role.

create or replace function public.register_device_token(p_token text)
returns void language sql security definer set search_path = public as $$
  insert into device_tokens(token, user_id) values (p_token, auth.uid())
  on conflict (token) do update set user_id = auth.uid(), updated_at = now();
$$;

create or replace function public.unregister_device_token(p_token text)
returns void language sql security definer set search_path = public as $$
  delete from device_tokens where token = p_token and user_id = auth.uid();
$$;

revoke all on function public.register_device_token(text), public.unregister_device_token(text) from public, anon;
grant execute on function public.register_device_token(text), public.unregister_device_token(text) to authenticated;

-- Secret shared with the edge function (generated here, kept in the vault, not in code).
select vault.create_secret(replace(gen_random_uuid()::text || gen_random_uuid()::text, '-', ''), 'push_secret')
where not exists (select 1 from vault.secrets where name = 'push_secret');

create or replace function public.get_push_secret()
returns text language sql security definer set search_path = public as $$
  select decrypted_secret from vault.decrypted_secrets where name = 'push_secret' limit 1;
$$;
revoke all on function public.get_push_secret() from public, anon, authenticated;
grant execute on function public.get_push_secret() to service_role;

create or replace function public.notify_push(p_user uuid, p_title text, p_body text)
returns void language plpgsql security definer set search_path = public, extensions as $$
declare s text;
begin
  select decrypted_secret into s from vault.decrypted_secrets where name = 'push_secret' limit 1;
  if s is null or p_user is null then return; end if;
  perform net.http_post(
    url := 'https://rofxxebtjrmtrulbkexi.supabase.co/functions/v1/push',
    headers := jsonb_build_object('Content-Type', 'application/json', 'x-push-secret', s),
    body := jsonb_build_object('user_id', p_user, 'title', p_title, 'body', p_body)
  );
exception when others then
  null; -- a push problem must never block the real action
end $$;
revoke all on function public.notify_push(uuid, text, text) from public, anon, authenticated;

-- Friend request / accepted.
create or replace function public.trg_push_friendship() returns trigger
language plpgsql security definer set search_path = public as $$
declare nm text;
begin
  if tg_op = 'INSERT' and new.status = 'pending' then
    select coalesce(name, 'Someone') into nm from social_profiles where user_id = new.a;
    perform notify_push(new.b, 'New friend request', coalesce(nm, 'Someone') || ' wants to be your friend.');
  elsif tg_op = 'UPDATE' and new.status = 'accepted' and old.status is distinct from 'accepted' then
    select coalesce(name, 'Someone') into nm from social_profiles where user_id = new.b;
    perform notify_push(new.a, 'Friend request accepted', coalesce(nm, 'Someone') || ' is now your friend.');
  end if;
  return new;
end $$;
drop trigger if exists push_friendship on public.friendships;
create trigger push_friendship after insert or update on public.friendships
  for each row execute function public.trg_push_friendship();

-- Cheers on a post.
create or replace function public.trg_push_cheer() returns trigger
language plpgsql security definer set search_path = public as $$
declare owner uuid; nm text;
begin
  select user_id into owner from feed_posts where id = new.post_id;
  if owner is null or owner = new.user_id then return new; end if;
  select coalesce(name, 'A friend') into nm from social_profiles where user_id = new.user_id;
  perform notify_push(owner, 'New cheer', coalesce(nm, 'A friend') || ' cheered your post ' || coalesce(new.emoji, ''));
  return new;
end $$;
drop trigger if exists push_cheer on public.feed_reactions;
create trigger push_cheer after insert on public.feed_reactions
  for each row execute function public.trg_push_cheer();
