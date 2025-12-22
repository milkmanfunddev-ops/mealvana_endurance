# Andrea Bizzotto's Flutter Flavors Guidance

## Overview

This document extracts and organizes key guidance from Andrea Bizzotto's Flutter flavors course (stored in `andrea_rizzoto_flavor.txt`). Andrea's approach emphasizes careful, staged implementation with custom processors to avoid breaking existing production apps.

---

## Core Concepts

### What Are Flavors?

**From Andrea:**

> "Flavors let you define compile-time configurations and set parameters that are read at runtime to customize your app's behavior."

**Key Points:**
- Flavors affect both Dart code and native platform code (iOS/Android)
- Allow multiple app versions installed on same device
- Each flavor has unique bundle ID (iOS) and application ID (Android)
- Only supported on iOS, macOS, and Android (not web)

### Flavors vs Dart Defines

**From Andrea:**

**Flavors:**
- Affect both Dart code and native platform code
- Require platform-specific setup on iOS and Android
- Only supported on iOS, macOS, and Android

**Dart Defines:**
- Affect only Dart code
- No platform-specific setup required
- Supported on all platforms

**Combined Approach:**
```bash
flutter run --flavor dev --dart-define-from-file=.env.dev
```

**Andrea's Insight:**
> "The flavor (dev) determines platform-specific details like app icon, package name, and platform-specific services. The dart-define-from-file passes in environment-specific variables (e.g., API_KEY, BASE_URL) to your Dart code."

**Perfect for Mealvana:** This is exactly what we're doing - flavors for platform config, .env files for environment variables.

---

## Implementation Approach

### When to Use Flutter Flavorizr

**From Andrea:**

**Two Approaches:**
1. **Use flutter_flavorizr** - Quicker, but works best on new Flutter projects
2. **Add Flavors Manually** - Time-consuming and error-prone, but safer for existing projects

**Andrea's Recommendation for Existing Apps:**

> "If you're adding flavors to an existing project, you need to retrofit flavors without breaking things."

> "Using Flutter Flavorizr with Custom Processors: If you're adding flavors to an existing project, use custom processors to avoid unwanted changes."

**Mealvana Decision:** Manual setup recommended (production app with complex initialization).

### The Danger of Running Flavorizr Without Care

**From Andrea:**

> "Sadly, the main.dart file has been completely overridden with these contents... Ouch! All the app initialization logic has been lost."

> "If you're adding flavors to a brand new Flutter project, it's not a big deal if main.dart gets overridden. However, I think it's best if we choose how to handle flavors in the Dart code, rather than using the default boilerplate from Flutter Flavorizr."

