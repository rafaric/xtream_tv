# Skill Registry — xtream_tv

## Project Skills

| Skill | Trigger | Compact Rules |
|-------|---------|---------------|
| flutter-expert | Flutter, Dart, widget, Riverpod | See below |

## Compact Rules

### flutter-expert

- Use `const` constructors wherever possible
- Implement proper keys for lists
- Use `Consumer`/`ConsumerWidget` for state (not `StatefulWidget` with setState for app state)
- Follow Material design guidelines
- Profile with DevTools, fix jank
- Test widgets with `flutter_test`
- NEVER build widgets inside `build()` method
- NEVER mutate state directly (always create new instances)
- NEVER use `setState` for app-wide state
- Use `compute()` for heavy computation (don't block UI thread)

## Project Conventions

### Deprecation Rules
- Use `withValues(alpha: x)` instead of `withOpacity(x)`
- Use `.toARGB32()` instead of `.value` for colors

### Architecture
- Riverpod for all state management
- SharedPreferences injected via `sharedPreferencesProvider` from main.dart
- Services layer for business logic
- Providers layer for Riverpod state

### Styling
- Primary: `Colors.deepPurple`
- Background: `0xFF0D0D1A`
- Surface: `0xFF1A1A2E`
- AnimatedContainer: 150ms duration

### Testing
- Target: Android TV / Google TV (D-pad navigation, no touch)
- Dev testing: `flutter run -d edge --web-port=8080`
- Deploy: `flutter build apk --debug && adb install -r build\app\outputs\flutter-apk\app-debug.apk`

---
Generated: 2026-03-27
