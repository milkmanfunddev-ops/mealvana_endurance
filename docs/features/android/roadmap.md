# Android Release Roadmap - Technical Implementation

**AI-Assisted Tasks**: This roadmap covers all technical configurations that can be implemented with AI assistance.

**Target:** Open Testing release on Google Play Store
**Timeline:** 5-7 days (technical only)

---

## Phase 1: Android Manifest & Permissions (Day 1)

### 1.1 Update AndroidManifest.xml Permissions

**File:** `/android/app/src/main/AndroidManifest.xml`

**Status:** ⚠️ Missing required permissions

**What Needs to Be Added:**

```xml
<!-- Internet (required for Supabase, Mixpanel, Sentry) -->
<uses-permission android:name="android.permission.INTERNET"/> <!-- ✅ Already present -->

<!-- Notifications (Android 13+) -->
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>

<!-- Camera for Barcode Scanning -->
<uses-permission android:name="android.permission.CAMERA"/>
<uses-feature android:name="android.camera" android:required="false"/>
<uses-feature android:name="android.camera.autofocus" android:required="false"/>

<!-- Notifications Scheduling -->
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM" />
<uses-permission android:name="android.permission.USE_EXACT_ALARM" />

<!-- Query for speech recognition (even though not used, mobile_scanner might need) -->
<queries>
    <intent>
        <action android:name="android.intent.action.PROCESS_TEXT"/>
        <data android:mimeType="text/plain"/>
    </intent>
</queries>
```

**Why Each Permission:**
- `POST_NOTIFICATIONS` - Required for `flutter_local_notifications` on Android 13+
- `CAMERA` - Required for `mobile_scanner` barcode scanning
- `RECEIVE_BOOT_COMPLETED` - Allows scheduled notifications to survive device restart
- `SCHEDULE_EXACT_ALARM` - Required for exact timing of notifications (Android 12+)
- `USE_EXACT_ALARM` - Alternative permission for exact alarms
- `PROCESS_TEXT` query - Required by Flutter engine for text processing

### 1.2 Add Notification Receivers

**Still in AndroidManifest.xml**, inside `<application>` tag, after `<activity>`:

```xml
<!-- Notification receivers for flutter_local_notifications -->
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

**Verification:**
```bash
flutter analyze
# Should show no manifest-related errors
```

---

## Phase 2: Target SDK & Build Configuration (Day 2)

### 2.1 Update Target SDK to Android 14 (API 34)

**Why:** Google Play requires targeting Android 14 (API 34) minimum. By August 2025, will require API 35.

**File:** `/android/app/build.gradle.kts`

**Current State:**
```kotlin
defaultConfig {
    applicationId = "com.milkman.mealvanaendurance"
    minSdk = flutter.minSdkVersion  // Currently API 21
    targetSdk = flutter.targetSdkVersion  // ⚠️ Uses Flutter default
    versionCode = flutter.versionCode
    versionName = flutter.versionName
}
```

**Update To:**
```kotlin
defaultConfig {
    applicationId = "com.milkman.mealvanaendurance"
    minSdk = 21  // Android 5.0 (keep for broad compatibility)
    targetSdk = 34  // Android 14 (required for Google Play 2025)
    versionCode = flutter.versionCode
    versionName = flutter.versionName

    // Enable multidex for notification library compatibility
    multiDexEnabled = true
}
```

### 2.2 Update Compile SDK

**Still in `/android/app/build.gradle.kts`:**

```kotlin
android {
    namespace = "com.milkman.mealvanaendurance"
    compileSdk = 34  // Match targetSdk
    ndkVersion = flutter.ndkVersion
    // ... rest of config
}
```

### 2.3 Enable Java 11 Support (Required for Notifications)

**Still in `/android/app/build.gradle.kts`:**

```kotlin
android {
    // ... existing config ...

    compileOptions {
        // Enable desugaring for backwards compatibility
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }
}

