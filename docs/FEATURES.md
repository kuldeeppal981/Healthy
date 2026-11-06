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
- Theme colour picker (UNTESTED): Profile -> Appearance -> Theme colour (Green default, Indigo, Orange, Pink, Blue, Teal, Black). `AccentPalette`/`accentPalettes` in `services/theme_service.dart`, saved as 'accent'. The 10 accent colours in `AppColors` became getters; a script removed `const` from 76 widget usages. `main.dart` keys MaterialApp by accent index so the whole app rebuilds (returns to Home). If the build reports 'not a constant expression', just remove that `const`. Real dark theme is still the colour filter.
- (old note) Colour picker plan: Plan: step 1 make a few accent colours non-const (primary, primaryLight, primaryDeep, link, chipBg, chipInk) and fix const errors screen by screen; step 2 Profile -> Theme colour with Green, Indigo, Orange, Pink, Blue, Teal; step 3 real dark mode.

- Diary meal cards have a coloured icon tile per meal (`_mealTile` in `diary_screen.dart`).
- Food drawings (UNTESTED): `widgets/food_art.dart` (`FoodArt`, CustomPainter: bowl, thali, chai, apple, picked by food name keywords). Used in the Diary meal tiles and next to matching food entries. More drawings can be added as new `FoodKind` values.
- Redesign round 2 (UNTESTED, after the green build was confirmed by the user): Home quick actions are round gradient icon buttons; amber protein tip card with drawn apple (`_proteinTip`, shows after 12:00 when protein is under 50% of target); photo scan screen has the `ScanFrame` viewfinder illustration (`widgets/scan_frame.dart`). Allergy keeps its food photo tiles, Workout keeps its photos. Remaining differences from the design canvas are layout details; ask the user for screenshots of screens that look off.
- Trust features (UNTESTED): Forgot password on the sign-in screen (`CloudSync.sendPasswordReset`, email link opens the app through the deep link, `AppShell` listens for `passwordRecovery` and shows a 'Set a new password' dialog); Settings -> Privacy policy (`screens/privacy_screen.dart`, plain text, review before the Play Store) and Settings -> Delete account (rpc `delete_my_account`, then clears the phone). The SQL is in `supabase/migrations/delete_my_account.sql`. The migration tool was cancelled twice from the sandbox, so the USER must run that SQL once in the Supabase SQL editor; until then Delete account shows 'Could not delete the account'. For the reset link: the redirect URL `io.supabase.healthy://login-callback/` must be allowed in Supabase URL configuration (same as Google login).
- Redesign round 3 (UNTESTED): 6 more food drawings in `widgets/food_art.dart` (roti, egg, samosa, dosa, paneer, rice) with keyword matching, also shown next to the food name on the scan result; `EmptyState` has softer double circle and an optional `art` widget; workout exercises without a photo get a `MuscleTile` (`widgets/muscle_art.dart`, coloured by muscle with its name; `muscleColor()` has the chart colours); page transitions use Zoom on Android (`buildTheme`).
- NOT done on purpose: real dark theme. Dark mode is still the colour filter, which works and is user-tested. A real dark theme needs ink/card/muted/etc. to become getters AND many hardcoded `Colors.white` fills replaced; doing that blind could make dark mode worse. Do it with screenshots, screen by screen.
- REAL layout redesign (UNTESTED, matches the design canvas): bottom bar now 5 tabs Home, Diary, Workout, Allergy, Profile (`app_shell.dart`; the floating scan button is gone, Scan is in Home quick actions and in the Diary header). Diary is a TAB (`diary_screen.dart`, StatefulWidget): last 7 days strip (tap a day to view it, `AppState.entriesOn`), Eaten/Protein/Carbs/Fat bar, meal cards with drawn icons, + / mic / scan buttons only for today. Home: greeting + name header, new nutrition card (Calories left, ring with %, three macro chips). Tab indexes: 0 Home, 1 Diary, 2 Workout, 3 Allergy, 4 Profile. Old 'Log food' button on the Home card is removed (use Diary + or Voice).
- Layout redesign round 2 (UNTESTED): Allergy = shield badge header + 3-column photo tiles with check badge; Profile = stat tiles row (streak, best streak, badges) under the account card; Workout = 'Workout' title with Edit plan, soft day chips, banner shows Today + plan title + exercises/minutes. Account card, Appearance, menus unchanged.
- Charts restyled (UNTESTED): `GradientBar` (`widgets/ui_kit.dart`, animated gradient progress bar) replaces plain LinearProgressIndicator on Home (steps/water), Steps, Streak and Muscle screens; muscle donut animates with round caps and gaps; `Sparkline` (weight) is now a smooth curve with soft fill, guide lines, min/max labels and an animated draw.
- Appearance (Auto/Light/Dark, Theme colour, Text size) moved from Profile to Settings (gear icon on Profile). Profile account card now has a drawn backdrop (`_BackdropPainter`: soft circles, leaf, shine) instead of the low-res hero.png.

