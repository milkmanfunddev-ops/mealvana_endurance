# Flutter Flavors Implementation Guide

## Overview

This document provides a comprehensive guide for implementing Flutter flavors in the Mealvana Endurance project. Flavors allow multiple variants of the app to be installed simultaneously on a device, each connecting to different backend environments (dev/prod).

## What Are Flutter Flavors?

Flutter flavors are a way to create distinct versions of your app with different configurations, identifiers, and behaviors. They allow you to:

- Install multiple versions of your app on the same device simultaneously
- Connect to different backend environments (development vs production)
- Use separate API keys, analytics projects, and error monitoring
- Customize app icons, names, and bundle identifiers per environment

### Key Distinction: Flavors vs Dart Defines

**Flavors:**
- Affect both Dart code and native platform code (iOS/Android)
- Require platform-specific setup (Xcode schemes, Android product flavors)
- Allow multiple app installations on same device
- Only supported on iOS, macOS, and Android

**Dart Defines:**
- Affect only Dart code
- No platform-specific setup required
- Supported on all platforms including web
- Simpler but less powerful

**Example Usage:**
```bash
# Flavors (requires platform setup)
flutter run --flavor dev

# Dart Defines (Dart-only)
flutter run --dart-define-from-file=.env.dev
```

## Current Environment Configuration Approach

### How It Works Today

Mealvana Endurance currently uses a **runtime environment switching** approach:

1. **Two .env files:**
   - `.env.dev.local` - Development environment (dev Supabase, dev Mixpanel)
   - `.env.prod.local` - Production environment (prod Supabase, prod Mixpanel)

2. **AppConfig service** (`lib/shared/services/app_config.dart`):
   - Determines which .env file to load at app startup
   - Uses `_DEFAULT_DEV_MODE` constant and runtime overrides
   - Loads appropriate environment variables from selected .env file

3. **Runtime switching capability:**
   - Users can switch environments via secret dialog in settings
   - Override stored in SharedPreferences
   - Requires app restart to take effect

4. **Main.dart initialization:**
   ```dart
   // Load dev mode override from SharedPreferences
   await AppConfig.loadDevModeOverride();

   // Determine which env file to load
   final isDevMode = AppConfig.effectiveDevMode;
   final envFileName = isDevMode ? '.env.dev.local' : '.env.prod.local';

   // Load environment variables
   await dotenv.load(fileName: envFileName);

   // Create app configuration
   final config = AppConfig.fromEnv();
   ```

### Bundle Identifiers (Current)

- **iOS Production:** `com.milkman.MealvanaEndurance`
- **Android Production:** `com.milkman.mealvanaendurance`
- **No separate dev/staging identifiers** - single bundle ID for all environments

### Advantages of Current Approach

1. **Runtime flexibility** - Users (and QA) can switch environments without reinstalling
2. **Simple setup** - No complex platform-specific configuration
3. **Single bundle ID** - Maintains existing App Store/Play Store identity
4. **Easy testing** - Developers can quickly test different environments

### Disadvantages of Current Approach

1. **Single installation** - Can't have dev and prod apps installed simultaneously
2. **Production risk** - Possible to accidentally connect prod app to dev backend
3. **No visual distinction** - Can't tell environments apart on home screen
4. **Shared local storage** - Dev and prod data can conflict in Drift database
5. **CI/CD complexity** - Build system must handle environment selection

## Proposed Flavor Approach

### How It Would Work

With flavors, the project would have:

1. **Two separate build variants:**
   - `dev` flavor - Development environment
   - `prod` flavor - Production environment

2. **Platform-specific configurations:**
   - **iOS:** Two Xcode schemes (dev, prod) with separate bundle IDs
   - **Android:** Two product flavors with separate application IDs

3. **Build commands:**
   ```bash
   # Development build
   flutter run --flavor dev
   flutter build ios --flavor dev

   # Production build
   flutter run --flavor prod
   flutter build ios --flavor prod
   ```

4. **Separate bundle identifiers:**
   - iOS Dev: `com.milkman.MealvanaEndurance.dev`
   - iOS Prod: `com.milkman.MealvanaEndurance` (unchanged)
   - Android Dev: `com.milkman.mealvanaendurance.dev`
   - Android Prod: `com.milkman.mealvanaendurance` (unchanged)

