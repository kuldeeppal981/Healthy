-- Applied to the live database (migration "pro_interest"). Counts people interested in Pro.
create table if not exists public.pro_interest (
  user_id uuid primary key references auth.users(id) on delete cascade,
  plan text, price text, feature text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table public.pro_interest enable row level security;
-- RPC set_pro_interest(p_plan, p_price, p_feature): upsert for auth.uid(), authenticated only.
-- Read: select count(*) from pro_interest; select plan, price, feature, count(*) from pro_interest group by 1,2,3;
