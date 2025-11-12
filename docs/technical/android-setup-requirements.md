# Android Setup Requirements for Critical Flutter Packages

**Research Date**: January 2025
**Status**: Comprehensive guide based on latest 2024-2025 documentation

This document provides Android-specific setup requirements, permissions, gradle configurations, and best practices for all critical Flutter packages used in the Mealvana Endurance app.

---

## Table of Contents

1. [Database & Storage](#1-database--storage)
2. [Authentication](#2-authentication)
3. [Media Packages](#3-media-packages)
4. [Barcode Scanning](#4-barcode-scanning)
5. [Analytics & Error Tracking](#5-analytics--error-tracking)
6. [Location Services](#6-location-services)
7. [Notifications](#7-notifications)
8. [Code Push](#8-code-push)
9. [UI & Platform Integration](#9-ui--platform-integration)
10. [Permission Management](#10-permission-management)
11. [General Android Configuration](#11-general-android-configuration)

---

## 1. Database & Storage

### drift (SQLite Database)

**Minimum SDK**: 21 (Android 5.0)
**Compile SDK**: 35 recommended

**Gradle Configuration**: None required for basic usage

**ProGuard/R8 Rules**:
- Drift is built on SQLite and generally doesn't require special ProGuard rules
- If you encounter R8 minification errors, check the generated `missing_rules.txt` file
- For SQLite native libraries, ensure `sqlite3_flutter_libs` ProGuard rules are included

**Best Practices**:
- No special AndroidManifest permissions required
- Works fully offline
- Type-safe queries with compile-time validation
- Use `drift_dev` for code generation

**Known Issues**: None significant for production use in 2024-2025

---

### supabase_flutter

**Minimum SDK**: 21 (Android 5.0)
**Compile SDK**: 35 recommended
**AndroidX**: Required

**Required Permissions** (`AndroidManifest.xml`):
```xml
<uses-permission android:name="android.permission.INTERNET"/>
```

**Gradle Configuration**:
```gradle
android {
    compileSdkVersion 35
}

// In gradle.properties
android.useAndroidX=true
android.enableJetifier=true
```

**Storage Migration**:
- v1 → v2 migration: Hive → SharedPreferences
- Use `MigrationLocalStorage` class for seamless migration
- No manual data migration required when properly configured

**OAuth Setup**:
- **Google Sign-In**: Requires native `google_sign_in` package
  - Configure Web Client ID in Supabase dashboard
  - Configure iOS Client ID (Android works without explicit Client ID)
- **Apple Sign-In**: Requires `sign_in_with_apple` package
  - Native setup required for iOS/macOS
  - Configure in Supabase project

**Best Practices**:
- Use `SharedPreferencesLocalStorage` for session persistence (default in v2+)
- Use `EmptyLocalStorage` to disable session persistence
- Use `flutter_secure_storage` with custom `LocalStorage` implementation for enhanced security
- Always check network connectivity before Supabase calls

**Deep Linking**:
- Configure redirect URL: `io.supabase.flutter://callback`
- Add intent filters in AndroidManifest.xml for OAuth callbacks

**Known Issues**:
- None significant for production use in 2024-2025
- Hive migration handled automatically in v2+

---

### shared_preferences

**Minimum SDK**: 16 (Android 4.1)
**Storage Location**: `data/data/<package_name>/shared_prefs/FlutterSharedPreferences.xml`

**Gradle Configuration**: None required

**Permissions**: None required

**New APIs (2024)**:
- Three available APIs since v2.3.0:
  1. `SharedPreferencesAsync` (recommended)
  2. `SharedPreferencesWithCache` (recommended)
  3. `SharedPreferences` (legacy)

**Storage Backend**:
- Default: DataStore Preferences (Android platform-recommended)
- Fallback: Android SharedPreferences (XML-based)

**Supported Data Types**:
- `int`, `double`, `bool`, `String`, `List<String>`

**Best Practices**:
- Use new `SharedPreferencesAsync` API for better performance
- Don't store sensitive data (use `flutter_secure_storage` instead)
- Limit stored data size (not suitable for large datasets)

**Known Issues**: None significant for production use in 2024-2025

---

## 2. Authentication

### device_info_plus

**Minimum SDK**: 16 (Android 4.1)

**Permissions**: None required for basic device info

**Special Permissions** (if needed):
- Serial number retrieval requires specific app permissions on Android 10+

**Common Use Case**: Version-specific permission handling
```dart
import 'package:device_info_plus/device_info_plus.dart';

final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
final AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;

// Check Android version for permission handling
if (androidInfo.version.sdkInt >= 33) {
  // Android 13+ - Request photos/videos permissions
  await [Permission.photos, Permission.videos].request();
} else {
  // Android 12 and below - Request storage permission
  await Permission.storage.request();
}
```

**Best Practices**:
- Use with `permission_handler` for version-specific permission requests
- Check SDK version before requesting deprecated permissions
- No special manifest configuration required

**Known Issues**: None significant for production use in 2024-2025

---

## 3. Media Packages

### image_picker

**Minimum SDK**: 21 (Android 5.0)
**Compile SDK**: 35 recommended

**Required Permissions** (`AndroidManifest.xml`):
```xml
<uses-permission android:name="android.permission.CAMERA"/>
<uses-permission android:name="android.permission.READ_MEDIA_IMAGES" android:minSdkVersion="33"/>
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" android:maxSdkVersion="32"/>
```

**Critical 2024-2025 Policy Changes**:

**⚠️ GOOGLE PLAY POLICY ALERT (October 31, 2024)**:
- New Photo and Video Permissions policy restricts broad photo/video permissions
- Apps may only access photos/videos for purposes directly related to app functionality
- `READ_MEDIA_IMAGES` and `READ_MEDIA_VIDEO` now require justification
- Google Play may reject apps without clear use case

**Recommended Approach (Android 13+)**:
- Use Android Photo Picker instead of requesting `READ_MEDIA_IMAGES` when possible
- Only request camera permission for capturing new photos
- Consider using `photo_picker` plugin for Android 11+ compliance

**Scoped Storage**:
- No longer need `android:requestLegacyExternalStorage="true"`
- Plugin updated for scoped storage compliance

**Best Practices**:
- Request permissions at runtime before using image picker
- Explain to users why camera/photo access is needed
- Handle permission denial gracefully
- Consider using photo picker for gallery access on Android 13+

**Known Issues (2024-2025)**:
- Google Play rejections due to `READ_MEDIA_IMAGES` permission
- Removing permission causes functionality failure on Android 13+
- Ongoing migration to Android Photo Picker

---

### file_picker

**Minimum SDK**: 21 (Android 5.0)

**Required Permissions** (`AndroidManifest.xml`):
```xml
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" android:maxSdkVersion="32"/>
<uses-permission android:name="android.permission.READ_MEDIA_IMAGES" android:minSdkVersion="33"/>
<uses-permission android:name="android.permission.READ_MEDIA_VIDEO" android:minSdkVersion="33"/>
<uses-permission android:name="android.permission.READ_MEDIA_AUDIO" android:minSdkVersion="33"/>
```

**2024-2025 Considerations**:
- Same Google Play policy applies as `image_picker`
- Use Storage Access Framework (SAF) when possible (no permissions needed)
- Consider scoped storage for file operations

**Best Practices**:
- Use SAF for user-selected files (no permissions required)
- Request specific media permissions only when needed
- Handle Android 13+ granular permissions correctly

---

### camera

**Minimum SDK**: 21 (Android 5.0)

**Required Permissions** (`AndroidManifest.xml`):
```xml
<uses-permission android:name="android.permission.CAMERA"/>
<uses-feature android:name="android.hardware.camera" android:required="false"/>
<uses-feature android:name="android.hardware.camera.autofocus" android:required="false"/>
```

**Best Practices**:
- Always request camera permission at runtime
- Handle permission denial gracefully
- Check camera availability before initialization
- Set `android:required="false"` for optional camera features

---

### record (Audio Recording)

**Minimum SDK**: 21 (Android 5.0)

**Required Permissions** (`AndroidManifest.xml`):
```xml
<uses-permission android:name="android.permission.RECORD_AUDIO"/>
<uses-permission android:name="android.permission.MODIFY_AUDIO_SETTINGS"/>
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" android:maxSdkVersion="32"/>
<uses-permission android:name="android.permission.READ_MEDIA_AUDIO" android:minSdkVersion="33"/>
```

**Best Practices**:
- Request `RECORD_AUDIO` permission at runtime before recording
- Use `permission_handler` for runtime permission requests
- Handle permission denial with user-friendly messages
- Consider using scoped storage for saving recordings

**Security Considerations**:
- System audio capture requires special permissions (typically restricted)
- Only microphone audio available to regular apps

**Known Issues**: None significant for production use in 2024-2025

---

## 4. Barcode Scanning

### mobile_scanner

**Minimum SDK**: 21 (Android 5.0)
**Compile SDK**: 35 recommended

**Required Permissions** (`AndroidManifest.xml`):
```xml
<uses-permission android:name="android.permission.CAMERA"/>
```

**Optional Permissions** (for image gallery picking):
```xml
<uses-permission android:name="android.permission.READ_MEDIA_IMAGES" android:minSdkVersion="33"/>
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" android:maxSdkVersion="32"/>
```

**Gradle Configuration** (Optional - Unbundled MLKit):
```gradle
# In gradle.properties
dev.steenbakker.mobile_scanner.useUnbundled=true
```

**Unbundled vs Bundled MLKit**:
- **Bundled**: Larger app size (~3-8 MB), works offline
- **Unbundled**: Smaller app size, downloads ML models on first use (requires internet)

**iOS Setup** (for reference):
```xml
<!-- Info.plist -->
<key>NSCameraUsageDescription</key>
<string>This app needs camera access to scan QR codes</string>

<key>NSPhotoLibraryUsageDescription</key>
<string>This app needs photos access to get QR code from photo library</string>
```

**Best Practices**:
- Request camera permission at runtime
- Handle lifecycle management with `WidgetsBindingObserver`
- Use `MobileScannerController` for advanced control
- Set `autoStart: false` for manual lifecycle management

**Advanced Features**:
- Camera resolution control
- Detection speed settings
- Torch control
- Zoom functionality
- Multiple barcode format support
- Image scanning from gallery

**Known Issues**: None significant for production use in 2024-2025

---

## 5. Analytics & Error Tracking

### rudder_sdk_flutter (RudderStack)

**Minimum SDK**: 21 (Android 5.0)

**Required Permissions** (`AndroidManifest.xml`):
```xml
<uses-permission android:name="android.permission.INTERNET"/>
```

**Gradle Configuration**:
```gradle
// In app/build.gradle
dependencies {
    implementation 'com.rudderstack.android.sdk:core:1.7+'
}
```

**ProGuard Rules**:
- Bundled in SDK from v1.20.0 onwards
- If using ProGuard full mode, rules are automatically included

**Manual ProGuard Rules** (if needed):
```proguard
# Reporter Module
-keep class com.rudderstack.android.** { *; }

# TypeToken for Utils conversion
-keepattributes Signature
-keepattributes *Annotation*

# SourceConfig serialization
-keep class com.rudderstack.android.sdk.core.** { *; }
```

**Best Practices**:
- Initialize RudderStack early in app lifecycle
- Use data plane URL from RudderStack dashboard
- Configure write key securely
- Test tracking in debug builds before production

**Known Issues**: None significant for production use in 2024-2025

---

### sentry_flutter

**Minimum SDK**: 21 (Android 5.0)
**Compile SDK**: 35 recommended

**Required Permissions** (`AndroidManifest.xml`):
```xml
<uses-permission android:name="android.permission.INTERNET"/>
```

**Gradle Configuration**:
```gradle
android {
    compileSdkVersion 35
}
```

**Native Backend**:
- **x86/x64**: Crashpad (default)
- **ARM64**: Breakpad (Flutter target platform: windows-arm64)

**Sentry Native Integration**:
```cmake
# In CMakeLists.txt
if(FLUTTER_TARGET_PLATFORM EQUAL "windows-arm64")
    set(native_backend "breakpad")
else()
    set(native_backend "crashpad")
endif()

set(SENTRY_BACKEND ${native_backend} CACHE STRING "The sentry backend" FORCE)
include("${CMAKE_CURRENT_SOURCE_DIR}/../sentry-native/sentry-native.cmake")
target_include_directories(sentry INTERFACE ${CMAKE_CURRENT_LIST_DIR})
```

**ProGuard Rules**: Automatically included in SDK

**Best Practices**:
- Initialize Sentry before `runApp()`
- Set DSN from Sentry project settings
- Configure sample rate for performance monitoring
- Use breadcrumbs for debugging context
- Enable user feedback collection
- Test error reporting in debug builds

**Advanced Features**:
- Performance monitoring
- User feedback
- Breadcrumbs
- Context information
- Attachments
- User identification

**Known Issues**: None significant for production use in 2024-2025

---

## 6. Location Services

### geolocator

**Minimum SDK**: 21 (Android 5.0)
**Compile SDK**: 35 (required)
**AndroidX**: Required

**Required Permissions** (`AndroidManifest.xml`):
```xml
<!-- Basic location permissions -->
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />

<!-- Background location (optional) -->
<uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION" />

<!-- Foreground service location (optional) -->
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_LOCATION" />
```

**Gradle Configuration**:
```gradle
// In app/build.gradle
android {
  compileSdkVersion 35
}

// In gradle.properties
android.useAndroidX=true
android.enableJetifier=true
```

**Permission Handling (Breaking Changes in v7.0.0)**:

**LocationPermission States**:
- `denied`: Permissions to access location services have been denied
- `whenInUse`: Permissions granted while app is in use
- `always`: Permissions granted even when app is in background
- `deniedForever`: Removed - use platform-specific checks

**Recommended Permission Flow**:
```dart
bool serviceEnabled;
LocationPermission permission;

// Check if location services are enabled
serviceEnabled = await Geolocator.isLocationServiceEnabled();
if (!serviceEnabled) {
  // Location services disabled - prompt user
  return Future.error('Location services are disabled.');
}

// Check current permission status
permission = await Geolocator.checkPermission();
if (permission == LocationPermission.denied) {
  permission = await Geolocator.requestPermission();

  if (permission == LocationPermission.denied) {
    // Show explanatory UI
    return Future.error('Location permissions are denied');
  }
}

if (permission == LocationPermission.deniedForever) {
  // Direct user to app settings
  await Geolocator.openAppSettings();
  return Future.error('Location permissions are permanently denied');
}

// Permissions granted - proceed
Position position = await Geolocator.getCurrentPosition();
```

**Location Accuracy Priorities** (Android):
- `PRIORITY_PASSIVE`: No active location requests
- `PRIORITY_LOW_POWER`: City-level accuracy
- `PRIORITY_BALANCED_POWER_ACCURACY`: Block-level accuracy
- `PRIORITY_HIGH_ACCURACY`: Most accurate (GPS)

**Platform-Specific Settings**:
```dart
late LocationSettings locationSettings;

if (defaultTargetPlatform == TargetPlatform.android) {
  locationSettings = AndroidSettings(
    accuracy: LocationAccuracy.high,
    distanceFilter: 100,
    forceLocationManager: true,
    intervalDuration: const Duration(seconds: 10),
    // Foreground notification for background location
    foregroundNotificationConfig: const ForegroundNotificationConfig(
      notificationText: "App will continue to receive location",
      notificationTitle: "Running in Background",
      enableWakeLock: true,
    ),
  );
}

// Use with getCurrentPosition or getPositionStream
Position position = await Geolocator.getCurrentPosition(
  locationSettings: locationSettings
);
```

**Best Practices**:
- Always check if location services are enabled before requesting permission
- Request location permission at runtime (don't rely on manifest alone)
- Explain why location access is needed before requesting
- Handle `deniedForever` by directing users to app settings
- Use appropriate accuracy level for your use case (battery life)
- For background location, configure foreground notification

**Known Issues**: None significant for production use in 2024-2025

---

## 7. Notifications

### flutter_local_notifications

**Minimum SDK**: 21 (Android 5.0)
**Compile SDK**: 35 (required)
**Android Gradle Plugin**: 8.6.0+ (required)

**Critical Android 14 Changes (2024)**:
- Now requires desugaring for scheduled notifications
- Behavioral changes for notification scheduling
- Minimum compile SDK: 35

**Required Gradle Configuration**:
```gradle
// In app/build.gradle
android {
    compileSdk 35

    defaultConfig {
        minSdkVersion 21
    }

    compileOptions {
        // Enable desugaring
        coreLibraryDesugaringEnabled true
        sourceCompatibility JavaVersion.VERSION_1_8
        targetCompatibility JavaVersion.VERSION_1_8
    }
}

dependencies {
    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.1.4'
}
```

**Required Permissions** (`AndroidManifest.xml`):

**Basic Permissions** (v16+):
```xml
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
<uses-permission android:name="android.permission.VIBRATE"/>
```

**For Scheduled Notifications** (add between `<manifest>` tags):
```xml
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
<uses-permission android:name="android.permission.WAKE_LOCK"/>
<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM"/>
```

**Android 13+ Runtime Permission Request**:
```dart
FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

// Request notification permissions (Android 13+)
await flutterLocalNotificationsPlugin
    .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
    ?.requestNotificationsPermission();

// Request exact alarm permissions if needed (Android 12+)
await flutterLocalNotificationsPlugin
    .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
    ?.requestExactAlarmsPermission();
```

**Best Practices**:
- Request `POST_NOTIFICATIONS` permission at runtime on Android 13+
- Explain to users why notification access is needed
- Handle permission denial gracefully
- Test scheduled notifications on Android 14 devices
- Use notification channels for Android 8.0+ (handled by plugin)

**Known Issues (2024-2025)**:
- Desugaring requirement may increase APK size slightly
- Exact alarm permission dialog may confuse users on Android 12+
- Test thoroughly on Android 14 due to scheduling changes

---

## 8. Code Push

### shorebird

**Supported Platforms**: Android, iOS (Fully supported as of 2024)

**Minimum Requirements**:
- Flutter version compatibility (check with `shorebird doctor`)
- Internet connectivity required for updates
- App must be distributed through app store or other method

**Android Setup**:

**Installation**:
```bash
# Install Shorebird CLI
curl -fsSL https://raw.githubusercontent.com/shorebirdtech/install/main/install.sh | bash

# Login
shorebird login

# Initialize in project root
cd your_flutter_project
shorebird init
```

**Automatic Configuration**:
- `shorebird init` automatically adds internet permission to AndroidManifest.xml if missing
- Creates `shorebird.yaml` in project root
- Configures flavors/variants if present

**Required Permissions** (auto-added):
```xml
<uses-permission android:name="android.permission.INTERNET"/>
```

**Release Commands**:
```bash
# Create a release (specify Flutter version if needed)
shorebird release android --flutter-version=3.24.0

# Create a patch
shorebird patch android

# Pass arguments to Flutter build
shorebird release android -- --obfuscate --split-debug-info=debug_info
```

**Important Limitations**:
- Cannot update Flutter version via Shorebird patches
- App released with Flutter 3.24 cannot be patched to use different Flutter version
- Offline-only apps not supported (requires internet for updates)
- Updates downloaded from Shorebird backend

**Best Practices**:
- Test patches thoroughly before deploying
- Use specific Flutter version flags for consistency
- Monitor update download success rate
- Provide fallback for failed updates
- Document which builds have which patches

**Known Issues**: None significant for production use in 2024-2025

---

## 9. UI & Platform Integration

### url_launcher

**Minimum SDK**: 16 (Android 4.1)

**Critical Android 11+ Requirement** (`AndroidManifest.xml`):
```xml
<!-- Required for Android 11 (API 30) or higher -->
<queries>
  <!-- For web URLs -->
  <intent>
    <action android:name="android.intent.action.VIEW" />
    <data android:scheme="https" />
  </intent>

  <!-- For phone calls -->
  <intent>
    <action android:name="android.intent.action.DIAL" />
    <data android:scheme="tel" />
  </intent>

  <!-- For SMS -->
  <intent>
    <action android:name="android.intent.action.SENDTO" />
    <data android:scheme="smsto" />
  </intent>

  <!-- For email -->
  <intent>
    <action android:name="android.intent.action.SENDTO" />
    <data android:scheme="mailto" />
  </intent>
</queries>
```

**Why This Is Required**:
- Android 11+ restricts package visibility
- `canLaunchUrl()` will return `false` without `<queries>` entries
- Must declare all URL schemes your app will check or launch

**Best Practices**:
- Always use `canLaunchUrl()` before `launchUrl()`
- Handle cases where URL cannot be launched
- Add `<queries>` entries for all URL schemes your app uses
- Test on Android 11+ devices

**Known Issues**: None significant for production use in 2024-2025

---

### share_plus

**Minimum SDK**: 21 (Android 5.0)

**Implementation**: Wraps Android `ACTION_SEND` Intent

**Permissions**: None required

**Best Practices**:
- No special AndroidManifest configuration required
- Works with any shareable content type
- Respects user's installed sharing apps

**Known Issues**: None significant for production use in 2024-2025

---

### package_info_plus

**Minimum SDK**: 16 (Android 4.1)

**Permissions**: None required

**Gradle Configuration**:
```gradle
// In app/build.gradle
android {
    defaultConfig {
        applicationId "com.example.app"  // This is packageName
        versionCode 1  // This is buildNumber
        versionName "1.0.0"  // This is version
    }
}
```

**AndroidManifest Configuration**:
```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.example.app">

    <application
        android:label="App Name">  <!-- This is appName -->
    </application>
</manifest>
```

**Important Setup**:
```dart
void main() async {
  // Required if PackageInfo.fromPlatform() called before runApp()
  WidgetsFlutterBinding.ensureInitialized();

  PackageInfo packageInfo = await PackageInfo.fromPlatform();

  runApp(MyApp());
}
```

**Recent Changes (2024)**:
- Addressed changed fields nullability on Android 15 (API 35)
- Switched to SHA-256 for `buildSignature` on Android
- Better support for Android 15 compatibility

**Best Practices**:
- Call `WidgetsFlutterBinding.ensureInitialized()` before `PackageInfo.fromPlatform()`
- Use for version display, update checks, and diagnostics
- Package name defined in gradle, not in Dart code

**Known Issues**: None significant for production use in 2024-2025

---

## 10. Permission Management

### permission_handler

**Minimum SDK**: 21 (Android 5.0)
**AndroidX**: Required (since v3.1.0)

**Critical Setup Requirements**:

**AndroidManifest.xml**:
```xml
<!-- Must declare ALL permissions your app will request -->
<uses-permission android:name="android.permission.CAMERA"/>
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.RECORD_AUDIO"/>
<!-- Add all other permissions your app needs -->
```

**Gradle Configuration**:
```gradle
// In gradle.properties
android.useAndroidX=true
android.enableJetifier=true
```

**Flutter 1.12+ Migration**:
- Since v4.4.0, requires Flutter 1.12 Android plugin APIs
- Follow Flutter's Android migration guide if needed

**Permission Request Best Practices (2024-2025)**:

**1. Request Only What You Need**:
```dart
// Only request permissions directly related to functionality
await Permission.camera.request();
```

**2. Explain Before Requesting**:
```dart
// Show explanation dialog first
if (await Permission.location.isDenied) {
  bool shouldRequest = await showPermissionDialog(
    'Location access is needed to show nearby events'
  );

  if (shouldRequest) {
    await Permission.location.request();
  }
}
```

**3. Handle All Permission States**:
```dart
PermissionStatus status = await Permission.camera.request();

switch (status) {
  case PermissionStatus.granted:
    // Proceed with functionality
    break;

  case PermissionStatus.denied:
    // Show explanation and encourage user to reconsider
    break;

  case PermissionStatus.permanentlyDenied:
    // Permission permanently denied
    // Direct user to app settings
    await openAppSettings();
    break;

  case PermissionStatus.restricted:
    // iOS only - restricted by parental controls
    break;

  case PermissionStatus.limited:
    // iOS 14+ - limited photo library access
    break;
}
```

**4. Version-Specific Handling**:
```dart
import 'package:device_info_plus/device_info_plus.dart';

final androidInfo = await DeviceInfoPlugin().androidInfo;

if (androidInfo.version.sdkInt >= 33) {
  // Android 13+ - Use granular media permissions
  await [Permission.photos, Permission.videos].request();
} else {
  // Android 12 and below - Use storage permission
  await Permission.storage.request();
}
```

**5. Handle Revoked Permissions**:
```dart
// Check permission status before use
if (await Permission.camera.isGranted) {
  // Use camera
} else {
  // Show alternative flow or re-request
}
```

**Critical 2024-2025 Permission Changes**:

**Android 13+ (API 33)**:
- Granular media permissions: `READ_MEDIA_IMAGES`, `READ_MEDIA_VIDEO`, `READ_MEDIA_AUDIO`
- `READ_EXTERNAL_STORAGE` deprecated (maxSdkVersion 32)
- `POST_NOTIFICATIONS` permission required

**Android 14 (API 34)**:
- Photo picker UI changes
- Partial media access grants
- Enhanced privacy controls

**Android 15 (API 35)**:
- Additional privacy improvements
- Stricter permission enforcement

**Best Practices Summary**:
1. Declare all permissions in AndroidManifest.xml
2. Request permissions at runtime (never assume granted)
3. Explain why each permission is needed
4. Handle all permission states gracefully
5. Provide alternative flows for denied permissions
6. Check permission status before use
7. Use version-specific permission handling
8. Direct users to settings for permanently denied permissions

**Known Issues**: None significant for production use in 2024-2025

---

## 11. General Android Configuration

### Minimum SDK Version Recommendations (2024-2025)

**Flutter Default**: Changed to 24 (Android 7.0) in Flutter 3.24+

**Industry Standard**: 21 (Android 5.0) - covers ~99% of devices

**Configuration** (`android/local.properties`):
```properties
flutter.minSdkVersion=21
```

**Or** (`app/build.gradle`):
```gradle
android {
    defaultConfig {
        minSdkVersion localProperties.getProperty('flutter.minSdkVersion').toInteger()
    }
}
```

---

### Compile SDK Version

**Required**: 35 (Android 15)

**Configuration** (`app/build.gradle`):
```gradle
android {
    compileSdk 35
}
```

---

### ProGuard/R8 Configuration

**Basic Setup** (`app/build.gradle`):
```gradle
android {
    buildTypes {
        release {
            minifyEnabled true
            shrinkResources true
            proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'),
                          'proguard-rules.pro'
        }
    }
}
```

**Common ProGuard Rules** (`proguard-rules.pro`):
```proguard
# Flutter wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Preserve annotations
-keepattributes *Annotation*

# Preserve line numbers for debugging
-keepattributes SourceFile,LineNumberTable

# If you keep the line number information, uncomment this to
# hide the original source file name
-renamesourcefileattribute SourceFile
```

**R8 Full Mode**:
- R8 replaced ProGuard as the default code shrinker
- More aggressive optimization than ProGuard
- May require additional keep rules
- Check `app/build/outputs/mapping/release/missing_rules.txt` for missing rules

**Troubleshooting**:
- If app crashes in release build, check ProGuard rules
- Use `missing_rules.txt` to identify required keep rules
- Test release builds thoroughly before publishing

---

### AndroidX Migration

**Required For** (all projects as of 2024):
```properties
# gradle.properties
android.useAndroidX=true
android.enableJetifier=true
```

**Why Required**:
- Most Flutter plugins now use AndroidX
- Support libraries deprecated
- Required for latest Android features

---

### Multidex Configuration

**When Required**: App has > 64K methods

**Configuration** (`app/build.gradle`):
```gradle
android {
    defaultConfig {
        multiDexEnabled true
    }
}

dependencies {
    implementation 'androidx.multidex:multidex:2.0.1'
}
```

---

## Summary Checklist

### Critical Setup Items

- [ ] Set `compileSdk 35` in `app/build.gradle`
- [ ] Set `minSdkVersion 21` (or 24 if using Flutter defaults)
- [ ] Enable AndroidX in `gradle.properties`
- [ ] Add required permissions to `AndroidManifest.xml`
- [ ] Add `<queries>` entries for `url_launcher` on Android 11+
- [ ] Configure desugaring for `flutter_local_notifications` on Android 14+
- [ ] Set up ProGuard/R8 rules for release builds
- [ ] Request runtime permissions for sensitive features
- [ ] Test on Android 13, 14, and 15 devices
- [ ] Verify Google Play policy compliance for photo/video permissions
- [ ] Configure foreground service notification for background location (if needed)
- [ ] Set up version-specific permission handling
- [ ] Test ProGuard/R8 release builds thoroughly

---

## Version-Specific Considerations

### Android 15 (API 35) - Latest
- Enhanced privacy controls
- Stricter permission enforcement
- `package_info_plus` SHA-256 signature changes

### Android 14 (API 34)
- Notification scheduling changes (requires desugaring)
- Photo picker improvements
- Partial media access

### Android 13 (API 33)
- Granular media permissions (`READ_MEDIA_IMAGES`, `READ_MEDIA_VIDEO`, `READ_MEDIA_AUDIO`)
- `POST_NOTIFICATIONS` runtime permission required
- Deprecated `READ_EXTERNAL_STORAGE`

### Android 12 (API 31)
- Exact alarm permission (`SCHEDULE_EXACT_ALARM`)
- Approximate location option
- Bluetooth permissions split

### Android 11 (API 30)
- Package visibility restrictions (`<queries>` required)
- Scoped storage enforcement
- One-time permissions

---

## References

### Official Documentation
- [Flutter Documentation](https://docs.flutter.dev)
- [Android Developer Guide](https://developer.android.com)
- [Drift Documentation](https://drift.simonbinder.eu/)
- [Supabase Flutter SDK](https://supabase.com/docs/reference/dart)
- [RudderStack Flutter SDK](https://www.rudderstack.com/docs/sources/event-streams/sdks/rudderstack-flutter-sdk/)
- [Sentry Flutter SDK](https://docs.sentry.io/platforms/flutter/)
- [Shorebird Documentation](https://docs.shorebird.dev/)

### Package Repositories
- [pub.dev](https://pub.dev) - Official Dart/Flutter package repository
- [flutter/packages](https://github.com/flutter/packages) - Official Flutter packages
- [baseflow/flutter-geolocator](https://github.com/baseflow/flutter-geolocator)
- [juliansteenbakker/mobile_scanner](https://github.com/juliansteenbakker/mobile_scanner)

### Google Play Policies
- [Photo and Video Permissions Policy](https://support.google.com/googleplay/android-developer/answer/14115180)
- [Permissions Best Practices](https://developer.android.com/training/permissions/requesting)

---

**Last Updated**: January 2025
**Maintained By**: Mealvana Development Team
**Review Frequency**: Quarterly or when major Android/Flutter updates released