### Key Differences: Current vs Proposed

| Aspect | Current (Runtime Switching) | Proposed (Flavors) |
|--------|---------------------------|-------------------|
| **Multiple installations** | ❌ No - single app | ✅ Yes - dev and prod apps side-by-side |
| **Bundle IDs** | Single bundle ID | Separate bundle IDs per flavor |
| **Environment switching** | ✅ Runtime (no reinstall) | ❌ Requires different build |
| **Visual distinction** | ❌ Same icon | ✅ Different icons/names possible |
| **Local storage** | Shared Drift database | Separate databases per flavor |
| **Platform setup** | ✅ Simple | ❌ Complex (Xcode schemes, Android product flavors) |
| **CI/CD** | Runtime configuration | Build-time configuration |
| **App Store identity** | Single identity | Separate dev app possible |
| **Production safety** | ⚠️ User could misconfigure | ✅ Hard separation |

## Benefits of Implementing Flavors

### Development & Testing

1. **Side-by-side installations:**
   - Test production build while developing features
   - QA can have both versions installed
   - Compare behavior between environments instantly

2. **Hard environment separation:**
   - No risk of accidentally connecting prod build to dev backend
   - Complete isolation of dev/prod data
   - Separate Drift databases prevent data conflicts

3. **Visual distinction:**
   - Different app icons (e.g., orange icon for dev, blue for prod)
   - Different app names on home screen
   - Immediately identify which environment you're in

### CI/CD & Deployment

1. **Clear build intentions:**
   - CI/CD explicitly specifies flavor in build command
   - No runtime configuration needed
   - Reduced chance of misconfiguration

2. **TestFlight/Internal testing:**
   - Can distribute dev flavor to internal testers
   - Separate from production App Store listing
   - Beta testers can't accidentally use prod backend

### Analytics & Monitoring

1. **Clean separation:**
   - Dev and prod analytics don't mix
   - Dev flavor uses dev Mixpanel project
   - Prod flavor uses prod Mixpanel project

2. **Error tracking:**
   - Sentry errors cleanly separated by flavor
   - Dev crashes don't pollute production monitoring

## Trade-offs & Considerations

### Lost Capabilities

1. **Runtime environment switching:**
   - Current: Users can switch dev/prod in settings
   - Proposed: Must install different builds to switch
   - **Impact:** Less flexible for QA and debugging

2. **Single app simplicity:**
   - Current: One app to manage, one bundle ID
   - Proposed: Two apps, two bundle IDs, more complexity
   - **Impact:** More cognitive overhead, more CI/CD configuration

### Increased Complexity

1. **Platform configuration:**
   - Must maintain Xcode schemes for iOS
   - Must maintain Android product flavors
   - More files to manage in native projects

2. **CI/CD workflows:**
   - Must build each flavor separately
   - More build time and resources
   - More complex build scripts

3. **App Store management:**
   - Could have separate dev app listing (or TestFlight only)
   - More provisioning profiles to manage (iOS)
   - More keystore management (Android)

### Critical Blocker: Shorebird Compatibility

**IMPORTANT:** Shorebird Code Push may have limitations with flavors.

- Mealvana Endurance uses Shorebird for OTA updates
- Shorebird creates separate releases per flavor
- Need to verify if dev and prod flavors can share releases
- May require separate Shorebird projects per flavor

**Action Required:** Test Shorebird compatibility before committing to flavors implementation.

## Production Bundle ID Preservation

**CRITICAL:** Production bundle IDs must never change:

- **iOS Prod:** `com.milkman.MealvanaEndurance` (current)
- **Android Prod:** `com.milkman.mealvanaendurance` (current)

App stores use bundle IDs to identify apps. Changing the production bundle ID would:
- Create a new App Store listing (losing all reviews, downloads, etc.)
- Break existing user installations
- Require users to download a "new" app

**Implementation Note:** Only dev flavor gets modified bundle ID (append `.dev` suffix).

## High-Level Architecture

### Flavor Configuration Flow

