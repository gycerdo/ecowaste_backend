# AcoWaste — Complete Project

```
acowaste_complete_project/
├── mobile_app/      ← Flutter app (lib/ + pubspec.yaml)
└── backend/         ← Node + Express API, Neon Postgres, deploys to Render
```

## ⚠️ Important — read before unzipping

`mobile_app/` here contains only `lib/` + `pubspec.yaml` + `analysis_options.yaml`.
It does **not** include `android/`, `ios/`, `web/`, `windows/`, `macos/`,
`linux/`, or `build/` — those are large, machine-generated platform folders
that aren't meaningful to hand-edit or transfer as text, and you already
have a working set of them in your existing `IMAGE_DETECTOR_APP` project.

**You have two ways to use this. Pick one:**

### Option A — Merge into your existing project (recommended, fastest)
You already have `IMAGE_DETECTOR_APP` with working `android/`, `ios/`, etc.
1. Copy everything inside `mobile_app/lib/` into your existing project's `lib/`,
   overwriting `main.dart`, `waste_detection_screen.dart`, and
   `nearby_users_screen.dart`, and adding the new `auth/`, `splash/`,
   `coordinator/`, `services/` folders.
2. Open your existing `pubspec.yaml` and add any dependency listed in
   `mobile_app/pubspec.yaml` that you don't already have (`shared_preferences`,
   `flutter_map`, `latlong2`, `image_picker`, `geolocator`, `http`).
3. Run `flutter pub get`.

### Option B — Make `mobile_app/` a standalone project
If you'd rather run this folder on its own:
```bash
cd mobile_app
flutter create .        # generates android/, ios/, web/, etc. around the existing lib/
flutter pub get
```
`flutter create .` fills in the missing platform folders without touching
your `lib/` or `pubspec.yaml`.

Either way, also add to `android/app/src/main/AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
```
and to `ios/Runner/Info.plist`:
```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>AcoWaste needs your location to find nearby waste operators.</string>
```

## Wiring the two halves together

1. Deploy `backend/` (see `backend/README.md` — Neon + Render steps).
2. Render gives you a live URL, e.g. `https://acowaste-backend.onrender.com`.
3. Open `mobile_app/lib/services/api_service.dart` and set:
   ```dart
   static const String baseUrl = 'https://acowaste-backend.onrender.com';
   ```
4. Run the app. Flow: Splash → Login/Register (role: user / collector "Mbeba
   Taka" / coordinator) → role-based home screen. Scanning and the radar/map
   now pull real rows from your Neon database through the backend — nothing
   is AI-fabricated, and no API key ships inside the app.

## What's real now vs. before
- Old: Gemini key hardcoded in Dart, and the "nearby users" radar asked an AI
  model to invent fake names, plates, and phone numbers.
- Now: real `users` table in Postgres, real JWT auth, real `/users/nearby`
  query by GPS distance, and the Gemini vision call happens server-side only.