## Push notifications via Firebase (BUILT, UNTESTED, needs user setup)
- `lib/services/push_service.dart`: starts Firebase from `--dart-define` values (`FIREBASE_API_KEY/APP_ID/SENDER_ID/PROJECT_ID`, see `config.dart`, `pushEnabled`), no google-services.json / gradle plugin. Asks permission, saves the FCM token with rpc `register_device_token`, refreshes on token change and on login, `unregister_device_token` on sign out. Foreground messages are shown with `ReminderService.showNow`.
- Server: `supabase/migrations/push_notifications.sql` (NOT applied; user must edit the secret and run it): `device_tokens` table (RLS, no policies), register/unregister RPCs, `notify_push()` via pg_net with vault secret `push_secret`, triggers for friend request, friend accepted, cheer. Edge function `push` (v2, verify_jwt off, checks `x-push-secret`, signs service-account JWT, calls FCM v1, removes dead tokens). Needs Supabase secret `FIREBASE_SERVICE_ACCOUNT`; the shared password is generated by the SQL into the vault (`get_push_secret()`), no PUSH_SECRET env needed.
- Workflow passes the four Firebase secrets and patches manifest meta-data for the default notification icon.
- Risk: new packages firebase_core/firebase_messaging may break the build or need a newer minSdk/Kotlin; read the Actions log.

## Budget diet planner (BUILT, UNTESTED)
- Profile -> "Budget diet plan" (`lib/screens/budget_plan_screen.dart`). User sets a daily rupee budget (Rs 80-500 slider), food type (veg / veg+egg / non-veg) and a price level (small town 0.8x, normal, big city 1.25x). Targets come from `AppState.kcalTarget` / `proteinTarget` (already follow the goal), allergies from `AppState.allergies`.
- `lib/services/budget_planner.dart`: rule-based, no AI, no internet. Random search per meal (500 tries) scoring calorie fit, protein shortfall, budget and repeats; 7 days, each avoiding the previous day's foods; tightens the budget up to 4 times if the day is over. Shows warnings: budget too low, calories low, protein low, no safe food for a meal.
- `lib/data/budget_foods.dart`: ~37 foods with APPROXIMATE home-cooking prices (Rs per serving), roles (staple/main/side/snack), allergens. Prices need a review and should be refreshed yearly.
- "Add to today's diary" per meal writes DiaryEntry rows. Budget, food type and price level are saved in SharedPreferences only (keys `bp_*`, not synced to the cloud).
- Next ideas: shopping list for the week, swap one food, health-condition filters, more regional foods, editable prices.

## Dark mode picture fix (UNTESTED)
Shoe, glass, hero, shaker, bowl and shield PNGs had a framed pale panel baked in, which showed as white boxes in dark mode (and the hero was purple). Replaced by painted widgets in `lib/widgets/activity_art.dart` (ShoeArt, GlassArt, DumbbellArt, ShakerArt) and removed those files. Allergy PNGs and trophy were cleaned of a faint haze. Remaining photos (dumbbell.jpg, ex1-4.jpg) still keep real colours in dark mode. A real dark theme (instead of the global colour filter) is still on the roadmap.

