# Flutter Flavors Usage Guide

## Overview
Your app now supports two flavors: **dev** and **prod**. Each flavor loads a different environment configuration and can be installed side-by-side on the same device.

## What Changed

### Files Created
- `lib/main_dev.dart` - Development flavor entry point
- `lib/main_prod.dart` - Production flavor entry point
- `ios/Flutter/dev-Debug.xcconfig` - iOS dev debug config
- `ios/Flutter/dev-Profile.xcconfig` - iOS dev profile config
- `ios/Flutter/dev-Release.xcconfig` - iOS dev release config
- `ios/Flutter/prod-Debug.xcconfig` - iOS prod debug config
- `ios/Flutter/prod-Profile.xcconfig` - iOS prod profile config
- `ios/Flutter/prod-Release.xcconfig` - iOS prod release config

### Files Modified
- `android/app/build.gradle.kts` - Added product flavors
- `android/app/src/main/AndroidManifest.xml` - Uses flavor-specific app name
- `ios/Runner/Info.plist` - Uses bundle display name variable
- `lib/shared/services/app_config.dart` - Removed runtime switching logic
- `lib/features/settings/presentation/screens/settings_menu_screen.dart` - Removed environment switcher

### Files Deleted
- `lib/shared/widgets/environment_switcher_dialog.dart` - No longer needed

## Environment Configuration

### Required: Update .env Files

Your `.env.dev.local` and `.env.prod.local` files **MUST** include the `APP_ENVIRONMENT` variable:

**`.env.dev.local`:**
```bash
APP_ENVIRONMENT=dev
SUPABASE_URL=https://vlmtsdzpnjnavdgytcmi.supabase.co
# ... other dev config
```

**`.env.prod.local`:**
```bash
APP_ENVIRONMENT=prod
SUPABASE_URL=https://wvmvsodrvbkxfydabqed.supabase.co
# ... other prod config
```

This variable is used by `AppConfig.fromEnv()` to determine the environment.

## Running Flavors

### Development Flavor

**Android:**
```bash
flutter run --flavor dev -t lib/main_dev.dart
```

**iOS:**
```bash
flutter run --flavor dev -t lib/main_dev.dart
```

**Specific device:**
```bash
flutter run --flavor dev -t lib/main_dev.dart -d <device-id>
```

### Production Flavor

**Android:**
```bash
flutter run --flavor prod -t lib/main_prod.dart
```

**iOS:**
```bash
flutter run --flavor prod -t lib/main_prod.dart
```

## Building Flavors

### Android Builds

**Dev Debug APK:**
```bash
flutter build apk --flavor dev -t lib/main_dev.dart
```

**Dev Release APK:**
```bash
flutter build apk --flavor dev -t lib/main_dev.dart --release
```

**Dev App Bundle (for Play Store internal testing):**
```bash
flutter build appbundle --flavor dev -t lib/main_dev.dart --release
```

**Prod Release App Bundle:**
```bash
flutter build appbundle --flavor prod -t lib/main_prod.dart --release
```

### iOS Builds

**Dev Debug (connected device):**
```bash
flutter build ios --flavor dev -t lib/main_dev.dart --debug
```

**Dev Release IPA:**
```bash
flutter build ipa --flavor dev -t lib/main_dev.dart --release
```

**Prod Release IPA:**
```bash
flutter build ipa --flavor prod -t lib/main_prod.dart --release
```

## IDE Configuration

### VS Code

Create `.vscode/launch.json`:

```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "Dev Flavor",
      "request": "launch",
      "type": "dart",
      "program": "lib/main_dev.dart",
      "args": [
        "--flavor",
        "dev"
      ]
    },
    {
      "name": "Prod Flavor",
      "request": "launch",
      "type": "dart",
      "program": "lib/main_prod.dart",
      "args": [
        "--flavor",
        "prod"
      ]
    }
  ]
}
```

Then select the flavor from the debug dropdown and press F5.

### Android Studio / IntelliJ

1. **Edit Configurations** (top toolbar dropdown)
2. Click **+** → **Flutter**
3. **Name:** Dev Flavor
4. **Dart entrypoint:** `lib/main_dev.dart`
5. **Additional run args:** `--flavor dev`
6. Click **OK**

Repeat for Prod Flavor with `lib/main_prod.dart` and `--flavor prod`.

## App Identification

### On Device

Both flavors can be installed simultaneously:

**Dev Flavor:**
- **App Name:** Mealvana Endurance Dev
- **Bundle ID (iOS):** com.mealvana.endurance.dev
- **Package Name (Android):** com.milkman.mealvanaendurance.dev
- **Icon:** Same as prod (no visual distinction)

**Prod Flavor:**
- **App Name:** Mealvana Endurance
- **Bundle ID (iOS):** com.mealvana.endurance
- **Package Name (Android):** com.milkman.mealvanaendurance
- **Icon:** Same as dev

### Visual Indicators

**Dev Flavor:** Shows amber wrench icon in top-right corner when `devModeEnabled` is true.

**Prod Flavor:** No indicator (clean interface).

## Testing Strategy

### Internal Testing

**Dev Flavor:**
- Use for active development
- Deploy via TestFlight (iOS) or Internal Testing (Android)
- All testers should install dev flavor
- Points to dev Supabase, dev Mixpanel, development Sentry

