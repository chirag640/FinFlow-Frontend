# FinFlow Frontend

FinFlow Frontend is a Flutter application for personal finance management, with secure cloud sync, budgeting, expense tracking, group expenses, investments, analytics, and productivity-focused financial flows.

## Stack

- Flutter 3 + Dart 3
- Riverpod for state management
- Dio for networking
- Hive + Flutter Secure Storage for local and secure storage
- Go Router for app navigation

## App Capabilities

- Cloud authentication with access and refresh token flow
- Expense tracking with category and recurring support
- Budget planning and spending visibility
- Group expenses and settlement support
- Investments and net worth tracking
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

## Troubleshooting

- If API calls fail locally on Android emulator, ensure you use `10.0.2.2` instead of `localhost`.
- If authentication fails repeatedly, clear app data and sign in again to refresh local tokens.
- If backend endpoint changes, update the `API_BASE_URL` define.

## Related Project

- Backend API: `../FinFlow-Backend`
