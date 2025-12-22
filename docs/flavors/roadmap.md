# Flutter Flavors Implementation Roadmap

## Overview

This document provides a detailed, step-by-step implementation plan for adding Flutter flavors to Mealvana Endurance. It assumes manual setup for maximum control and safety in this production app.

**Recommendation:** Manual setup over Flutter Flavorizr for this existing production application.

---

## Prerequisites & Decision Points

### Critical Decisions Required Before Starting

1. **Shorebird Compatibility Testing (MANDATORY)**
   - Test Shorebird with flavors in a sample project
   - Verify releases are per-flavor or shared
   - Determine if separate Shorebird app IDs needed
   - **Go/No-Go Decision Point:** If Shorebird doesn't support flavors well, consider hybrid approach or abandon flavors

2. **Rollout Strategy**
   - Both platforms (iOS + Android) or iOS-only first?
   - **Recommendation:** iOS-only first (lower risk, easier to manage)

3. **Distribution Strategy**
   - How to distribute dev flavor? (TestFlight, Codemagic artifacts, Firebase App Distribution)
   - Keep dev flavor internal only or allow external testers?

4. **Timeline Commitment**
   - Full implementation: 3-5 days (iOS + Android)
   - iOS-only: 2-3 days
   - Testing and validation: 1-2 days
   - **Total:** 4-7 days for complete rollout

### Prerequisites

- [ ] Git repository is clean (commit all work)
- [ ] Shorebird compatibility testing complete
- [ ] Decision made on rollout strategy (both platforms vs iOS-only)
- [ ] Backup of current production builds
- [ ] Team aligned on approach
- [ ] QA testing plan prepared
- [ ] Rollback plan documented and understood

---

## Phase 1: Research & Preparation (Day 1, Morning)

**Time Estimate:** 3-4 hours

### 1.1 Shorebird Compatibility Testing

**CRITICAL:** Must be completed before proceeding.

**Setup Test Project:**
```bash
# Create test Flutter project
flutter create shorebird_flavor_test
cd shorebird_flavor_test

# Initialize Shorebird
shorebird init

# Add basic iOS flavor manually (skip if Android-only test)
# Edit ios/Runner.xcodeproj in Xcode to add dev scheme

# Add basic Android flavor
# Edit android/app/build.gradle.kts to add dev/prod flavors
```

**Test Flavor Support:**
```bash
# Test creating releases per flavor
shorebird release ios --flavor dev
shorebird release ios --flavor prod

shorebird release android --flavor dev
shorebird release android --flavor prod

# Check if releases are isolated
shorebird releases --flavor dev
shorebird releases --flavor prod

# Test patching per flavor
# Make a code change
shorebird patch ios --flavor dev
shorebird patch ios --flavor prod

shorebird patch android --flavor dev
shorebird patch android --flavor prod
```

**Document Findings:**
- [ ] Shorebird supports flavors: Yes/No
- [ ] Releases are per-flavor: Yes/No
- [ ] Separate app IDs required: Yes/No
- [ ] Any workarounds needed: Document
- [ ] **Decision:** Proceed with flavors / Adjust approach / Abandon flavors

### 1.2 Bundle ID Registration (iOS Only)

**If proceeding with iOS flavors:**

