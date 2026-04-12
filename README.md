# FinFlow Frontend

FinFlow Frontend is a Flutter application for personal finance management, with secure cloud sync, budgeting, expense tracking, group expenses, analytics, and productivity-focused financial flows.

## Stack

- Flutter 3 + Dart 3
- Riverpod for state management
- Dio for networking
- Hive + Flutter Secure Storage for local and secure storage
- Go Router for app navigation

## App Capabilities

- Cloud authentication with access and refresh token flow
- First-run onboarding walkthrough with settings-based replay
- Expense tracking with category and recurring support
- Budget planning and spending visibility
- Group expenses and settlement support
- Sync and offline-first data behavior

## Project Structure

```
lib/
	core/
		network/
		router/
		storage/
	features/
	shared/
```

## Prerequisites

- Flutter SDK (stable)
- Dart SDK (bundled with Flutter)
- Android Studio or VS Code with Flutter tooling
- Running FinFlow backend API

## Quick Start

1. Install dependencies:

```bash
flutter pub get
```

2. Run the app:

```bash
flutter run
```

## API Base URL Configuration

The app reads API base URL from compile-time define `API_BASE_URL`.

Current default in code points to production backend:

`https://finflow-backend-lunz.onrender.com/api/v1`

You can override it per environment when launching:

```bash
flutter run --dart-define=API_BASE_URL=https://finflow-backend-lunz.onrender.com/api/v1
```

Android emulator local backend example:

```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000/api/v1
```

## FCM Push Notifications Setup

The app now syncs FCM device tokens to backend and shows foreground push alerts.

Required setup:

- Add Firebase app config for each target platform (Android/iOS/web as needed)
- For Android, include `google-services.json` in `android/app/`
- Ensure backend has Firebase service-account env configured

Without Firebase configuration, the app continues working; FCM features remain disabled gracefully.

## Build Commands

- Android APK:

```bash
flutter build apk --release
```

- Android App Bundle:

```bash
flutter build appbundle --release
```

- iOS (macOS only):

```bash
flutter build ios --release
```

## Development Notes

- Secure tokens are stored with Flutter Secure Storage.
- API calls go through the shared Dio provider and auth interceptor.
- Error formatting and request trace IDs are surfaced for debugging.
- Hive startup now applies schema marker migration via `HiveService.migrateStorageSchema()`.
- If Hive startup detects corruption, local cache repair is attempted and an in-app repair banner is shown.
- Settings now includes Privacy Mode (amount masking) and Sync Conflict Resolution center (`/sync/conflicts`).
- Shell now exposes a quick Privacy Mode toggle; app switcher is masked in privacy mode and Android screenshots are blocked with secure flag.
- Sync circuit-breaker UX is visible in shell banner (full sync opens after 3 failures for 45s, pull-only opens after 5 failures for 30s).
- Group detail now includes a settlement audit timeline with dispute submission and owner-only dispute resolution actions.
- Authenticated first-run now opens a guided onboarding walkthrough (`/onboarding`), and Settings can replay it.
- Investments feature scaffolds were removed from active frontend scope until product requirements are finalized.

Storage migration and corruption recovery strategy:

- `../docs/HIVE_MIGRATION_CORRUPTION_RECOVERY.md`

Design system reference:

- `../docs/DESIGN_SYSTEM.md`

## AI-Assisted Development Workflow

This workspace includes a production-focused Copilot setup for consistent coding standards.

- Main rules: `../.github/copilot-instructions.md`
- Local playbooks: `../.copilot/skills/`
- VS Code automation: `../.vscode/tasks.json`, `../.vscode/settings.json`
- Setup guide: `../docs/AI_VSCODE_POWER_SETUP.md`

Run full validation from VS Code task `Validate: All` or manually run:

```bash
flutter analyze
```

For environment sanity checks:

```powershell
powershell -ExecutionPolicy Bypass -File ../tools/ai/check-dev-environment.ps1
```

For one-command local bootstrap (dependencies, optional Docker services, optional validation):

```powershell
powershell -ExecutionPolicy Bypass -File ../tools/ai/bootstrap-local-dev.ps1 -Validate
```

To launch backend + frontend in separate terminals from this repo:

```powershell
powershell -ExecutionPolicy Bypass -File ../tools/ai/start-local-stack.ps1
```

To stop local Docker services when done:

```powershell
powershell -ExecutionPolicy Bypass -File ../tools/ai/stop-local-stack.ps1
```

## Troubleshooting

- If API calls fail locally on Android emulator, ensure you use `10.0.2.2` instead of `localhost`.
- If authentication fails repeatedly, clear app data and sign in again to refresh local tokens.
- If backend endpoint changes, update the `API_BASE_URL` define.

## Related Project

- Backend API: `../FinFlow-Backend`
