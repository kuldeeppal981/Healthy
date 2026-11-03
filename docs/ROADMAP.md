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
4. **Diet / meal plans:** budget planner BUILT (see FEATURES). Still to do: shopping list, swap a food, more foods and regional menus, health-condition filters.
5. **Engagement:** friend nudge (BUILT), weekly summary card, weekly league,
   small friend groups, PR share card, milestones, daily personal AI tip.
6. **Hindi** (and regional languages).
7. **Trust:** forgot password, account delete, privacy policy are built (untested, see FEATURES); data export still missing.
8. **Ship:** app name and icon, Play Store listing.

## Backlog
- Photo to calories of a meal (AI). Label photo scan is DONE via Gemini (see FEATURES), old ML Kit version stays parked
- Recipes, family profiles, premium plan (AI limit raise), tips/journey
- In-app exercise images or videos (needs licensed assets or the user's own files)
- Real push notifications via Firebase FCM: DONE (see FEATURES)

## Needs the user (cannot be done from the sandbox)
- Push setup: Firebase project + Android app `com.kuldeep.healthy_app`; GitHub secrets FIREBASE_API_KEY, FIREBASE_APP_ID, FIREBASE_SENDER_ID, FIREBASE_PROJECT_ID; Supabase secrets FIREBASE_SERVICE_ACCOUNT; run `supabase/migrations/push_notifications.sql` (nothing to edit).
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

- Idea: muscle heat-map body figure (needs body artwork), weekly set targets per muscle, trends over weeks.

## Hybrid label scan (OCR -> database -> AI): BUILT, untested (see FEATURES). Remaining: barcode saving, report button, Hindi OCR.
Flow: on-device OCR (google_mlkit_text_recognition, free; English first, Hindi labels fall back to image->AI) -> normalise ingredient text -> hash -> look up shared Supabase table -> hit: instant result, no AI -> miss: send TEXT (not photo) to `coach` label mode -> save result for everyone.
Also: barcode path = our DB first, then Open Food Facts, then photo scan; offer "scan barcode too" after an AI read so the product is saved by barcode.
Safety: label saved data "AI-read"; treat as confirmed only when 2 different users' results match; store text only (no photos/user info); writes only through a SECURITY DEFINER RPC; allergy warning always shown.
Risk: ML Kit broke the release build before (R8). Add it as its own commit so it can be reverted; keep image->AI path working.
Also: ingredient -> allergen dictionary table grown from AI answers to make allergy_checker smarter.

- Pro: real payments (Play Billing + server verification), Pro-only features (AI diet plan, meal photo calories, deep analytics), free trial. Pro limit 60 AI/day is only a guess, check real AI cost per user first.

- Real dark theme (replace the filter): make AppColors theme-aware without breaking const widgets. Plan: add `AppColors.of(context)` for new/edited screens first, migrate screen by screen.
- Still old style: parts of Friends tabs inside, Allergy sub-dialogs, Reminders, Settings, Health Connect screens. Use ui_kit helpers.

- (picker done, untested) Food illustrations for food/empty states from the design canvas. Needs AppColors accent colours to become non-const; do after the green build is confirmed. Optional black-and-white premium option exists in the design canvas.
