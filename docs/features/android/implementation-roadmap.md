# Android Implementation Roadmap

**Version:** 1.9.0+30
**Target:** Google Play Store Open Testing
**Timeline:** 5-7 days (technical implementation)
**Last Updated:** 2025-11-12

---

## Table of Contents

- [Overview](#overview)
- [Phase 1: Android Manifest & Permissions](#phase-1-android-manifest--permissions-day-1)
- [Phase 2: Target SDK & Build Configuration](#phase-2-target-sdk--build-configuration-day-2)
- [Phase 3: Release Build Configuration](#phase-3-release-build-configuration-day-3)
- [Phase 4: Notification Implementation](#phase-4-notification-implementation-day-4)
- [Phase 5: Testing & Validation](#phase-5-testing--validation-day-5)
- [Phase 6: Shorebird Android Setup](#phase-6-shorebird-android-setup-day-6)
- [Phase 7: Google Play Submission](#phase-7-google-play-submission-day-7)
- [Verification Checklist](#verification-checklist)
- [Risk Mitigation](#risk-mitigation)

---

## Overview

This roadmap provides a step-by-step implementation plan for deploying Mealvana Endurance v1.9.0+30 to Google Play Store. The plan assumes:

- ✅ Core app functionality is working on Android (tested locally)
- ✅ All Flutter packages are compatible with Android
- ✅ Developer has access to a physical Android device for testing
- 🔴 Critical blockers exist (target SDK, signing, notifications)

### Timeline Summary

| Phase | Duration | Status | Priority |
|-------|----------|--------|----------|
| Phase 1: Manifest & Permissions | 1-2 hours | ⚪ Not Started | 🔴 Critical |
| Phase 2: SDK & Build Config | 1-2 hours | ⚪ Not Started | 🔴 Critical |
| Phase 3: Release Signing | 2-3 hours | ⚪ Not Started | 🔴 Critical |
| Phase 4: Notifications | 4-6 hours | ⚪ Not Started | 🔴 Critical |
| Phase 5: Testing | 4-8 hours | ⚪ Not Started | 🟡 Medium |
| Phase 6: Shorebird Setup | 1-2 hours | ⚪ Not Started | 🟡 Medium |
| Phase 7: Play Store Prep | 2-4 hours | ⚪ Not Started | 🟡 Medium |

**Total Technical Time:** 15-27 hours over 5-7 days

---

## Phase 1: Android Manifest & Permissions (Day 1)

**Duration:** 1-2 hours
**Priority:** 🔴 CRITICAL

### 1.1 Update AndroidManifest.xml Permissions

**File:** `/android/app/src/main/AndroidManifest.xml`

**Current State:**
```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
  <uses-permission android:name="android.permission.INTERNET"/>
  <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
  <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
  <!-- Missing: POST_NOTIFICATIONS, CAMERA, RECEIVE_BOOT_COMPLETED, etc. -->
</manifest>
```

**Add These Permissions:**

```xml
<!-- Notifications (Android 13+) -->
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>

<!-- Camera for Barcode Scanning -->
<uses-permission android:name="android.permission.CAMERA"/>
<uses-feature android:name="android.camera" android:required="false"/>
<uses-feature android:name="android.camera.autofocus" android:required="false"/>

<!-- Notification Scheduling -->
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM" />
<uses-permission android:name="android.permission.USE_EXACT_ALARM" />
```

**Why Each Permission:**

| Permission | Required By | User Impact |
|------------|-------------|-------------|
| POST_NOTIFICATIONS | flutter_local_notifications | Android 13+ requires runtime permission |
| CAMERA | mobile_scanner | Runtime permission for barcode scanning |
| RECEIVE_BOOT_COMPLETED | flutter_local_notifications | Notifications persist after reboot |
| SCHEDULE_EXACT_ALARM | flutter_local_notifications | Exact timing for reminders (Android 12+) |
| USE_EXACT_ALARM | flutter_local_notifications | Alternative permission for exact alarms |

### 1.2 Add Notification Receivers

**Still in AndroidManifest.xml**, inside the `<application>` tag, **after** the `<activity>` closing tag:

```xml
<application ...>
    <activity ...>
        <!-- Existing activity configuration -->
    </activity>

    <!-- ADD THESE RECEIVERS -->
    <receiver android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver"
              android:exported="false"/>

    <receiver android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver"
              android:enabled="true"
              android:exported="false">
        <intent-filter>
            <action android:name="android.intent.action.BOOT_COMPLETED"/>
        </intent-filter>
    </receiver>

    <!-- Existing meta-data -->
    <meta-data android:name="flutterEmbedding" android:value="2"/>
</application>
```

**Why These Receivers:**
- `ScheduledNotificationReceiver` - Handles notification delivery
- `ScheduledNotificationBootReceiver` - Reschedules notifications after device reboot

### 1.3 Verification

```bash
# Check for syntax errors
flutter analyze

# Build debug to verify manifest changes
flutter build apk --debug

# Expected: No manifest-related errors
```

**Checklist:**
- [ ] All permissions added to AndroidManifest.xml
- [ ] Notification receivers added inside `<application>` tag
- [ ] `flutter analyze` passes without manifest errors
- [ ] Debug build succeeds

---

## Phase 2: Target SDK & Build Configuration (Day 2)

**Duration:** 1-2 hours
**Priority:** 🔴 CRITICAL

### 2.1 Update Target SDK to 34

**File:** `/android/app/build.gradle.kts`

**Current State (INCORRECT):**
```kotlin
defaultConfig {
    applicationId = "com.milkman.mealvanaendurance"
    minSdk = flutter.minSdkVersion      // Unknown, should be explicit
    targetSdk = flutter.targetSdkVersion  // Unknown, must be 34
    versionCode = flutter.versionCode
    versionName = flutter.versionName
}
```

**Update To:**
```kotlin
defaultConfig {
    applicationId = "com.milkman.mealvanaendurance"
    minSdk = 21        // Android 5.0 (explicit for clarity)
    targetSdk = 34     // 🔴 CRITICAL: Required for Google Play 2025
    versionCode = flutter.versionCode
    versionName = flutter.versionName

    // Enable multidex for notification library
    multiDexEnabled = true
}
```

**Why:**
- **minSdk 21**: Covers 99%+ of devices, required by Drift and Supabase
- **targetSdk 34**: Google Play **rejects** submissions without Android 14 targeting
- **multiDexEnabled**: Notification library exceeds 64K method limit

### 2.2 Update Compile SDK to 35

**Still in `/android/app/build.gradle.kts`:**

**Current State:**
```kotlin
android {
    namespace = "com.milkman.mealvanaendurance"
    compileSdk = flutter.compileSdkVersion  // Unknown, must be 35
    ndkVersion = flutter.ndkVersion
}
```

**Update To:**
```kotlin
android {
    namespace = "com.milkman.mealvanaendurance"
    compileSdk = 35  // 🔴 CRITICAL: Required by supabase_flutter 2.8.5
    ndkVersion = flutter.ndkVersion
}
```

**Why:**
- `supabase_flutter 2.8.5` requires compileSdk 35
- `sentry_flutter 9.6.0` requires compileSdk 35
- Future-proofs for August 2025 when targetSdk 35 will be required

### 2.3 Enable Java 11 Desugaring

**Still in `/android/app/build.gradle.kts`:**

**Current State (CORRECT):**
```kotlin
compileOptions {
    sourceCompatibility = JavaVersion.VERSION_11
    targetCompatibility = JavaVersion.VERSION_11
}

kotlinOptions {
    jvmTarget = JavaVersion.VERSION_11.toString()
}
```

✅ **Already correct, no changes needed.**

**Add Desugaring:**
```kotlin
android {
    // ... existing config ...

    compileOptions {
        // Add this line
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }
}

dependencies {
    // Add this dependency at the end of the file
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
```

**Why:**
- Notification library uses Java 8+ features (`java.time.*`)
- Desugaring enables these features on Android API 21-25
- Without this, notifications will crash on older devices

### 2.4 Verification

```bash
# Clean build
flutter clean
cd android
./gradlew clean

# Check for desugaring dependency
./gradlew app:dependencies | grep desugar
# Expected output: com.android.tools:desugar_jdk_libs:2.1.4

# Build debug
cd ..
flutter build apk --debug

# Expected: No SDK-related errors
```

**Checklist:**
- [ ] compileSdk set to 35
- [ ] targetSdk set to 34
- [ ] minSdk set to 21
- [ ] multiDexEnabled = true
- [ ] Desugaring enabled
- [ ] desugar_jdk_libs dependency added
- [ ] Debug build succeeds

---

## Phase 3: Release Build Configuration (Day 3)

**Duration:** 2-3 hours
**Priority:** 🔴 CRITICAL

### 3.1 Generate Release Keystore

**⚠️ IMPORTANT:** Lee must run these commands himself (requires password creation).

**Commands for Lee:**

```bash
# Navigate to Android app directory
cd /Users/leemartin/development/mealvana_endurance/android/app

# Generate keystore
keytool -genkey -v -keystore mealvana-release-key.jks \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000 \
  -alias mealvana-release

# You'll be prompted for:
# 1. Keystore password (create a strong password)
# 2. Key password (can be same as keystore password)
# 3. Your name (e.g., "Lee Martin")
# 4. Organization unit (e.g., "Development")
# 5. Organization (e.g., "Milkman")
# 6. City (e.g., "San Francisco")
# 7. State (e.g., "CA")
# 8. Country code (e.g., "US")
```

**What to Remember:**
| Item | Value | Notes |
|------|-------|-------|
| Keystore Password | `<your_password>` | ⚠️ Write this down securely |
| Key Password | `<your_password>` | Can be same as keystore password |
| Key Alias | `mealvana-release` | Fixed value, don't change |
| Keystore Location | `android/app/mealvana-release-key.jks` | Fixed path |

**⚠️ CRITICAL SECURITY:**
1. **Back up the keystore file** - If you lose this, you can **never** update the app on Google Play
2. **Store passwords securely** - Use a password manager
3. **Do NOT commit to git** - Already in `.gitignore`

**Verification:**
```bash
# Check keystore was created
ls -l android/app/mealvana-release-key.jks
# Expected: File exists with ~2-3KB size
```

### 3.2 Create key.properties File

**⚠️ Lee creates this file manually.**

**File:** `/android/key.properties`

**Content:**
```properties
storePassword=YOUR_KEYSTORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=mealvana-release
storeFile=app/mealvana-release-key.jks
```

**Example:**
```properties
storePassword=MySecurePassword123!
keyPassword=MySecurePassword123!
keyAlias=mealvana-release
storeFile=app/mealvana-release-key.jks
```

**⚠️ SECURITY:**
- This file is in `.gitignore` - do NOT commit it
- Replace `YOUR_KEYSTORE_PASSWORD` and `YOUR_KEY_PASSWORD` with actual passwords

**Verification:**
```bash
# Check file exists
cat android/key.properties
# Expected: Shows your configuration (without exposing passwords in git)

# Verify it's in .gitignore
grep key.properties .gitignore
# Expected: "android/key.properties" or "**/key.properties"
```

### 3.3 Update build.gradle.kts for Release Signing

**File:** `/android/app/build.gradle.kts`

**Add at the top, before `android {` block:**

```kotlin
plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

// ADD THIS SECTION
// Load keystore properties
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = java.util.Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(java.io.FileInputStream(keystorePropertiesFile))
}

android {
    // ... existing config ...
```

**Replace the `buildTypes` section:**

**Current (INCORRECT):**
```kotlin
buildTypes {
    release {
        // TODO: Add your own signing config for the release build.
        // Signing with the debug keys for now, so `flutter run --release` works.
        signingConfig = signingConfigs.getByName("debug")
    }
}
```

**Update To:**
```kotlin
android {
    // ... existing config ...

    // Add signing configs
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
```

**Why:**
- Release builds are signed with production keystore
- Debug builds still use debug keystore for development
- ProGuard/R8 disabled to avoid reflection issues with Drift/Riverpod

### 3.4 Build & Verify Release Build

```bash
# Clean build
flutter clean

# Build release AAB (Android App Bundle)
flutter build appbundle --release

# Expected output:
# ✓ Built build/app/outputs/bundle/release/app-release.aab

# Verify signing
cd android
./gradlew app:dependencies | grep release
cd ..

# Check AAB signature
jarsigner -verify -verbose -certs build/app/outputs/bundle/release/app-release.aab

# Expected output: "jar verified."
```

**Checklist:**
- [ ] Keystore generated: `android/app/mealvana-release-key.jks`
- [ ] key.properties created: `android/key.properties`
- [ ] Keystore passwords stored securely (password manager)
- [ ] Keystore backed up to secure location
- [ ] build.gradle.kts updated with signing config
- [ ] Release AAB builds successfully
- [ ] AAB signature verified with jarsigner

**⚠️ BACKUP REMINDER:** Copy `mealvana-release-key.jks` to a secure backup location NOW.

---

## Phase 4: Notification Implementation (Day 4)

**Duration:** 4-6 hours
**Priority:** 🔴 CRITICAL

**📚 Full details in:** [notification-implementation.md](./notification-implementation.md)

### 4.1 Current State Analysis

**File:** `/lib/shared/services/notification_service.dart`

**Lines 60-96 (iOS-ONLY CODE):**
```dart
static Future<bool> requestPermissions() async {
  if (!_isInitialized) {
    await initialize();
  }

  if (Platform.isIOS) {  // ⚠️ Android not handled
    final iosPlugin = _plugin
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    if (iosPlugin != null) {
      return await iosPlugin.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    }
  }

  return false;  // ⚠️ Android always returns false
}
```

**Problem:** Android notification permissions and channels are not implemented.

### 4.2 Implement Android Notification Channels

**Update:** `/lib/shared/services/notification_service.dart`

**Add constants at the top of the class:**
```dart
class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _isInitialized = false;
  static int? _pendingNavigationActivityId;
  static AnalyticsTracker _analytics = const NoopAnalyticsTracker();

  // ADD THESE CONSTANTS
  static const String channelId = 'nutrition_plan_reminders';
  static const String channelName = 'Nutrition Plan Reminders';
  static const String channelDescription = 'Reminders for your nutrition plans and meals';
```

**Update `initialize()` method:**
```dart
static Future<void> initialize() async {
  if (_isInitialized) return;

  tz.initializeTimeZones();

  const iosSettings = DarwinInitializationSettings(
    requestAlertPermission: false,
    requestBadgePermission: false,
    requestSoundPermission: false,
  );

  // UPDATE: Use correct icon reference
  const androidSettings = AndroidInitializationSettings('@mipmap/launcher_icon');

  const initializationSettings = InitializationSettings(
    android: androidSettings,
    iOS: iosSettings,
  );

  await _plugin.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse: _onNotificationTapped,
  );

  // ADD: Create Android notification channel
  if (Platform.isAndroid) {
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      channelId,
      channelName,
      description: channelDescription,
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  _isInitialized = true;
}
```

### 4.3 Implement Android Permission Request

**Update `requestPermissions()` method:**
```dart
static Future<bool> requestPermissions() async {
  if (!_isInitialized) {
    await initialize();
  }

  // ADD: Android 13+ permission request
  if (Platform.isAndroid) {
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

    final bool? granted = await androidPlugin?.requestNotificationsPermission();
    return granted ?? false;
  }

  // iOS permission request (existing code)
  if (Platform.isIOS) {
    final iosPlugin = _plugin
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    if (iosPlugin != null) {
      return await iosPlugin.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    }
  }

  return false;
}
```

### 4.4 Implement Android Notification Checking

**Update `areNotificationsEnabled()` method:**
```dart
static Future<bool> areNotificationsEnabled() async {
  if (!_isInitialized) {
    await initialize();
  }

  // ADD: Android permission check
  if (Platform.isAndroid) {
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

    final bool? enabled = await androidPlugin?.areNotificationsEnabled();
    return enabled ?? false;
  }

  // iOS permission check (existing code)
  if (Platform.isIOS) {
    final iosPlugin = _plugin
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    if (iosPlugin != null) {
      final result = await iosPlugin.checkPermissions();
      return result?.isEnabled ?? false;
    }
  }

  return false;
}
```

### 4.5 Update Notification Scheduling

**Update `scheduleReminder()` method:**
```dart
static Future<void> scheduleReminder({
  required DateTime scheduledDate,
  required bool recurring,
  required String title,
  required String body,
  int? activityId,
}) async {
  if (!_isInitialized) {
    await initialize();
  }

  final hasPermission = await areNotificationsEnabled();
  if (!hasPermission) {
    return;
  }

  // UPDATE: Add Android notification details
  final notificationDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/launcher_icon',
    ),
    iOS: const DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    ),
  );

  final scheduledTZ = tz.TZDateTime.from(scheduledDate, tz.local);

  if (activityId != null) {
    // Track both reminder_set and reminder_scheduled
    await _analytics.trackReminderSet(
      deviceId: 'unknown',
      activityId: activityId,
      reminderTime: scheduledDate,
    );

    await _analytics.trackReminderScheduled(
      deviceId: 'unknown',
      activityId: activityId,
      reminderTime: scheduledDate,
    );
  }

  if (recurring) {
    await _plugin.zonedSchedule(
      1,
      title,
      body,
      scheduledTZ,
      notificationDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      payload: activityId?.toString(),
    );
  } else {
    await _plugin.zonedSchedule(
      2,
      title,
      body,
      scheduledTZ,
      notificationDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: activityId?.toString(),
    );
  }
}
```

### 4.6 Verification

```bash
# Run code generation (in case Riverpod providers need updating)
dart run build_runner build --delete-conflicting-outputs

# Check for errors
flutter analyze

# Build debug and test on Android device
flutter run --debug
```

**Manual Testing:**
1. Launch app on Android device
2. Navigate to settings/notifications
3. Tap "Enable Notifications"
4. Verify system permission dialog appears
5. Grant permission
6. Schedule a test notification (set for 1 minute from now)
7. Wait for notification to appear
8. Tap notification and verify navigation works

**Checklist:**
- [ ] Notification channels created in `initialize()`
- [ ] Android permission request implemented
- [ ] Android permission check implemented
- [ ] Notification details include Android configuration
- [ ] Code builds without errors
- [ ] Notifications appear on Android 13+
- [ ] Notification tapping navigates correctly

---

## Phase 5: Testing & Validation (Day 5)

**Duration:** 4-8 hours
**Priority:** 🟡 MEDIUM

### 5.1 Build Release APK for Testing

```bash
# Build release APK (for local installation)
flutter build apk --release

# Output: build/app/outputs/flutter-apk/app-release.apk
```

### 5.2 Install on Physical Device

**Recommended Device:** Pixel 7 Pro (Android 14)

```bash
# Uninstall debug version first (different signature)
adb uninstall com.milkman.mealvanaendurance

# Install release APK
adb install build/app/outputs/flutter-apk/app-release.apk

# Launch app
adb shell am start -n com.milkman.mealvanaendurance/.MainActivity
```

### 5.3 Comprehensive Feature Testing

**Test Plan:**

| Feature | Test Steps | Expected Result | Status |
|---------|------------|----------------|--------|
| **User Authentication** | 1. Open app<br>2. Sign up with new account<br>3. Log out<br>4. Log back in | Account created, login works | ⚪ |
| **Device ID** | 1. Check logs for device ID<br>2. Verify it's unique | Device ID generated correctly | ⚪ |
| **Nutrition Plan** | 1. Create new plan<br>2. Input distance, pace, weight<br>3. Generate plan | Plan generates with foods | ⚪ |
| **Offline Mode** | 1. Create plan online<br>2. Turn off wifi/data<br>3. View plan | Plan loads from Drift database | ⚪ |
| **Barcode Scanning** | 1. Navigate to barcode scanner<br>2. Grant camera permission<br>3. Scan food barcode | Permission granted, barcode scanned | ⚪ |
| **Notifications** | 1. Enable notifications<br>2. Grant permission<br>3. Schedule reminder<br>4. Wait for notification | Permission granted, notification appears | ⚪ |
| **Notification Tap** | 1. Tap notification | Navigates to activity detail | ⚪ |
| **Analytics** | 1. Check Mixpanel dashboard<br>2. Trigger events | Events appear for Android | ⚪ |
| **Error Tracking** | 1. Check Sentry dashboard<br>2. Trigger test error | Error logged for Android | ⚪ |
| **Data Sync** | 1. Create plan on Android<br>2. Log in on iOS<br>3. Check plan appears | Data syncs via Supabase | ⚪ |

### 5.4 Android-Specific Testing

**Android 13+ Permissions:**
```bash
# Check granted permissions
adb shell dumpsys package com.milkman.mealvanaendurance | grep permission

# Expected: runtime permissions granted for camera, notifications
```

**Notification Channel Check:**
```bash
# List notification channels
adb shell dumpsys notification | grep "channelId=nutrition_plan_reminders"

# Expected: Channel exists with importance: HIGH
```

**Background Restrictions:**
```bash
# Check battery optimization status
adb shell dumpsys deviceidle whitelist | grep mealvana

# If app is optimized, notifications may be delayed
# User can manually disable optimization in Settings > Apps > Mealvana > Battery
```

### 5.5 Performance Testing

**Startup Time:**
```bash
# Measure cold start time
adb shell am start -W -n com.milkman.mealvanaendurance/.MainActivity

# Expected: TotalTime < 3000ms (3 seconds)
```

**Memory Usage:**
```bash
# Check memory usage
adb shell dumpsys meminfo com.milkman.mealvanaendurance | grep TOTAL

# Expected: < 200MB for typical usage
```

**Database Performance:**
```bash
# Check Drift database size
adb shell run-as com.milkman.mealvanaendurance ls -lh databases/

# Expected: app_database.db < 10MB for typical usage
```

### 5.6 Common Issues & Fixes

**Issue: "App not installed"**
```bash
# Cause: Debug version with different signature still installed
# Fix:
adb uninstall com.milkman.mealvanaendurance
adb install build/app/outputs/flutter-apk/app-release.apk
```

**Issue: Notifications not appearing**
```bash
# Cause 1: Permission not granted
adb shell dumpsys package com.milkman.mealvanaendurance | grep POST_NOTIFICATIONS
# Fix: Manually grant in Settings > Apps > Mealvana > Permissions

# Cause 2: Battery optimization enabled
adb shell dumpsys deviceidle whitelist | grep mealvana
# Fix: Disable in Settings > Apps > Mealvana > Battery > Unrestricted

# Cause 3: Do Not Disturb enabled
# Fix: Temporarily disable DND for testing
```

**Issue: Camera not working**
```bash
# Check camera permission
adb shell dumpsys package com.milkman.mealvanaendurance | grep CAMERA
# Fix: Manually grant in Settings > Apps > Mealvana > Permissions
```

**Debugging Commands:**
```bash
# View real-time logs
adb logcat | grep flutter

# Filter for errors only
adb logcat | grep -E "E/flutter|F/flutter"

# Save logs to file
adb logcat > android_test_logs.txt
```

### 5.7 Checklist

- [ ] Release APK installs successfully
- [ ] All critical features working (auth, plans, scanning)
- [ ] Notifications appear and navigate correctly
- [ ] Camera permission granted and scanning works
- [ ] Offline mode works (Drift database)
- [ ] Analytics events appear in Mixpanel
- [ ] Errors logged in Sentry
- [ ] Data syncs with Supabase
- [ ] App startup time < 3 seconds
- [ ] No memory leaks or crashes
- [ ] Tested on Android 13+ device

---

## Phase 6: Shorebird Android Setup (Day 6)

**Duration:** 1-2 hours
**Priority:** 🟡 MEDIUM

### 6.1 Verify Shorebird CLI

```bash
# Check Shorebird is installed
shorebird --version

# Expected: shorebird 1.x.x or higher
```

**If not installed:**
```bash
# Install Shorebird
curl --proto '=https' --tlsv1.2 https://raw.githubusercontent.com/shorebirdtech/install/main/install.sh -sSf | bash

# Add to PATH (if needed)
export PATH="$HOME/.shorebird/bin:$PATH"

# Verify installation
shorebird --version
```

### 6.2 Initialize Android for Shorebird

```bash
# In project root
cd /Users/leemartin/development/mealvana_endurance

# Initialize Android platform
shorebird init --platforms android

# This will:
# 1. Update shorebird.yaml for Android
# 2. Configure Android build files
# 3. Set up Android-specific settings
```

### 6.3 Verify shorebird.yaml

**File:** `/shorebird.yaml`

**Expected Content:**
```yaml
# Shorebird configuration
app_id: YOUR_SHOREBIRD_APP_ID

# Platform-specific configuration
flavors:
  development: com.milkman.mealvanaendurance.dev
  production: com.milkman.mealvanaendurance
```

**Note:** If `app_id` is missing, you need to create a Shorebird app:
```bash
shorebird apps create
# Follow prompts to create app
```

### 6.4 Create Baseline Android Release

```bash
# Create first Shorebird release for Android
shorebird release android --target lib/main.dart

# This creates the baseline release that patches will be based on
# Build time: ~5-10 minutes

# Output:
# ✓ Built Android release
# ✓ Uploaded to Shorebird
# Release version: 1.9.0+30
```

**What This Does:**
1. Builds release AAB with Shorebird instrumentation
2. Uploads release artifact to Shorebird servers
3. Creates baseline for future patches
4. Generates release notes

### 6.5 Test Shorebird Patch (Optional)

**Make a small code change:**
```dart
// lib/shared/widgets/tabs_screen.dart
// Change a UI string to verify patching works

// Before:
Text('Home')

// After:
Text('Home (Patched)')
```

**Create patch:**
```bash
# Create patch for Android
shorebird patch android --target lib/main.dart

# This pushes the code change to existing installs
# Users receive update without Play Store submission
# Patch time: ~2-5 minutes

# Output:
# ✓ Built patch
# ✓ Uploaded to Shorebird
# Patch version: 1.9.0+30 (patch 1)
```

**Test patch delivery:**
```bash
# Install baseline release on device
flutter install --release

# Wait 30-60 seconds for patch to download
# Restart app
# Verify change appears
```

### 6.6 Shorebird Workflow

**Future development process:**

1. **Full Release (native changes):**
```bash
# When changing Android manifest, dependencies, or native code
shorebird release android --target lib/main.dart
# Upload to Google Play Store
```

2. **Patch (Dart/UI changes only):**
```bash
# When changing Dart code, UI, or business logic
shorebird patch android --target lib/main.dart
# Users receive update automatically (no Play Store)
```

**When to use patches:**
- ✅ Dart code changes
- ✅ UI updates
- ✅ Bug fixes in business logic
- ✅ Asset changes (images, fonts)

**When to use full releases:**
- ❌ Android manifest changes
- ❌ Dependency version updates
- ❌ Native code changes
- ❌ Permission additions

### 6.7 Checklist

- [ ] Shorebird CLI installed and verified
- [ ] Android platform initialized
- [ ] shorebird.yaml configured
- [ ] Baseline release created
- [ ] Baseline uploaded to Shorebird
- [ ] Test patch created (optional)
- [ ] Patch delivery verified (optional)
- [ ] Team understands patch vs. release workflow

---

## Phase 7: Google Play Submission (Day 7)

**Duration:** 2-4 hours
**Priority:** 🟡 MEDIUM

**📚 Full details in:** [google-play-submission.md](./google-play-submission.md)

### 7.1 Build Final Release AAB

```bash
# Clean build
flutter clean

# Build release AAB
flutter build appbundle --release

# Verify signing
jarsigner -verify -verbose -certs build/app/outputs/bundle/release/app-release.aab

# Expected: "jar verified."
```

### 7.2 Google Play Console Setup

**Create App Listing:**

1. Go to [Google Play Console](https://play.google.com/console/)
2. Click **Create app**
3. Fill in:
   - **App name:** Mealvana Run (or desired name)
   - **Default language:** English (United States)
   - **App or game:** App
   - **Free or paid:** Free
4. Accept declarations and click **Create app**

### 7.3 Store Listing Content

**Category:**
- **App category:** Health & Fitness
- **Tags:** Nutrition, Running, Endurance, Sports

**Contact Details:**
- **Email:** your_email@domain.com
- **Phone:** (optional)
- **Website:** https://yourdomain.com

**Privacy Policy:**
- **URL:** https://yourdomain.com/privacy-policy
- ⚠️ Must be live before submission

### 7.4 Data Safety Declaration

**Data Collection Summary:**

| Data Type | Collected? | Purpose | Shared? |
|-----------|-----------|---------|---------|
| Name | ✅ Yes | Account creation | ❌ No |
| Email | ✅ Yes | Authentication | ❌ No |
| User ID | ✅ Yes | Account management | ❌ No |
| Health & Fitness | ✅ Yes | Nutrition plans | ❌ No |
| App Activity | ✅ Yes | Analytics | ✅ Yes (Mixpanel) |
| Crash Logs | ✅ Yes | Error tracking | ✅ Yes (Sentry) |
| Device ID | ✅ Yes | User identification | ❌ No |

**Data Security Practices:**
- ✅ Data encrypted in transit (HTTPS)
- ✅ Data encrypted at rest (Supabase)
- ✅ Users can request data deletion
- ✅ Users can request data export

**Third-Party Data Sharing:**
- **Mixpanel:** Analytics and user behavior
- **Sentry:** Error tracking and performance

### 7.5 Upload AAB

**In Google Play Console:**

1. Go to **Release > Testing > Open testing**
2. Click **Create new release**
3. Click **Upload** and select `app-release.aab`
4. Wait for upload and processing (~5-10 minutes)
5. Review release details:
   - **Version name:** 1.9.0
   - **Version code:** 30
   - **Supported devices:** Check coverage
   - **APK sizes:** Review size warnings

### 7.6 Release Notes

**Example Release Notes:**

```
Initial Android release of Mealvana Run! 🎉

Features:
• Personalized nutrition plans for endurance athletes
• Science-based calculations using ACSM formulas
• Food preference integration
• Barcode scanning for quick food entry
• Offline mode with local database
• Nutrition reminders

This is an open testing release. Please provide feedback!
```

### 7.7 Create Testing Track

**Open Testing Setup:**

1. Go to **Testing > Open testing**
2. Click **Create new release**
3. Upload AAB (if not done in 7.5)
4. Add release notes
5. **Review release**
6. Click **Start rollout to Open testing**
7. Wait for review (~1-3 days for first submission)

**Get Opt-In URL:**
```
https://play.google.com/apps/testing/com.milkman.mealvanaendurance
```

**Share with testers:**
- Send opt-in URL via email
- Post in community/testing groups
- Add to website

### 7.8 Post-Submission Monitoring

**Track Review Status:**
- Check Play Console daily for review updates
- Expected review time: 1-3 days (first submission)
- Future updates: ~1-24 hours

**Monitor Crash Reports:**
```bash
# Check Sentry for Android crashes
# https://sentry.io/organizations/milkman-24/issues/

# Check Play Console vitals
# Play Console > Quality > Android vitals
```

**Gather Tester Feedback:**
- Monitor Play Console feedback
- Set up feedback email
- Track analytics in Mixpanel

### 7.9 Checklist

- [ ] Final release AAB built and signed
- [ ] Google Play Console app created
- [ ] Store listing content completed
- [ ] Data safety declaration completed
- [ ] Privacy policy live and linked
- [ ] AAB uploaded to open testing
- [ ] Release notes added
- [ ] Release started rollout
- [ ] Opt-in URL shared with testers
- [ ] Monitoring set up (Sentry, Play Console)

---

## Verification Checklist

### Pre-Submission (Must Complete All)

- [ ] **Manifest & Permissions**
  - [ ] All permissions in AndroidManifest.xml
  - [ ] Notification receivers configured
  - [ ] No manifest-related errors

- [ ] **SDK Configuration**
  - [ ] compileSdk = 35
  - [ ] targetSdk = 34
  - [ ] minSdk = 21
  - [ ] multiDexEnabled = true
  - [ ] Desugaring enabled

- [ ] **Release Signing**
  - [ ] Keystore generated and backed up
  - [ ] key.properties created
  - [ ] Passwords stored securely
  - [ ] Release AAB signs correctly

- [ ] **Notification Implementation**
  - [ ] Android channels created
  - [ ] Runtime permissions requested
  - [ ] Notifications appear on device
  - [ ] Notification tapping works

- [ ] **Testing**
  - [ ] All critical features work
  - [ ] Tested on physical Android device
  - [ ] No crashes or errors
  - [ ] Analytics and Sentry working

- [ ] **Shorebird**
  - [ ] Android platform initialized
  - [ ] Baseline release created
  - [ ] Patch workflow understood

- [ ] **Play Store**
  - [ ] Store listing completed
  - [ ] Data safety declared
  - [ ] Privacy policy live
  - [ ] AAB uploaded
  - [ ] Open testing started

---

## Risk Mitigation

### High-Risk Items

| Risk | Impact | Mitigation | Status |
|------|--------|------------|--------|
| Keystore lost | 🔴 **Cannot update app ever** | Back up immediately after creation | ⚪ |
| Target SDK < 34 | 🔴 **Play Store rejects** | Verify in build.gradle.kts | ⚪ |
| Notifications broken | 🔴 **Core feature fails** | Implement Android channels properly | ⚪ |
| Signing misconfigured | 🔴 **Cannot publish** | Test release build before submission | ⚪ |

### Medium-Risk Items

| Risk | Impact | Mitigation | Status |
|------|--------|------------|--------|
| Camera permission denied | 🟡 Barcode scanning fails | Graceful fallback to manual entry | ⚪ |
| Analytics not working | 🟡 Can't track Android usage | Test in release mode before launch | ⚪ |
| Shorebird setup issues | 🟡 Can't use OTA updates | Full Play Store releases work | ⚪ |

### Low-Risk Items

| Risk | Impact | Mitigation | Status |
|------|--------|------------|--------|
| UI rendering differences | 🟢 Minor visual issues | Test on multiple devices | ⚪ |
| Performance slower | 🟢 User experience | Profile and optimize | ⚪ |

---

## Timeline Recap

| Day | Phase | Tasks | Duration |
|-----|-------|-------|----------|
| **1** | Manifest & Permissions | Update AndroidManifest.xml, add receivers | 1-2 hours |
| **2** | SDK & Build Config | Update target/compile SDK, enable desugaring | 1-2 hours |
| **3** | Release Signing | Generate keystore, configure signing | 2-3 hours |
| **4** | Notifications | Implement Android channels and permissions | 4-6 hours |
| **5** | Testing | Comprehensive feature and device testing | 4-8 hours |
| **6** | Shorebird | Initialize Android, create baseline release | 1-2 hours |
| **7** | Play Store | Upload AAB, complete store listing | 2-4 hours |

**Total:** 15-27 hours over 7 days

---

## Resources

- [Flutter Android Deployment](https://docs.flutter.dev/deployment/android)
- [Google Play Console Help](https://support.google.com/googleplay/android-developer)
- [Android Notification Channels](https://developer.android.com/training/notify-user/channels)
- [Shorebird Documentation](https://docs.shorebird.dev/)

---

*Last updated: 2025-11-12 for Mealvana Endurance v1.9.0+30*