dependencies {
    // Add desugaring dependency
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
```

**Why:** `flutter_local_notifications` requires Java 8+ features, and desugaring ensures compatibility with older Android versions (minSdk 21).

**Verification:**
```bash
cd android
./gradlew app:dependencies | grep desugar
# Should show desugar_jdk_libs dependency
```

---

## Phase 3: Release Build Configuration (Day 3)

### 3.1 Generate Release Keystore

**⚠️ IMPORTANT:** Lee will need to run these commands himself (requires password creation).

**Instructions for Lee:**

```bash
cd android/app

# Generate keystore (you'll be prompted for passwords and info)
keytool -genkey -v -keystore mealvana-release-key.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias mealvana-release

# You'll be asked:
# - Keystore password (remember this!)
# - Key password (can be same as keystore)
# - Your name, organization, city, state, country
```

**What to Remember:**
- Keystore password
- Key password
- Key alias: `mealvana-release`
- Keystore location: `android/app/mealvana-release-key.jks`

**⚠️ SECURITY:**
- Do NOT commit `mealvana-release-key.jks` to git (already in `.gitignore`)
- Back up this file securely (you'll need it for Google Play App Signing upload)

### 3.2 Create key.properties File

**File:** `/android/key.properties` (Lee will create this)

```properties
storePassword=YOUR_KEYSTORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=mealvana-release
storeFile=app/mealvana-release-key.jks
```

**⚠️ SECURITY:** Already in `.gitignore`, do NOT commit this file.

### 3.3 Update build.gradle.kts for Release Signing

**File:** `/android/app/build.gradle.kts`

**Replace the current `buildTypes` section:**

```kotlin
// Load keystore properties
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = java.util.Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(java.io.FileInputStream(keystorePropertiesFile))
}

android {
    // ... existing config ...

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

            // ⚠️ You declined ProGuard/R8, so keeping disabled
            isMinifyEnabled = false
            isShrinkResources = false
        }

        debug {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}
```

**Note on ProGuard/R8:** You declined code shrinking/obfuscation. If you change your mind later, set `isMinifyEnabled = true` and `isShrinkResources = true`.

**Verification (after Lee creates keystore):**
```bash
flutter build appbundle --release
# Should build successfully without signing errors
```

---

## Phase 4: Notification Implementation (Day 4)

### 4.1 Android Notification Channels

**Background:** Android 8.0+ requires notification channels. Users can control settings per channel.

**File:** `lib/shared/services/notification_service.dart` (or create new file)

**Implementation needed:**

```dart
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static const String channelId = 'nutrition_plan_reminders';
  static const String channelName = 'Nutrition Plan Reminders';
  static const String channelDescription = 'Reminders for your nutrition plans and meals';

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    // Android initialization with app icon
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('launcher_icon');

    // iOS initialization
    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
      requestSoundPermission: false,
      requestBadgePermission: false,
      requestAlertPermission: false,
    );

    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notificationsPlugin.initialize(settings);

    // Create Android notification channel
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      channelId,
      channelName,
      description: channelDescription,
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  /// Request notification permissions (Android 13+, iOS)
  Future<bool> requestPermissions() async {
    // Android 13+ requires runtime permission
    final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
        _notificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    final bool? androidGranted = await androidPlugin?.requestNotificationsPermission();

    // iOS permissions
    final IOSFlutterLocalNotificationsPlugin? iosPlugin =
        _notificationsPlugin.resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();

    final bool? iosGranted = await iosPlugin?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );

    return androidGranted ?? iosGranted ?? false;
  }

  Future<void> scheduleNutritionReminder({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
  }) async {
    await _notificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      scheduledTime.toLocal(),
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          channelDescription: channelDescription,
          importance: Importance.high,
          priority: Priority.high,
          icon: 'launcher_icon',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }
}
```

### 4.2 Integrate with App Startup

**File:** `lib/shared/services/app_startup_service.dart`

**Add notification initialization:**

```dart
// Add to existing imports
import 'package:mealvana_endurance/shared/services/notification_service.dart';

// Inside your app startup service initialization
final notificationService = NotificationService();
await notificationService.initialize();
```

### 4.3 Add Notification Icon

**Android requires a notification icon in drawable folder:**

**File:** Copy your launcher icon to `/android/app/src/main/res/drawable/launcher_icon.png`

```bash
# Run this command (I can help)
cp assets/images/endurance_launcher_icon_basecream_1024.png \
   android/app/src/main/res/drawable/launcher_icon.png
```

**Or create a simple white icon on transparent background for better notification appearance.**

---

## Phase 5: Camera Permissions for Barcode Scanning (Day 4)

### 5.1 Runtime Permission Request

**mobile_scanner handles permissions automatically**, but you should add a permission rationale for users.

**Where barcode scanning is initiated** (likely in a controller):

```dart
import 'package:mobile_scanner/mobile_scanner.dart';

