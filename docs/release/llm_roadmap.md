# LLM Roadmap - App Store Release Tasks

**Last Updated**: 2025-11-28
**Target**: ASAP Release
**Platform**: iPhone only (initial release)
**Launch Model**: FREE (no subscriptions for v1.0)

This document contains all tasks that the LLM (Claude) should complete before the app is ready for App Store submission. Each task includes specific files to modify and the exact changes needed.

---

## Current App Store Connect Status

The following items are ALREADY configured correctly in ASC:
- App Name: Mealvana Endurance
- Subtitle: Race-Day & Training Nutrition
- Bundle ID: com.milkman.mealvanaendurance
- Primary Category: Health & Fitness
- Secondary Category: Food & Drink
- Age Rating: 9+ (173 countries)
- App Availability: 175 countries
- Keywords: running, nutrition, fueling, marathon, triathlon, carbloading, hydration, electrolytes, gels
- Privacy Labels: Configured (Health, Crash Data, Diagnostics, User ID, Performance, Fitness)
- Promotional Text: Configured
- Description: Configured

**No demo account needed** - App uses anonymous auth, no sign-in required for reviewers.

---

## Critical Blockers (Must Complete)

### 1. Fix Privacy Manifest (PrivacyInfo.xcprivacy)

**File**: `/ios/Runner/PrivacyInfo.xcprivacy`

**Current State**: Incomplete - missing Mixpanel and Sentry declarations

**Required Changes**:
- Add Mixpanel data collection to `NSPrivacyCollectedDataTypes`
- Add Sentry error tracking to `NSPrivacyCollectedDataTypes`
- Declare all API types being accessed
- Set tracking purposes correctly

**Data Types to Declare** (must match ASC privacy labels):
- Health (nutrition, biometrics)
- Fitness (activity data)
- Crash Data (Sentry)
- Other Diagnostic Data
- Product Interaction (usage analytics)
- User ID
- Performance Data

**Reference**: Apple's Privacy Manifest documentation and `/docs/release/andrea/manifest.md`

---

### 2. ~~Fix App Category in Info.plist~~ - NOT NEEDED

**Status**: Already correct in App Store Connect (Health & Fitness + Food & Drink)

The Info.plist category is for macOS apps. iOS apps use App Store Connect categories which are already set correctly.

---

### 3. Enable Survey Time Restrictions

**File**: `/lib/features/feedback/data/feedback_repository.dart`

**Current Code** (broken):
```dart
/// TODO: Re-enable time restrictions for production
Future<bool> hasRecentSurveyResponse(String deviceId) async {
  return false; // Always allow survey submissions during development
}
```

**Required Fix**: Implement proper time-based rate limiting (e.g., one survey per 24 hours or per week) to prevent spam/abuse in production.

---

### 4. Update Push Notification Entitlement

**File**: `/ios/Runner/Runner.entitlements`

**Current Value**:
```xml
<key>aps-environment</key>
<string>development</string>
```

**Required Value** (for production):
```xml
<key>aps-environment</key>
<string>production</string>
```

---

### 5. ~~Add App Tracking Transparency (ATT) Support~~ - LIKELY NOT NEEDED

**Status**: Probably not required

Based on the privacy labels already configured in ASC, tracking is not declared. If Mixpanel is configured without IDFA tracking (which is the modern default), ATT is not required.

**Verify**: Check Mixpanel initialization to confirm no IDFA/advertising identifier usage.

---

## High Priority Tasks

### 6. Clean Up Debug Print Statements

**Scope**: Review all files with `print()` or `debugPrint()` statements

**Action**:
- Keep logging through `LoggingService` (it handles production filtering)
- Remove or convert direct `print()` calls in UI screens to logging service
- Ensure no sensitive data is being logged

**Key Files to Review**:
- All files in `/lib/features/*/presentation/screens/`
- Any file outside logging service using `print()`

---

### 7. Review and Update Minimum iOS Version

**Files**:
- `/ios/Podfile`
- `/ios/Runner.xcodeproj/project.pbxproj`
- `/ios/Flutter/AppframeworkInfo.plist`

**Current**: iOS 12.0

**Recommendation**: Set to iOS 13.0 minimum
- Better compatibility with modern dependencies
- Firebase, AWS Amplify require iOS 13+
- 99%+ market coverage

---

### 8. Verify Production Environment Configuration

**Files**:
- `/.env.prod.local`
- `/lib/shared/services/app_config.dart`

**Checks**:
- [ ] `DEV_MODE_ENABLED=false` in production
- [ ] Correct Supabase production URL and keys
- [ ] Correct Sentry production DSN
- [ ] Correct Mixpanel production token (`bd8fe50bb67b1dd0860351e6297347db`)
- [ ] No test/development credentials in production config

