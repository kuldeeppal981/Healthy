# Roadmap and plans

Update this file when priorities change. Keep it honest: mark what is done.

## Product direction
Beat HealthifyMe by being free where they charge, safe for allergies, great for Indian food, and social
(friends feed, cheers, challenges). Weak spots to fix first: Indian food accuracy, progress visibility.

## Next up (suggested order)
0. **UI redesign follow-ups:** user's design screenshots were applied to Home, Workout, Profile, bottom nav
   (untested). Allergy tab redesigned too. Still old style: Scan screen, Onboarding, Auth, Coach, Social, Report, Badges
   screens. Photos from the design (food bowl, dumbbells, exercise thumbnails) need real image assets.
1. **Test everything on a real phone.** Voice logging, social with two accounts, feed + cheers,
   dark mode, check-in/freeze, exercise library, widget, alarm, Health Connect. Fix what breaks.
2. **Progress screen:** graphs of weight, waist, calories, PRs over time (retention booster).
3. **Indian food database depth:** more dishes, katori/roti/glass portions, thali, street food.
4. **Diet / meal plans:** by goal, veg/non-veg, calories.
5. **Engagement:** friend streak nudge ("send a punch"), weekly summary card, weekly league,
   small friend groups, PR share card, milestones, daily personal AI tip.
6. **Hindi** (and regional languages).
7. **Trust:** forgot password, account delete, data export, privacy policy.
8. **Ship:** app name and icon, Play Store listing.

## Backlog
- Photo to calories (AI), restore label scan with a build-safe approach
- Recipes, family profiles, premium plan (AI limit raise), tips/journey
- In-app exercise images or videos (needs licensed assets or the user's own files)
- Real push notifications via Firebase FCM (cheers, friend requests, reminders when app is closed)

## Needs the user (cannot be done from the sandbox)
- Supabase dashboard: add Edge Function secret `GEMINI_API_KEY` (key from aistudio.google.com/apikey);
  optional `GEMINI_MODEL`, `COACH_DAILY_LIMIT`
- Supabase: custom SMTP + edit the "Confirm sign up" email template to send the code (templates cannot
  be edited without custom SMTP)
- Google login: Google Cloud OAuth client + Supabase Google provider; redirect URL
  `io.supabase.healthy://login-callback/` in Supabase URL configuration
- Firebase project + `google-services.json` (only if we do real push)
- Test with two accounts: data isolation and friends

## Done (history)
Core diary, scan, allergies, workouts (v1) -> cloud accounts + sync -> custom plans, reminders, gym alarm
-> AI coach, steps, streaks/badges, widget -> voice logging, health conditions, monthly report + PDF,
Health Connect -> friends, leaderboard, challenges, share card (label scan parked after build failures)
-> name at sign up, friend search/suggestions, button-width bug fix, dark mode -> friend feed with PRs,
cheers + notifications -> daily check-in, streak freezes, XP/levels -> exercise library.
