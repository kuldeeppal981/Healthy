-- Run this once in Supabase: SQL Editor -> New query -> paste -> Run.
--
-- One row per user. "data" holds that user's whole app snapshot (profile,
-- diary, weights, workouts, allergies, targets) as JSON. Row Level Security
-- makes sure a signed-in user can only ever read or change their own row.

create table if not exists public.user_data (
  user_id    uuid primary key references auth.users (id) on delete cascade,
  data       jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

alter table public.user_data enable row level security;

drop policy if exists "user_data select own" on public.user_data;
create policy "user_data select own"
  on public.user_data for select
  using (auth.uid() = user_id);

drop policy if exists "user_data insert own" on public.user_data;
create policy "user_data insert own"
  on public.user_data for insert
  with check (auth.uid() = user_id);

drop policy if exists "user_data update own" on public.user_data;
create policy "user_data update own"
  on public.user_data for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "user_data delete own" on public.user_data;
create policy "user_data delete own"
  on public.user_data for delete
  using (auth.uid() = user_id);