**Critical for Mealvana:**
- We have complex initialization (Sentry, Supabase, AppConfig, Andrea's startup pattern)
- Cannot let Flavorizr override main.dart
- Must use custom processors OR manual setup

### Commit Before Running Flavorizr

**From Andrea:**

> "Commit all your changes to Git... This way, you'll be able to go back to a working state if anything goes wrong."

**Rollback Command:**
```bash
# Discard changes, untracked files and directories
git reset --hard HEAD && git clean -fd
```

**Critical Practice:** Always commit before running Flavorizr.

---

## Platform-Specific Guidance

### Android Setup

**Andrea's Recommended Processors:**

```bash
dart run flutter_flavorizr -p android:buildGradle,android:flavorizrGradle,android:androidManifest
```

**What This Does:**
- `android:buildGradle` - Modifies build.gradle.kts
- `android:flavorizrGradle` - Creates flavorizr.gradle.kts with flavor definitions
- `android:androidManifest` - Updates AndroidManifest.xml to use `@string/app_name`

**Generated Flavor Configuration (from Andrea's example):**

```kotlin
android.apply {
    flavorDimensions("flavor-type")

    productFlavors {
        create("dev") {
            dimension = "flavor-type"
            applicationId = "com.codewithandrea.flutter_ship_app.dev"
            resValue(type = "string", name = "app_name", value = "Flutter Ship Dev")
        }
        create("prod") {
            dimension = "flavor-type"
            applicationId = "com.codewithandrea.flutter_ship_app"
            resValue(type = "string", name = "app_name", value = "Flutter Ship")
        }
    }
}
```

**Key Changes:**
- Application IDs per flavor
- App names stored as string resources
- Manifest uses `android:label="@string/app_name"`

**For Mealvana:**
- Similar structure applies
- Keep prod application ID unchanged: `com.milkman.mealvanaendurance`
- Dev gets suffix: `com.milkman.mealvanaendurance.dev`

### Android Icons Setup

**Andrea's Icon Processor:**

```bash
dart run flutter_flavorizr -p android:icons
```

**What This Does:**
- Generates mipmap icon files for each flavor
- Creates adaptive icons (foreground + background)
- Places icons in flavor-specific directories

**Icon Configuration in pubspec.yaml:**

```yaml
flavors:
  dev:
    android:
      icon: "assets/dev/app-icon.png"
      adaptiveIcon:
        foreground: "assets/dev/app-icon-foreground.png"
        background: "assets/android/app-icon-background.png"

  prod:
    android:
      icon: "assets/prod/app-icon.png"
      adaptiveIcon:
        foreground: "assets/prod/app-icon-foreground.png"
        background: "assets/android/app-icon-background.png"
```

### iOS Setup

**Prerequisites (from Andrea):**

To manipulate iOS and macOS projects, install:
- Ruby
- Gem
- Xcodeproj (through RubyGems)

**Note:** Skip if only working with Android.

**Andrea's Recommended Processors:**

The iOS setup is more complex than Android. Andrea breaks it into stages:

1. **Basic iOS Setup:**
   ```bash
   dart run flutter_flavorizr -p ios:xcconfig,ios:buildTargets,ios:schema
   ```

2. **iOS Icons:**
   ```bash
   dart run flutter_flavorizr -p ios:icons
   ```

**What These Do:**
- `ios:xcconfig` - Creates .xcconfig files per flavor/mode
- `ios:buildTargets` - Updates Xcode build targets
- `ios:schema` - Creates Xcode schemes (dev, stg, prod)
- `ios:icons` - Generates app icon sets per flavor

**Generated .xcconfig Structure (from Andrea):**

```
ios/Flutter/
├── DevDebug.xcconfig
├── DevRelease.xcconfig
├── DevProfile.xcconfig
├── StgDebug.xcconfig
├── StgRelease.xcconfig
├── StgProfile.xcconfig
├── ProdDebug.xcconfig
├── ProdRelease.xcconfig
└── ProdProfile.xcconfig
```

**Each includes base config and sets flavor-specific values:**

```xcconfig
#include "Debug.xcconfig"

PRODUCT_BUNDLE_IDENTIFIER=com.codewithandrea.flutterShipApp.dev
PRODUCT_NAME=Flutter Ship Dev
ASSETCATALOG_COMPILER_APPICON_NAME=DevAppIcon
```

**For Mealvana:**
- Similar structure needed
- Prod bundle ID unchanged: `com.milkman.MealvanaEndurance`
- Dev gets suffix: `com.milkman.MealvanaEndurance.dev`

### iOS Icons Setup

**Icon Configuration in pubspec.yaml:**

```yaml
flavors:
  dev:
    ios:
      bundleId: "com.codewithandrea.flutterShipApp.dev"
      icon: "assets/dev/app-icon.png"

  prod:
    ios:
      bundleId: "com.codewithandrea.flutterShipApp"
      icon: "assets/prod/app-icon.png"
```

**Andrea's Note on iOS 18:**

> "Unfortunately, Flutter Flavorizr doesn't support dark and tinted icons for iOS 18 yet. If you want to generate dark and tinted icons for your flavored app on iOS, you can use the flutter_launcher_icons package."

---

## Dart Code Integration

### Using the appFlavor Constant

**From Andrea:**

```dart
import 'package:flutter/services.dart';
import 'dart:developer';

void main() {
  if (appFlavor == 'prod') {
    log('Running in production');
  } else {
    log('Not running in production');
  }
  runApp(const MainApp());
}
```

**Key Point:**
- `appFlavor` constant is provided by Flutter when using platform flavors
- Automatically set based on `--flavor` flag
- Available as top-level constant

**For Mealvana:**
- Could use `appFlavor` directly
- Or use `String.fromEnvironment('FLAVOR')` for consistency
- Recommend both for compatibility:
  ```dart
  const flavor = String.fromEnvironment('FLAVOR', defaultValue: 'prod');
  // Also accessible via appFlavor if needed
  ```

---

## Custom Processors Strategy

### Why Custom Processors?

**From Andrea:**

> "To avoid dealing with too many changes at once, we can use custom processors."

> "When we run flutter_flavorizr without the -p option, all the processors are run by default, resulting in many unwanted changes to the project."

> "If we don't want to mess up our existing project, we must be very specific about which processors we want to run."

### Recommended Processor Sequence

**Andrea's Staged Approach:**

**Stage 1 - Basic Android:**
```bash
dart run flutter_flavorizr -p android:buildGradle,android:flavorizrGradle,android:androidManifest
```

**Stage 2 - Android Icons (optional):**
```bash
dart run flutter_flavorizr -p android:icons
```

**Stage 3 - Basic iOS:**
```bash
dart run flutter_flavorizr -p ios:xcconfig,ios:buildTargets,ios:schema
```

**Stage 4 - iOS Icons (optional):**
```bash
dart run flutter_flavorizr -p ios:icons
```

**Stage 5 - iOS plist (if needed):**
```bash
dart run flutter_flavorizr -p ios:plist
```

**Processors to AVOID for Existing Apps:**
- `dart:main` - Would override complex main.dart initialization
- `dart:app` - Creates boilerplate app widget
- `ide:config` - May override VSCode/Android Studio configs

### Available Processors

**From flutter_flavorizr usage:**

**Assets:**
- `assets:download` - Download assets
- `assets:extract` - Extract downloaded assets
- `assets:clean` - Clean up temporary files

**Android:**
- `android:androidManifest` - Update AndroidManifest.xml
- `android:buildGradle` - Update build.gradle/build.gradle.kts
- `android:flavorizrGradle` - Create flavorizr.gradle.kts with flavor config
- `android:icons` - Generate app icons
- `android:adaptiveIcons` - Generate adaptive icons

**iOS:**
- `ios:xcconfig` - Create .xcconfig files
- `ios:buildTargets` - Update build targets
- `ios:schema` - Create Xcode schemes
- `ios:icons` - Generate app icons
- `ios:plist` - Update Info.plist
- `ios:launchScreen` - Update launch screens

**Dart:**
- `dart:main` - Create main_<flavor>.dart files
- `dart:app` - Create app widget
- `dart:flavors` - Create flavors helper file

**IDE:**
- `ide:config` - Update IDE configuration (VSCode/Android Studio)

---

## Bundle ID Best Practices

### Preserving Production Bundle IDs

**From Andrea:**

> "The app stores use the applicationId and bundleId to identify your app, so never change them for production builds of existing apps."

**Andrea's Example:**
```yaml
prod:
  app:
    name: "Flutter Ship"
  android:
    applicationId: "com.codewithandrea.flutter_ship_app"
  ios:
    bundleId: "com.codewithandrea.flutterShipApp"
```

**Key Insight:**
- Production IDs must remain unchanged
- Only dev/staging flavors get modified IDs
- Changing prod ID creates new App Store listing

**For Mealvana (CRITICAL):**
- iOS Prod: `com.milkman.MealvanaEndurance` (UNCHANGED)
- Android Prod: `com.milkman.mealvanaendurance` (UNCHANGED)
- iOS Dev: `com.milkman.MealvanaEndurance.dev` (NEW)
- Android Dev: `com.milkman.mealvanaendurance.dev` (NEW)

---

## Common Flavor Setups

**From Andrea:**

Common setups based on team size and complexity:

**1. Two Flavors (dev + prod):**
- Best for: Small teams, simple projects
- Use cases: Basic separation, QA testing

**2. Three Flavors (dev + stg + prod):**
- Best for: Medium teams, more complex projects
- Use cases: Separate staging environment for pre-production testing

**3. Four Flavors (dev + testing + stg + prod):**
- Best for: Large teams, enterprise projects
- Use cases: Complete separation of all stages

**Mealvana Recommendation:**
- Start with two flavors (dev + prod)
- Simple, manageable, meets core need
- Can add staging later if needed

---

## Visual Distinction

### The Power of Different Icons

**From Andrea's example:**

Three variants with different colored icons:
- Dev: Orange/yellow icon
- Staging: Purple icon
- Production: Blue icon

**Benefits:**
- Instantly identify which environment you're in
- Prevents accidentally using wrong app
- Great for QA team clarity

**For Mealvana:**
- Dev: Consider orange/red tinted icon or "DEV" badge overlay
- Prod: Keep current blue icon unchanged
- Makes side-by-side testing much clearer

---

## pubspec.yaml Configuration

### Complete Example from Andrea

```yaml
flavorizr:
  ide: "vscode"  # or "idea" for Android Studio
  app:
    android:
      flavorDimensions: "flavor-type"

  flavors:
    dev:
      app:
        name: "Flutter Ship Dev"
      android:
        applicationId: "com.codewithandrea.flutter_ship_app.dev"
        icon: "assets/dev/app-icon.png"
        adaptiveIcon:
          foreground: "assets/dev/app-icon-foreground.png"
          background: "assets/android/app-icon-background.png"
      ios:
        bundleId: "com.codewithandrea.flutterShipApp.dev"
        icon: "assets/dev/app-icon.png"

    prod:
      app:
        name: "Flutter Ship"
      android:
        applicationId: "com.codewithandrea.flutter_ship_app"
        icon: "assets/prod/app-icon.png"
        adaptiveIcon:
          foreground: "assets/prod/app-icon-foreground.png"
          background: "assets/android/app-icon-background.png"
      ios:
        bundleId: "com.codewithandrea.flutterShipApp"
        icon: "assets/prod/app-icon.png"
```

### Adapted for Mealvana

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
        # Optional: icon: "assets/dev/app-icon.png"
      ios:
        bundleId: "com.milkman.MealvanaEndurance.dev"
        # Optional: icon: "assets/dev/app-icon.png"

    prod:
      app:
        name: "Mealvana"
      android:
        applicationId: "com.milkman.mealvanaendurance"
      ios:
        bundleId: "com.milkman.MealvanaEndurance"
```

**Note:** Icons optional - can add later if desired.

---

## Testing Flavors

### Running Different Flavors

**From Andrea:**

```bash
# Run dev flavor
flutter run --flavor dev

# Run prod flavor
flutter run --flavor prod
```

**With dart-define (recommended):**
```bash
flutter run --flavor dev --dart-define-from-file=.env.dev
flutter run --flavor prod --dart-define-from-file=.env.prod
```

**For Mealvana:**
```bash
# Dev flavor
flutter run --flavor dev --dart-define=FLAVOR=dev

# Prod flavor
flutter run --flavor prod --dart-define=FLAVOR=prod
```

### Building Release Versions

**From Andrea:**

```bash
# iOS release builds
flutter build ios --flavor dev --release
flutter build ios --flavor prod --release

# Android release builds
flutter build appbundle --flavor dev --release
flutter build appbundle --flavor prod --release
```

---

## Integration with Andrea's Architecture

### Compatibility with App Initialization Pattern

**Andrea's Initialization Flow (from his docs):**
```
main()
  ↓
Non-recoverable initialization (Sentry, Firebase)
  ↓
runApp(ProviderScope → RootAppWidget)
  ↓
MaterialApp.router with builder
  ↓
AppStartupWidget (manages appStartupProvider)
  ↓
Recoverable initialization (Database, user session, analytics)
```

**Flavors Integration Point:**

Flavors only affect **main.dart** and **.env file selection**. The rest of Andrea's pattern remains unchanged:

```dart
void main() async {
  // NEW: Determine flavor
  const flavor = String.fromEnvironment('FLAVOR', defaultValue: 'prod');

  // NEW: Load flavor-specific .env
  await dotenv.load(fileName: '.env.$flavor.local');

  // UNCHANGED: Andrea's pattern continues
  final config = AppConfig.fromEnv(flavor);
  await SentryFlutter.init(/* ... */);
  await Supabase.initialize(/* ... */);

  runApp(
    ProviderScope(
      overrides: [appConfigProvider.overrideWithValue(config)],
      child: const RootAppWidget(),
    ),
  );
}
```

**Key Insight:**
- Andrea's architecture is flavor-friendly
- AppConfig + Riverpod override pattern works perfectly
- RootAppWidget → AppStartupWidget flow unchanged
- Drift database initialization in appStartupProvider unchanged

---

## Key Takeaways for Mealvana

### From Andrea's Course

1. **Commit Before Running Flavorizr:**
   - Always commit changes before running any Flavorizr commands
   - Use `git reset --hard HEAD && git clean -fd` to rollback if needed

2. **Use Custom Processors for Existing Apps:**
   - DO NOT run `dart run flutter_flavorizr` without `-p` flag
   - Carefully select processors to avoid overwriting critical files
   - Especially protect main.dart with complex initialization

3. **Preserve Production Bundle IDs:**
   - Never change prod bundle ID/application ID
   - Only dev flavor gets modified ID (append `.dev`)
   - App stores identify apps by bundle ID

4. **Stage the Implementation:**
   - Android first (simpler, faster)
   - iOS second (more complex)
   - Icons optional (can add later)
   - Test thoroughly at each stage

5. **Consider Manual Setup for Production Apps:**
   - Manual setup gives more control
   - Safer for apps with complex initialization
   - Reduces risk of breaking existing functionality

### Decision for Mealvana

**Recommendation: Manual Setup**

**Reasons:**
1. Production app with existing users
2. Complex initialization pattern (Sentry, Supabase, AppConfig, Andrea's startup)
3. Cannot risk breaking main.dart
4. Better understanding of platform configuration
5. More control over exact changes

**Alternative: Staged Flavorizr with Custom Processors**

If time is critical:
1. Use custom processors carefully
2. Skip `dart:*` processors entirely
3. Test thoroughly after each stage
4. Manual cleanup of any issues

---

## Additional Resources

**From Andrea:**

- [Flutter Official Docs - Flavors](https://docs.flutter.dev/deployment/flavors)
- [Flutter Flavorizr Package](https://pub.dev/packages/flutter_flavorizr)
- [Andrea's Course Project](https://github.com/bizz84/flutter_ship_app)

**Mealvana-Specific:**
- `/docs/flavors/README.md` - Overview and decision framework
- `/docs/flavors/notes.md` - Technical analysis and file changes
- `/docs/flavors/roadmap.md` - Step-by-step implementation plan

---

**Last Updated:** 2025-12-16
**Source:** Andrea Bizzotto's Flutter Flavors Course
**Status:** Reference Document - Guidance Extracted and Adapted