// Example in your barcode scanning screen
class BarcodeScannerScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan Barcode')),
      body: MobileScanner(
        controller: MobileScannerController(
          detectionSpeed: DetectionSpeed.normal,
          facing: CameraFacing.back,
        ),
        onDetect: (capture) {
          final List<Barcode> barcodes = capture.barcodes;
          for (final barcode in barcodes) {
            // Handle scanned barcode
            print('Barcode found: ${barcode.rawValue}');
          }
        },
      ),
    );
  }
}
```

**The package will automatically:**
1. Request camera permission when scanner is opened
2. Show Android's system permission dialog
3. Handle permission denial gracefully

**Optional: Add pre-request explanation:**

```dart
Future<void> _showCameraPermissionRationale(BuildContext context) async {
  await showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Camera Permission'),
      content: const Text(
        'Mealvana needs camera access to scan food barcodes. '
        'This helps you quickly add foods to your nutrition plan.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}
```

---

## Phase 6: Shorebird Android Setup (Day 5)

### 6.1 Install Shorebird CLI (If Not Already)

**Lee may need to do this:**

```bash
# Install Shorebird CLI
curl --proto '=https' --tlsv1.2 https://raw.githubusercontent.com/shorebirdtech/install/main/install.sh -sSf | bash

# Verify installation
shorebird --version
```

### 6.2 Initialize Android for Shorebird

```bash
# In project root
shorebird init --platforms android

# This will:
# 1. Add shorebird.yaml configuration for Android
# 2. Update Android build files
# 3. Configure Shorebird for Android builds
```

### 6.3 Create Android Release with Shorebird

```bash
# First release (baseline)
shorebird release android --target lib/main.dart

# This creates the initial release that patches will be based on
```

### 6.4 Verify shorebird.yaml

**File:** `/shorebird.yaml`

**Should contain:**

```yaml
app_id: YOUR_SHOREBIRD_APP_ID
flavors:
  development: com.milkman.mealvanaendurance.dev
  production: com.milkman.mealvanaendurance
```

### 6.5 Future Patching Process

```bash
# After making code changes
shorebird patch android --target lib/main.dart

# Users will receive updates without Play Store submission
```

**Note:** Native code changes (Android manifest, dependencies) require full Play Store release.

---

## Phase 7: Data Safety Declaration Preparation (Day 6)

### 7.1 Audit Data Collection

**Based on your app's code, here's what to declare in Google Play Console:**

| Data Type | Collected | Purpose | Shared with Third Parties |
|-----------|-----------|---------|---------------------------|
| **User Account Info** | ✅ Yes | Authentication (Supabase) | ❌ No (Supabase is processor) |
| **Email Address** | ✅ Yes | Account creation | ❌ No |
| **Health & Fitness** | ✅ Yes | Nutrition plan generation | ❌ No |
| **App Activity** | ✅ Yes | Analytics (Mixpanel) | ✅ Yes (Mixpanel) |
| **Crash Logs** | ✅ Yes | Error tracking (Sentry) | ✅ Yes (Sentry) |
| **Device ID** | ✅ Yes | User identification | ❌ No |
| **Location** | ❌ No | N/A | ❌ No |
| **Photos/Videos** | ⚠️ Camera Access | Barcode scanning only | ❌ No |
| **Audio** | ❌ No | Not used (speech_to_text inactive) | ❌ No |

### 7.2 Data Security Practices to Declare

**Encryption:**
- ✅ Data encrypted in transit (HTTPS)
- ✅ Data encrypted at rest (Supabase)

**Data Deletion:**
- ✅ Users can request data deletion (provide contact: your_email@domain.com)

**Data Sharing:**
- ⚠️ Analytics data shared with Mixpanel
- ⚠️ Error data shared with Sentry

### 7.3 Create Data Safety Answers Document

**I'll create a separate document:** `data_safety_answers.md` with complete form answers.

---

## Phase 8: Build & Test Release (Day 7)

### 8.1 Build Release App Bundle

```bash
# Clean build
flutter clean
flutter pub get

# Build release AAB
flutter build appbundle --release

# Output: build/app/outputs/bundle/release/app-release.aab
```

### 8.2 Test Release Build Locally

```bash
# Install release build on physical device
flutter install --release

# Test on Pixel 7 Pro:
# 1. User login/registration
# 2. Create nutrition plan
# 3. Scan barcode (camera permission)
# 4. Schedule notification (notification permission)
# 5. Test offline mode (turn off wifi/data)
# 6. Check analytics events in Mixpanel
# 7. Trigger error to test Sentry
```

### 8.3 Verify App Signing

```bash
# Check AAB signing
jarsigner -verify -verbose -certs build/app/outputs/bundle/release/app-release.aab

# Should show: "jar verified."
```

### 8.4 Run Flutter Analyze & Tests

```bash
# Check for issues
flutter analyze

# Run tests
flutter test

# Check for Android-specific warnings
cd android && ./gradlew assembleRelease --warning-mode all
```

---

## Phase 9: Google Play Console Setup (Prerequisites)

**Note:** Some of these Lee will do manually (see `roadmap_lee.md`), but here's the technical checklist:

### 9.1 Upload Keystore for App Signing

**In Google Play Console:**

1. Go to **Release > Setup > App Integrity**
2. Choose **Google Play App Signing**
3. Upload `mealvana-release-key.jks` (one-time)
4. Google generates production signing key
5. Download `deployment_cert.der` for future updates

### 9.2 Upload First AAB

**In Google Play Console:**

1. Go to **Release > Testing > Open Testing**
2. Click **Create new release**
3. Upload `app-release.aab`
4. Add release notes
5. Save as draft (don't submit yet)

### 9.3 Configure Internal App Sharing (Optional, for fast testing)

```bash
# Build and upload to internal app sharing
flutter build appbundle --release
# Then upload via Play Console > Internal app sharing
```

---

## Verification Checklist

Before submitting to Open Testing, verify:

- [ ] App builds successfully: `flutter build appbundle --release`
- [ ] No `flutter analyze` errors
- [ ] Target SDK is 34 (Android 14)
- [ ] All required permissions in AndroidManifest.xml
- [ ] Notification channels created and working
- [ ] Camera permission requested for barcode scanning
- [ ] Release signing configured with keystore
- [ ] Shorebird Android initialized
- [ ] Test on Pixel 7 Pro with all features
- [ ] Data Safety form completed (see `data_safety_answers.md`)
- [ ] Privacy Policy and Terms of Service URLs added to listing

---

## Common Issues & Troubleshooting

### Issue: "App not installed" on release build

**Cause:** Debug version still installed with different signature

**Fix:**
```bash
adb uninstall com.milkman.mealvanaendurance
flutter install --release
```

### Issue: Notifications not showing

**Causes:**
1. Permission not granted (Android 13+)
2. Notification channel not created
3. Do Not Disturb mode enabled
4. Battery optimization killing background tasks

**Debug:**
```bash
adb logcat | grep flutter
# Check for notification-related errors
```

### Issue: Gradle build fails

**Common causes:**
- Java version mismatch
- Gradle daemon corrupted
- Dependency conflicts

**Fix:**
```bash
cd android
./gradlew clean
./gradlew build --refresh-dependencies
```

### Issue: Keystore file not found

**Cause:** `key.properties` path incorrect

**Fix:** Ensure `storeFile=app/mealvana-release-key.jks` (relative to `/android/`)

---

## Next Steps After Technical Setup

Once all technical configuration is complete:

1. **Lee's Tasks** → See `roadmap_lee.md` for store listing assets
2. **Submit for Open Testing** → Follow Google Play Console workflow
3. **Invite Testers** → Share opt-in URL with test users
4. **Gather Feedback** → Use Google Play Console testing feedback
5. **Iterate** → Use Shorebird for rapid patches
6. **Promote to Production** → After successful testing period

---

## Resources & References

### Official Documentation
- [Flutter Android Deployment](https://docs.flutter.dev/deployment/android)
- [Google Play Console Help](https://support.google.com/googleplay/android-developer)
- [Android API Levels](https://apilevels.com/)

### Package Documentation
- [flutter_local_notifications](https://pub.dev/packages/flutter_local_notifications)
- [mobile_scanner](https://pub.dev/packages/mobile_scanner)
- [sentry_flutter](https://docs.sentry.io/platforms/flutter/)
- [Shorebird Docs](https://docs.shorebird.dev/)

### Tools
- [Android Studio](https://developer.android.com/studio)
- [adb (Android Debug Bridge)](https://developer.android.com/tools/adb)
- [Bundletool](https://developer.android.com/tools/bundletool) - for AAB testing

---

**Last Updated:** 2025-10-17
**Status:** Ready for implementation
**Estimated Time:** 5-7 days (technical only)