1. **Apple Developer Portal:**
   - Log in to [developer.apple.com](https://developer.apple.com)
   - Navigate to Certificates, Identifiers & Profiles
   - Register new App ID: `com.milkman.MealvanaEndurance.dev`
   - Enable required capabilities (Sign in with Apple, Associated Domains, etc.)

2. **Sign in with Apple:**
   - Register new Service ID for dev flavor (if needed)
   - Configure return URLs for dev bundle ID
   - Test in development environment

3. **Provisioning Profiles:**
   - Create Development profile for dev bundle ID
   - Create Distribution profile for dev bundle ID (if distributing via TestFlight)

**Verification:**
- [ ] Dev bundle ID registered in Apple Developer portal
- [ ] Capabilities enabled on dev bundle ID
- [ ] Sign in with Apple configured for dev
- [ ] Provisioning profiles created

### 1.3 Play Store Setup (Android Only)

**If proceeding with Android flavors and separate listing:**

1. **Play Console:**
   - Log in to [play.google.com/console](https://play.google.com/console)
   - Decide: Separate Play Store listing or internal only?
   - If separate listing: Create new app for dev flavor

2. **Keystore:**
   - Decide: New keystore for dev or use existing?
   - **Recommendation:** Use existing keystore with different alias
   - Add dev alias to existing keystore:
     ```bash
     keytool -genkey -v -keystore ~/upload-keystore.jks \
       -alias mealvana-dev \
       -keyalg RSA -keysize 2048 -validity 10000
     ```

**Verification:**
- [ ] Play Store strategy decided (separate listing vs internal)
- [ ] Keystore strategy decided
- [ ] Dev alias added to keystore (if applicable)

### 1.4 Create Implementation Branch

```bash
# Create feature branch from develop
git checkout develop
git pull origin develop
git checkout -b feature/flutter-flavors

# Push to remote
git push -u origin feature/flutter-flavors
```

### 1.5 Backup Current Configuration

```bash
# Create backup branch
git checkout develop
git checkout -b backup/pre-flavors-$(date +%Y%m%d)
git push -u origin backup/pre-flavors-$(date +%Y%m%d)

# Return to feature branch
git checkout feature/flutter-flavors
```

---

## Phase 2: Manual Setup Approach (Recommended)

**Time Estimate:** 6-8 hours (iOS + Android) OR 4-5 hours (iOS only)

### Why Manual Setup?

1. **Full Control:** No unexpected file modifications
2. **Safety:** Production app with complex initialization
3. **Understanding:** Better grasp of configuration
4. **Precision:** Exact changes we want, nothing more

### Alternative: Flutter Flavorizr with Custom Processors

See Appendix A at end of document for Flutter Flavorizr approach.

---

## Phase 3: Android Configuration (Day 1, Afternoon)

**Time Estimate:** 2-3 hours

### 3.1 Update build.gradle.kts

**File:** `android/app/build.gradle.kts`

**Add flavor configuration after `defaultConfig` block:**

```kotlin
android {
    namespace = "com.milkman.mealvanaendurance"
    compileSdk = 36
    // ... existing config ...

    defaultConfig {
        applicationId = "com.milkman.mealvanaendurance"
        // ... existing config ...
    }

    // NEW: Flavor configuration
    flavorDimensions += "environment"

    productFlavors {
        create("dev") {
            dimension = "environment"
            applicationId = "com.milkman.mealvanaendurance.dev"

            // App name in launcher
            resValue("string", "app_name", "Mealvana Dev")

            // Optional: Different version name suffix
            versionNameSuffix = "-dev"

            // Optional: Different app icon
            // manifestPlaceholders["appIcon"] = "@mipmap/ic_launcher_dev"
        }

        create("prod") {
            dimension = "environment"

            // Keep production ID unchanged (CRITICAL)
            applicationId = "com.milkman.mealvanaendurance"

            // Production app name
            resValue("string", "app_name", "Mealvana")

            // No version suffix for prod
        }
    }

    // Existing signingConfigs and buildTypes blocks remain unchanged
    signingConfigs { /* ... existing ... */ }
    buildTypes { /* ... existing ... */ }
}

// ... rest of file unchanged ...
```

**Commit:**
```bash
git add android/app/build.gradle.kts
git commit -m "feat(android): add product flavors for dev and prod"
```

### 3.2 Update AndroidManifest.xml

**Main Manifest:** `android/app/src/main/AndroidManifest.xml`

**Update app label to use string resource:**

```xml
<application
    android:label="@string/app_name"
    android:icon="@mipmap/ic_launcher"
    ...>
```

**Note:** `@string/app_name` is provided by `resValue()` in build.gradle.kts per flavor.

**Commit:**
```bash
git add android/app/src/main/AndroidManifest.xml
git commit -m "feat(android): use flavor-specific app name in manifest"
```

### 3.3 Optional: Create Flavor-Specific Icons

**If you want different icons per flavor:**

1. **Generate dev icons** (e.g., orange tint, "DEV" badge):
   - Use tool like [icon.kitchen](https://icon.kitchen/) or Figma
   - Generate all density versions

2. **Add to dev flavor directory:**
   ```
   android/app/src/dev/res/
   ├── mipmap-hdpi/ic_launcher.png
   ├── mipmap-mdpi/ic_launcher.png
   ├── mipmap-xhdpi/ic_launcher.png
   ├── mipmap-xxhdpi/ic_launcher.png
   ├── mipmap-xxxhdpi/ic_launcher.png
   └── mipmap-anydpi-v26/ic_launcher.xml
   ```

3. **Prod uses existing icons** in `android/app/src/main/res/`

**Commit:**
```bash
git add android/app/src/dev/
git commit -m "feat(android): add dev flavor app icon"
```

### 3.4 Test Android Flavors

**Build and run each flavor:**

```bash
# Clean build
flutter clean

# Dev flavor
flutter run --flavor dev

# Verify in app:
# 1. Check app name in launcher: "Mealvana Dev"
# 2. Check package name in About section
# 3. Test that it doesn't conflict with existing production app

# Prod flavor
flutter run --flavor prod

# Verify in app:
# 1. Check app name in launcher: "Mealvana"
# 2. Check package name in About section
```

**Verification Checklist:**
- [ ] Dev flavor builds successfully
- [ ] Prod flavor builds successfully
- [ ] Dev and prod can be installed simultaneously
- [ ] Different app names visible in launcher
- [ ] Different package IDs confirmed
- [ ] No build errors or warnings

**Commit:**
```bash
git add .
git commit -m "test(android): verify dev and prod flavors build and install"
```

---

## Phase 4: iOS Configuration (Day 2, Morning)

**Time Estimate:** 4-5 hours

### 4.1 Create .xcconfig Files

**Create directory:** `ios/Flutter/`

**Dev Debug Config:** `ios/Flutter/DevDebug.xcconfig`
```xcconfig
#include "Debug.xcconfig"

// Flavor identification
FLUTTER_FLAVOR=dev

// Bundle identifier for dev flavor
PRODUCT_BUNDLE_IDENTIFIER=com.milkman.MealvanaEndurance.dev

// App name
PRODUCT_NAME=Mealvana Dev

// Optional: Different app icon
// ASSETCATALOG_COMPILER_APPICON_NAME=DevAppIcon
```

**Dev Release Config:** `ios/Flutter/DevRelease.xcconfig`
```xcconfig
#include "Release.xcconfig"

// Flavor identification
FLUTTER_FLAVOR=dev

// Bundle identifier for dev flavor
PRODUCT_BUNDLE_IDENTIFIER=com.milkman.MealvanaEndurance.dev

// App name
PRODUCT_NAME=Mealvana Dev

// Optional: Different app icon
// ASSETCATALOG_COMPILER_APPICON_NAME=DevAppIcon
```

**Dev Profile Config:** `ios/Flutter/DevProfile.xcconfig`
```xcconfig
#include "Release.xcconfig"

// Flavor identification
FLUTTER_FLAVOR=dev

// Bundle identifier for dev flavor
PRODUCT_BUNDLE_IDENTIFIER=com.milkman.MealvanaEndurance.dev

// App name
PRODUCT_NAME=Mealvana Dev

// Optional: Different app icon
// ASSETCATALOG_COMPILER_APPICON_NAME=DevAppIcon
```

**Prod Debug Config:** `ios/Flutter/ProdDebug.xcconfig`
```xcconfig
#include "Debug.xcconfig"

// Flavor identification
FLUTTER_FLAVOR=prod

// Production bundle identifier (UNCHANGED)
PRODUCT_BUNDLE_IDENTIFIER=com.milkman.MealvanaEndurance

// App name
PRODUCT_NAME=Mealvana

// Production app icon
ASSETCATALOG_COMPILER_APPICON_NAME=AppIcon
```

**Prod Release Config:** `ios/Flutter/ProdRelease.xcconfig`
```xcconfig
#include "Release.xcconfig"

// Flavor identification
FLUTTER_FLAVOR=prod

// Production bundle identifier (UNCHANGED)
PRODUCT_BUNDLE_IDENTIFIER=com.milkman.MealvanaEndurance

// App name
PRODUCT_NAME=Mealvana

// Production app icon
ASSETCATALOG_COMPILER_APPICON_NAME=AppIcon
```

**Prod Profile Config:** `ios/Flutter/ProdProfile.xcconfig`
```xcconfig
#include "Release.xcconfig"

// Flavor identification
FLUTTER_FLAVOR=prod

// Production bundle identifier (UNCHANGED)
PRODUCT_BUNDLE_IDENTIFIER=com.milkman.MealvanaEndurance

// App name
PRODUCT_NAME=Mealvana

// Production app icon
ASSETCATALOG_COMPILER_APPICON_NAME=AppIcon
```

**Commit:**
```bash
git add ios/Flutter/Dev*.xcconfig ios/Flutter/Prod*.xcconfig
git commit -m "feat(ios): add flavor-specific xcconfig files"
```

### 4.2 Update Info.plist

**File:** `ios/Runner/Info.plist`

**Replace hardcoded bundle identifier with variable:**

Find:
```xml
<key>CFBundleIdentifier</key>
<string>com.milkman.MealvanaEndurance</string>
```

Replace with:
```xml
<key>CFBundleIdentifier</key>
<string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
```

**Replace hardcoded app name (if present):**

Find:
```xml
<key>CFBundleName</key>
<string>Mealvana Endurance</string>
```

Replace with:
```xml
<key>CFBundleName</key>
<string>$(PRODUCT_NAME)</string>
```

**Commit:**
```bash
git add ios/Runner/Info.plist
git commit -m "feat(ios): use variables for bundle ID and app name"
```

### 4.3 Create Xcode Schemes (via Xcode GUI)

**IMPORTANT:** This is the most complex and error-prone step. Follow carefully.

**Open Xcode:**
```bash
cd ios
open Runner.xcodeproj
```

**Step 1: Duplicate Runner Scheme**

1. In Xcode, click on "Runner" scheme dropdown (top left, next to stop button)
2. Click "Edit Scheme..."
3. At bottom left, click dropdown → "Duplicate Scheme"
4. Name it "dev"
5. Ensure "Shared" checkbox is checked
6. Click "Close"

**Step 2: Configure Dev Scheme**

1. With "dev" scheme selected, click "Edit Scheme..."
2. For each section (Run, Test, Profile, Analyze, Archive):
   - **Build Configuration:**
     - Run → Set to "DevDebug"
     - Test → Set to "DevDebug"
     - Profile → Set to "DevProfile"
     - Analyze → Set to "DevDebug"
     - Archive → Set to "DevRelease"

3. Click "Close"

**Step 3: Duplicate and Configure Prod Scheme**

1. Click on scheme dropdown → "Edit Scheme..."
2. At bottom left, click dropdown → "Duplicate Scheme"
3. Name it "prod"
4. Ensure "Shared" checkbox is checked
5. Click "Close"

6. With "prod" scheme selected, click "Edit Scheme..."
7. For each section (Run, Test, Profile, Analyze, Archive):
   - **Build Configuration:**
     - Run → Set to "ProdDebug"
     - Test → Set to "ProdDebug"
     - Profile → Set to "ProdProfile"
     - Analyze → Set to "ProdDebug"
     - Archive → Set to "ProdRelease"

8. Click "Close"

**Step 4: Create Build Configurations**

1. In Xcode, select Runner project (blue icon at top of file navigator)
2. Select Runner target (under TARGETS)
3. Select "Info" tab
4. Under "Configurations", click "+" button
5. Select "Duplicate 'Debug' Configuration"
6. Name it "DevDebug"
7. Repeat for:
   - DevRelease (duplicate Release)
   - DevProfile (duplicate Release)
   - ProdDebug (duplicate Debug)
   - ProdRelease (duplicate Release)
   - ProdProfile (duplicate Release)

**Step 5: Assign .xcconfig Files to Configurations**

1. Still in "Info" tab, under "Configurations"
2. For each configuration, set the correct .xcconfig file:
   - DevDebug → DevDebug.xcconfig
   - DevRelease → DevRelease.xcconfig
   - DevProfile → DevProfile.xcconfig
   - ProdDebug → ProdDebug.xcconfig
   - ProdRelease → ProdRelease.xcconfig
   - ProdProfile → ProdProfile.xcconfig

3. Look for dropdown in "Based on configuration file" column

**Verification in Xcode:**
- [ ] Six build configurations exist
- [ ] Two schemes exist (dev, prod)
- [ ] Each scheme uses correct configurations
- [ ] .xcconfig files assigned to configurations
- [ ] Schemes are marked as "Shared"

**Commit Changes:**
```bash
# Xcode modifies these files:
git add ios/Runner.xcodeproj/project.pbxproj
git add ios/Runner.xcodeproj/xcshareddata/xcschemes/dev.xcscheme
git add ios/Runner.xcodeproj/xcshareddata/xcschemes/prod.xcscheme
git commit -m "feat(ios): add dev and prod Xcode schemes and build configurations"
```

### 4.4 Optional: Create Flavor-Specific Icons

**If you want different icons per flavor:**

1. **Create dev icon set:**
   - In Xcode, right-click on `Assets.xcassets`
   - Select "New Image Set" or "New iOS App Icon"
   - Name it "DevAppIcon"
   - Add dev-themed icons (e.g., orange tint, "DEV" badge)

2. **Update DevDebug.xcconfig:**
   - Uncomment: `ASSETCATALOG_COMPILER_APPICON_NAME=DevAppIcon`

3. **Prod uses existing AppIcon** (no changes)

**Commit:**
```bash
git add ios/Runner/Assets.xcassets/DevAppIcon.appiconset/
git commit -m "feat(ios): add dev flavor app icon"
```

### 4.5 Test iOS Flavors

**Build and run each flavor:**

```bash
# Clean build
flutter clean

# Dev flavor
flutter run --flavor dev

# Verify in app:
# 1. Check app name in home screen: "Mealvana Dev"
# 2. Check bundle ID in Settings > General > iPhone Storage
# 3. Test that it doesn't conflict with existing production app

# Prod flavor
flutter run --flavor prod

# Verify in app:
# 1. Check app name in home screen: "Mealvana"
# 2. Check bundle ID in Settings > General > iPhone Storage
```

**Verification Checklist:**
- [ ] Dev flavor builds successfully in Xcode
- [ ] Prod flavor builds successfully in Xcode
- [ ] Dev and prod can be installed simultaneously on iOS device
- [ ] Different app names visible on home screen
- [ ] Different bundle IDs confirmed in Settings
- [ ] No build errors or warnings

**Commit:**
```bash
git add .
git commit -m "test(ios): verify dev and prod flavors build and install"
```

---

## Phase 5: Flutter Code Updates (Day 2, Afternoon)

**Time Estimate:** 2-3 hours

### 5.1 Update main.dart

**File:** `lib/main.dart`

**Current code to modify:**

Find this section:
```dart
// Load dev mode override from SharedPreferences BEFORE loading env
await AppConfig.loadDevModeOverride();
debugPrint('[STARTUP] Dev mode override loaded: ${mainStopwatch.elapsedMilliseconds}ms');

// Determine which env file to load based on dev mode
final isDevMode = AppConfig.effectiveDevMode;
final envFileName = isDevMode ? '.env.dev.local' : '.env.prod.local';

// Load environment variables from appropriate file
await dotenv.load(fileName: envFileName);
debugPrint('[STARTUP] dotenv loaded ($envFileName): ${mainStopwatch.elapsedMilliseconds}ms');

// Create app configuration from loaded env
final config = AppConfig.fromEnv();
```

**Replace with:**
```dart
// Determine flavor from platform (via --dart-define or appFlavor constant)
const flavor = String.fromEnvironment('FLAVOR', defaultValue: 'prod');
debugPrint('[STARTUP] Flavor: $flavor');

// Load flavor-specific .env file
final envFileName = '.env.$flavor.local'; // .env.dev.local or .env.prod.local
await dotenv.load(fileName: envFileName);
debugPrint('[STARTUP] dotenv loaded ($envFileName): ${mainStopwatch.elapsedMilliseconds}ms');

// Create app configuration with flavor
final config = AppConfig.fromEnv(flavor);
debugPrint('[STARTUP] AppConfig created: ${mainStopwatch.elapsedMilliseconds}ms');
```

**Explanation:**
- Uses `String.fromEnvironment('FLAVOR')` to read flavor from build command
- Defaults to 'prod' if not specified (safety)
- Loads corresponding .env file
- Passes flavor to AppConfig

**Commit:**
```bash
git add lib/main.dart
git commit -m "feat(flutter): update main.dart to use flavor-based env loading"
```

### 5.2 Update AppConfig Service

**File:** `lib/shared/services/app_config.dart`

**Remove runtime override logic:**

Delete these sections:
```dart
// Environment control - CHANGE THIS TO false FOR PRODUCTION RELEASE BUILDS
// When true: loads .env.dev.local (dev Supabase, dev Mixpanel)
// When false: loads .env.prod.local (prod Supabase, prod Mixpanel)
// ignore: constant_identifier_names
static const bool _DEFAULT_DEV_MODE = false;

// Runtime override (persisted in SharedPreferences)
static bool? _runtimeOverride;

/// Get the effective dev mode setting
/// Priority order:
/// 1. Runtime override (if set via SharedPreferences)
/// 2. kDebugMode (debug builds always use dev environment as safety net)
/// 3. _DEFAULT_DEV_MODE (fallback for release builds)
static bool get effectiveDevMode {
  // Runtime override takes highest priority
  if (_runtimeOverride != null) {
    return _runtimeOverride!;
  }
  // Debug builds always use dev environment (safety net)
  // if (kDebugMode) {
  //   return true;
  // }
  // Release builds use the configured default
  return _DEFAULT_DEV_MODE;
}

/// Override dev mode at runtime (requires app restart to take effect)
static Future<void> setDevModeOverride(bool value) async {
  _runtimeOverride = value;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool('dev_mode_override', value);
}

/// Clear runtime override (revert to default)
static Future<void> clearDevModeOverride() async {
  _runtimeOverride = null;
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove('dev_mode_override');
}

/// Initialize runtime override from SharedPreferences
static Future<void> loadDevModeOverride() async {
  final prefs = await SharedPreferences.getInstance();
  _runtimeOverride = prefs.getBool('dev_mode_override');
}
```

**Add flavor field:**

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
    required this.flavor, // NEW: Add flavor field
    this.enableDebugLogging = false,
    this.enableSentryProfiling = false,
  });

  // ... existing fields ...

  // NEW: Flavor identification
  final String flavor; // 'dev' or 'prod'

  // Simplified environment checks
  bool get isProduction => flavor == 'prod';
  bool get isDevelopment => flavor == 'dev';

  /// Factory for loading configuration from .env file
  /// Must call dotenv.load() before using this factory
  factory AppConfig.fromEnv(String flavor) {
    // Read all configuration from loaded .env file
    final supabaseUrl = dotenv.get('SUPABASE_URL', fallback: '');
    final supabaseAnonKey = dotenv.get('SUPABASE_ANON_KEY', fallback: '');

    return AppConfig(
      flavor: flavor, // Store flavor

      // Supabase configuration - read from loaded .env file
      supabaseUrl: supabaseUrl,
      supabaseAnonKey: supabaseAnonKey,
      // ... rest unchanged ...

      // Debug settings
      enableDebugLogging: kDebugMode,
      enableSentryProfiling: !kDebugMode,
    );
  }

  // Update forTesting factory to include flavor
  factory AppConfig.forTesting({
    String? supabaseUrl,
    String? supabaseAnonKey,
    String? supabasePublishableKey,
    String? supabaseSecretKey,
    String? sentryDsn,
    String? sentryEnvironment,
    String? mixpanelToken,
    String? wiredashProjectId,
    String? wiredashSecret,
    String? oneSignalAppId,
    String? usdaApiKey,
    String flavor = 'dev', // NEW: Add flavor parameter
    bool enableDebugLogging = true,
    bool enableSentryProfiling = false,
  }) {
    return AppConfig(
      flavor: flavor, // Pass flavor
      supabaseUrl: supabaseUrl ?? 'http://localhost:54321',
      // ... rest unchanged ...
    );
  }
}
```

**Remove references to old devModeEnabled field:**

Delete or update:
```dart
// OLD (remove these):
final bool devModeEnabled;
final String appEnvironment; // 'dev' or 'prod'

