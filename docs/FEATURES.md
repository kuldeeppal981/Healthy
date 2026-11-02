# Features built so far

Status key: **untested** = written but never compiled or run (the sandbox has no Flutter).
Only the early core was confirmed running by the user (APK installs, Home screen shows).
Update this file whenever a feature is added or changed.

## UI (redesigned Nov 2026, untested)
New look from the user's design screenshots: lavender gradient background, soft-shadow rounded cards,
purple gradient buttons (`GradientButton`), `MenuCard`/`MenuRow` lists, floating scan button in the middle
of the bottom bar with an underline on the active tab (`theme.dart`, `screens/app_shell.dart`).
- **Home** (`screens/home_screen.dart`): greeting + avatar, Daily nutrition card (ring, goal, macros, Log food),
  Quick actions (Scan, Voice, Water, Weight), Steps + Water cards, Today's workout card, AI daily insight
  (rule-based tip, links to coach) + Your consistency card (`screens/streak_card.dart`: streak, level, XP,
  check-in), friends card. "Track your day" opens `screens/diary_screen.dart` (Today's meals list, Speak, tip).
- **Workout** (`screens/workout_screen.dart`): header, day chips with dates, gym alarm, purple banner
  (exercises and minutes), plan overview list (tap = exercise info, "Log sets" or Start = set logging mode),
  Pro Tip, Your Progress (workouts this week of plan days, kg lifted). The design showed exercise photos and
  a food photo; there are no image assets, so icons and gradients are used instead.
- **Allergy tab** (`screens/allergy_screen.dart`): redesigned from the user's screenshot: food photo tiles for the
  10 allergens, Food/Other tabs (Other = placeholder, no data model yet), one "How severe?" control that sets
  the level for all selected allergies, trace warning switch, Save Profile (data already saves instantly).
- **Images** (`assets/images/`, declared in pubspec): cropped and cut out from the user's design screenshots
  (food photos, shield, bowl, shoe, glass, dumbbell photo, 4 exercise thumbnails, shaker, trophy, muscle
  silhouette). Resolution is low (screenshot crops). Replace the files with originals of the same name to
  improve quality. Exercise thumbnails exist only for bench press, incline press, triceps pushdown, overhead
  triceps extension (mapping in `workout_screen.dart` `_photos`).
- **Profile** (`screens/profile_screen.dart`): gradient account card, weight + BMI card, appearance,
  menus for everything else (health conditions, reminders, badges, report, exercise library, Health Connect,
  friends, coach). Daily targets and "Delete all data" moved to `screens/settings_screen.dart` (gear icon).

## Food and nutrition
- Calorie diary by meal, macro targets, calorie ring (`screens/home_screen.dart`, `state/app_state.dart`)
- Barcode scan with Open Food Facts lookup + manual barcode entry (`screens/scan_screen.dart`, `services/food_service.dart`)
- Ingredient/label PHOTO scan (UNTESTED): `screens/label_photo_screen.dart` + `services/label_ai.dart` send the photo to edge function `coach` (mode `label`, Gemini vision, counts as 1 daily AI request), build a FoodItem(fromLabel) and open ScanResultScreen (allergy warnings, health flags, add to diary). Needs GEMINI_API_KEY secret.
- Manual food add, Indian foods list (`data/indian_foods.dart`, `widgets/add_food_sheet.dart`)
- Water counter and reminders
- Voice logging: speak "2 roti aur dal", parsed by `voice_parser.dart`, nutrition estimated by the AI
  edge function (`mode: estimate`), reviewed in `widgets/voice_review.dart` (untested)
- Targets from profile (`services/nutrition_calc.dart`)

## Allergy and health
- Allergen matching incl. hidden ingredient names, may-contain traces, severity levels; never says "safe"
  when ingredient data is missing (`services/allergy_checker.dart`, `screens/allergy_screen.dart`)
- Health condition mode, e.g. diabetes/BP guidance (`services/health_conditions.dart`, `screens/health_screen.dart`) (untested)
- Health Connect: steps, heart rate, sleep, exercise (`services/health_service.dart`, `screens/health_connect_screen.dart`) (untested)
- Weight log

## Workout
- Day-wise plan Mon-Sun (`screens/workout_data.dart`), user can edit any day (`screens/plan_editor.dart`)
- Set logging kg x reps, 90 s rest timer, history, best set per exercise saved in `WorkoutLog.bests`
- Voice set logging "bench press 40 kilo 8 reps"
- Daily gym alarm (full-screen/insistent notification) and meal/water/workout reminders
  (`services/reminder_service.dart`, `screens/reminders_screen.dart`) (untested)
- Personal records: a PR is a heavier set (or same weight, more reps) than anything logged before;
  first time logging an exercise is not a PR (`findNewPrs` in `services/social_service.dart`)
- Exercise library: 39 exercises with muscles, equipment, steps, mistakes, beginner/intermediate/advanced
  variations, filters, YouTube search button for a video demo; "?" button in the workout screen
  (`data/exercise_library.dart`, `screens/exercise_library_screen.dart`). No in-app images or videos.

## Steps, widget
- Phone step sensor (`services/step_service.dart`), steps screen, goal
- Android home screen widget (`services/widget_service.dart`; native files are created by the workflow)

## Habits and rewards
- Daily check-in, daily streak (check-in OR food log OR workout), 2 streak freezes per month used
  automatically when exactly one day is missed (`state/app_state.dart`, `screens/streak_card.dart`)
- XP and levels (Beginner, Mover Lv3, Fit Lv5, Athlete Lv8, Beast Lv12, Legend Lv18), computed from data,
  not stored (`services/levels.dart`). Level n needs 50*n*(n-1) XP.
- Food-log streak and 15 badges (`services/badges.dart`, `screens/badges_screen.dart`)

## Account and cloud
- Email + password sign up with name, email code verification, sign in, guest mode, Google sign-in code
  (Google setup not done) (`screens/auth_screen.dart`, `services/cloud_sync.dart`)
- Profile photo (picked from gallery, stored on this phone only, `services/avatar_service.dart`) and editable
  display name (`AppState.profileName`, synced; also updates the account name and the friends name),
  edited from the avatar/pencil in Profile (`widgets/edit_identity.dart`). Photo is not shared with friends yet.
- Per-user cloud backup/sync of all app data (Supabase `user_data`), merge on login
- Dark mode: Auto/Light/Dark in Profile (`services/theme_service.dart`)

## Social (needs account + "turn on friends")
- Social profile with name + friend code, find people by name, "People you may know", add by code,
  requests, discoverable switch (`services/social_service.dart`, `screens/social_screen.dart`)
- Leaderboard: steps today / 7 days, workout streak, food streak, workouts in 30 days
- Challenges: steps, workout days, 30-day transformation, join by code
- **Feed**: posts for PRs, finished workouts, level-ups, streak milestones; reactions fire/clap/muscle/heart;
  "My personal records"; "Share my achievements" switch
- **Cheers**: reactions on your posts show in "Cheers for you", an unread badge on the Home card, and a
  local phone notification. The app polls every 90 s **only while the app process is alive**; there is no
  real push (needs Firebase FCM).
- Share progress card as image (`widgets/share_card.dart`)

## AI
- AI coach chat via the `coach` edge function (Gemini), 10 free requests/day per user
  (`screens/coach_screen.dart`). **Not usable until the `GEMINI_API_KEY` secret is added in Supabase.**

## Reports
- Monthly report with totals, protein consistency, weight change, PRs, and PDF export
  (`services/report.dart`, `report_pdf.dart`, `screens/report_screen.dart`) (untested)

## Parked or unused
- Label scan (photo of nutrition label): `parked/label_scan_screen.dart`, `services/label_parser.dart`.
  Removed because ML Kit broke the release build (R8 missing classes). Needs a different approach.

- Muscle Volume Analyzer (UNTESTED): `screens/muscle_screen.dart` (Profile -> Muscle volume). Donut + bars of completed sets per Chest/Back/Shoulders/Biceps/Triceps/Legs/Core for last 7 or 30 days. `WorkoutLog.muscleSets` is saved at finish (`muscleOf()` in `data/exercise_library.dart`); workouts before this change have no muscle data. Custom exercises not in the library are not counted.

- Scan button now opens the ingredient PHOTO scan first (`ScanScreen` -> `LabelPhotoScreen`); barcode scanner is `BarcodeScanScreen` (button 'Scan barcode instead'). If a barcode is not found, the result screen offers photo scan or manual add. UNTESTED.

- Hybrid label scan (UNTESTED, ML Kit build risk): `services/label_ai.dart` runs on-device OCR (google_mlkit_text_recognition, latin) -> ingredient fingerprint -> `find_label_product` (shared cache) -> else `coach` label mode with the OCR TEXT (photo only if OCR failed) -> `save_label_product`. If the build fails because of ML Kit, remove `google_mlkit_text_recognition` from pubspec and the `_ocr` method (always return '') and the rest still works via photo -> AI.

- Healthy Pro groundwork (UNTESTED): `screens/pro_screen.dart` (Profile -> Healthy Pro, Free vs Pro table, honest 'coming soon' button), `services/plan_service.dart` (reads `my_plan()`). Server side: table `user_plans` (RLS read-own, no client writes) + `my_plan()`; edge function `coach` v12 gives Pro users `COACH_PRO_DAILY_LIMIT` (default 60) instead of 10. NO real purchase yet.

- UI polish pass (UNTESTED): `widgets/ui_kit.dart` (Space, Haptic, EmptyState, ErrorCard, Skeleton/SkeletonList, CountUp, AppImage). Onboarding, Auth, Coach, Badges, Report, Scan, Scan result, Friends restyled with AppBackground/AppCard/GradientButton and empty/error/skeleton states. Calorie ring animates (`widgets/ring.dart`), badges pop in, streak numbers count up. Haptics on water add, check-in, workout set done. Text size setting (Normal/Large/Extra) in Profile -> Appearance (`ThemeService.textScale`, applied in `main.dart` via MediaQuery).
- Dark mode is STILL the colour-filter trick. Improvement: all asset pictures use `AppImage` and the profile photo uses `undoDark`, so photos keep real colours. A real dark theme needs AppColors to stop being `static const` (about 385 uses in 31 files, many inside const widgets), which is risky without a compiler. Do it only when the app can be built and tested step by step (e.g. one screen per commit).

- App icon + notification icon (UNTESTED): workflow step 'Add app icon and notification icon' writes vector drawables (white heart `ic_notification`, adaptive launcher icon with purple gradient + white heart). `reminder_service.dart` uses `ic_notification`. Before this the app used the default Flutter icon, which looks like a white square in the status bar. Replace the heart with a real logo later (needs a final app name and logo).
- User-chosen accent colour: NOT built. Same blocker as real dark mode (AppColors are `static const`). A hue-rotate filter was rejected because it would also recolour the red/green/orange warning colours (allergy safety).

- Green theme + white look (UNTESTED; AppBackground is now white with a green glow at the top, thinner card borders, lighter shadow): the whole palette in `lib/theme.dart` changed from purple to green on white (primary #16A34A, light #4ADE80, ink #0F1222, card white, soft green tints), same `static const` names so no screen code changed. Also changed: avatar icon, allergy chip, share card, PDF report colour, home-widget colours and launcher icon gradient (in the workflow). The calorie/streak accent `AppColors.ring` stays orange, muscle chart colours unchanged. Design reference: the Design canvas 'Healthy new look' (green row, plus a black and white option B row).
- Colour picker in settings: STILL NOT built (see above). Plan: step 1 make a few accent colours non-const (primary, primaryLight, primaryDeep, link, chipBg, chipInk) and fix const errors screen by screen; step 2 Profile -> Theme colour with Green, Indigo, Orange, Pink, Blue, Teal; step 3 real dark mode.