## Analytics tab + new Muscle volume look + Allergy moved (BUILT, UNTESTED)
- Bottom tabs now: Home, Diary, Workout, **Analytics**, Profile. The Allergy screen moved to Profile -> "Allergies" (`AllergyPage` wrapper in `allergy_screen.dart`; the tab body `AllergyScreen` is unchanged).
- `lib/screens/analytics_screen.dart`: 7 / 30 day range. Tiles (avg kcal, days on target, workouts), bar charts for calories, protein, workouts, steps, water (`lib/widgets/bar_chart.dart`: animated rounded bars, dashed goal line, last bar strongest), a carbs/protein/fat split bar, weight line (`Sparkline`), and the muscle section. "Days on target" = 80% to 110% of the kcal goal. Averages ignore days with nothing logged.
- Muscle volume: `lib/widgets/muscle_activity.dart` draws front and back body figures in code (no picture files), muscles coloured by status (high volume blue, trained green, needs attention orange, not trained grey), tap a muscle for details, list, balance tip. Status rule in `muscleStatus()`: share >= 25% high; under 3 sets or under 8% needs attention. `lib/services/muscle_stats.dart` computes sets, volume, workouts. `MuscleScreen` (Profile -> Muscle volume) reuses the same section.
- Body figure artwork: `lib/data/body_paths.dart`, converted from the MIT-licensed npm package react-native-body-highlighter (male front/back) into move/line/curve numbers (arcs became cubics). Licence text is registered in `main.dart` (LicenseRegistry) and shown under Settings -> Open source licences. Mapping from artwork slugs to our 7 muscle groups is `_slugGroup` in `muscle_activity.dart`; forearms, neck, hands, feet stay grey. A female variant exists in the same package if wanted.

## Real dark theme (BUILT, UNTESTED)
The global invert/hue ColorFilter is gone. `ThemeService.dark` + `darkVariantOf(palette)` give a real dark palette; `AppColors` surface, text and accent colours are getters, `buildTheme()` is brightness-aware, `HealthApp` listens to phone brightness and rebuilds (key `accent-dark`). A script dropped `const` in 38 files; if the build says 'not a constant expression', remove that `const`. Hardcoded colours fixed in home protein tip (warnBg/warnInk), muscle figure (dark-aware base/hair/none grey), scan result, allergy, badges, sparkline. Check each screen in dark mode on the phone and report white boxes or unreadable text.

## Friend nudge (BUILT, UNTESTED, needs SQL)
Bell button on each friend row in Social -> Friends calls `SocialService.nudge()` -> rpc `send_nudge` -> push 'Nudge from NAME'. Needs `friend_nudge.sql` run in Supabase and push set up.

## Sounds, confetti, fade-in (BUILT, UNTESTED)
- NEW PACKAGE `audioplayers: ^6.1.0` (versions from memory; if the build fails on it, remove it from pubspec and make `SoundService.play` a no-op). Sounds are 3 small WAVs generated by script in `assets/sounds/` (win, pop, splash). `lib/services/sound_service.dart`, on/off switch in Settings -> Appearance ("Sounds", saved as `sounds_on`).
- `Haptic.win()` (chime) on check-in and finished workout, `Haptic.done()` (pop) on a finished set, `Haptic.splash()` on adding water (`widgets/ui_kit.dart`).
- `lib/widgets/celebrate.dart`: `Celebrate.show(context)` confetti overlay (check-in, workout finish).
- `FadeSlideIn` (ui_kit) staggers the Home cards on open. Page transition is still the Material zoom.

## Story-size share cards (BUILT, UNTESTED)
`widgets/share_card.dart`: progress card is now 9:16 (rendered 4x, story size) and `showPrShareCard()` makes a personal-record card. In Social -> "My personal records" each chip is tappable and opens the PR card. Sharing uses the system share sheet (share_plus), where the user picks Instagram Stories or WhatsApp Status. A one-tap direct "Instagram Story" button would need a native intent with FileProvider (patched in the workflow) or an extra package, not done.

## Tap repeat in workout logging (BUILT, UNTESTED)
`screens/workout_screen.dart`: "Copy last workout" chip above the exercises (fills every exercise from the best set of its last workout, via `bestSetsOf`), per exercise chips "Last time X kg x Y" and "Same as set 1", and ticking a set auto-fills the next empty set with the same kg/reps. Only the best set per exercise is stored in history, so "last time" is that best set, not every set. Superset (pairing two exercises with a shared rest) is NOT built.
