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
Source: `supabase/functions/coach/index.ts`. Modes: chat (`messages`, `context`) and `estimate`
(`items` -> nutrition JSON). Gemini model from `GEMINI_MODEL` (default gemini-2.5-flash), daily limit from
`COACH_DAILY_LIMIT` (default 10, day boundary in IST). Secret `GEMINI_API_KEY` must be set in the
Supabase dashboard (not yet set at the time of writing).