---

### 9. ~~Create Demo Account for Apple Review~~ - NOT NEEDED

**Status**: Not required

App uses Supabase anonymous auth - no sign-in required. Reviewers can use the app without credentials. Lee should uncheck "Sign-in required" in App Store Connect.

---

### 10. Update Version Number for Release

**File**: `/pubspec.yaml`

**Current**: `version: 1.11.0+33`

**For Release**:
- App Store Connect shows version 1.0
- Update pubspec.yaml to match: `version: 1.0.0+1` (or appropriate build number)
- Build number must be unique and higher than any previous uploads

---

## Medium Priority Tasks

### 11. Review Location Permission Descriptions

**File**: `/ios/Runner/Info.plist`

**Current Descriptions**:
- `NSLocationWhenInUseUsageDescription`: "This app uses your location to provide weather forecasts for your running activities."
- `NSLocationAlwaysAndWhenInUseUsageDescription`: "This app uses your location to provide weather forecasts for your running activities."

**Review**:
- Is "Always" location actually needed? If not, remove that key
- Ensure descriptions accurately reflect usage

---

### 12. Verify iPad Support is Disabled

**Since iPhone-only release**:

**File**: `/ios/Runner.xcodeproj/project.pbxproj`

**Check**:
- `TARGETED_DEVICE_FAMILY = 1;` (1 = iPhone only, "1,2" = iPhone + iPad)
- Remove iPad from supported destinations in Xcode if present

---

### 13. Add ITSAppUsesNonExemptEncryption Key

**File**: `/ios/Runner/Info.plist`

**Add Key** (since app only uses HTTPS - exempt):
```xml
<key>ITSAppUsesNonExemptEncryption</key>
<false/>
```

This prevents the "Missing Compliance" warning in App Store Connect and avoids needing to upload encryption documentation.

---

## Future v1.1 Tasks (RevenueCat - NOT for initial release)

### 14. RevenueCat Integration (DEFERRED)

**Status**: Launching FREE first, subscriptions in future update

**When Ready**:
- [ ] Add RevenueCat SDK to pubspec.yaml
- [ ] Configure API keys for production
- [ ] Implement restore purchases
- [ ] Create paywall UI
- [ ] Set up subscription products in App Store Connect
- [ ] Configure RevenueCat dashboard

---

## Low Priority / Nice-to-Have

### 15. Remove Deprecated Files

**Files Identified in Git Status**:
- `FLUTTER_35_MIGRATION.md` - deleted
- Various deleted docs that should be cleaned from history
- Old/deprecated screen files (marked .DEPRECATED)

**Action**: Ensure clean codebase before release

---

### 16. Run Flutter Analyze

**Command**: `flutter analyze`

**Goal**: Zero warnings, zero errors

**Common Issues to Fix**:
- Unused imports
- Unused variables
- Deprecated API usage
- Missing return statements

---

### 17. Run All Tests

**Command**: `flutter test`

**Goal**: All tests passing

**Alternative**: Use `/task-checker` agent for comprehensive checks

---

## Files Summary

### Must Modify:
1. `/ios/Runner/PrivacyInfo.xcprivacy` - Privacy manifest (add Mixpanel/Sentry)
2. `/ios/Runner/Runner.entitlements` - Push notification environment → production
3. `/ios/Runner/Info.plist` - Add ITSAppUsesNonExemptEncryption = false
4. `/lib/features/feedback/data/feedback_repository.dart` - Survey limits
5. `/pubspec.yaml` - Version number to 1.0.0

### Should Review:
6. `/.env.prod.local` - Production config
7. All files with `print()` statements
8. `/ios/Runner/Info.plist` - Location "Always" permission needed?

### May Need Changes:
9. `/ios/Podfile` - iOS minimum version (12→13)
10. `/ios/Runner.xcodeproj/project.pbxproj` - Device family, iOS version

---

## Verification Checklist (LLM to Complete)

After all changes:

- [ ] `flutter analyze` passes with no errors
- [ ] `flutter test` passes
- [ ] Privacy manifest includes all required declarations
- [ ] ITSAppUsesNonExemptEncryption = false added
- [ ] Survey time restrictions are enabled
- [ ] Push notification entitlement set to production
- [ ] No hardcoded development credentials
- [ ] Version number set to 1.0.0+X

---

## Notes for Implementation

1. **Order of Operations**: Complete Critical Blockers first, then High Priority
2. **Testing**: After each change, run `flutter analyze` to catch issues
3. **Commits**: Commit after completing each section for easy rollback
4. **Documentation**: Update this file as tasks are completed

---

*This roadmap was updated based on App Store Connect review on 2025-11-28*