// Helper methods
bool get isProduction => appEnvironment == 'prod' && !devModeEnabled;
bool get isDevelopment => appEnvironment == 'dev' || devModeEnabled;
```

**Commit:**
```bash
git add lib/shared/services/app_config.dart
git commit -m "refactor(config): simplify AppConfig with flavor-based configuration"
```

### 5.3 Update Environment Switcher Dialog (Optional)

**File:** `lib/shared/widgets/environment_switcher_dialog.dart`

**Option A - Remove entirely:**
```bash
git rm lib/shared/widgets/environment_switcher_dialog.dart
git commit -m "refactor(ui): remove environment switcher dialog (replaced by flavors)"
```

**Option B - Convert to read-only info display:**

Update class to show flavor info without switching capability:

```dart
/// Environment information dialog
/// Shows current flavor and configuration (read-only)
class EnvironmentInfoDialog extends StatelessWidget {
  final AppConfig config;

  const EnvironmentInfoDialog({
    super.key,
    required this.config,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.info_outline, size: 24),
          const SizedBox(width: 8),
          const Text('Environment Info'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Current Flavor: ${config.flavor.toUpperCase()}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16.sp,
                color: config.isDevelopment ? Colors.orange : Colors.blue,
              ),
            ),
            SizedBox(height: 16.h),
            _buildInfoRow('Supabase', _getSupabaseProject(config.supabaseUrl)),
            _buildInfoRow('Mixpanel', config.mixpanelProjectToken),
            _buildInfoRow('Sentry', config.sentryEnvironment),
            SizedBox(height: 16.h),
            Text(
              'Note: To switch environments, install the different flavor build.',
              style: TextStyle(
                fontSize: 12.sp,
                fontStyle: FontStyle.italic,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.sp),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 14.sp),
            ),
          ),
        ],
      ),
    );
  }

  String _getSupabaseProject(String url) {
    // Extract project identifier from URL
    final uri = Uri.tryParse(url);
    return uri?.host.split('.').first ?? 'Unknown';
  }
}
```

**Commit:**
```bash
git add lib/shared/widgets/environment_switcher_dialog.dart
git commit -m "refactor(ui): convert environment switcher to read-only info dialog"
```

### 5.4 Update Environment Indicator (Minor)

**File:** `lib/shared/widgets/environment_indicator.dart`

**Update to read flavor from AppConfig:**

Find:
```dart
final isDev = config.devModeEnabled;
```

Replace with:
```dart
final isDev = config.isDevelopment;
```

**Commit:**
```bash
git add lib/shared/widgets/environment_indicator.dart
git commit -m "refactor(ui): update environment indicator to use flavor"
```

### 5.5 Update Settings Screen (Remove Switcher Reference)

**File:** `lib/features/settings/presentation/screens/settings_screen.dart` (or similar)

**Find and remove/update environment switcher button:**

If there's a button/menu item to show environment switcher:

```dart
// OLD (remove or update):
onTap: () {
  showDialog(
    context: context,
    builder: (context) => EnvironmentSwitcherDialog(config: config),
  );
}

