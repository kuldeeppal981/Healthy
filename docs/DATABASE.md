# Database (Supabase project `rofxxebtjrmtrulbkexi`)

The live project is the source of truth. Inspect it with the Supabase MCP (`execute_sql`,
`list_tables`, `pg_get_functiondef`). Row Level Security is on for every table. After any change,
update this file. Keep `supabase/functions/coach/index.ts` in sync with the deployed function.

## Tables (public)
| Table | Purpose | Key columns |
|---|---|---|
| user_data | One JSON backup per user (all app data) | user_id, data jsonb, updated_at |
| ai_usage | AI requests per user per day | user_id, day, count |
| social_profiles | Opt-in social identity | user_id, name, code (6 chars), discoverable |
| friendships | Friend links | a (requester), b (receiver), status pending/accepted |
| daily_stats | Numbers shared with friends | user_id, day, steps, workouts, logged, goal_met |
| challenges | Challenges | id, creator, name, kind steps/workouts/transform, start_day, end_day, code |
| challenge_members | Members | challenge_id, user_id |
| feed_posts | Achievements | id, user_id, kind pr/workout/streak/badge/steps, title, body, dedupe (unique per user) |
| feed_reactions | Cheers | post_id, user_id, emoji fire/clap/muscle/heart (one per user per post) |

## Security model
- Users only read/write their own `user_data`, `ai_usage` (read), own `daily_stats` writes, own posts.
- Reading other people's data goes through helper functions: `are_friends`, `is_friend`,
  `shares_challenge`, `in_challenge`. `daily_stats` and `social_profiles` are readable by self, friends,
  and challenge mates.
- Feed posts are only readable through `get_feed` (self + accepted friends, last 30 days). Reactions are
  only written through `react_to_post`, which checks friendship.
- Functions are SECURITY DEFINER with `search_path = public`; execute is granted to `authenticated` only.
  The advisor warning "authenticated_security_definer_function_executable" is expected.
- `bump_ai_usage` is for the edge function (service role).

## Functions (RPC)
create_social_profile, request_friend (by code), request_friend_id (by user, needs discoverable),
search_people (name search, discoverable only), suggested_people, pending_requests, friends_board
(leaderboard numbers), create_challenge, join_challenge, challenge_board, get_feed, react_to_post,
get_cheers (reactions others gave to my posts), bump_ai_usage.

## Edge function `coach` (verify_jwt on)
Source: `supabase/functions/coach/index.ts` (deployed v11; label mode also accepts `text` from phone OCR). Modes: chat (`messages`, `context`), `estimate`
(`items` -> nutrition JSON) and `label` (`image` base64 JPEG + `mime` -> `label` JSON: ingredients, contains, may_contain, per100 values). Gemini model from `GEMINI_MODEL` (default gemini-3.8-flash), daily limit from
`COACH_DAILY_LIMIT` (default 10, day boundary in IST). Secret `GEMINI_API_KEY` must be set in the
Supabase dashboard (not yet set at the time of writing).

## Label product cache (migration `label_products_cache`)
Shared cache of products read from label photos, so the same product never needs the AI twice.
- `label_products` (text_hash unique = sha256 of the sorted unique words of the ingredient list, name, ingredients, contains[], may_contain[], serving_grams, per100 jsonb, seen_count) and `label_product_seen` (product_id, user_id). RLS on, NO policies: access only through the functions.
- `find_label_product(p_hash)` returns the product json (and records that this user saw it); `save_label_product(...)` inserts if new (first writer wins, no overwrite), records the user, clamps lengths. Both SECURITY DEFINER, authenticated only.
- Known weakness: first writer wins, so a wrong or malicious first save would be served to others. Idea for later: report button, delete entries reported by several users, trust only when seen_count >= 2.