```
Build Command (--flavor dev/prod)
         ↓
Platform Configuration
         ↓
   ┌─────────┴─────────┐
   ↓                   ↓
iOS Scheme         Android Product Flavor
   ↓                   ↓
Bundle ID          Application ID
   ↓                   ↓
Launch correct .env file
   ↓
AppConfig.fromEnv()
   ↓
Supabase, Mixpanel, Sentry initialized
```

### Integration with Existing Architecture

**Andrea Bizzotto's Initialization Pattern:**

Flavors integrate cleanly with Andrea's pattern:

1. **main.dart:**
   - Determine flavor from platform
   - Load appropriate .env file based on flavor
   - Initialize Sentry and Supabase (non-recoverable)

2. **AppConfig:**
   - Read environment variables from flavor-specific .env
   - Provide configuration to app via Riverpod override

3. **RootAppWidget → AppStartupWidget:**
   - Initialize recoverable dependencies (Drift, analytics)
   - Works identically regardless of flavor

**Key Insight:** Flavors only affect main.dart and platform configuration. Rest of Andrea's architecture remains unchanged.

### File Changes Required

**iOS Changes:**
- `ios/Runner.xcodeproj/project.pbxproj` - Add schemes and build configurations
- `ios/Runner/Info.plist` - Flavor-specific bundle IDs
- New `.xcconfig` files per flavor
- New app icon sets per flavor (optional)

**Android Changes:**
- `android/app/build.gradle.kts` - Add product flavors
- New `AndroidManifest.xml` per flavor (in flavor directories)
- New app icon sets per flavor (optional)

**Flutter Changes:**
- `lib/main.dart` - Detect flavor and load correct .env
- `.env.dev.local` and `.env.prod.local` - No changes needed
- `lib/shared/services/app_config.dart` - Simplify (remove runtime override logic)

**CI/CD Changes:**
- `codemagic.yaml` - Add flavor-specific workflows
- `.github/workflows/` - Add flavor to build commands
- Shorebird commands - Add flavor specification

## Recommendation

### Decision Framework

**Implement Flavors If:**
- Team frequently needs dev and prod apps installed simultaneously
- Production safety is paramount (no risk of misconfiguration)
- QA team benefits from visual distinction between environments
- Willing to accept increased CI/CD complexity
- Shorebird testing confirms flavor compatibility

**Keep Current Runtime Approach If:**
- Runtime flexibility is more valuable than hard separation
- Team prefers simplicity over strict isolation
- Single bundle ID management is preferred
- Shorebird has flavor limitations
- CI/CD overhead outweighs benefits

### Hybrid Approach (Recommended)

Consider implementing flavors for **iOS only** initially:

1. **iOS:** Use flavors (dev and prod)
   - iOS users can install both versions
   - Leverages TestFlight for dev distribution
   - Maintains separate provisioning profiles

2. **Android:** Keep runtime switching
   - Android's sideloading makes testing easier
   - Avoids complex Android flavor setup
   - Reduces CI/CD overhead

This approach:
- Gets primary benefit (side-by-side installations for iOS team/QA)
- Reduces complexity (Android stays simple)
- Easier rollback if issues arise
- Can add Android flavors later if valuable

## Next Steps

1. **Review notes.md** - Detailed technical analysis of codebase
2. **Review roadmap.md** - Step-by-step implementation plan
3. **Test Shorebird compatibility** - Critical blocker validation
4. **Make decision** - Flavors vs current approach vs hybrid
5. **If proceeding:** Follow roadmap.md implementation phases

## Additional Resources

- **Andrea Bizzotto's Flavor Guide:** `/docs/flavors/andrea_rizzoto_flavor.txt`
- **Official Flutter Docs:** [Flavors in Flutter](https://docs.flutter.dev/deployment/flavors)
- **Flutter Flavorizr Package:** [pub.dev/packages/flutter_flavorizr](https://pub.dev/packages/flutter_flavorizr)
- **Shorebird Flavors:** [Shorebird Flavors Documentation](https://docs.shorebird.dev/)
- **Project Technical Docs:** `/docs/technical/README.md`
- **Andrea's Initialization:** `/docs/technical/andrea/andrea_initialization.txt`

---

**Last Updated:** 2025-12-16
**Status:** Planning Phase - No implementation yet