// NEW (if keeping info dialog):
onTap: () {
  showDialog(
    context: context,
    builder: (context) => EnvironmentInfoDialog(config: config),
  );
}
```

**Commit:**
```bash
git add lib/features/settings/presentation/screens/settings_screen.dart
git commit -m "refactor(settings): update environment info dialog reference"
```

### 5.6 Run Code Generation

**Generate updated code:**

```bash
dart run build_runner build --delete-conflicting-outputs
```

**Commit:**
```bash
git add lib/**/*.g.dart
git commit -m "build: regenerate code after flavor changes"
```

---

## Phase 6: CI/CD Integration (Day 3, Morning)

**Time Estimate:** 2-3 hours

### 6.1 Update Codemagic Workflows

**File:** `codemagic.yaml`

**Add flavor-specific workflows:**

```yaml
workflows:
  # ============================================================
  # iOS Dev Build (Shorebird)
  # ============================================================
  ios-dev-shorebird:
    name: iOS Dev Build (Shorebird)
    instance_type: mac_mini_m2
    max_build_duration: 60

    environment:
      flutter: stable
      xcode: latest
      cocoapods: default
      groups:
        - supabase_dev
        - app_store_credentials
        - shorebird
      vars:
        FLAVOR: dev
        XCODE_SCHEME: dev

    triggering:
      events:
        - push
      branch_patterns:
        - pattern: 'develop'
          include: true
      cancel_previous_builds: true

    scripts:
      - *install_shorebird
      - *flutter_pub_get
      - *run_build_runner

      - name: Build iOS Dev with Shorebird
        script: |
          shorebird release ios \
            --flavor dev \
            --dart-define=FLAVOR=dev \
            -- --export-options-plist=/path/to/dev-export-options.plist

    artifacts:
      - build/ios/archive/*.ipa
      - build/ios/archive/*.dSYM.zip

    publishing:
      app_store_connect:
        api_key: $APP_STORE_CONNECT_KEY
        submit_to_testflight: true
        beta_groups:
          - Internal Testers

  # ============================================================
  # iOS Prod Build (Shorebird)
  # ============================================================
  ios-prod-shorebird:
    name: iOS Prod Build (Shorebird)
    instance_type: mac_mini_m2
    max_build_duration: 60

    environment:
      flutter: stable
      xcode: latest
      cocoapods: default
      groups:
        - supabase_prod
        - app_store_credentials
        - shorebird
      vars:
        FLAVOR: prod
        XCODE_SCHEME: prod

    triggering:
      events:
        - push
      branch_patterns:
        - pattern: 'main'
          include: true
      cancel_previous_builds: false

    scripts:
      - *install_shorebird
      - *flutter_pub_get
      - *run_build_runner

      - name: Build iOS Prod with Shorebird
        script: |
          shorebird release ios \
            --flavor prod \
            --dart-define=FLAVOR=prod \
            -- --export-options-plist=/path/to/prod-export-options.plist

    artifacts:
      - build/ios/archive/*.ipa
      - build/ios/archive/*.dSYM.zip

    publishing:
      app_store_connect:
        api_key: $APP_STORE_CONNECT_KEY
        submit_to_testflight: true
        beta_groups:
          - External Testers

  # ============================================================
  # Android Dev Build (Shorebird)
  # ============================================================
  android-dev-shorebird:
    name: Android Dev Build (Shorebird)
    instance_type: linux_x2
    max_build_duration: 60

    environment:
      flutter: stable
      groups:
        - supabase_dev
        - android_signing
        - shorebird
      vars:
        FLAVOR: dev

    triggering:
      events:
        - push
      branch_patterns:
        - pattern: 'develop'
          include: true
      cancel_previous_builds: true

    scripts:
      - *install_shorebird
      - *flutter_pub_get
      - *run_build_runner

      - name: Build Android Dev with Shorebird
        script: |
          shorebird release android \
            --flavor dev \
            --dart-define=FLAVOR=dev

    artifacts:
      - build/app/outputs/**/*.aab
      - build/app/outputs/**/*.apk

    publishing:
      google_play:
        credentials: $PLAY_STORE_CREDENTIALS
        track: internal

  # ============================================================
  # Android Prod Build (Shorebird)
  # ============================================================
  android-prod-shorebird:
    name: Android Prod Build (Shorebird)
    instance_type: linux_x2
    max_build_duration: 60

    environment:
      flutter: stable
      groups:
        - supabase_prod
        - android_signing
        - shorebird
      vars:
        FLAVOR: prod

    triggering:
      events:
        - push
      branch_patterns:
        - pattern: 'main'
          include: true
      cancel_previous_builds: false

    scripts:
      - *install_shorebird
      - *flutter_pub_get
      - *run_build_runner

      - name: Build Android Prod with Shorebird
        script: |
          shorebird release android \
            --flavor prod \
            --dart-define=FLAVOR=prod

    artifacts:
      - build/app/outputs/**/*.aab
      - build/app/outputs/**/*.apk

    publishing:
      google_play:
        credentials: $PLAY_STORE_CREDENTIALS
        track: production
