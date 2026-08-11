# Flutter Flavors Technical Notes

## Overview

This document contains detailed technical findings from analyzing the Mealvana Endurance codebase for implementing Flutter flavors. It identifies files to modify, existing patterns to leverage, potential conflicts, and critical questions to answer.

---

## Current Codebase Analysis

### Environment Configuration System

**Current Implementation:**

The app uses a sophisticated runtime environment switching system:

**1. AppConfig Service** (`lib/shared/services/app_config.dart`):
```dart
// Environment control constant
static const bool _DEFAULT_DEV_MODE = false;

// Runtime override (persisted in SharedPreferences)
static bool? _runtimeOverride;

// Effective dev mode with priority order:
// 1. Runtime override (SharedPreferences)
// 2. kDebugMode (debug builds)
// 3. _DEFAULT_DEV_MODE (release builds)
static bool get effectiveDevMode { ... }
```

**Key Features:**
- Three-tier priority for determining environment
- SharedPreferences persistence for user overrides
- Separate .env files: `.env.dev.local` and `.env.prod.local`
- Loads all configuration from selected .env file

**2. Main.dart Initialization** (`lib/main.dart`):
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

**3. Environment Switcher UI** (`lib/shared/widgets/environment_switcher_dialog.dart`):
- Secret dialog accessible from settings
- Shows current environment (Supabase, Mixpanel, Sentry)
- Allows runtime switching (requires app restart)
- Persists choice to SharedPreferences

### Andrea Bizzotto Initialization Pattern

**Current Flow:**
```
main()
  ↓
AppConfig.loadDevModeOverride() [SharedPreferences]
  ↓
Load .env.dev.local or .env.prod.local
  ↓
Sentry.init() [Non-recoverable]
  ↓
Supabase.initialize() [Non-recoverable]
  ↓
runApp(ProviderScope → RootAppWidget)
  ↓
RootAppWidget [MaterialApp.router with builder]
  ↓
AppStartupWidget [Manages appStartupProvider]
  ↓
appStartupProvider [Recoverable: Drift DB, analytics, session]
```

**Key Insight:** Flavors would only affect the .env file selection in main(). Andrea's pattern remains intact.

---

## Files Requiring Modification

### iOS Configuration Files

#### 1. Xcode Project File (CRITICAL)

**File:** `ios/Runner.xcodeproj/project.pbxproj`

**Current State:**
- Single "Runner" scheme
- No flavor configurations
- Single bundle ID: `com.milkman.MealvanaEndurance`

**Required Changes:**
- Add two build configurations per mode:
  - Dev-Debug, Dev-Release, Dev-Profile
  - Prod-Debug, Prod-Release, Prod-Profile
- Create two schemes:
  - `dev` - Uses Dev build configurations
  - `prod` - Uses Prod build configurations
- Configure scheme-specific bundle IDs via .xcconfig files

**Complexity:** HIGH
- Direct XML editing of .pbxproj is error-prone
- Xcode GUI manipulation preferred but complex
- Flutter Flavorizr can automate (see tool recommendation)

#### 2. XCConfig Files

**New Files to Create:**

Development configs:
- `ios/Flutter/DevDebug.xcconfig`
- `ios/Flutter/DevRelease.xcconfig`
- `ios/Flutter/DevProfile.xcconfig`

Production configs:
- `ios/Flutter/ProdDebug.xcconfig`
- `ios/Flutter/ProdRelease.xcconfig`
- `ios/Flutter/ProdProfile.xcconfig`

**Example DevDebug.xcconfig:**
```xcconfig
#include "Debug.xcconfig"

// Flutter build mode
FLUTTER_BUILD_MODE=debug

// Flavor-specific bundle identifier
PRODUCT_BUNDLE_IDENTIFIER=com.milkman.MealvanaEndurance.dev

// Flavor-specific app name
PRODUCT_NAME=Mealvana Dev

// Icon asset catalog (optional)
ASSETCATALOG_COMPILER_APPICON_NAME=DevAppIcon
```

