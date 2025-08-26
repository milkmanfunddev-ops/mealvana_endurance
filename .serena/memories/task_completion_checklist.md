# Task Completion Checklist

When completing any development task, follow this checklist:

## 1. Code Generation (If applicable)
If you added/modified any files with annotations:
- `@riverpod` controllers
- `@DriftDatabase` classes  
- JSON serialization

Run:
```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

## 2. Database Migrations (If applicable)
If you modified database schema in `lib/shared/database/tables/`:
```bash
dart run drift_dev make-migrations
```

## 3. Quality Checks (MANDATORY)
Always run before completing a task:
```bash
flutter analyze
```

## 4. Testing (If applicable)
```bash
flutter test
```

## 5. Content Management Verification
Ensure all UI text comes from ContentService, not hardcoded strings.
Check that content keys exist in `assets/config/content_defaults.json`.

## 6. Architecture Compliance
Verify that:
- Controllers use `@riverpod AsyncNotifier<T>` pattern
- Services are properly injected via Riverpod
- Features follow FOA structure
- No static methods are used

## 7. Error Handling
Ensure all async operations use `AsyncValue.guard()` for consistent error handling.

## 8. Performance Check
- Controllers use `ref.invalidateSelf()` for refresh
- Proper disposal of resources
- No memory leaks in streams/subscriptions

## CRITICAL RULES
- **NEVER run `flutter build`** - This is for humans only (takes 5-10+ minutes)
- **ALWAYS run `flutter analyze`** - This is fast and catches issues
- **DO run code generation** - After any `@riverpod` or database changes
- **DO check ContentService integration** - All UI text must be dynamic

## Git Commit (Only if user requests)
```bash
git add .
git commit -m "feat: descriptive commit message

🤖 Generated with Claude Code
Co-Authored-By: Claude <noreply@anthropic.com>"
```