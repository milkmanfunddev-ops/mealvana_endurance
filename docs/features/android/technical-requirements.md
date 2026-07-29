# Android Technical Requirements

**Version:** 1.9.0+30
**Last Updated:** 2025-11-12

---

## Table of Contents

- [Android SDK Requirements](#android-sdk-requirements)
- [Package Requirements](#package-requirements)
- [Gradle Configuration](#gradle-configuration)
- [Permission Requirements](#permission-requirements)
- [Build Configuration](#build-configuration)
- [ProGuard/R8 Considerations](#proguardr8-considerations)

---

## Android SDK Requirements

### Current Status (build.gradle.kts)

```kotlin
// CURRENT (INCOMPLETE)
compileSdk = flutter.compileSdkVersion  // Unknown, likely 33 or 34
minSdk = flutter.minSdkVersion         // Unknown, should be 21
targetSdk = flutter.targetSdkVersion   // Unknown, must be 34
```

### Required Configuration

```kotlin
// REQUIRED FOR GOOGLE PLAY 2025
android {
    compileSdk = 35  // 🔴 CRITICAL: Required by multiple packages

    defaultConfig {
        minSdk = 21       // Android 5.0 (Lollipop) - broad compatibility
        targetSdk = 34    // 🔴 CRITICAL: Required by Google Play
        // Note: By August 2025, targetSdk 35 will be required
    }
}
```

### SDK Version Rationale

| Version | Requirement | Reason |
|---------|-------------|--------|
| **minSdk: 21** | Recommended | Covers 99%+ of Android devices, allows Drift, Supabase |
| **targetSdk: 34** | 🔴 MANDATORY | Google Play requires Android 14 targeting as of 2024 |
| **compileSdk: 35** | 🔴 CRITICAL | Required by supabase_flutter 2.8.5 and sentry_flutter 9.6.0 |

### Google Play Requirements Timeline

- **January 2024:** targetSdk 33 required
- **August 2024:** targetSdk 34 required (current requirement)
- **August 2025:** targetSdk 35 will be required
- **Recommendation:** Set compileSdk to 35 now for future-proofing

---

## Package Requirements

### Critical Packages Analysis

All package requirements have been researched based on 2024-2025 documentation:

#### 1. flutter_local_notifications 19.4.1

**Android Requirements:**
- Minimum Android SDK: 21
- Target SDK: 34+ recommended
- Compile SDK: 34+

**Key Features:**
- **Notification Channels** (Android 8.0+): Required for all notifications
- **Runtime Permissions** (Android 13+): POST_NOTIFICATIONS permission
- **Exact Alarms** (Android 12+): SCHEDULE_EXACT_ALARM permission
- **Boot Receivers**: RECEIVE_BOOT_COMPLETED for persistent notifications

**Required Gradle Configuration:**
```kotlin
android {
    compileOptions {
        // Required for notification library
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
```

**AndroidManifest.xml Additions:**
```xml
<!-- Android 13+ runtime permission -->
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>

<!-- Notification scheduling -->
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM" />
<uses-permission android:name="android.permission.USE_EXACT_ALARM" />

<!-- Receivers inside <application> tag -->
<receiver android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver"
          android:exported="false"/>
<receiver android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver"
          android:enabled="true"
          android:exported="false">
    <intent-filter>
        <action android:name="android.intent.action.BOOT_COMPLETED"/>
    </intent-filter>
</receiver>
```

**Code Changes Required:**
- Current `notification_service.dart` is iOS-only (lines 60-96)
- Must implement Android notification channels
- Must request Android 13+ runtime permissions

📚 **See:** [notification-implementation.md](./notification-implementation.md)

---

#### 2. mobile_scanner 7.0.1

**Android Requirements:**
- Minimum Android SDK: 21
- Compile SDK: 34+
- Camera permission required

**Permissions:**
```xml
<uses-permission android:name="android.permission.CAMERA"/>
<uses-feature android:name="android.camera" android:required="false"/>
<uses-feature android:name="android.camera.autofocus" android:required="false"/>
```

**Features:**
- ✅ Automatically requests camera permission at runtime
- ✅ Handles permission denial gracefully
- ✅ Works with Android 13+ photo/video policy (camera only, no gallery access)

**Code Status:**
- ✅ Package already in use
- 🟡 Needs permission in AndroidManifest.xml
- ✅ Runtime permission handled by package

---

#### 3. supabase_flutter 2.8.5

**Android Requirements:**
- **Compile SDK: 35** 🔴 CRITICAL
- Target SDK: 34+
- Internet permission required

**Known Issues:**
- Earlier versions had compileSdk 34 requirement
- Version 2.8.5 updated to compileSdk 35
- Must upgrade to compileSdk 35 in build.gradle.kts

**Permissions:**
```xml
<!-- Already present in AndroidManifest.xml -->
<uses-permission android:name="android.permission.INTERNET"/>
```

**Features:**
- ✅ Auth works cross-platform
- ✅ Realtime subscriptions work on Android
- ✅ Edge functions work on Android
- ✅ Offline mode with Drift integration

---

#### 4. sentry_flutter 9.6.0

**Android Requirements:**
- **Compile SDK: 35** 🔴 CRITICAL
- Target SDK: 34+
- Internet permission required

**Gradle Configuration:**
```kotlin
// Already in pubspec.yaml dev_dependencies
sentry_dart_plugin: ^3.1.1
```

**Features:**
- ✅ Crash reporting works on Android
- ✅ Performance monitoring enabled
- ✅ Source maps upload configured
- ✅ Native crash reporting (NDK)

**Verification:**
- Test crash reporting in release mode
- Verify source maps uploaded
- Check Sentry dashboard for Android events

---

#### 5. drift 2.20.0 + sqlite3_flutter_libs 0.5.0

**Android Requirements:**
- Minimum Android SDK: 21
- No special compile SDK requirements

**Features:**
- ✅ Works identically on iOS and Android
- ✅ Type-safe database with code generation
- ✅ No runtime permissions needed (internal storage)
- ✅ Automatic migrations handled

**Verification:**
- Test offline mode
- Verify data persistence across app restarts
- Check migration handling

---

#### 6. geolocator 13.0.2

**Android Requirements:**
- Minimum Android SDK: 21
- Location permissions required

**Permissions:**
```xml
<!-- Already present in AndroidManifest.xml -->
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
```

**Features:**
- ✅ Location permissions already in manifest
- ✅ Runtime permission handling built-in
- ✅ Works with Android 12+ approximate location

**Usage in App:**
- Used for race location features
- Not critical for core functionality

---

#### 7. mixpanel_flutter 2.4.4

**Android Requirements:**
- Minimum Android SDK: 21
- Internet permission required

**Features:**
- ✅ Analytics events work cross-platform
- ✅ No special Android configuration needed
- ✅ User identification works

**Verification:**
- Test analytics events in release mode
- Check Mixpanel dashboard for Android events

---

#### 8. device_info_plus 10.1.0

**Android Requirements:**
- No special requirements
- No permissions needed

**Features:**
- ✅ Used for device ID generation (auth_service.dart:191-212)
- ✅ Works cross-platform
- ✅ No runtime permissions

---

### Package Compatibility Matrix

| Package | Current Version | Min SDK | Compile SDK | Target SDK | Special Requirements |
|---------|----------------|---------|-------------|------------|---------------------|
| flutter_local_notifications | 19.4.1 | 21 | 34+ | 34+ | Desugaring, channels |
| mobile_scanner | 7.0.1 | 21 | 34+ | 34+ | Camera permission |
| supabase_flutter | 2.8.5 | 21 | **35** | 34+ | 🔴 Compile 35 required |
| sentry_flutter | 9.6.0 | 21 | **35** | 34+ | 🔴 Compile 35 required |
| drift | 2.20.0 | 21 | Any | 21+ | None |
| geolocator | 13.0.2 | 21 | 34+ | 34+ | Location permissions |
| mixpanel_flutter | 2.4.4 | 21 | 34+ | 34+ | None |
| device_info_plus | 10.1.0 | 21 | 34+ | 34+ | None |

**Key Takeaway:** compileSdk **must** be 35 due to supabase_flutter and sentry_flutter requirements.

---

## Gradle Configuration

### Complete build.gradle.kts Configuration

**File:** `/android/app/build.gradle.kts`

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
    compileSdk = 35  // 🔴 CRITICAL: Required by supabase/sentry
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // Enable desugaring for notification library
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.milkman.mealvanaendurance"
        minSdk = 21      // Android 5.0 (broad compatibility)
        targetSdk = 34   // 🔴 CRITICAL: Google Play requirement
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // Enable multidex for notification library
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
    // Desugaring for notification library
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
```

### Key Changes from Current

| Setting | Current | Required | Impact |
|---------|---------|----------|--------|
| compileSdk | flutter.compileSdkVersion | **35** | 🔴 Build will fail without this |
| targetSdk | flutter.targetSdkVersion | **34** | 🔴 Google Play rejects without this |
| minSdk | flutter.minSdkVersion | **21** | Should be explicit |
| multiDexEnabled | Not set | **true** | Needed for notification library |
| desugaring | Not enabled | **true** | Needed for notification library |
| signingConfig | debug | **release** | 🔴 Cannot publish without this |

---

## Permission Requirements

### Complete AndroidManifest.xml Permissions

**File:** `/android/app/src/main/AndroidManifest.xml`

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">

  <!-- Internet (required for Supabase, Mixpanel, Sentry) -->
  <uses-permission android:name="android.permission.INTERNET"/> <!-- ✅ Already present -->

  <!-- Notifications (Android 13+) -->
  <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/> <!-- 🔴 MISSING -->

  <!-- Camera for Barcode Scanning -->
  <uses-permission android:name="android.permission.CAMERA"/> <!-- 🔴 MISSING -->
  <uses-feature android:name="android.camera" android:required="false"/> <!-- 🔴 MISSING -->
  <uses-feature android:name="android.camera.autofocus" android:required="false"/> <!-- 🔴 MISSING -->

  <!-- Location Services (already present) -->
  <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/> <!-- ✅ Present -->
  <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/> <!-- ✅ Present -->

  <!-- Notification Scheduling -->
  <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/> <!-- 🔴 MISSING -->
  <uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM" /> <!-- 🔴 MISSING -->
  <uses-permission android:name="android.permission.USE_EXACT_ALARM" /> <!-- 🔴 MISSING -->

  <!-- Query for text processing (already present) -->
  <queries>
    <intent>
      <action android:name="android.intent.action.PROCESS_TEXT"/>
      <data android:mimeType="text/plain"/>
    </intent>
  </queries>

  <application ...>
    <!-- Notification receivers (inside application tag) -->
    <receiver android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver"
              android:exported="false"/> <!-- 🔴 MISSING -->
    <receiver android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver"
              android:enabled="true"
              android:exported="false"> <!-- 🔴 MISSING -->
      <intent-filter>
        <action android:name="android.intent.action.BOOT_COMPLETED"/>
      </intent-filter>
    </receiver>
  </application>

</manifest>
```

### Permission Justification for Data Safety Declaration

| Permission | Purpose | User-Facing Justification |
|------------|---------|--------------------------|
| INTERNET | Supabase, analytics, error tracking | "Required for syncing your nutrition plans and user data" |
| POST_NOTIFICATIONS | Meal reminders | "Optional: Receive reminders for your nutrition plans" |
| CAMERA | Barcode scanning | "Optional: Scan food barcodes to quickly add items" |
| ACCESS_FINE_LOCATION | Race location features | "Optional: Find races near you" |
| RECEIVE_BOOT_COMPLETED | Persistent notifications | "Ensures your reminders work after device restart" |
| SCHEDULE_EXACT_ALARM | Exact timing of reminders | "Deliver reminders at the exact time you set" |

**Note:** All permissions except INTERNET are runtime permissions that require user approval.

---

## Build Configuration

### Java Version Requirements

**Current Status:**
```kotlin
compileOptions {
    sourceCompatibility = JavaVersion.VERSION_11
    targetCompatibility = JavaVersion.VERSION_11
}

kotlinOptions {
    jvmTarget = JavaVersion.VERSION_11.toString()
}
```

✅ **Status:** Already correct, no changes needed.

### MultiDex Configuration

**Required Addition:**
```kotlin
defaultConfig {
    // ... other settings ...
    multiDexEnabled = true
}
```

**Why:** flutter_local_notifications and other dependencies exceed the 64K method limit.

### Desugaring Configuration

**Required Addition:**
```kotlin
android {
    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        // ... Java versions ...
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
```

**Why:** Notification library uses Java 8+ features not available on API 21-25 without desugaring.

---

## ProGuard/R8 Considerations

### Developer Decision: Disabled

The developer has chosen to **disable** ProGuard/R8 code shrinking and obfuscation:

```kotlin
buildTypes {
    release {
        isMinifyEnabled = false      // Code shrinking disabled
        isShrinkResources = false    // Resource shrinking disabled
    }
}
```

### Rationale

**Pros of Disabling:**
- ✅ No risk of breaking reflection-based code (Drift, Riverpod, Supabase)
- ✅ Easier debugging of production crashes
- ✅ No need for ProGuard rules maintenance
- ✅ Faster build times

**Cons of Disabling:**
- ⚠️ Larger APK/AAB size (~5-10MB increase)
- ⚠️ Source code more easily reverse-engineered
- ⚠️ No dead code elimination

### If You Change Your Mind

To enable ProGuard/R8:

1. **Set flags:**
```kotlin
release {
    isMinifyEnabled = true
    isShrinkResources = true
}
```

2. **Create proguard-rules.pro:**
```proguard
# Drift database
-keep class ** extends com.simolus.drift.database.Database { *; }
-keep class ** extends com.simolus.drift.database.Table { *; }

# Riverpod
-keep class ** extends com.riverpod.* { *; }

# Supabase
-keep class io.supabase.** { *; }
-dontwarn io.supabase.**

# Sentry
-keep class io.sentry.** { *; }
-dontwarn io.sentry.**

# Flutter
-keep class io.flutter.** { *; }
-dontwarn io.flutter.**
```

3. **Test thoroughly** - ProGuard can break functionality if rules are incomplete.

---

## Verification Checklist

Before building release:

- [ ] compileSdk set to 35
- [ ] targetSdk set to 34
- [ ] minSdk set to 21
- [ ] multiDexEnabled = true
- [ ] Desugaring enabled with dependency
- [ ] All required permissions in AndroidManifest.xml
- [ ] Notification receivers in AndroidManifest.xml
- [ ] Release signing configured
- [ ] Java 11 compatibility confirmed

**Verification Commands:**

```bash
# Check Gradle configuration
cd android
./gradlew app:dependencies

# Verify desugaring dependency
./gradlew app:dependencies | grep desugar

# Check for build errors
flutter analyze

# Build release bundle
flutter build appbundle --release
```

---

## Common Issues

### Issue: "SDK version not found"

**Symptom:**
```
Could not find compileSdk version 35
```

**Fix:**
Update Android SDK in Android Studio:
```
Tools > SDK Manager > SDK Platforms > Android 15.0 (API 35)
```

### Issue: "Desugaring failed"

**Symptom:**
```
java.lang.NoSuchMethodError: No static method ... in class Ljava/time/...
```

**Fix:**
Ensure desugaring is enabled and dependency added (see above).

### Issue: "Permission denied: SCHEDULE_EXACT_ALARM"

**Symptom:**
Notifications not scheduling on Android 12+.

**Fix:**
Request permission at runtime:
```dart
await AndroidAlarmManager.initialize();
```

---

## Resources

- [Android API Levels](https://apilevels.com/)
- [Google Play Target API Requirements](https://developer.android.com/google/play/requirements/target-sdk)
- [Android Permissions Guide](https://developer.android.com/guide/topics/permissions/overview)
- [Desugaring Documentation](https://developer.android.com/studio/write/java8-support)

---

*Last updated: 2025-11-12 for Mealvana Endurance v1.9.0+30*