```

**Update Integration Tests Workflow:**

```yaml
workflows:
  integration-tests:
    name: Integration Tests
    # ... existing config ...

    scripts:
      # ... existing scripts ...

      - name: Run integration tests
        script: |
          flutter test integration_test/test_runner.dart \
            --flavor dev \
            --dart-define=FLAVOR=dev \
            -d "$TEST_DEVICE"
```

**Commit:**
```bash
git add codemagic.yaml
git commit -m "ci(codemagic): add flavor-specific workflows"
```

### 6.2 Update GitHub Actions (if used)

**Files:**
- `.github/workflows/deploy-dev.yml`
- `.github/workflows/deploy-prod.yml`
- `.github/workflows/test.yml`

**Add flavor flags to all flutter commands:**

```yaml
# deploy-dev.yml
- name: Run tests
  run: |
    flutter test \
      --flavor dev \
      --dart-define=FLAVOR=dev

# deploy-prod.yml
- name: Run tests
  run: |
    flutter test \
      --flavor prod \
      --dart-define=FLAVOR=prod
```

**Commit:**
```bash
git add .github/workflows/
git commit -m "ci(github): add flavor support to workflows"
```

### 6.3 Update Environment Variable Groups

**Codemagic:**

1. Log in to Codemagic dashboard
2. Navigate to environment variable groups
3. Ensure groups exist:
   - `supabase_dev` - Dev Supabase credentials
   - `supabase_prod` - Prod Supabase credentials

4. Verify each group has:
   - `SUPABASE_URL`
   - `SUPABASE_ANON_KEY`
   - Other required env vars

**GitHub Actions (if used):**

1. Navigate to repository Settings → Secrets and variables → Actions
2. Create environment-specific secrets:
   - `DEV_SUPABASE_URL`
   - `DEV_SUPABASE_ANON_KEY`
   - `PROD_SUPABASE_URL`
   - `PROD_SUPABASE_ANON_KEY`

---

## Phase 7: Testing & Validation (Day 3, Afternoon)

**Time Estimate:** 3-4 hours

### 7.1 Local Testing

**Dev Flavor Testing:**

```bash
# Clean build
flutter clean
flutter pub get
dart run build_runner build --delete-conflicting-outputs