## Plans (migration `user_plans`)
`user_plans(user_id pk, plan 'free'|'pro', expires_at, source, updated_at)`. RLS: users read only their own row, nobody writes from the app. `my_plan()` returns {plan, expires_at} with expiry applied. Grant Pro by hand: `insert into user_plans(user_id, plan, expires_at) values ('<uuid>', 'pro', now() + interval '30 days') on conflict (user_id) do update set plan='pro', expires_at=excluded.expires_at;`
Real purchases later: Google Play Billing (in_app_purchase or RevenueCat) -> an edge function verifies the purchase with the Play Developer API (or RevenueCat webhook) and writes this table. Needs a Play Console account first.

## delete_my_account() (SQL file only, NOT yet applied)
`supabase/migrations/delete_my_account.sql`: SECURITY DEFINER, deletes the caller from auth.users (all user tables cascade). Execute only for `authenticated`. Apply it, then remove this 'not applied' note.

## Push notifications (SQL file only, NOT yet applied)
`supabase/migrations/push_notifications.sql`: table `device_tokens(token pk, user_id, updated_at)` with RLS and no policies; RPCs `register_device_token`, `unregister_device_token` (authenticated); `notify_push(user, title, body)` (pg_net POST to edge function `push` with vault secret `push_secret`, read by the function via `get_push_secret()`, service_role only); triggers `push_friendship` on friendships and `push_cheer` on feed_reactions. Edge function `push` source: `supabase/functions/push/index.ts` (deployed v2, verify_jwt off).

## Friend nudge
`supabase/migrations/friend_nudge.sql` (user pastes in SQL editor): table `nudges` (RLS, no policies), RPC `send_nudge(p_user)` (authenticated; checks accepted friendship, 1 per friend per day, 10 per day, then `notify_push`). Returns ok / already_today / limit / not_friends.

## Edge function `report`
Source `supabase/functions/report/index.ts` (verify_jwt on, v1). Reads a medical report photo with Gemini and returns food guidance JSON. Uses the same `bump_ai_usage` daily limit and `user_plans` as `coach`. Needs the `GEMINI_API_KEY` secret. The `coach` function (v15) also has a `form` mode for exercise form photos.

## Social safety (applied to the live DB via MCP; source: `supabase/migrations/social_safety.sql`)
- `social_profiles` new columns: `private_profile`, `show_activity`, `last_active`.
- Tables `blocks(blocker, blocked, mute)` and `reports(id, reporter, reported, post_id, reason)`: RLS on, no policies (RPC only). The owner reads `reports` in the Supabase dashboard (no admin screen yet).
- Helpers `is_blocked_pair`, `is_muted`; `is_friend` / `are_friends` now return false for blocked pairs.
- Replaced: `get_feed`, `friends_board` (hide muted people and private profiles), `search_people`, `suggested_people` (skip blocked and private), `request_friend`, `request_friend_id` (refuse blocked pairs, return not_found).
- New RPCs (authenticated only): `block_user(p_user, p_mute)` (block also deletes the friendship), `unblock_user`, `my_blocks`, `report_user` (10 per day), `set_privacy(p_private, p_activity)` (private also turns discoverable off), `get_privacy`, `touch_activity`, `friends_activity` (friends who opted in, active in the last 10 min).

## Social part 2 (applied via MCP; source `supabase/migrations/social_part2.sql`)
Tables (RLS on, no policies, RPC only): `groups(id, owner, name, code)`, `group_members`, `partners(a requester, b, status pending/active)`, `buddy_profiles(user_id, goal, level, slot, looking)`. `challenges.group_id` added (group challenges).
RPCs (authenticated only): `create_group`, `join_group(code)` (max 30 members, 5 groups per owner), `leave_group` (owner passes to oldest member), `my_groups`, `weekly_league(p_today)` (me + accepted friends, hides blocked/muted/private), `group_league`, `create_group_challenge`, `group_challenges`, `join_group_challenge`, `request_partner`, `respond_partner`, `end_partner`, `my_partner`, `set_buddy_profile`, `get_buddy_profile`, `find_buddies` (same goal, opt-in, discoverable, not private, not blocked, not already friends).
League points (7 days): 20 per workout day, 5 per food-logged day, 2 per 1000 steps (cap 20000/day). Helper `_league_points` is not callable by clients.
Invite "links" are codes shared with the share sheet (real deep links need Play Store setup).
