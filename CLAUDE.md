# Healthy (working name): project guide for Claude and other coding agents

Read this first in every new session. Details live in `docs/`:
- `docs/FEATURES.md`: everything built, where the code is, what is untested
- `docs/ROADMAP.md`: what is next, backlog, user-side setup still pending
- `docs/DATABASE.md`: Supabase tables, security rules, functions, edge function

## What this is
A HealthifyMe-style health app for India, built with Flutter (Android only for now):
calorie diary, barcode scan, allergy alerts, Indian foods, voice logging, workout planner,
streaks/XP, friends feed and challenges, AI coach, reports. Free to use; the plan is to beat
paid apps on free features, allergy safety and Indian food. UI language: English.
Theme: fresh green on white (changed from purple), font Outfit. User can pick a theme colour in Profile.

## The user and how to work with them
- Owner: kuldeeppal981 (GitHub). Repo: `kuldeeppal981/Healthy`, branch `main`. Time zone IST.
- Writes Hinglish (Hindi in Roman letters). **Reply in Hinglish**, short and clear, no jargon.
- **Works only from a phone.** No computer, no Flutter, no terminal. He installs the APK and
  sends screenshots of errors. Never ask him to run commands; do it for him or give phone steps.
- The sandbox where Claude works **cannot run Flutter** (no SDK, pub.dev unreachable). All Dart
  is uncompiled. Only check bracket balance (python count of `()`, `{}`, `[]`). Package versions
  are written from memory. Any compile error is found by his GitHub Actions build.
  Never claim something "works" or "builds"; say it is untested until he confirms.
- Be honest about limits (example: real push notifications need Firebase, which he must set up).

## Build and release
- GitHub Actions workflow `.github/workflows/build-apk.yml` ("Build Android APK"), run it from
  Actions -> Run workflow (about 7 min). Artifact name: `healthy-apk`.
- The workflow runs `flutter create --platforms=android --project-name healthy_app --org com.kuldeep .`
  and then **patches the generated Android project with Python**: manifest permissions and
  `<queries>`, notification receivers, home-widget files, `FlutterFragmentActivity`, minSdk 26,
  core library desugaring, R8 minify off + ML Kit dontwarn rules. There is no committed `android/`
  folder. Any native change must go in the workflow.
- Build command: `flutter build apk --release --no-shrink --dart-define=SUPABASE_ANON_KEY=...`
  (secret `SUPABASE_ANON_KEY` in the repo). Supabase URL default is in `lib/config.dart`.
- Commit messages must end with the trailers Claude Code asks for (Co-Authored-By and Claude-Session).
  `git push` prints a harmless "repository moved" notice.

## Code map (`lib/`)
- `main.dart`: startup, providers, theme (dark mode filter), widget refresh, social watcher
- `state/app_state.dart`: the one big ChangeNotifier. Profile, targets, diary, water, weights,
  workouts, custom plans, check-ins, freezes. Saved to SharedPreferences and synced to Supabase
  (`user_data` JSON) through `toSnapshot()` / `applySnapshot()`. New persistent fields must be
  added to snapshot, applySnapshot, load, save and clearAll.
- `services/`: cloud_sync, social_service (friends, feed, cheers, PR detection), reminder_service
  (local notifications + gym alarm), step_service, health_service (Health Connect), badges, levels,
  health_conditions, allergy_checker, food_service, nutrition_calc, voice_service/voice_parser,
  report/report_pdf, widget_service, theme_service, label_parser (unused, see parked)
- `screens/`, `widgets/`, `data/` (indian_foods, exercise_library), `theme.dart`, `models.dart`,
  `profile_models.dart`
- `parked/label_scan_screen.dart`: label scan (ML Kit) removed because it broke the release build

## Rules and gotchas learned the hard way
- **Buttons in a Row:** `buildTheme()` gives Filled/Outlined buttons `minimumSize: Size.fromHeight(52)`
  (infinite width). Inside a Row this breaks layout (text rendered vertically). Always pass
  `styleFrom(minimumSize: Size(0, 40))` or wrap in a bounded widget.
- **Colors:** accent colours in `AppColors` (primary, primaryLight, primaryDeep, link, chipBg, chipInk, bg, bgTop, border, track) are now GETTERS (theme colour picker, `ThemeService.palette`), so they can NOT be used in `const` widgets or `const` lists; drop the `const` keyword. The other colours (ink, muted, card, danger, safe, ring...) are still `static const`. Dark mode is a global ColorFilter in `main.dart`
  (invert + hue rotate). Wrap anything that must keep real colors (camera) in `ThemeService.undoDark`.
- **Do not add packages that need newer JVM targets or ML Kit** without testing: they broke the
  build before (flutter_timezone, google_mlkit text recognition). The time zone is derived from the
  phone offset in `reminder_service`.
- `--no-shrink` does not disable R8; the workflow step for minify/dontwarn does.
- Keep user data private: Supabase RLS everywhere; social data only via SECURITY DEFINER RPCs that
  check friendship. Sharing is opt-in (social profile, discoverable switch, share-achievements switch).
- Health/medical content must stay general guidance with a not-medical-advice note. The AI coach
  never gives crash-diet advice; do not weaken its system prompt in the edge function.
- Never put the Gemini key or the service role key in the app. Secrets live in Supabase.

## Supabase
Project ref `rofxxebtjrmtrulbkexi`. The live database is the source of truth; `docs/DATABASE.md`
describes it and `supabase/functions/coach/index.ts` is the edge function source. When changing
the database, apply a migration (MCP `apply_migration`), then update `docs/DATABASE.md`.
Security advisor warnings about SECURITY DEFINER functions are intentional.

## Working agreement
- Before building a big feature, look at the roadmap, then build, then update `docs/FEATURES.md`
  and `docs/ROADMAP.md` in the same commit so the next session knows.
- Keep replies to the user short: what changed, what to test, what he must do himself.