# iOS Dev
flutter run --flavor dev --dart-define=FLAVOR=dev -d [iOS device]

# Android Dev
flutter run --flavor dev --dart-define=FLAVOR=dev -d [Android device]
```

**Test Checklist - Dev Flavor:**
- [ ] App installs alongside production app
- [ ] Different icon/name on home screen (if implemented)
- [ ] Connects to dev Supabase (check logs)
- [ ] Dev Mixpanel events (verify in Mixpanel dashboard)
- [ ] Sentry errors tagged with "development" environment
- [ ] Drift database is separate (different path)
- [ ] Sign in with Apple/Google works
- [ ] Nutrition plan generation works
- [ ] All core features functional

**Prod Flavor Testing:**

```bash
# iOS Prod
flutter run --flavor prod --dart-define=FLAVOR=prod -d [iOS device]

# Android Prod
flutter run --flavor prod --dart-define=FLAVOR=prod -d [Android device]
```

**Test Checklist - Prod Flavor:**
- [ ] Same bundle/application ID as before
- [ ] Connects to prod Supabase
- [ ] Prod Mixpanel events
- [ ] Sentry errors tagged with "production" environment
- [ ] All core features functional
- [ ] No regressions from current production behavior

### 7.2 Shorebird Testing

**CRITICAL:** Test Shorebird functionality per flavor.

**Create Releases:**

```bash
# Dev releases
shorebird release ios --flavor dev --dart-define=FLAVOR=dev
shorebird release android --flavor dev --dart-define=FLAVOR=dev

# Prod releases
shorebird release ios --flavor prod --dart-define=FLAVOR=prod
shorebird release android --flavor prod --dart-define=FLAVOR=prod
```

**Verify Releases:**

```bash
# Check releases per flavor
shorebird releases --flavor dev
shorebird releases --flavor prod