**Example ProdRelease.xcconfig:**
```xcconfig
#include "Release.xcconfig"

// Flutter build mode
FLUTTER_BUILD_MODE=release

// Production bundle identifier (UNCHANGED)
PRODUCT_BUNDLE_IDENTIFIER=com.milkman.MealvanaEndurance

// Production app name
PRODUCT_NAME=Mealvana

// Icon asset catalog (optional)
ASSETCATALOG_COMPILER_APPICON_NAME=AppIcon
```

#### 3. Info.plist

**File:** `ios/Runner/Info.plist`

**Current State:**
- Hardcoded bundle identifier
- Hardcoded app name

**Required Changes:**
- Replace hardcoded values with variables:
  ```xml
  <key>CFBundleIdentifier</key>
  <string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>

  <key>CFBundleName</key>
  <string>$(PRODUCT_NAME)</string>
  ```

#### 4. Entitlements (Optional)

**File:** `ios/Runner/Runner.entitlements`

**Current State:**
- Associated domains for Sign in with Apple
- App groups (if used)

**Potential Changes:**
- May need flavor-specific entitlements files if domains differ
- Likely can keep single file shared across flavors

#### 5. App Icons (Optional)

**Directory:** `ios/Runner/Assets.xcassets/`

**Current:**
- Single `AppIcon.appiconset`

**Optional Enhancement:**
- Create `DevAppIcon.appiconset` with orange/different icon
- Update .xcconfig files to reference different icon sets
- Helps visually distinguish dev vs prod builds

### Android Configuration Files

#### 1. Build Gradle (PRIMARY FILE)

**File:** `android/app/build.gradle.kts`

**Current State:**
```kotlin
android {
    namespace = "com.milkman.mealvanaendurance"
    defaultConfig {
        applicationId = "com.milkman.mealvanaendurance"
        // ...
    }
}
```

**Required Changes:**

Add flavor dimensions and product flavors:
```kotlin
android {
    namespace = "com.milkman.mealvanaendurance"

    flavorDimensions += "environment"

    productFlavors {
        create("dev") {
            dimension = "environment"
            applicationId = "com.milkman.mealvanaendurance.dev"
            resValue("string", "app_name", "Mealvana Dev")
            // Optional: different icon
            manifestPlaceholders["appIcon"] = "@mipmap/ic_launcher_dev"
        }

        create("prod") {
            dimension = "environment"
            // Keep production ID unchanged (CRITICAL)
            applicationId = "com.milkman.mealvanaendurance"
            resValue("string", "app_name", "Mealvana")
            manifestPlaceholders["appIcon"] = "@mipmap/ic_launcher"
        }
    }
}
```

**Complexity:** MEDIUM
- Kotlin DSL syntax (newer Flutter projects)
- Clear structure, easier than iOS
- Well-documented by Flutter community

#### 2. AndroidManifest.xml Files

**Current File:** `android/app/src/main/AndroidManifest.xml`

**New Structure:**
```
android/app/src/
├── main/
│   └── AndroidManifest.xml (shared config)
├── dev/
│   └── AndroidManifest.xml (dev-specific overrides)
└── prod/
    └── AndroidManifest.xml (prod-specific overrides)
```

**Shared AndroidManifest.xml:**
- Keep most configuration here
- Use `${applicationId}` placeholder
- Use `@string/app_name` for app label

**Flavor-specific manifests:**
- Override only flavor-specific values
- Typically minimal (just app name/icon if not using resValue)

#### 3. App Icons (Optional)

**Directories:**
```
android/app/src/dev/res/
├── mipmap-hdpi/ic_launcher_dev.png
├── mipmap-mdpi/ic_launcher_dev.png
├── mipmap-xhdpi/ic_launcher_dev.png
├── mipmap-xxhdpi/ic_launcher_dev.png
└── mipmap-xxxhdpi/ic_launcher_dev.png

android/app/src/prod/res/
└── (uses main/res icons)
```

### Flutter/Dart Code Changes

#### 1. Main Entry Point

**File:** `lib/main.dart`