**Prod Flavor:**
- Use for pre-release validation
- Deploy via TestFlight (iOS) or Internal Testing (Android)
- QA team installs prod flavor alongside dev
- Points to prod Supabase, prod Mixpanel, production Sentry

### Side-by-Side Testing

Testers can have both flavors installed simultaneously:

1. Install dev flavor for day-to-day testing
2. Install prod flavor for pre-release validation
3. Switch between apps to compare behavior
4. Different bundle IDs prevent conflicts

## What You Lost (Trade-offs)

### ❌ Runtime Environment Switching
- **Before:** Long-press Settings title → switch dev/prod → restart app
- **After:** Must uninstall and install different flavor
- **Mitigation:** Install both flavors simultaneously

### ❌ Single Build for Both Environments
- **Before:** One build, toggle at runtime
- **After:** Must build dev and prod separately
- **Mitigation:** Automated CI/CD handles this

## What You Gained (Benefits)

### ✅ True Environment Isolation
- No risk of accidentally using prod config in dev
- No SharedPreferences state to manage
- Clear separation at build time

### ✅ Side-by-Side Installation
- Dev and prod apps coexist on same device
- Easy to compare behavior between environments
- No uninstall/reinstall friction

### ✅ Cleaner Architecture
- No runtime switching logic in AppConfig
- Environment determined at compile time
- Follows Flutter best practices

### ✅ Visual Distinction
- App name clearly indicates environment
- Different icons in launcher (by name)
- Reduces confusion for testers

## CI/CD Integration (Your TODO)

You mentioned you'll configure Codemagic separately. Here's what you'll need:

### Branch → Flavor Mapping

**Recommended:**
- `develop` branch → build dev flavor automatically
- `main` branch → build prod flavor automatically

### Build Commands

**Dev Workflow:**
```yaml
scripts:
  - name: Build Android Dev
    script: flutter build appbundle --flavor dev -t lib/main_dev.dart --release
  - name: Build iOS Dev
    script: flutter build ipa --flavor dev -t lib/main_dev.dart --release
```

**Prod Workflow:**
```yaml
scripts:
  - name: Build Android Prod
    script: flutter build appbundle --flavor prod -t lib/main_prod.dart --release
  - name: Build iOS Prod
    script: flutter build ipa --flavor prod -t lib/main_prod.dart --release
```

### Shorebird Integration

**Dev Flavor:** No Shorebird (as per your requirements)

**Prod Flavor Only:**
```bash
# Create release
shorebird release ios --flavor prod -t lib/main_prod.dart

# Create patch
shorebird patch ios --flavor prod -t lib/main_prod.dart
```

## Troubleshooting

### "No flavor named 'dev' found"

**Cause:** iOS schemes not configured in Xcode.

**Fix:** Complete the Xcode setup instructions in `/docs/flavors/XCODE_SETUP_INSTRUCTIONS.md`.

### "Failed to load .env file"

**Cause:** `.env.dev.local` or `.env.prod.local` missing or not in project root.

**Fix:** Ensure both files exist and contain `APP_ENVIRONMENT` variable.

### Dev flavor shows prod data

**Cause:** `APP_ENVIRONMENT` not set correctly in `.env.dev.local`.

**Fix:** Add `APP_ENVIRONMENT=dev` to `.env.dev.local`.

### Both apps show same name

**Cause:** Android resource strings not generated correctly.

**Fix:**
```bash
cd android
./gradlew clean
cd ..
flutter clean
flutter pub get
flutter run --flavor dev -t lib/main_dev.dart
```

### Xcode build fails with "Configuration not found"

**Cause:** xcconfig files not associated with build configurations.

**Fix:** Follow Step 3 in XCODE_SETUP_INSTRUCTIONS.md to associate xcconfig files.

## Next Steps

1. ✅ **Complete Xcode Setup** (see `/docs/flavors/XCODE_SETUP_INSTRUCTIONS.md`)
2. ✅ **Add `APP_ENVIRONMENT` to .env files** (both dev and prod)
3. ✅ **Test dev flavor:** `flutter run --flavor dev -t lib/main_dev.dart`
4. ✅ **Test prod flavor:** `flutter run --flavor prod -t lib/main_prod.dart`
5. ✅ **Verify side-by-side installation** (both apps on same device)
6. ✅ **Configure Codemagic workflows** (dev and prod pipelines)
7. ✅ **Update Shorebird config** (prod flavor only)
8. ✅ **Test deployments** (internal testing tracks)

## Reference Commands

### Quick Commands

```bash
# Run dev
flutter run --flavor dev -t lib/main_dev.dart

# Run prod
flutter run --flavor prod -t lib/main_prod.dart

# Build dev release
flutter build appbundle --flavor dev -t lib/main_dev.dart --release

# Build prod release
flutter build appbundle --flavor prod -t lib/main_prod.dart --release

# Clean build
flutter clean && flutter pub get
```

### Check Available Flavors

```bash
# Android
cd android && ./gradlew app:tasks | grep assemble

# iOS (after Xcode setup)
xcodebuild -workspace ios/Runner.xcworkspace -list
```

## Questions?

Refer to:
- `/docs/flavors/README.md` - Overview and decision rationale
- `/docs/flavors/notes.md` - Technical implementation details
- `/docs/flavors/roadmap.md` - Full implementation plan
- `/docs/flavors/XCODE_SETUP_INSTRUCTIONS.md` - iOS configuration steps
