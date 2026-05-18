# Wicara Mobile

Flutter mobile app for WICARA: prerequisite-first adaptive tutoring with local-first AI routing and LiteRT-based on-device Gemma integration.

## What This App Includes

- Authentication and onboarding flow
- Curriculum knowledge map and learning goal selection
- Adaptive pretest flow (local-first on device)
- Workspace 5E tutoring flow (Engage, Explore, Explain, Elaborate, Evaluate)
- Edge AI settings (download, initialize, and runtime status for LiteRT model)
- Home, queue, progress, reports, posttest, and media flows

## Requirements

- Flutter SDK 3.24+ (stable recommended)
- Android SDK + USB debugging enabled on a real Android device
- Optional backend API running at `http://127.0.0.1:8000` (for hybrid flows)

## Repository Path

```text
wicara-mobile-brian/
```

App product name: **Wicara Mobile**.

## Quick Start (Recommended for Judges)

1. Open terminal in this repo:

```powershell
cd "C:\Kuliah\Semester 6\Wicara App\final\wicara-mobile-brian"
```

2. Install dependencies:

```powershell
flutter pub get
```

3. Confirm your Android device is detected:

```powershell
flutter devices
```

4. Run app on device (note: use `-d`, not `-D`):

```powershell
flutter run -d <DEVICE_ID> --dart-define=WICARA_API_BASE_URL=http://127.0.0.1:8000
```

Example:

```powershell
flutter run -d RRCY902FXQN --dart-define=WICARA_API_BASE_URL=http://127.0.0.1:8000
```

## First Run for Local AI (LiteRT)

When app opens:

1. Go to **Edge AI Settings**.
2. If model is missing, press **Install model**.
3. Press **Initialize** until runtime status is ready.
4. Return to learning flow.

Notes:

- Model file is persisted in app storage, so it does not re-download every run.
- Reinstall is only needed if app data is cleared/uninstalled or model files are removed.

## Runtime Defines Used by This App

- `WICARA_API_BASE_URL`  
  Backend base URL for hybrid API calls.
- `EDGE_LITERT_FORCE_LOCAL_FOR_PILOT` (default `true`)  
  Forces local-first behavior for supported tutor/pretest paths.
- `EDGE_CLOUD_FALLBACK_ALLOWED` (default `false`)  
  Allows cloud fallback if enabled.
- `EDGE_DEBUG_ROUTE_TRACE` (default `false`)  
  Enables route/debug trace output.
- `WICARA_GOOGLE_WEB_CLIENT_ID`  
  Optional for web Google Sign-In.

Example with explicit local-only posture:

```powershell
flutter run -d <DEVICE_ID> `
  --dart-define=WICARA_API_BASE_URL=http://127.0.0.1:8000 `
  --dart-define=EDGE_LITERT_FORCE_LOCAL_FOR_PILOT=true `
  --dart-define=EDGE_CLOUD_FALLBACK_ALLOWED=false
```

## Optional: Run on Chrome (UI Check Only)

```powershell
flutter run -d chrome --dart-define=WICARA_API_BASE_URL=http://127.0.0.1:8000
```

Important: LiteRT native runtime and Flutter platform channels are Android/iOS-native. Chrome is useful for UI checks, not for validating on-device LiteRT inference.

## Troubleshooting

- `Improperly formatted define flag: <DEVICE_ID>`  
  Cause: used `-D` instead of `-d`.  
  Fix: `flutter run -d <DEVICE_ID> ...`

- `MissingPluginException(... wicara/edge_litert ...)`  
  Cause: running on unsupported target or stale build.  
  Fix: run on Android device and restart app with fresh `flutter run`.

- Runtime shows `available_not_loaded`  
  Model exists but not initialized.  
  Fix: open Edge AI Settings and press **Initialize**.

## Project Structure

- `lib/src/app`: routes and app composition
- `lib/src/core`: theme, shared UI, network client
- `lib/src/features/auth`: auth flow
- `lib/src/features/onboarding`: profile onboarding
- `lib/src/features/learning_goal`: goal resolution/selection
- `lib/src/features/pretest`: adaptive pretest UI/state
- `lib/src/features/offline_pretest`: local pretest engine and diagnosis
- `lib/src/features/workspace`: workspace 5E flow and local tutor routing
- `lib/src/features/edge_ai`: LiteRT runtime/settings integration
- `lib/src/features/home`: queue, tracks, reports, posttest, profile

## Demo Flow for Judges

1. Login
2. Choose learning goal
3. Finish pretest
4. Continue to generated path/workspace
5. Chat in workspace and advance phase
6. Open Edge AI panel to verify runtime status
