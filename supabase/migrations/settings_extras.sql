-- Applied to the live DB as "settings_extras": notification choices, feedback.
create table if not exists public.notif_prefs (
  user_id uuid primary key references auth.users(id) on delete cascade,
  friends boolean not null default true,
  cheers boolean not null default true,
  quiet_on boolean not null default false,
  quiet_from int not null default 1320,
  quiet_to int not null default 420,
  tz_min int not null default 330,
  updated_at timestamptz not null default now()
);
alter table public.notif_prefs enable row level security;
create table if not exists public.feedback (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  kind text not null default 'idea' check (kind in ('bug','idea','other')),
  message text not null check (char_length(message) between 5 and 1500),
  app_version text,
  created_at timestamptz not null default now()
);
alter table public.feedback enable row level security;
-- set_notif_prefs(p_friends, p_cheers, p_quiet_on, p_from, p_to, p_tz): upsert own row (minutes after midnight, tz offset minutes).
-- send_feedback(p_kind, p_message, p_version): max 5 per day, 5..1500 chars, returns ok/short/limit/auth.
-- notify_push(p_user, p_title, p_body): now skips cheers / friend requests+nudges when the receiver turned them off,
--   and everything during the receiver's quiet hours (local minute = utc minute + tz_min).
-- Full function bodies live in the database (see DATABASE.md).
