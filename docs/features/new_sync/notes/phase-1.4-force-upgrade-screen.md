# Phase 1.4: ForceUpgradeScreen Implementation

**Date**: 2026-01-18
**Agent**: claude-sonnet-4.5-20260118
**Status**: ✅ Complete

## Summary

Created the ForceUpgradeScreen component that blocks the app when a mandatory update is required. This screen is displayed when the version check determines the user's app version is below the minimum required version set in the `app_config` table.

## Files Created

### 1. `/lib/features/app_startup/presentation/screens/force_upgrade_screen.dart`

**Features:**
- Displays current version vs required version
- Platform-specific app store URLs (iOS, Android, Web)
- Uses Kyle's Design System (AppColors, AppTextStyles, AppSpacing)
- Blocks back navigation with `PopScope(canPop: false)`
- Opens appropriate app store with `url_launcher` package

**Design Decisions:**
- Used `PopScope` (Flutter 3.12+) instead of deprecated `WillPopScope`
- Added web support with fallback URL
- Followed existing pattern from WelcomeScreen for theming
- Used KylePrimaryButton for consistency
- Centered layout with warning icon (system_update)

**App Store URLs (Placeholders):**
```dart
// iOS: https://apps.apple.com/app/id123456789
// Android: https://play.google.com/store/apps/details?id=com.mealvana.endurance
// Web: https://app.mealvana.com
```

**Note:** These URLs need to be updated with real values when:
1. iOS App Store listing is created (replace app ID)
2. Android package name is confirmed
3. Web app URL is finalized

### 2. `/lib/shared/core/app_router.dart` (Modified)

**Changes:**
- Added import for ForceUpgradeScreen
- Added `/force-upgrade` route
- Route accepts version parameters via `extra` map:
  - `currentVersion`: User's installed app version
  - `requiredVersion`: Minimum version from app_config table

**Example Navigation:**
```dart
context.go('/force-upgrade', extra: {
  'currentVersion': '1.11.0',
  'requiredVersion': '1.12.0',
});
```

### 3. `/test/new_sync/force_upgrade_screen_test.dart`

**Test Coverage (6 tests, all passing):**
1. ✅ Displays current version
2. ✅ Displays required version
3. ✅ Displays Update Now button
4. ✅ Displays Update Required title
5. ✅ Displays system update icon
6. ✅ Blocks back navigation with PopScope

**Test Results:**
```
00:04 +6: All tests passed!
```

## Integration Points

### Next Steps (Phase 1.5)
The ForceUpgradeScreen is ready to be integrated into the app startup flow:

1. **VersionCheckService** will check `app_config.min_app_version`
2. If current version < min version → Navigate to `/force-upgrade`
3. User must update app to continue (no bypass)

### Expected Flow
```
App Launch
    ↓
appStartupProvider
    ↓
VersionCheckService.checkVersion()
    ↓
VersionCheckResult.updateRequired?
    ├── Yes → context.go('/force-upgrade')
    └── No → Continue normal startup
```

## Technical Notes

### PopScope vs WillPopScope
- Flutter 3.12+ deprecates `WillPopScope`
- `PopScope` is the new API with improved predictive back support
- `canPop: false` completely blocks back navigation on Android

### url_launcher Package
- Already in pubspec.yaml (version ^6.2.0)
- No additional dependencies needed
- Works on iOS, Android, and Web

### Theme Consistency
- Uses Kyle's Design System throughout
- Dark theme (blackberry background)
- Orange warning icon
- Sansita font for title, Apercu for body text
- Proper spacing with AppSpacing constants

## Verification

### Manual Testing Checklist
- [ ] Screen displays correctly on iOS
- [ ] Screen displays correctly on Android
- [ ] Screen displays correctly on Web
- [ ] Back button is blocked (Android)
- [ ] Back swipe is blocked (iOS)
- [ ] Update button opens App Store (iOS)
- [ ] Update button opens Play Store (Android)
- [ ] Update button opens web URL (Web)
- [ ] Version numbers display correctly
- [ ] Theme matches rest of app

### Automated Testing
- ✅ All 6 widget tests passing
- ✅ No integration tests needed (UI-only component)

## Known Limitations

1. **App Store URLs are placeholders** - Need to update before production:
   - iOS: Replace `id123456789` with real App Store ID
   - Android: Confirm package name `com.mealvana.endurance`
   - Web: Confirm final web app URL

2. **No version comparison logic** - This screen assumes VersionCheckService has already determined an update is required. It just displays the message.

3. **No retry mechanism** - If user dismisses the App/Play Store, they're still blocked. This is intentional (forced update).

## Files Modified

1. `lib/shared/core/app_router.dart` - Added force-upgrade route
2. `docs/new_sync/checklist.md` - Marked task 1.4 complete

## Files Created

1. `lib/features/app_startup/presentation/screens/force_upgrade_screen.dart`
2. `test/new_sync/force_upgrade_screen_test.dart`
3. `docs/new_sync/notes/phase-1.4-force-upgrade-screen.md` (this file)

## Commit Message

```
feat(sync): add ForceUpgradeScreen for mandatory updates

- Create screen with version display and store links
- Add platform-specific app store URLs
- Block back navigation with PopScope
- Add to GoRouter routes
- Add widget tests (6 tests, all passing)

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
```

## Completion Status

✅ **Phase 1.4 Complete**

**Next Task:** Phase 1.5 - Integrate Version Check into Startup