# Ensure they're isolated
```

**Test Patching:**

1. Make a small code change (e.g., update a text string)
2. Create patches:
   ```bash
   shorebird patch ios --flavor dev --dart-define=FLAVOR=dev
   shorebird patch android --flavor dev --dart-define=FLAVOR=dev
   ```

3. Test update delivery:
   - Open dev flavor app
   - Restart app
   - Verify update is received
   - Verify change is applied

4. Ensure prod is unaffected:
   - Open prod flavor app
   - Should not receive dev patch
   - Should remain on prod version

**Shorebird Checklist:**
- [ ] Can create releases for dev flavor
- [ ] Can create releases for prod flavor
- [ ] Releases are isolated (dev doesn't affect prod)
- [ ] Can patch dev flavor
- [ ] Can patch prod flavor
- [ ] Patches are isolated
- [ ] Update mechanism works per flavor

### 7.3 Integration Test Updates

**Update test files to support flavors:**

**File:** `integration_test/test_runner.dart` (or similar)

**Option A - Test dev flavor:**
```dart
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // Set flavor for tests
  const flavor = String.fromEnvironment('FLAVOR', defaultValue: 'dev');

  // Run tests with dev config
  group('Integration Tests (Dev Flavor)', () {
    // ... existing tests ...
  });
}
```

**Run integration tests:**

```bash
# iOS
flutter test integration_test/test_runner.dart \
  --flavor dev \
  --dart-define=FLAVOR=dev \
  -d [iOS device]

# Android
flutter test integration_test/test_runner.dart \
  --flavor dev \
  --dart-define=FLAVOR=dev \
  -d [Android device]
```

**Integration Test Checklist:**
- [ ] All tests pass on dev flavor (iOS)
- [ ] All tests pass on dev flavor (Android)
- [ ] All tests pass on prod flavor (iOS)
- [ ] All tests pass on prod flavor (Android)

### 7.4 CI/CD Testing

**Trigger test builds:**

1. **Dev Build:**
   - Push to `develop` branch
   - Verify Codemagic triggers `ios-dev-shorebird` and `android-dev-shorebird` workflows
   - Check build logs for flavor flags
   - Verify artifacts generated

2. **Prod Build:**
   - Create test tag or push to `main` (if safe)
   - Verify Codemagic triggers `ios-prod-shorebird` and `android-prod-shorebird` workflows
   - Check build logs for flavor flags
   - Verify artifacts generated

**CI/CD Checklist:**
- [ ] Dev workflow builds successfully (iOS)
- [ ] Dev workflow builds successfully (Android)
- [ ] Prod workflow builds successfully (iOS)
- [ ] Prod workflow builds successfully (Android)
- [ ] Correct .env files loaded in CI
- [ ] Shorebird commands succeed in CI
- [ ] Artifacts have correct bundle/application IDs

---

## Phase 8: Documentation & Team Training (Day 4)

**Time Estimate:** 2-3 hours

### 8.1 Update Project Documentation

**Update CLAUDE.md:**

Add flavor information to relevant sections:

```markdown
### Build & Deployment

**Local Development with Flavors:**
```bash
# Dev flavor
flutter run --flavor dev --dart-define=FLAVOR=dev

# Prod flavor
flutter run --flavor prod --dart-define=FLAVOR=prod
```

**Release Builds:**
```bash
# iOS Dev
flutter build ios --flavor dev --dart-define=FLAVOR=dev --release

# iOS Prod
flutter build ios --flavor prod --dart-define=FLAVOR=prod --release

# Android Dev
flutter build appbundle --flavor dev --dart-define=FLAVOR=dev --release

# Android Prod
flutter build appbundle --flavor prod --dart-define=FLAVOR=prod --release
```

**Shorebird Code Push:**
```bash
# Create release for flavor
shorebird release ios --flavor [dev|prod] --dart-define=FLAVOR=[dev|prod]

# Push patch for flavor
shorebird patch ios --flavor [dev|prod] --dart-define=FLAVOR=[dev|prod]
```
```

**Update /docs/technical/README.md:**

Add section on flavors:

```markdown
### Flutter Flavors

Mealvana Endurance uses Flutter flavors to maintain separate dev and prod builds:

- **Dev Flavor:**
  - Bundle ID: `com.milkman.MealvanaEndurance.dev` (iOS)
  - Application ID: `com.milkman.mealvanaendurance.dev` (Android)
  - Connects to dev Supabase, dev Mixpanel
  - Can be installed alongside production app

- **Prod Flavor:**
  - Bundle ID: `com.milkman.MealvanaEndurance` (iOS)
  - Application ID: `com.milkman.mealvanaendurance` (Android)
  - Connects to prod Supabase, prod Mixpanel
  - Production users' app

See `/docs/flavors/README.md` for complete implementation guide.
```

**Commit:**
```bash
git add CLAUDE.md docs/technical/README.md
git commit -m "docs: update documentation with flavor information"
```

### 8.2 Create Developer Quickstart Guide

**Create file:** `/docs/flavors/quickstart.md`

```markdown
# Flutter Flavors Quickstart

## Running the App Locally

**Dev Flavor (recommended for development):**
```bash
flutter run --flavor dev --dart-define=FLAVOR=dev
```

**Prod Flavor (test production configuration):**
```bash
flutter run --flavor prod --dart-define=FLAVOR=prod
```

## Building Release Versions

**iOS:**
```bash
# Dev
flutter build ios --flavor dev --dart-define=FLAVOR=dev --release

# Prod
flutter build ios --flavor prod --dart-define=FLAVOR=prod --release
```

**Android:**
```bash
# Dev
flutter build appbundle --flavor dev --dart-define=FLAVOR=dev --release

# Prod
flutter build appbundle --flavor prod --dart-define=FLAVOR=prod --release
```

## Shorebird Releases

**Create new release:**
```bash
shorebird release [ios|android] --flavor [dev|prod] --dart-define=FLAVOR=[dev|prod]
```

**Push code update:**
```bash
shorebird patch [ios|android] --flavor [dev|prod] --dart-define=FLAVOR=[dev|prod]
```

## Common Issues

**Issue:** "No flavor specified"
**Solution:** Always include `--flavor` and `--dart-define=FLAVOR=` flags

**Issue:** "Wrong environment loaded"
**Solution:** Verify `.env.dev.local` and `.env.prod.local` files exist in project root

