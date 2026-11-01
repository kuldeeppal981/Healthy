# Healthy (working name)

Calorie tracker with barcode scan, personal allergy alerts and a day-wise gym workout planner.
Theme: bright purple, font: Outfit. UI language: English.

## What works in this first version

- Home dashboard: calorie ring, protein/carbs/fat bars, water counter, meal-wise diary, daily tip
- Barcode scan (camera) with product lookup on Open Food Facts, plus manual barcode entry
- Allergy alerts: declared allergens, hidden ingredient names (casein, whey, malt...), "may contain" traces,
  highlighted words in the ingredient list, severity levels
- Never says "safe" when the product has no ingredient data
- Manual food add (home food like roti and dal) when a product is not found
- Gym planner: Mon to Sun split (Chest+Triceps, Back+Biceps, Legs, Shoulders+Abs, Full body, Cardio+Core, Rest),
  set logging (kg x reps) and a 90 second rest timer
- Daily targets (Profile), data saved on the phone

## Run it

1. Install Flutter (https://docs.flutter.dev/get-started/install)
2. From this folder, generate the platform folders (keeps `lib/` and `pubspec.yaml`):
   ```
   flutter create --platforms=android,ios --project-name healthy_app .
   ```
   Then delete the default `test/widget_test.dart`.
3. Android: in `android/app/src/main/AndroidManifest.xml` add inside `<manifest>`:
   ```xml
   <uses-permission android:name="android.permission.INTERNET"/>
   <uses-permission android:name="android.permission.CAMERA"/>
   ```
   and set `minSdk` to 23 in `android/app/build.gradle` (or `build.gradle.kts`).
4. iOS: add to `ios/Runner/Info.plist`:
   ```xml
   <key>NSCameraUsageDescription</key>
   <string>Barcode scan karne ke liye camera chahiye</string>
   ```
5. In `lib/services/food_service.dart` replace `change-this@example.com` with your email
   (Open Food Facts asks apps to identify themselves).
6. Run:
   ```
   flutter pub get
   flutter run
   ```

## Also built

- Onboarding: sex, age, height, weight, activity, goal gives daily calorie and macro targets (Mifflin-St Jeor)
- Weight log with BMI and a small trend chart; edit profile and recalculate targets
- Indian food search (about 27 common foods, approximate values) when adding meals
- Workout history is saved; logging streak and workouts-this-week on Home

## Not built yet (next steps)

- Login and cloud backup (Supabase or Firebase), so data is saved per user
- Family profiles, label photo (OCR) for products not in the database
- Meal plans, reminders, weekly report
- Exercise videos, progressive overload suggestions
- Hindi language switch

Note: this code was written without being compiled in the build environment, so expect to fix a few
small errors on the first `flutter run`.
