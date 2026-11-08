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
- Exercise library: 39 gym exercises + 19 yoga poses/breathing + 8 stretches (groups 'Yoga' and 'Stretch', text steps plus green stickman drawing (`widgets/yoga_figure.dart`, CustomPaint) for 10 poses, ponytail version when profile sex is female, other poses have no drawing yet, UNTESTED; muscleOf returns null for them so muscle volume is unaffected). 66 total, each with muscles, equipment, steps, mistakes, beginner/intermediate/advanced
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

## Alternative exercise when a machine is busy (BUILT, UNTESTED)
Swap icon on each exercise card while logging opens a sheet of other library exercises for the same muscle (`alternativesFor()` in `data/exercise_library.dart`, sorted closest first, different equipment before same). Tapping one swaps it for TODAY only (`_swaps` map in `workout_screen.dart`, cleared when the day is reset/finished); the saved plan is unchanged. Kg of unfinished sets is cleared on swap. "Back to planned" is in the same sheet. Only works for exercises that exist in the library (custom names have no swap icon).

## Auto check-in with popup (BUILT, UNTESTED)
The first thing logged each day (food entry, water +, finished workout, weight) checks the user in by itself: `AppState._autoCheckIn()` adds today to `checkIns` and fires `autoCheckInEvents`. `AppShell` listens and shows `showAutoCheckInPopup()` (`widgets/checkin_popup.dart`): bouncing flame, counting streak number, +10 XP / level chip, confetti, chime, auto closes after ~3 s. Merely opening the app does not check in. Data coming from cloud sync or old data does not trigger it. The manual Check in button still exists and is greyed out after an auto check-in. There is no switch to turn the popup off yet.

## Rest timer on the lock screen (BUILT, UNTESTED)
`ReminderService.startRestTimer(seconds, exercise:)` / `stopRestTimer()`. When a set is ticked (or logged by voice) the rest countdown also shows as an ongoing, lock-screen-visible notification using the Android chronometer in count-down mode (`usesChronometer` + `chronometerCountDown` + `when`, `timeoutAfter`), so it ticks with the screen off without the app running. A scheduled "Rest over" notification (channel `rest_done`, high importance) rings at the end; the app cancels it when its own timer is showing (app open). Skip/finish cancel both. Rest length is still fixed at 90 s (`_restSeconds`). If `chronometerCountDown` does not compile in this flutter_local_notifications version, remove that one argument (the timer will count up). On some phones Doze can delay the "Rest over" ring by a few seconds to minutes unless exact alarms are allowed.

## AI Form check from a photo (BUILT, UNTESTED, edge function `coach` v15 deployed with mode `form`)
Camera icon on each library exercise card while logging opens `screens/form_check_screen.dart`: take/choose ONE photo, `services/form_ai.dart` sends it to the `coach` function (mode `form`, Gemini vision, counts as 1 daily AI request). Result: summary, "Looks good" list, up to 4 issues with a fix cue, and a skeleton drawn over the photo (joint positions are AI estimates as fractions of the photo, problem joints red, dashed plumb line). It is NOT live/real-time and not real pose detection; accuracy is approximate. A real-time skeleton would need an on-device pose model (ML Kit pose detection + camera stream), which was not added because ML Kit packages broke the build before. No medical claims: general guidance, stop if pain.