**Current Implementation:**
```dart
// Load dev mode override from SharedPreferences
await AppConfig.loadDevModeOverride();

// Determine which env file to load based on dev mode
final isDevMode = AppConfig.effectiveDevMode;
final envFileName = isDevMode ? '.env.dev.local' : '.env.prod.local';

// Load environment variables from appropriate file
await dotenv.load(fileName: envFileName);
```

**With Flavors:**

Option A - Use appFlavor constant (requires platform setup):
```dart
import 'package:flutter/services.dart' show appFlavor;

Future<void> main() async {
  runZonedGuarded(() async {
    final mainStopwatch = Stopwatch()..start();

    SentryWidgetsFlutterBinding.ensureInitialized();

    // Determine env file from flavor
    final flavor = appFlavor ?? 'prod'; // Default to prod if null
    final envFileName = '.env.$flavor.local'; // .env.dev.local or .env.prod.local

    // Load environment variables
    await dotenv.load(fileName: envFileName);

    // Create app configuration
    final config = AppConfig.fromEnv();

    // Initialize Sentry and Supabase
    await SentryFlutter.init(/* ... */);
    await _runMealvanaApp(config, mainStopwatch);
  }, (exception, stackTrace) async {
    await Sentry.captureException(exception, stackTrace: stackTrace);
  });
}
```

Option B - Use String.fromEnvironment (simpler, requires --dart-define):
```dart
Future<void> main() async {
  runZonedGuarded(() async {
    final mainStopwatch = Stopwatch()..start();

    SentryWidgetsFlutterBinding.ensureInitialized();

    // Read flavor from dart-define
    const flavor = String.fromEnvironment('FLAVOR', defaultValue: 'prod');
    final envFileName = '.env.$flavor.local';

    // Load environment variables
    await dotenv.load(fileName: envFileName);

    // Rest of initialization...
  }, (exception, stackTrace) async {
    await Sentry.captureException(exception, stackTrace: stackTrace);
  });
}
```

**Build Commands:**
```bash
# Option A (native flavors)
flutter run --flavor dev

# Option B (dart-define)
flutter run --flavor dev --dart-define=FLAVOR=dev

# Recommended: Combine both for compatibility
flutter run --flavor dev --dart-define=FLAVOR=dev
```

#### 2. AppConfig Service

**File:** `lib/shared/services/app_config.dart`

**Current Code to REMOVE:**
```dart
// Remove runtime override logic
static const bool _DEFAULT_DEV_MODE = false;
static bool? _runtimeOverride;
static bool get effectiveDevMode { ... }
static Future<void> setDevModeOverride(bool value) async { ... }
static Future<void> clearDevModeOverride() async { ... }
static Future<void> loadDevModeOverride() async { ... }
```

**Simplified with Flavors:**
```dart
class AppConfig {
  const AppConfig({
    required this.supabaseUrl,
    required this.supabaseAnonKey,
    required this.supabasePublishableKey,
    required this.supabaseSecretKey,
    required this.sentryDsn,
    required this.sentryEnvironment,
    required this.mixpanelProjectToken,
    required this.usdaApiKey,
    required this.wiredashProjectId,
    required this.wiredashSecret,
    required this.oneSignalAppId,
    required this.flavor, // NEW: store flavor
    this.enableDebugLogging = false,
    this.enableSentryProfiling = false,
  });

  // Configuration properties
  final String supabaseUrl;
  // ... other properties ...

  // NEW: Flavor identification
  final String flavor; // 'dev' or 'prod'

  // Simplified environment checks
  bool get isProduction => flavor == 'prod';
  bool get isDevelopment => flavor == 'dev';

  // Factory for loading configuration from .env file
  // Now much simpler - flavor determined by main.dart
  factory AppConfig.fromEnv(String flavor) {
    return AppConfig(
      flavor: flavor,

      // Read all configuration from loaded .env file
      supabaseUrl: dotenv.get('SUPABASE_URL', fallback: ''),
      supabaseAnonKey: dotenv.get('SUPABASE_ANON_KEY', fallback: ''),
      // ... rest of config ...

      // Debug settings
      enableDebugLogging: kDebugMode,
      enableSentryProfiling: !kDebugMode,
    );
  }

  // Keep forTesting factory for tests
  factory AppConfig.forTesting({ /* ... */ }) { /* ... */ }
}
```

