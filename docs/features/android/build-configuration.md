# Android Build Configuration Guide

**Version:** 1.9.0+30
**Last Updated:** 2025-11-12

---

## Table of Contents

- [Overview](#overview)
- [build.gradle.kts Configuration](#buildgradlekts-configuration)
- [Release Signing Setup](#release-signing-setup)
- [AndroidManifest.xml Configuration](#androidmanifestxml-configuration)
- [Shorebird Configuration](#shorebird-configuration)
- [Verification & Testing](#verification--testing)

---

## Overview

This guide covers all Android build configuration requirements for Mealvana Endurance v1.9.0+30. It includes Gradle settings, release signing, manifest configuration, and Shorebird setup.

### Current State vs. Required State

| Configuration | Current | Required | Impact |
|---------------|---------|----------|--------|
| compileSdk | Unknown (flutter default) | **35** | 🔴 Build fails without this |
| targetSdk | Unknown (flutter default) | **34** | 🔴 Google Play rejects |
| minSdk | Unknown (flutter default) | **21** | Should be explicit |
| signingConfig | debug | **release** | 🔴 Cannot publish |
| multiDexEnabled | Not set | **true** | 🔴 Build may fail |
| desugaring | Not enabled | **true** | 🔴 Crashes on API 21-25 |

---

## build.gradle.kts Configuration

**File:** `/android/app/build.gradle.kts`

### Complete Configuration

```kotlin
plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

// Load keystore properties for release signing
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = java.util.Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(java.io.FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.milkman.mealvanaendurance"
    compileSdk = 35  // 🔴 CRITICAL: Required by supabase_flutter 2.8.5 and sentry_flutter 9.6.0
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // Enable desugaring for notification library (Java 8+ features on API 21-25)
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.milkman.mealvanaendurance"
        minSdk = 21      // Android 5.0 (Lollipop) - 99%+ device coverage
        targetSdk = 34   // 🔴 CRITICAL: Google Play requires Android 14 targeting
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // Enable multidex for notification library (exceeds 64K method limit)
        multiDexEnabled = true
    }

    // Define signing configs
    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")

            // ProGuard/R8 disabled per developer decision
            // (avoids reflection issues with Drift, Riverpod, Supabase)
            isMinifyEnabled = false
            isShrinkResources = false
        }

        debug {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Desugaring dependency for Java 8+ features on older Android versions
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
```

### Configuration Breakdown

#### 1. SDK Versions

```kotlin
compileSdk = 35  // Compile against Android 15 SDK
minSdk = 21      // Support Android 5.0+
targetSdk = 34   // Target Android 14
```

**Why These Versions:**

| Version | Reason |
|---------|--------|
| **compileSdk: 35** | Required by supabase_flutter 2.8.5 and sentry_flutter 9.6.0. Build will fail if lower. |
| **targetSdk: 34** | Google Play **rejects** submissions without Android 14 targeting (as of August 2024). |
| **minSdk: 21** | Android 5.0 (Lollipop). Covers 99%+ of devices. Required by Drift and Supabase packages. |

**Future Consideration:**
- August 2025: Google Play will require targetSdk 35
- Consider updating targetSdk to 35 before then

#### 2. Java Configuration

```kotlin
compileOptions {
    isCoreLibraryDesugaringEnabled = true
    sourceCompatibility = JavaVersion.VERSION_11
    targetCompatibility = JavaVersion.VERSION_11
}

kotlinOptions {
    jvmTarget = JavaVersion.VERSION_11.toString()
}
```

**Why Java 11:**
- Flutter 3.8+ requires Java 11
- Notification library uses Java 8+ features (`java.time.*`)
- Desugaring backports these features to API 21-25

**What is Desugaring:**
- Converts Java 8+ bytecode to Java 7 compatible code
- Allows using modern APIs on older Android versions
- Required for `flutter_local_notifications` on API 21-25

#### 3. MultiDex

```kotlin
defaultConfig {
    multiDexEnabled = true
}
```

**Why Needed:**
- Android has 64K method reference limit per DEX file
- `flutter_local_notifications` + dependencies exceed this limit
- MultiDex splits code across multiple DEX files

**Impact:**
- Slightly slower app startup (~100-200ms)
- Essential for app to build and run

#### 4. Signing Configs

```kotlin
signingConfigs {
    create("release") {
        if (keystorePropertiesFile.exists()) {
            keyAlias = keystoreProperties["keyAlias"] as String
            keyPassword = keystoreProperties["keyPassword"] as String
            storeFile = file(keystoreProperties["storeFile"] as String)
            storePassword = keystoreProperties["storePassword"] as String
        }
    }
}

buildTypes {
    release {
        signingConfig = signingConfigs.getByName("release")
    }
}
```

**See:** [Release Signing Setup](#release-signing-setup) below for detailed keystore creation.

#### 5. ProGuard/R8 (Disabled)

```kotlin
buildTypes {
    release {
        isMinifyEnabled = false      // No code shrinking
        isShrinkResources = false    // No resource shrinking
    }
}
```

**Why Disabled:**
- Avoids breaking reflection-based code (Drift, Riverpod, Supabase)
- Simplifies debugging of production crashes
- No ProGuard rules to maintain

**Trade-offs:**
- **Pro:** No risk of runtime crashes from ProGuard issues
- **Con:** APK/AAB ~5-10MB larger
- **Con:** Source code easier to reverse-engineer

**If You Enable ProGuard Later:**
```kotlin
buildTypes {
    release {
        isMinifyEnabled = true
        isShrinkResources = true
        proguardFiles(
            getDefaultProguardFile("proguard-android-optimize.txt"),
            "proguard-rules.pro"
        )
    }
}
```

Then create `/android/app/proguard-rules.pro`:
```proguard
# Drift
-keep class ** extends com.simolus.drift.database.Database { *; }

# Riverpod
-keep class ** extends com.riverpod.* { *; }

# Supabase
-keep class io.supabase.** { *; }
-dontwarn io.supabase.**

# Sentry
-keep class io.sentry.** { *; }
-dontwarn io.sentry.**
```

---

## Release Signing Setup

### Overview

Android requires all release builds to be signed with a production keystore. Debug builds use an automatically-generated debug keystore.

**⚠️ CRITICAL WARNING:**
- If you lose the release keystore, you can **NEVER** update the app on Google Play
- Users would have to uninstall and reinstall
- You'd lose all reviews, ratings, and download counts
- **Back up the keystore immediately after creation**

### Step 1: Generate Keystore

**⚠️ Lee must run these commands:**

```bash
# Navigate to Android app directory
cd /Users/leemartin/development/mealvana_endurance/android/app

# Generate release keystore
keytool -genkey -v -keystore mealvana-release-key.jks \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000 \
  -alias mealvana-release
```

**Interactive Prompts:**

```
Enter keystore password: ********
Re-enter new password: ********
What is your first and last name?
  [Unknown]: Lee Martin
What is the name of your organizational unit?
  [Unknown]: Development
What is the name of your organization?
  [Unknown]: Milkman
What is the name of your City or Locality?
  [Unknown]: San Francisco
What is the name of your State or Province?
  [Unknown]: CA
What is the two-letter country code for this unit?
  [Unknown]: US
Is CN=Lee Martin, OU=Development, O=Milkman, L=San Francisco, ST=CA, C=US correct?
  [no]: yes

Enter key password for <mealvana-release>
  (RETURN if same as keystore password): ********
Re-enter new password: ********
```

**What to Remember:**

| Item | Value | Storage |
|------|-------|---------|
| Keystore Password | Your chosen password | Password manager |
| Key Password | Your chosen password (can be same) | Password manager |
| Key Alias | `mealvana-release` | Fixed value |
| Keystore Location | `android/app/mealvana-release-key.jks` | Fixed path |

### Step 2: Back Up Keystore

**⚠️ IMMEDIATELY after creation:**

```bash
# Copy to secure backup location
cp android/app/mealvana-release-key.jks ~/Backups/
# Or upload to secure cloud storage (Dropbox, Google Drive, 1Password)
```

**Backup Checklist:**
- [ ] Keystore file backed up to at least 2 locations
- [ ] Passwords stored in password manager
- [ ] Key alias documented (`mealvana-release`)
- [ ] Team members know where backups are

### Step 3: Create key.properties

**⚠️ Lee creates this file manually:**

**File:** `/android/key.properties`

**Content:**
```properties
storePassword=YOUR_KEYSTORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=mealvana-release
storeFile=app/mealvana-release-key.jks
```

**Example (with real passwords):**
```properties
storePassword=MySecurePassword123!
keyPassword=MySecurePassword123!
keyAlias=mealvana-release
storeFile=app/mealvana-release-key.jks
```

**⚠️ SECURITY:**
- This file is in `.gitignore` - **DO NOT** commit it
- Contains plaintext passwords - keep secure
- Only needed on machines that build release builds

**Verify .gitignore:**
```bash
grep key.properties .gitignore
# Expected: "android/key.properties" or "**/key.properties"
```

### Step 4: Verify Signing Works

```bash
# Build release AAB
flutter build appbundle --release

# Should succeed without signing errors
# Output: build/app/outputs/bundle/release/app-release.aab

# Verify AAB is signed
jarsigner -verify -verbose -certs build/app/outputs/bundle/release/app-release.aab

# Expected output:
# jar verified.
#
# This jar contains entries whose certificate chain is not validated.
# (This is normal - Google Play will re-sign with their key)
```

---

## AndroidManifest.xml Configuration

**File:** `/android/app/src/main/AndroidManifest.xml`

### Complete Configuration

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">

  <!-- Internet (required for Supabase, Mixpanel, Sentry) -->
  <uses-permission android:name="android.permission.INTERNET"/>

  <!-- Notifications (Android 13+) -->
  <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>

  <!-- Camera for Barcode Scanning -->
  <uses-permission android:name="android.permission.CAMERA"/>
  <uses-feature android:name="android.camera" android:required="false"/>
  <uses-feature android:name="android.camera.autofocus" android:required="false"/>

  <!-- Location Services (race finder feature) -->
  <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
  <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>

  <!-- Notification Scheduling -->
  <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
  <uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM" />
  <uses-permission android:name="android.permission.USE_EXACT_ALARM" />

  <!-- Query for text processing (required by Flutter) -->
  <queries>
    <intent>
      <action android:name="android.intent.action.PROCESS_TEXT"/>
      <data android:mimeType="text/plain"/>
    </intent>
  </queries>

  <application
      android:label="Mealvana Run"
      android:name="${applicationName}"
      android:icon="@mipmap/launcher_icon">

    <activity
        android:name=".MainActivity"
        android:exported="true"
        android:launchMode="singleTop"
        android:taskAffinity=""
        android:theme="@style/LaunchTheme"
        android:configChanges="orientation|keyboardHidden|keyboard|screenSize|smallestScreenSize|locale|layoutDirection|fontScale|screenLayout|density|uiMode"
        android:hardwareAccelerated="true"
        android:windowSoftInputMode="adjustResize">

      <meta-data
          android:name="io.flutter.embedding.android.NormalTheme"
          android:resource="@style/NormalTheme"/>

      <intent-filter>
        <action android:name="android.intent.action.MAIN"/>
        <category android:name="android.intent.category.LAUNCHER"/>
      </intent-filter>
    </activity>

    <!-- Notification receivers for flutter_local_notifications -->
    <receiver
        android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver"
        android:exported="false"/>

    <receiver
        android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver"
        android:enabled="true"
        android:exported="false">
      <intent-filter>
        <action android:name="android.intent.action.BOOT_COMPLETED"/>
      </intent-filter>
    </receiver>

    <!-- Flutter metadata -->
    <meta-data
        android:name="flutterEmbedding"
        android:value="2"/>
  </application>

</manifest>
```

### Permission Breakdown

| Permission | Required By | User-Facing Purpose | Runtime? |
|------------|-------------|---------------------|----------|
| INTERNET | Supabase, Sentry, Mixpanel | Sync data, track analytics | No (install-time) |
| POST_NOTIFICATIONS | flutter_local_notifications | Meal reminders | Yes (Android 13+) |
| CAMERA | mobile_scanner | Barcode scanning | Yes |
| ACCESS_FINE_LOCATION | geolocator | Race finder | Yes |
| ACCESS_COARSE_LOCATION | geolocator | Race finder | Yes |
| RECEIVE_BOOT_COMPLETED | flutter_local_notifications | Reschedule notifications after reboot | No |
| SCHEDULE_EXACT_ALARM | flutter_local_notifications | Exact timing for reminders | Special (Android 12+) |
| USE_EXACT_ALARM | flutter_local_notifications | Alternative exact alarm permission | Special (Android 12+) |

**Runtime Permissions:**
- Require user approval via system dialog
- Can be requested at any time
- User can revoke in Settings

**Install-Time Permissions:**
- Automatically granted on installation
- Cannot be revoked by user

**Special Permissions:**
- Require specific user action (e.g., navigating to settings)
- `SCHEDULE_EXACT_ALARM` requires user to allow in Settings > Apps > Special access > Alarms & reminders

---

## Shorebird Configuration

### Overview

Shorebird enables over-the-air (OTA) updates for Android without going through Google Play Store review.

**Use Cases:**
- ✅ Dart code changes (bug fixes, UI updates)
- ✅ Asset changes (images, fonts)
- ❌ Native code changes (requires Play Store release)
- ❌ Dependency updates (requires Play Store release)

### File: `/shorebird.yaml`

**Expected Content:**
```yaml
# Shorebird app ID (generated during shorebird init)
app_id: YOUR_SHOREBIRD_APP_ID

# Flavor configuration
flavors:
  development: com.milkman.mealvanaendurance.dev
  production: com.milkman.mealvanaendurance
```

### Setup Steps

#### 1. Install Shorebird CLI

```bash
# Install Shorebird (if not already installed)
curl --proto '=https' --tlsv1.2 https://raw.githubusercontent.com/shorebirdtech/install/main/install.sh -sSf | bash

# Add to PATH
export PATH="$HOME/.shorebird/bin:$PATH"

# Verify installation
shorebird --version
```

#### 2. Initialize Android Platform

```bash
# In project root
cd /Users/leemartin/development/mealvana_endurance

# Initialize Android platform
shorebird init --platforms android

# This will:
# - Update shorebird.yaml for Android
# - Configure Android build files
# - Set up Shorebird instrumentation
```

#### 3. Create Baseline Release

```bash
# Create first Shorebird release for Android
shorebird release android --target lib/main.dart

# Build time: ~5-10 minutes
# This creates the baseline that patches will be based on
```

#### 4. Upload to Google Play

```bash
# The generated AAB is at:
# build/app/outputs/bundle/release/app-release.aab

# Upload this to Google Play Console (Open Testing or Production)
```

#### 5. Create Patch (When Needed)

```bash
# After making Dart code changes
shorebird patch android --target lib/main.dart

# Patch time: ~2-5 minutes
# Users automatically receive update (no Play Store review)
```

### Shorebird Workflow

**Full Release (Use for):**
- Android manifest changes
- Dependency version updates
- Native code changes
- Permission additions
- First release or major version

**Patch (Use for):**
- Dart code bug fixes
- UI updates
- Business logic changes
- Asset updates

---

## Verification & Testing

### 1. Gradle Configuration Verification

```bash
# Check Gradle configuration
cd android
./gradlew app:dependencies

# Verify desugaring dependency
./gradlew app:dependencies | grep desugar
# Expected: com.android.tools:desugar_jdk_libs:2.1.4

# Check for configuration issues
./gradlew assembleRelease --warning-mode all

# Look for warnings about:
# - Deprecated APIs
# - Incorrect SDK versions
# - Missing dependencies
```

### 2. Build Verification

```bash
# Clean build
flutter clean

# Build release AAB
flutter build appbundle --release

# Expected: Success with output at build/app/outputs/bundle/release/app-release.aab
```

### 3. Signing Verification

```bash
# Verify AAB signature
jarsigner -verify -verbose -certs build/app/outputs/bundle/release/app-release.aab

# Expected output:
# jar verified.

# View certificate details
jarsigner -verify -verbose -certs build/app/outputs/bundle/release/app-release.aab | grep "Signed by"
# Expected: Shows your certificate CN (e.g., "CN=Lee Martin")
```

### 4. APK Size Analysis

```bash
# Build APK for size analysis
flutter build apk --release --analyze-size

# Expected output:
# ================================== Summary ==================================
# Total size: ~50-60MB (without ProGuard)
#
# Dart code: ~8MB
# Native code: ~15MB
# Assets: ~5MB
# Other: ~25MB

# If size is concerning, consider enabling ProGuard/R8
```

### 5. Install on Device

```bash
# Uninstall debug version (different signature)
adb uninstall com.milkman.mealvanaendurance

# Install release APK
flutter install --release

# Launch app
adb shell am start -n com.milkman.mealvanaendurance/.MainActivity

# Check for crashes
adb logcat | grep -E "AndroidRuntime|flutter"
```

### 6. Manifest Verification

```bash
# Dump merged manifest
cd android
./gradlew app:processDebugManifest

# View merged manifest
cat app/build/intermediates/merged_manifests/debug/AndroidManifest.xml

# Verify permissions are present:
# - POST_NOTIFICATIONS
# - CAMERA
# - RECEIVE_BOOT_COMPLETED
# - SCHEDULE_EXACT_ALARM
```

---

## Troubleshooting

### Issue: "SDK version not found"

**Symptom:**
```
Could not find compileSdk version 35
```

**Fix:**
```bash
# Update Android SDK in Android Studio
# Tools > SDK Manager > SDK Platforms > Android 15.0 (API 35)

# Or via command line
sdkmanager "platforms;android-35"
```

### Issue: "Keystore file not found"

**Symptom:**
```
Execution failed for task ':app:packageRelease'.
> A failure occurred while executing com.android.build.gradle.internal.tasks.Workers$ActionFacade
> File not found: android/app/mealvana-release-key.jks
```

**Fix:**
```bash
# Verify keystore exists
ls -l android/app/mealvana-release-key.jks

# Verify key.properties exists
cat android/key.properties

# Check storeFile path in key.properties
# Should be: storeFile=app/mealvana-release-key.jks
```

### Issue: "Desugaring failed"

**Symptom:**
```
java.lang.NoSuchMethodError: No static method metaClass
```

**Fix:**
```kotlin
// Ensure desugaring is enabled in build.gradle.kts
android {
    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        // ...
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
```

### Issue: "MultiDex error"

**Symptom:**
```
The number of method references in a .dex file cannot exceed 64K.
```

**Fix:**
```kotlin
// Enable multidex in build.gradle.kts
defaultConfig {
    multiDexEnabled = true
}
```

---

## Checklist

### build.gradle.kts

- [ ] compileSdk = 35
- [ ] targetSdk = 34
- [ ] minSdk = 21
- [ ] multiDexEnabled = true
- [ ] Desugaring enabled
- [ ] desugar_jdk_libs dependency added
- [ ] Signing configs defined
- [ ] Release build type uses release signing

### Release Signing

- [ ] Keystore generated: `android/app/mealvana-release-key.jks`
- [ ] key.properties created: `android/key.properties`
- [ ] Keystore backed up to secure location
- [ ] Passwords stored in password manager
- [ ] Release AAB builds and signs successfully

### AndroidManifest.xml

- [ ] All required permissions added
- [ ] Notification receivers added
- [ ] Camera feature marked as optional
- [ ] App name and icon configured

### Shorebird

- [ ] Shorebird CLI installed
- [ ] Android platform initialized
- [ ] shorebird.yaml configured
- [ ] Baseline release created (optional for now)

### Verification

- [ ] `flutter analyze` passes
- [ ] Release AAB builds successfully
- [ ] AAB signature verified with jarsigner
- [ ] App installs on physical device
- [ ] No crashes on launch

---

## Resources

- [Android Build Configuration](https://developer.android.com/studio/build)
- [App Signing Guide](https://developer.android.com/studio/publish/app-signing)
- [Desugaring Documentation](https://developer.android.com/studio/write/java8-support)
- [Shorebird Documentation](https://docs.shorebird.dev/)

---

*Last updated: 2025-11-12 for Mealvana Endurance v1.9.0+30*