## Medical report scan (BUILT, UNTESTED, edge function `report` v1 deployed)
Profile -> Medical report (`screens/medical_report_screen.dart`, `services/report_ai.dart`). Photo/camera of a lab report -> edge function `report` (Gemini vision, 1 daily AI request, photo not stored) returns summary, key markers, `condition_ids` (only diabetes, bp, cholesterol, pcos), other concerns, foods to limit and foods to eat more of. The user reviews the result and taps Save: `AppState.saveMedicalNotes()` stores it in `medicalNotes` (local + synced in the user's private snapshot, never shared with friends) and switches on matching health conditions (so label scans use them). While logging food (`add_food_sheet.dart`, `scan_result_screen.dart`) `AppState.reportAvoidHit(name)` shows a gentle snackbar when the food matches a "limit" word. Only images, no PDF yet. Always labelled as general guidance, not medical advice; the AI prompt forbids diagnoses, medicines and personal details. The coach does not read the saved report yet.

## Food logging batch: quick foods, templates, suggestions, alerts, portions (BUILT, UNTESTED)
- 36 more Indian foods in `data/indian_foods.dart` (now 63).
- Add food sheet has a "Quick" tab: Recent foods (derived from the diary), Favourites (star), Meal templates ("Save today's breakfast as template", one tap adds all items). Stored in `AppState.favFoods` / `mealTemplates` (synced with the user's data).
- Portion dialog: Small/Medium/Large (0.75x/1x/1.3x), pieces stepper, grams (when the serving text has "(150 g)"), extra ghee/oil in tsp (+45 kcal, +5 g fat per tsp). Label records the choice.
- Home: `_coachCards` shows gentle alerts (`services/food_suggest.dart` `coachAlerts`: protein gap after 2 pm, kcal 250+ over, water behind, add fibre) and "Ideas for your next meal" (`suggestFoods`: fits next-meal calories, closes protein gap, skips allergens by name hints, report "limit" foods, penalises carbs for diabetes and fat for cholesterol). Fibre is not tracked in numbers, only a food-word check.
- NOT built yet from the user's list: recipe nutrition calculator, eating-out mode, meal photo recognition, food substitution, weekly fibre trend (needs a fibre field).

## Training status and short workout (BUILT, UNTESTED)
- `services/training_stats.dart` `TrainingOverview.compute()`: per tracked muscle last trained, sets in the last session, completed sets in 7 days, sessions in 28 days (times per week), and a recovery ESTIMATE (48 to 72 h by how many sets the last session had). Plus workouts and total volume this week vs last week (volume is per workout total, not per muscle). Shown in `screens/training_status_screen.dart` (opened from the "Training status" card under the banner in Workout). Wording says it is an estimate from history, not a measurement.
- "Short on time?" chip in Workout -> sheet with 15/20/30/45 min: `shortenPlan()` keeps big compound lifts and rested muscles first, trims exercises to as few as 2 sets, skips the rest (2.25 min per set, same as `estimateMinutes`). It replaces today's plan only (`_short` map in `workout_screen.dart`), the saved plan is unchanged, and resets after finishing. Starting a short plan clears the day's set rows.

## Live form analysis (merged into main from `pose-test`; build passed, behaviour UNTESTED)
On branch `pose-test` only (to protect main from build breaks): `camera ^0.11.0+2` and `google_mlkit_pose_detection ^0.13.0` (versions NOT verified against google_mlkit_text_recognition's google_mlkit_commons; if `pub get` fails, align the versions). `services/pose_math.dart` (angles, rep state machine, exercise rules: squat, lunge, push-up, biceps curl; front/side view checks: depth, torso lean, knee tracking, sway, left/right asymmetry, elbow drift, body line), `screens/live_form_screen.dart` (camera stream NV21 -> ML Kit pose -> skeleton overlay, reps, angle, range of motion, summary, "uncertain" message when landmarks have low confidence). Entry: "Live camera analysis (beta)" in the Form check screen. Portrait only; coordinates assume sensor rotation 90/270. To test: Actions -> Run workflow -> choose branch `pose-test`. Merge into main only after it builds and works.

## UX batch: 10 points in one commit (BUILT, UNTESTED, no new packages)
1. **Smart home**: Home order is now greeting + search icon, calorie card, Today's plan, quick actions, steps/water, coach cards, workout, streak. Not re-ordered by time of day yet (only "Next:" hint in Today's plan).
2. **Universal Quick Add**: centre "+" in the bottom bar (`AppShell._addButton`, `widgets/quick_add_sheet.dart` `showQuickAdd`): Food, Scan, Voice, Water, Workout, Weight, Check in, Search. Bottom bar now has 6 slots (labels shrink to fit).
3. **Today's plan** (`widgets/todays_plan_card.dart`): auto-ticking list: breakfast/lunch/dinner logged, water goal, steps goal (only if step permission is granted), today's workout (hidden on rest days), check in. Tap a row to do it. Confetti + win sound once when the last item turns done (not on app open). Progress bar + "Next:" line.
4. **Global search** (`screens/search_screen.dart`): foods (opens the add sheet with the query filled via `showAddFoodSheet(initialQuery:)`), exercises (detail page), app screens/settings by keyword. Empty search shows recent foods and shortcuts. Friends/AI coach are hidden when cloud is off.
5. **Flexible calendar**: (a) Diary: past days (the 7-day strip) now have a + and per-meal + that log food on THAT day (`showAddFoodSheet(forDay:)`, entries are dated that day at the current clock time; no auto check-in for past days). Scan/voice stay today-only. (b) Workout: "You missed Tuesday: Push" card (earlier weekday this week with a planned workout and no log): "Do it today" replaces today's plan for today only (reuses the `_short` override), "Skip it" hides it. Not saved across app restarts.
6. **Notification intelligence** (`ReminderService`): "Smart reminders" switch in Reminders (default ON, saved on the phone). Skips today's meal reminder if that meal is logged, today's gym alarm if a workout is logged, today's water reminders once the water goal is reached (schedules start tomorrow). Meal reminders move to the user's usual time minus 15 min after 4+ logs in 14 days, only when that is more than 45 min from the set time. `onStateChanged` (hooked in `main.dart`) re-plans 2 s after a meal/workout/water-goal change. `reschedule` now cancels only its own ids (1-3, 11-17, 100-124), so the rest-timer notification is no longer cancelled by it.
7. **Offline mode**: no new package. Everything already saves on the phone first. `widgets/offline_banner.dart` shows a bar above the pages when signed in and the last backup failed (`AppState.syncError`), with Retry (`syncAfterLogin`, newer side wins). The app also retries when it comes back to the foreground (`didChangeAppLifecycleState` in `main.dart`). Real connectivity detection is not used.
8. **Accessibility**: Settings -> High contrast (darker text/borders, bold text; `ThemeService.highContrast`) and Reduce motion (`reduceMotion`: no confetti, no fade-in; also follows the phone's "remove animations"). Text size already existed. Semantics labels added on the bottom bar, quick add, onboarding choices, Today's plan rows, diary add button, profile avatar. Tap targets >= 44-48 dp on new buttons. Not tested with TalkBack.
9. **Privacy dashboard** (Profile -> Privacy dashboard, `screens/privacy_dashboard_screen.dart`): counts of stored data, Health Connect status + link, plain-language AI data usage (+ remove medical report notes), friend visibility switches (discoverable, share achievements) when friends are on, Export all data (JSON of `toSnapshot`) and food diary CSV through the share sheet (`share_plus` + `path_provider`, temp file), links to delete data/account (Settings) and the policy.
10. **Adaptive onboarding**: onboarding/edit profile now also asks training experience, equipment (gym/home/none), food preference (veg/egg/non-veg/vegan) and food budget. Stored in `AppState.prefs` (local + synced snapshot key `prefs`). Used by: `suggestFoods` (hides foods that break the diet by name words, `foodBreaksDiet`; low budget lowers costly foods like paneer/nuts/fish), exercise swap sheet (`alternativesFor(equipmentHave:)` puts equipment you have first, marks "needs more equipment"). Experience and budget are stored but only budget is used so far (experience is for future plan defaults). Existing users get defaults (beginner/gym/veg/medium) the next time they open Edit profile; until then `prefs` is empty and nothing is filtered.

## Gamification batch (BUILT, UNTESTED, no SQL, no new packages)
- **Weekly missions** (`services/missions.dart`, `screens/missions_screen.dart`): Mon-Sun, worked out from the logs (nothing stored): train N days (N = planned days, max 5), protein on 4 days (>= 90% of target), water goal on 5 days, food logged on 6 days. Home card "This week" (`WeeklyMissionsCard`) + full screen (Profile -> Missions and challenges). Each finished mission = 30 XP in `Progress.of` (looks back 26 weeks).
- **Custom challenges**: user picks name, what to count (workout/protein/water/food days), target days, length 7/14/30. Stored in `AppState.customChallenges` (local + synced). Phone only, not shared with friends yet. Swipe to delete.
- **PR celebration**: `widgets/pr_popup.dart` after a finished workout that has new PRs.
- **Comeback reward**: first activity after 4+ days away sets `AppState.comebackGap`; the auto check-in popup shows "Welcome back" and "+25 comeback bonus". XP is derived (`Missions.comebacks` = 25 XP each).
- **Milestones** 7/30/90/180 (best daily streak, `Missions.bestStreak`) and **Streak freezes** card (left this month + dates used) in Streaks and badges.
- Not built: team challenges (needs SQL), friends seeing custom challenges.

## Social safety (BUILT, UNTESTED, SQL already applied to the live database)
Friends screen: more menu (3 dots) on friend rows and other people's feed posts -> Mute / Block / Report (`_showSafetySheet` in `social_screen.dart`). Friends tab bottom: "Safety and privacy" card with Private profile, Show when I am active (opt-in, green dot for friends, updated when numbers are sent), and the blocked/muted list with Unblock. Mute hides their posts and numbers only; block removes the friendship and hides both ways. Reports go to the `reports` table (no admin screen). Needs two accounts to test. Not built from the social list: buddy matching, private groups, group challenges, shared plans, weekly community leaderboard, invite links, accountability partner, PR reaction types.

## Home redesign (branch `home-redesign`, NOT merged, untested)
- Bottom bar: Home, Diary, + (centre), Workout, Analytics. Profile opens by tapping the avatar on Home (`openProfile`).
- Home order: header (greeting, search, bell, avatar) -> Calories -> Steps + Water (Water: "+ glass", reminder bell top right) -> Today's plan (compact, next 3, "View all" sheet) -> Workout + AI coach side by side -> Explore your fitness.
- `widgets/explore_section.dart`: 2x3 tiles, "Customize" saved in `AppState.prefs['explore']`.
- `screens/hub_screens.dart`: Nutrition, Health, Library, Community, Daily plan, Challenges hubs with tabs, linking existing screens.
- `screens/notifications_screen.dart`: friend requests and cheers (bell). `ReminderService` is now a ChangeNotifier.
- Streak startup checks moved to AppShell (`streakStartupChecks` in streak_card.dart).

## AI wait card (untested)
`widgets/ai_wait.dart` `AiWaitCard`: while a photo goes to the AI (report, form check, label scan) shows photo size, 3 steps, seconds and an estimated bar (max 95%). Real upload bytes are not available from supabase `functions.invoke`, so the bar is time based and labelled as usual 10 to 30 s.

## Pro UI preview (untested)
`pro_screen.dart`: gradient hero, preview prices (Rs 99/month, Rs 799/year, marked not final), "Notify me when Pro opens" (`prefs['proNotify']`). `widgets/pro_sheet.dart` `showProLimitSheet`: shown in the coach when the server answers error "limit". No real payment yet (needs Google Play Billing / RevenueCat).

## Social part 2 (untested)
`services/community_service.dart`, `screens/groups_screen.dart` (Explore, Community, Friends tab, "League and groups"): tabs League (weekly points of friends), Groups (create, join by code, share invite text, group league, group challenges, leave), Partner (pick a friend, accept/decline, today's check-in, nudge, end), Buddies (goal/level/time profile, matches, Add friend). PR reactions already exist on feed posts (fire, clap, muscle, heart).

## First-run app tour (untested)
`screens/tour_screen.dart`: 8 slides (meal photo, health report and form check come first, they are the core features) with Next, Back, Skip. Shown once after onboarding (`prefs['tourDone']`, checked in AppShell.build); replay from Profile -> App tour. Existing users also see it once.

## Meal photo to calories (untested)
`coach` edge function v16 has mode `meal` (photo -> items with kcal/protein/carbs/fat). `services/meal_ai.dart`, `screens/meal_photo_screen.dart` (Home "+" -> Meal photo): AiWaitCard, per item portion +/- (0.5 steps), meal chips, saves to the diary. Counts as 1 daily AI request (free 10, Pro 60). It is NOT Pro-only for now, because payments are not open yet. Pro table row updated. Still not built: weekly AI diet/workout plan (Pro).
- Meal photo full nutrients (untested): `coach` v17 meal mode also returns fiber, sugar, sat fat, sodium, iron, calcium, potassium, vitamins A, C, B12, D per item. `meal_photo_screen.dart` shows an "All nutrients" card (totals scale with the +/- portions, percent of a typical adult daily need or limit). The diary still saves only kcal, protein, carbs, fat. Idea: save these too and show a daily nutrient view.

## Settings redesign (untested)
`settings_screen.dart` is now a category list (account card -> edit name; Preferences: Appearance, Notifications; Privacy and security: Privacy and data, Privacy policy, Delete data or account; Support: App tour, About and licences; Sign out/in at the bottom). Each opens its own screen: `appearance_screen.dart` (moved from Settings), `reminders_screen.dart`, `privacy_dashboard_screen.dart`, `delete_data_screen.dart` (new, holds the two delete actions). Daily targets moved to Profile: compact 4-tile card (`_targetsCard`) with an Edit bottom sheet (`_editTargets`). NOT built (ideas only): units, language, change password, quiet hours, feedback form.

## Settings v2: categories, notifications, units, language, help (BUILT, UNTESTED)
- `settings_screen.dart`: account card, big Sign out on top, Account (Change password via `CloudSync.updatePassword`, Name and photo), Preferences (Appearance, Notifications, Units/Language), Connected apps (Health Connect), Privacy and security (Privacy and data, Friends privacy, Privacy policy), Support (Help and feedback, About with `appVersion`), red Danger zone (Delete data or account), version text.
- `notification_settings_screen.dart`: Reminders link, friend requests/nudges and cheers switches (`NotifyPrefs`, synced to the `notif_prefs` table so the server also skips those pushes), Quiet hours with From/To. Gym alarm is exempt from quiet hours.
- `units_language_screen.dart`: `Units` (kg/lb, cm/ft; gym lifts stay kg) and `AppLang` (Hindi partial via `tr()` in `services/l10n.dart`). Rebuild through `AppState.refreshUi()`.
- `help_feedback_screen.dart`: FAQ, tour replay, feedback form -> rpc `send_feedback` (table `feedback`, max 5/day).
- `appVersion` in `lib/config.dart` (bump on release).

## Profile illustrations (BUILT, UNTESTED)
- `lib/widgets/illustrations.dart`: `HeroArt` / `HeroHeader` draw shield, heart, report, flame, crown with CustomPaint (no image files, follows theme colour). Used on Allergies, Health conditions, Medical report, Streaks and badges (flame + streak) and Healthy Pro (crown). Profile stat tiles (streak, best streak, badges) now have icons.
- Idea from a ChatGPT concept image, not done yet: month tabs and weekly bar chart on Monthly report; swipeable "Quick access" is NOT wanted (Profile already has categories).

## Calories detail, report chart, nutrients in diary, smaller APK (BUILT, UNTESTED)
- `calories_detail_screen.dart`: tap the calorie card on Home. Ring (goal, eaten, left), protein/carbs/fat rings, by meal, other nutrients (sum of `DiaryEntry.more`, only from foods that have it), 7/30/90 day bar trend with goal line. No "burned" number yet (not tracked).
- `DiaryEntry.more` (optional map, saved in toJson only when not empty, so old data still loads). Meal photo now saves all nutrients per item (scaled by portion). `nutrientRows` in models.dart is the shared list with daily references.
- Monthly report: last 4 months as tabs (plus the old arrows) and a bar per day of calories with the goal line.
- APK size: workflow now builds `--target-platform android-arm64` only (single APK, about one third of the fat APK). Old 32-bit phones will not install it. If still big: check google_mlkit_text_recognition (all script models) and pose detection.

## My Recipes, quick logging, Weekly AI review (BUILT, UNTESTED, edge function `coach` v18 deployed)
- `AppState.recipes` (synced): {id, name, servings, items:[{name, serving, qty, kcal, p, c, f}]}, item numbers are totals for that line. `services/recipes.dart` has 30+ raw ingredients (oil, ghee, dals, atta, veg, paneer, chicken...) plus `indianFoods` as choices, and per-serving maths.
- `recipes_screen.dart`: list (tap = log), New/Edit recipe (name, servings, ingredients by search with quantity or "enter numbers"), per-serving card. `showLogRecipeSheet`: servings stepper (0.5 steps) + chips, meal chips, adds one DiaryEntry scaled. Tiles "My recipes" and "Weekly review" in the "+" sheet.
- Weekly review: `services/weekly_review.dart` builds numbers from the last 7 diary days (no name, email or photos sent), calls `coach` mode `weekly` (JSON: headline, went_well, improve, 3 steps; safe prompt, no crash diets). `weekly_review_screen.dart` shows stats + review. Free: one review per week (stored in `prefs['weeklyReview']`, client side), Pro (from `my_plan`): "Make it again". Counts as 1 AI request.
- Not done: recipe photo/AI estimate, edit a logged recipe, recipes shared with friends, nutrients beyond kcal/macros in recipes.