**Benefits:**
- Removes ~50 lines of complex runtime switching logic
- No SharedPreferences dependency
- Flavor determined at build time (simpler)
- No possibility of misconfiguration

#### 3. Environment Switcher Dialog

**File:** `lib/shared/widgets/environment_switcher_dialog.dart`

**Decision Required:**

Option A - Remove entirely:
- Flavors make runtime switching impossible
- Users install different builds to switch
- Simpler codebase

Option B - Keep as read-only info display:
- Show current flavor and configuration
- Remove switching capability
- Useful for debugging

**Recommendation:** Keep as read-only with flavor info:
```dart
class EnvironmentInfoDialog extends StatelessWidget {
  final AppConfig config;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Environment Info'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildInfoRow('Flavor', config.flavor),
          _buildInfoRow('Supabase', config.supabaseUrl),
          _buildInfoRow('Mixpanel', config.mixpanelProjectToken),
          _buildInfoRow('Sentry', config.sentryEnvironment),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
```

#### 4. Environment Indicator

**File:** `lib/shared/widgets/environment_indicator.dart`

**Likely Changes:**
- Update to read flavor from AppConfig
- Show "DEV" or "PROD" badge based on flavor
- No significant structural changes

### CI/CD Configuration Changes

#### 1. Codemagic Workflows

**File:** `codemagic.yaml`

**Current Workflows:**
- `integration-tests` - Runs tests on dev environment
- `ios-release-shorebird` - Builds iOS release
- `android-release-shorebird` - Builds Android release

**Required Changes:**

Add flavor-specific workflows:

```yaml
workflows:
  # iOS Dev Build
  ios-dev-shorebird:
    name: iOS Dev Build (Shorebird)
    environment:
      groups:
        - supabase_dev
      vars:
        FLAVOR: dev
    scripts:
      - *install_shorebird
      - *flutter_pub_get
      - *run_build_runner
      - name: Build iOS Dev with Shorebird
        script: |
          shorebird release ios \
            --flavor dev \
            --dart-define=FLAVOR=dev

  # iOS Prod Build
  ios-prod-shorebird:
    name: iOS Prod Build (Shorebird)
    environment:
      groups:
        - supabase_prod
      vars:
        FLAVOR: prod
    scripts:
      - *install_shorebird
      - *flutter_pub_get
      - *run_build_runner
      - name: Build iOS Prod with Shorebird
        script: |
          shorebird release ios \
            --flavor prod \
            --dart-define=FLAVOR=prod

  # Android Dev Build
  android-dev-shorebird:
    name: Android Dev Build (Shorebird)
    environment:
      groups:
        - supabase_dev
      vars:
        FLAVOR: dev
    scripts:
      - *install_shorebird
      - *flutter_pub_get
      - *run_build_runner
      - name: Build Android Dev with Shorebird
        script: |
          shorebird release android \
            --flavor dev \
            --dart-define=FLAVOR=dev

  # Android Prod Build
  android-prod-shorebird:
    name: Android Prod Build (Shorebird)
    environment:
      groups:
        - supabase_prod
      vars:
        FLAVOR: prod
    scripts:
      - *install_shorebird
      - *flutter_pub_get
      - *run_build_runner
      - name: Build Android Prod with Shorebird
        script: |
          shorebird release android \
            --flavor prod \
            --dart-define=FLAVOR=prod
```

**Complexity Increase:**
- Workflows double (4 flavor builds vs 2 current builds)
- Need separate environment variable groups per flavor
- More maintenance overhead

#### 2. GitHub Actions

> **Stale (2026-05-22):** `deploy-dev.yml` / `deploy-prod.yml` were deleted in `b2f86b4f`;
> backend deploys are manual now (see `/docs/deployment/README.md`). Current test workflow
> is `tests-selfhosted.yml`.

**Files (historical):**
- `.github/workflows/deploy-dev.yml`
- `.github/workflows/deploy-prod.yml`
- `.github/workflows/test.yml`

**Required Changes:**

Add flavor flags to build/test commands:

```yaml
# deploy-dev.yml
- name: Run integration tests
  run: |
    flutter test integration_test/test_runner.dart \
      --flavor dev \
      --dart-define=FLAVOR=dev

# deploy-prod.yml (if exists)
- name: Run integration tests
  run: |
    flutter test integration_test/test_runner.dart \
      --flavor prod \
      --dart-define=FLAVOR=prod
```

**Impact:** Minimal - just add flavor flags to existing commands

---

## Existing Patterns to Leverage

### 1. AppConfig + Riverpod Override Pattern

**Current Pattern (EXCELLENT for flavors):**

```dart
// main.dart
final config = AppConfig.fromEnv();

runApp(
  ProviderScope(
    overrides: [
      appConfigProvider.overrideWithValue(config),
    ],
    child: const RootAppWidget(),
  ),
);
```

**Why This Works Perfectly:**
- Configuration loaded once at startup
- Provided to entire app via Riverpod
- No global variables or singletons
- Easy to test with different configs

**With Flavors:**
```dart
// Load flavor-specific .env
await dotenv.load(fileName: '.env.$flavor.local');

// Create config with flavor
final config = AppConfig.fromEnv(flavor);

// Provide to app (same pattern)
runApp(
  ProviderScope(
    overrides: [
      appConfigProvider.overrideWithValue(config),
    ],
    child: const RootAppWidget(),
  ),
);
```

### 2. .env File Structure

**Current Structure (PERFECT for flavors):**
```
.env.dev.local   # Development environment
.env.prod.local  # Production environment
```

**No Changes Needed:**
- File naming already matches flavor names
- Just change selection logic in main.dart
- All configuration stays in .env files
- No hardcoded values in platform config

### 3. Drift Database Initialization

**Current Pattern:**
```dart
// appStartupProvider initializes Drift database
// Separate databases per environment via path
```

**With Flavors:**
- Each flavor automatically gets separate database
- iOS: Different bundle ID → different app documents directory
- Android: Different application ID → different app data directory
- No code changes needed - happens automatically

### 4. Sentry Environment Tags

**Current Pattern:**
```dart
options.environment = config.sentryEnvironment;
```

**With Flavors:**
- Each .env file already specifies environment
- `.env.dev.local`: `SENTRY_ENVIRONMENT=development`
- `.env.prod.local`: `SENTRY_ENVIRONMENT=production`
- No changes needed - configuration is perfect

---

## Potential Conflicts & Blockers

### 1. Shorebird Code Push (CRITICAL BLOCKER)

**Issue:** Shorebird may have flavor-specific limitations.

**Questions to Answer:**
1. Can Shorebird create releases for multiple flavors?
2. Are releases per flavor or shared across flavors?
3. Can dev and prod flavors receive different patches?
4. Does each flavor need separate Shorebird app ID?

**Testing Required:**
```bash
# Test creating releases for each flavor
shorebird release ios --flavor dev
shorebird release ios --flavor prod

# Test patching each flavor
shorebird patch ios --flavor dev
shorebird patch ios --flavor prod

# Check if releases are isolated
shorebird releases --flavor dev
shorebird releases --flavor prod
```

**Potential Workaround:**
- If Shorebird doesn't support flavors well:
  - Keep prod flavor for Shorebird releases
  - Build dev flavor without Shorebird
  - Use standard Flutter build for dev