**Issue:** "Can't install dev and prod simultaneously"
**Solution:** Check bundle/application IDs are different per flavor
```

**Commit:**
```bash
git add docs/flavors/quickstart.md
git commit -m "docs: add flavor quickstart guide"
```

### 8.3 Update VSCode Launch Configurations

**File:** `.vscode/launch.json`

**Add flavor-specific launch configs:**

```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "Dev Flavor",
      "request": "launch",
      "type": "dart",
      "program": "lib/main.dart",
      "args": [
        "--flavor", "dev",
        "--dart-define", "FLAVOR=dev"
      ]
    },
    {
      "name": "Prod Flavor",
      "request": "launch",
      "type": "dart",
      "program": "lib/main.dart",
      "args": [
        "--flavor", "prod",
        "--dart-define", "FLAVOR=prod"
      ]
    },
    {
      "name": "Dev Flavor (Profile)",
      "request": "launch",
      "type": "dart",
      "flutterMode": "profile",
      "program": "lib/main.dart",
      "args": [
        "--flavor", "dev",
        "--dart-define", "FLAVOR=dev"
      ]
    }
  ]
}
```

**Commit:**
```bash
git add .vscode/launch.json
git commit -m "build: add flavor configurations to VSCode launch.json"
```

### 8.4 Team Training

**Create training checklist:**

- [ ] Schedule team meeting to demo flavors
- [ ] Walk through local development workflow
- [ ] Show how to install both flavors simultaneously
- [ ] Explain visual differences (icons/names)
- [ ] Demo environment info dialog
- [ ] Show CI/CD changes and new workflows
- [ ] Explain Shorebird flavor isolation
- [ ] Provide quickstart documentation link
- [ ] Answer questions

**Training Topics:**
1. Why we implemented flavors (side-by-side testing)
2. How to run dev vs prod locally
3. How flavors integrate with Shorebird
4. CI/CD changes and deployment process
5. Loss of runtime environment switching
6. Troubleshooting common issues

---

## Appendix A: Flutter Flavorizr Approach (Alternative)

**If you decide to use Flutter Flavorizr instead of manual setup:**

### A.1 Install Flutter Flavorizr

```bash
dart pub add dev:flutter_flavorizr
flutter pub get
```

### A.2 Configure pubspec.yaml

**Add to end of `pubspec.yaml`:**

```yaml
flavorizr:
  ide: "vscode"
  app:
    android:
      flavorDimensions: "environment"

  flavors:
    dev:
      app:
        name: "Mealvana Dev"
      android:
        applicationId: "com.milkman.mealvanaendurance.dev"
      ios:
        bundleId: "com.milkman.MealvanaEndurance.dev"

    prod:
      app:
        name: "Mealvana"
      android:
        applicationId: "com.milkman.mealvanaendurance"
      ios:
        bundleId: "com.milkman.MealvanaEndurance"
```

### A.3 Commit Before Running

**CRITICAL:**

```bash
git add .
git commit -m "feat: add flutter_flavorizr configuration"
```

### A.4 Run with Custom Processors

**DO NOT run `dart run flutter_flavorizr` without processors - it will overwrite files.**

**Recommended processor list:**

```bash
dart run flutter_flavorizr -p \
  android:androidManifest,\
  android:buildGradle,\
  ios:xcconfig,\
  ios:buildTargets,\
  ios:schema,\
  ios:plist
```

**Explanation:**
- `android:androidManifest` - Updates AndroidManifest.xml
- `android:buildGradle` - Adds product flavors to build.gradle.kts
- `ios:xcconfig` - Creates .xcconfig files
- `ios:buildTargets` - Updates Xcode build targets
- `ios:schema` - Creates Xcode schemes
- `ios:plist` - Updates Info.plist

**Skipped processors:**
- `dart:main` - Would overwrite our complex main.dart
- `dart:app` - Would create boilerplate we don't need
- `assets:*` - We'll handle icons manually if needed

### A.5 Review Changes Carefully

After running:

```bash
# Check what was modified
git status
git diff

# Review each file carefully
# Ensure main.dart was NOT overridden
# Ensure Andrea's initialization pattern preserved
```

### A.6 Manual Cleanup

After Flutter Flavorizr:

1. **Update main.dart** - Follow Phase 5.1 instructions
2. **Update AppConfig** - Follow Phase 5.2 instructions
3. **Review generated files** - Ensure they match requirements
4. **Test thoroughly** - Follow Phase 7 testing steps

---

## Summary & Final Checklist

### Implementation Complete When:

- [ ] iOS dev and prod flavors build successfully
- [ ] Android dev and prod flavors build successfully
- [ ] Dev and prod apps install simultaneously on both platforms
- [ ] Correct .env files loaded per flavor
- [ ] Shorebird releases work per flavor
- [ ] Shorebird patches work per flavor
- [ ] All integration tests pass on both flavors
- [ ] CI/CD workflows build both flavors successfully
- [ ] Documentation updated
- [ ] Team trained

### Post-Implementation

1. **Monitor Production:**
   - Watch for any user reports of issues
   - Monitor Sentry for unexpected errors
   - Check Mixpanel for correct event tagging

2. **Iterate:**
   - Gather team feedback on flavor workflow
   - Refine CI/CD processes as needed
   - Update documentation based on learnings

3. **Rollback Plan:**
   - If critical issues arise, revert to backup branch
   - Restore original main.dart and AppConfig
   - Resume runtime environment switching

---

## Timeline Summary

**Manual Setup (Recommended):**

- **Day 1 Morning (3-4 hours):** Research & Preparation
- **Day 1 Afternoon (2-3 hours):** Android Configuration
- **Day 2 Morning (4-5 hours):** iOS Configuration
- **Day 2 Afternoon (2-3 hours):** Flutter Code Updates
- **Day 3 Morning (2-3 hours):** CI/CD Integration
- **Day 3 Afternoon (3-4 hours):** Testing & Validation
- **Day 4 (2-3 hours):** Documentation & Team Training

**Total:** 18-25 hours (3-5 days)

**Flutter Flavorizr Approach:**

- **Day 1 (6-8 hours):** Research, setup, run Flavorizr, manual cleanup
- **Day 2 (4-6 hours):** Flutter code updates, CI/CD integration
- **Day 3 (4-5 hours):** Testing & validation
- **Day 4 (2-3 hours):** Documentation & team training

**Total:** 16-22 hours (3-4 days)

---

**Last Updated:** 2025-12-16
**Status:** Ready for Implementation