**Documentation to Review:**
- [Shorebird Flavors Documentation](https://docs.shorebird.dev/)
- Check GitHub issues for flavor compatibility

### 2. Firebase Configuration

**Current State:**
- `android/app/google-services.json` - Single Firebase config
- `ios/Runner/GoogleService-Info.plist` - Single Firebase config

**With Flavors:**
- Need separate Firebase projects for dev and prod? OR
- Use same Firebase project with different configs? OR
- No Firebase (doesn't appear to be used for core features)

**Investigation Required:**
- Check if Firebase is actively used
- Determine if separate projects needed
- If needed, add flavor-specific Firebase files:
  ```
  android/app/src/dev/google-services.json
  android/app/src/prod/google-services.json
  ios/Runner/dev/GoogleService-Info.plist
  ios/Runner/prod/GoogleService-Info.plist
  ```

**Note from codemagic.yaml:**
```yaml
# Google Services plugin for Firebase (required for OneSignal push notifications)
id("com.google.gms.google-services")
```
Firebase is used for OneSignal push notifications setup.

### 3. Sign in with Apple

**File:** `ios/Runner/Runner.entitlements`

**Current:**
```xml
<key>com.apple.developer.applesignin</key>
<array>
  <string>Default</string>
</array>
```

**With Flavors:**
- Dev flavor needs separate Apple service ID? OR
- Can share service ID across flavors?

**Action Required:**
- Test Sign in with Apple on dev flavor
- Verify associated domains work with dev bundle ID
- May need to register dev bundle ID in Apple Developer portal

### 4. Deep Links & Universal Links

**Potential Issue:**
- Associated domains tied to bundle ID
- Dev flavor has different bundle ID
- May need separate domain configuration

**Files to Check:**
- `ios/Runner/Runner.entitlements`
- `android/app/src/main/AndroidManifest.xml`

**Resolution:**
- Configure separate domains for dev flavor? OR
- Only production flavor supports deep links? OR
- Use wildcard configuration if possible

### 5. Local Notification Channels

**Potential Issue:**
- Android notification channels registered with application ID
- Different app IDs might need different channel setup

**Files to Check:**
- `android/app/src/main/kotlin/com/milkman/mealvanaendurance/MainActivity.kt`
- Notification setup code in Flutter

**Likely:** No issue - channels are app-specific and will work fine per flavor.

### 6. Keychain Sharing (iOS)

**If Used:**
- Keychain access groups tied to team ID + bundle ID
- Dev flavor needs separate keychain group

**Check:**
- `ios/Runner/Runner.entitlements`
- Look for `keychain-access-groups` key

**Likely:** Not used, but verify.

---

## Critical Questions Before Implementation

### Business Questions

1. **Value Proposition:**
   - Does team actually need dev and prod apps installed simultaneously?
   - How often does this scenario occur?
   - Is visual distinction (different icons) valuable?

2. **Trade-off Acceptance:**
   - Is team willing to lose runtime environment switching capability?
   - Is increased CI/CD complexity acceptable?
   - Can we justify the implementation effort?

3. **Rollout Strategy:**
   - iOS-only first, or both platforms?
   - How to distribute dev flavor (TestFlight, Codemagic artifacts)?
   - Internal testing process changes?

### Technical Questions

1. **Shorebird Compatibility (MOST CRITICAL):**
   - Does Shorebird support flavors?
   - Are releases isolated per flavor?
   - Any workarounds if not supported?

2. **Firebase Configuration:**
   - Is Firebase actively used? For what?
   - Need separate Firebase projects?
   - OneSignal configuration per flavor?

3. **Sign in with Apple:**
   - Works with dev bundle ID?
   - Need separate Apple service ID registration?

4. **App Store Distribution:**
   - Keep dev flavor internal (TestFlight only)?
   - Or separate App Store listing for dev?
   - Provisioning profile management strategy?

5. **Testing Infrastructure:**
   - Integration tests work with flavors?
   - Test fixtures need flavor-awareness?
   - E2E tests run on both flavors?

---

## Platform-Specific Considerations

### iOS Specifics

**Xcode Scheme Complexity:**
- Xcode schemes control build settings
- Creating schemes manually is error-prone
- Flutter Flavorizr can automate but modifies many files
- Alternative: Manual creation via Xcode GUI (preferred for existing projects)

**Provisioning Profiles:**
- Dev flavor needs new App ID registration in Apple Developer portal
- Need separate provisioning profiles (development, distribution)
- Wildcard profiles might work but not recommended

**TestFlight Distribution:**
- Can have separate TestFlight groups per flavor
- Dev flavor: Internal testers only
- Prod flavor: External testers + production

**Bundle ID Management:**
- Production bundle ID must never change
- Dev bundle ID: Append `.dev` suffix
- Format: `com.milkman.MealvanaEndurance.dev`

### Android Specifics

**Product Flavor Complexity:**
- Android flavors are simpler than iOS schemes
- Clear dimension-based structure
- Well-supported by Gradle

**Application ID:**
- Production application ID must never change
- Dev application ID: Append `.dev` suffix
- Format: `com.milkman.mealvanaendurance.dev`

**Play Store Distribution:**
- Can have separate Play Store listings per flavor? (Yes)
- Or keep dev flavor internal (Firebase App Distribution, Codemagic)
- Internal testing tracks per flavor

**Keystore Management:**
- Need separate keystore for dev flavor? OR
- Use same keystore with different alias?
- CI/CD needs access to appropriate keystores

---

## Tool Recommendations

### Option A: Flutter Flavorizr (Automated)

**Package:** [flutter_flavorizr](https://pub.dev/packages/flutter_flavorizr)

**Pros:**
- Automates platform configuration
- Handles iOS schemes, Android product flavors
- Generates launcher icons per flavor
- Creates flavor-specific files

**Cons:**
- Works best on new projects
- Can override existing files (e.g., main.dart)
- Generates boilerplate we might not want
- Requires careful processor selection for existing projects

**Andrea's Guidance:**
> "Using Flutter Flavorizr with Custom Processors: If you're adding flavors to an existing project, use custom processors to avoid unwanted changes."

**Recommended Usage for Mealvana:**
```bash
# Install
dart pub add dev:flutter_flavorizr

# Add flavors config to pubspec.yaml
# Run with custom processors (see roadmap.md)
dart run flutter_flavorizr -p <custom_processor_list>
```

**Key Insight from Andrea's doc:**
> "Running flutter_flavorizr all at once causes unwanted changes, like overriding main.dart. To solve this, we'll flavor the app in stages by specifying which processors to run."

### Option B: Manual Setup (Recommended for Mealvana)

**Approach:**
1. Manually create Xcode schemes via Xcode GUI
2. Manually create Android product flavors in build.gradle.kts
3. Hand-craft .xcconfig files
4. Manually update Info.plist and AndroidManifest.xml

**Pros:**
- Full control over every change
- No unexpected file modifications
- Better understanding of configuration
- Safer for production app

**Cons:**
- Time-consuming (2-4 hours for iOS, 1-2 hours for Android)
- Error-prone if not careful
- Requires deep platform knowledge

**Recommendation:** **Manual setup** given this is a production app with existing users and complex initialization patterns.

---

## Risk Assessment

### High Risk Areas

1. **Shorebird Compatibility:**
   - Risk: May not support flavors, breaking OTA updates
   - Impact: Core deployment strategy affected
   - Mitigation: Test thoroughly before committing

2. **Production Bundle ID:**
   - Risk: Accidentally changing prod bundle ID
   - Impact: New App Store listing, lost users
   - Mitigation: Careful code review, CI/CD validation

3. **Main.dart Overwrite:**
   - Risk: Flutter Flavorizr overwriting complex initialization
   - Impact: Breaking Andrea's initialization pattern
   - Mitigation: Manual setup or careful processor selection

### Medium Risk Areas

1. **iOS Xcode Project Corruption:**
   - Risk: .pbxproj file corruption during manual editing
   - Impact: Project won't build in Xcode
   - Mitigation: Git commits before changes, Xcode GUI usage

2. **CI/CD Workflow Complexity:**
   - Risk: Increased workflow complexity causes build failures
   - Impact: Deployment delays
   - Mitigation: Thorough testing, staged rollout

3. **Sign in with Apple:**
   - Risk: OAuth not working on dev flavor
   - Impact: Authentication broken in dev builds
   - Mitigation: Test auth flows thoroughly

### Low Risk Areas

1. **Deep Links:**
   - Can be flavor-specific or prod-only
   - Doesn't affect core functionality

2. **Analytics:**
   - Already separated by .env config
   - Flavors just formalize the separation

3. **Local Storage:**
   - Automatic separation by bundle/application ID
   - No code changes needed

---

## Rollback Strategy

### If Flavors Implementation Fails

**Rollback Steps:**

1. **Git Reset:**
   ```bash
   git reset --hard HEAD
   git clean -fd
   ```

2. **Restore Files:**
   - iOS: Restore original .xcodeproj
   - Android: Restore original build.gradle.kts
   - Flutter: Restore original main.dart and AppConfig

3. **Verify Build:**
   ```bash
   flutter clean
   flutter pub get
   dart run build_runner build --delete-conflicting-outputs
   flutter run
   ```

4. **Test Key Functionality:**
   - Authentication (OAuth)
   - Nutrition plan generation
   - Local database operations
   - Analytics tracking

### Partial Implementation Rollback

**If iOS works but Android fails (or vice versa):**

1. Keep working platform flavor
2. Revert failing platform to original config
3. Ship iOS flavor, keep Android as runtime switching
4. Revisit Android flavor later

**Hybrid approach is valid and reduces risk.**

---

## Testing Checklist Before Go-Live

### Platform Testing

**iOS Dev Flavor:**
- [ ] Installs alongside production app
- [ ] Different icon/name visible on home screen
- [ ] Connects to dev Supabase
- [ ] Drift database is separate from prod
- [ ] Sign in with Apple works
- [ ] Analytics go to dev Mixpanel
- [ ] Sentry errors tagged correctly

**iOS Prod Flavor:**
- [ ] Same bundle ID as current production
- [ ] Existing users can update (no new install)
- [ ] All functionality works identically

**Android Dev Flavor:**
- [ ] Installs alongside production app
- [ ] Different icon/name visible on home screen
- [ ] Connects to dev Supabase
- [ ] Drift database is separate from prod
- [ ] Sign in with Google works
- [ ] Analytics go to dev Mixpanel
- [ ] Sentry errors tagged correctly

**Android Prod Flavor:**
- [ ] Same application ID as current production
- [ ] Existing users can update (no new install)
- [ ] All functionality works identically

### Shorebird Testing (CRITICAL)

- [ ] Can create release for dev flavor
- [ ] Can create release for prod flavor
- [ ] Can patch dev flavor independently
- [ ] Can patch prod flavor independently
- [ ] Releases are isolated per flavor
- [ ] Update checking works per flavor

### CI/CD Testing

- [ ] Codemagic builds dev flavor successfully
- [ ] Codemagic builds prod flavor successfully
- [ ] Shorebird release commands work in CI
- [ ] Environment variables correct per flavor
- [ ] Artifacts have correct naming

### Functionality Testing

- [ ] Authentication (all OAuth providers)
- [ ] Nutrition plan generation (AI edge functions)
- [ ] Local database CRUD operations
- [ ] Content management system loads
- [ ] Push notifications work
- [ ] Analytics events send correctly
- [ ] Sentry crash reporting works
- [ ] Offline mode functions properly

---

## Summary of Changes

**Total Files to Modify:**

**iOS: ~8-10 files**
- `ios/Runner.xcodeproj/project.pbxproj`
- 6 new `.xcconfig` files
- `ios/Runner/Info.plist`
- Optional: App icon assets

**Android: ~3-5 files**
- `android/app/build.gradle.kts`
- 2 new flavor `AndroidManifest.xml` files
- Optional: App icon assets

**Flutter/Dart: ~3-4 files**
- `lib/main.dart`
- `lib/shared/services/app_config.dart`
- `lib/shared/widgets/environment_switcher_dialog.dart` (optional refactor)
- `lib/shared/widgets/environment_indicator.dart` (minor update)

**CI/CD: ~2-3 files**
- `codemagic.yaml`
- `.github/workflows/tests-selfhosted.yml` (the deploy-dev/deploy-prod workflows were
  deleted 2026-05-22 — backend deploys are manual)

**No Changes Needed:**
- `.env.dev.local` and `.env.prod.local` files
- Andrea Bizzotto initialization pattern
- Riverpod provider structure
- Drift database code
- Content management system
- Analytics integration
- Most of the Flutter codebase

**Net Code Reduction:**
- ~50 lines removed from AppConfig (runtime switching logic)
- ~20 lines added to main.dart (flavor detection)
- Overall: Simpler, more maintainable configuration

---

**Last Updated:** 2025-12-16
**Status:** Technical Analysis Complete - Ready for Implementation Planning
