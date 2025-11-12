# Android Notification Implementation Guide

**Version:** 1.9.0+30
**Package:** flutter_local_notifications 19.4.1
**Last Updated:** 2025-11-12

---

## Table of Contents

- [Overview](#overview)
- [Current iOS Implementation](#current-ios-implementation)
- [Android Requirements](#android-requirements)
- [Step-by-Step Implementation](#step-by-step-implementation)
- [Testing Guide](#testing-guide)
- [Troubleshooting](#troubleshooting)

---

## Overview

This guide provides detailed instructions for implementing Android notifications in Mealvana Endurance. The current implementation is **iOS-only** and needs to be extended to support Android 13+ notification channels and runtime permissions.

### Key Differences: iOS vs Android

| Feature | iOS | Android |
|---------|-----|---------|
| **Permission Request** | At app launch | Runtime (Android 13+) |
| **Notification Channels** | Not required | Required (Android 8.0+) |
| **Permission Types** | Alert, Badge, Sound | Single POST_NOTIFICATIONS |
| **Exact Alarms** | Automatic | Requires SCHEDULE_EXACT_ALARM |
| **Boot Persistence** | Automatic | Requires RECEIVE_BOOT_COMPLETED receiver |

---

## Current iOS Implementation

### File: `/lib/shared/services/notification_service.dart`

**Current State Analysis:**

```dart
// Lines 60-96: iOS-ONLY CODE
static Future<bool> requestPermissions() async {
  if (!_isInitialized) {
    await initialize();
  }

  // ⚠️ PROBLEM: Only handles iOS
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

  return false;  // ⚠️ PROBLEM: Android always returns false
}
```

**Issues:**
1. `requestPermissions()` only handles iOS (lines 65-76)
2. `areNotificationsEnabled()` only checks iOS (lines 86-92)
3. Android-specific notification channels not created
4. Runtime permission request missing for Android 13+

---

## Android Requirements

### 1. Notification Channels (Android 8.0+)

Android requires notification channels for organizing notifications:

```dart
const AndroidNotificationChannel channel = AndroidNotificationChannel(
  'nutrition_plan_reminders',           // Channel ID
  'Nutrition Plan Reminders',           // Channel name (user-visible)
  description: 'Reminders for meals',   // Channel description
  importance: Importance.high,          // Notification importance
  playSound: true,                      // Enable sound
  enableVibration: true,                // Enable vibration
);
```

**User Control:**
- Users can disable channels in Settings > Apps > Mealvana > Notifications
- Each channel can have different importance/sound settings
- Channels cannot be deleted after creation (can only be renamed)

### 2. Runtime Permissions (Android 13+)

Android 13 (API 33) introduced runtime permission for notifications:

```xml
<!-- AndroidManifest.xml -->
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
```

**Permission Flow:**
1. App requests permission via system dialog
2. User grants or denies
3. If denied, app must respect user's choice (can't show system dialog again without user action)

### 3. Exact Alarm Permissions (Android 12+)

For precise notification timing:

```xml
<!-- AndroidManifest.xml -->
<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM" />
<uses-permission android:name="android.permission.USE_EXACT_ALARM" />
```

### 4. Boot Receivers

To reschedule notifications after device restart:

```xml
<!-- AndroidManifest.xml -->
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>

<receiver android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver"
          android:enabled="true"
          android:exported="false">
    <intent-filter>
        <action android:name="android.intent.action.BOOT_COMPLETED"/>
    </intent-filter>
</receiver>
```

---

## Step-by-Step Implementation

### Step 1: Add Notification Channel Constants

**File:** `/lib/shared/services/notification_service.dart`

**Add at the top of the `NotificationService` class:**

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
  static const String channelDescription =
      'Reminders for your nutrition plans and meals';
```

**Why:**
- Centralizes channel configuration
- Easy to update channel details in one place
- Consistent channel ID across all notifications

---

### Step 2: Update `initialize()` Method

**Replace the existing `initialize()` method:**

```dart
static Future<void> initialize() async {
  if (_isInitialized) return;

  tz.initializeTimeZones();

  const iosSettings = DarwinInitializationSettings(
    requestAlertPermission: false,
    requestBadgePermission: false,
    requestSoundPermission: false,
  );

  // Use launcher_icon (matches AndroidManifest.xml)
  const androidSettings = AndroidInitializationSettings('@mipmap/launcher_icon');

  const initializationSettings = InitializationSettings(
    android: androidSettings,
    iOS: iosSettings,
  );

  await _plugin.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse: _onNotificationTapped,
  );

  // CREATE ANDROID NOTIFICATION CHANNEL
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

**Changes Made:**
1. Added Android initialization settings with launcher icon
2. Created Android notification channel on platform initialization
3. Channel only created once (on first app launch or reinstall)

**Important Notes:**
- Icon reference: `@mipmap/launcher_icon` must match your launcher icon
- Channel creation is idempotent (safe to call multiple times)
- Channel settings (importance, sound) cannot be changed after creation

---

### Step 3: Implement Android Permission Request

**Replace the existing `requestPermissions()` method:**

```dart
static Future<bool> requestPermissions() async {
  if (!_isInitialized) {
    await initialize();
  }

  // ANDROID 13+ PERMISSION REQUEST
  if (Platform.isAndroid) {
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      // Request POST_NOTIFICATIONS permission (Android 13+)
      final bool? granted = await androidPlugin.requestNotificationsPermission();
      return granted ?? false;
    }
    return false;
  }

  // iOS PERMISSION REQUEST (existing code)
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

**What This Does:**
1. Detects Android platform
2. Requests `POST_NOTIFICATIONS` permission via system dialog
3. Returns `true` if granted, `false` if denied
4. Falls back to iOS implementation for iOS devices

**User Experience:**
- First call shows system permission dialog
- Subsequent calls return current permission status
- If user denies, they must grant via Settings > Apps > Mealvana > Permissions

---

### Step 4: Implement Android Permission Check

**Replace the existing `areNotificationsEnabled()` method:**

```dart
static Future<bool> areNotificationsEnabled() async {
  if (!_isInitialized) {
    await initialize();
  }

  // ANDROID PERMISSION CHECK
  if (Platform.isAndroid) {
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      // Check if POST_NOTIFICATIONS permission is granted
      final bool? enabled = await androidPlugin.areNotificationsEnabled();
      return enabled ?? false;
    }
    return false;
  }

  // iOS PERMISSION CHECK (existing code)
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

**Usage:**
```dart
// Before scheduling notifications, check permission
final hasPermission = await NotificationService.areNotificationsEnabled();
if (!hasPermission) {
  // Show UI to request permission or inform user
  final granted = await NotificationService.requestPermissions();
  if (!granted) {
    // Handle denial gracefully
  }
}
```

---

### Step 5: Update Notification Scheduling

**Replace the existing `scheduleReminder()` method:**

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
    return;  // Don't schedule if permission not granted
  }

  // ADD ANDROID NOTIFICATION DETAILS
  final notificationDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/launcher_icon',
      // Optional: Add custom sound
      // sound: RawResourceAndroidNotificationSound('notification_sound'),
    ),
    iOS: const DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    ),
  );

  final scheduledTZ = tz.TZDateTime.from(scheduledDate, tz.local);

  if (activityId != null) {
    // Track analytics
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
      1,  // Notification ID
      title,
      body,
      scheduledTZ,
      notificationDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      payload: activityId?.toString(),
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  } else {
    await _plugin.zonedSchedule(
      2,  // Notification ID (different from recurring)
      title,
      body,
      scheduledTZ,
      notificationDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: activityId?.toString(),
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }
}
```

**Key Android Configuration:**
- `channelId`: Must match the channel created in `initialize()`
- `importance: Importance.high`: Shows notification as heads-up notification
- `priority: Priority.high`: Ensures notification appears immediately
- `androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle`: Delivers notification at exact time, even in Doze mode

**Android Schedule Modes:**
| Mode | Behavior | Battery Impact |
|------|----------|----------------|
| `exact` | Exact time, but delayed in Doze | Medium |
| `exactAllowWhileIdle` | Exact time, even in Doze | Higher |
| `inexact` | Approximate time (±5 minutes) | Low |
| `inexactAllowWhileIdle` | Approximate time, even in Doze | Medium |

**Recommendation:** Use `exactAllowWhileIdle` for meal reminders (user expects exact timing).

---

### Step 6: Handle Notification Tap (Already Implemented)

The existing `_onNotificationTapped` handler already works for both platforms:

```dart
static void _onNotificationTapped(NotificationResponse response) {
  if (response.payload == null) return;

  final activityId = int.tryParse(response.payload!);
  if (activityId == null) return;

  _analytics.trackReminderClicked(
    deviceId: 'unknown',
    activityId: activityId,
  );
  _pendingNavigationActivityId = activityId;
}
```

✅ **No changes needed** - This works for both iOS and Android.

---

### Step 7: Update AndroidManifest.xml

**File:** `/android/app/src/main/AndroidManifest.xml`

**Add these permissions at the top (outside `<application>` tag):**

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">

  <!-- Existing permissions -->
  <uses-permission android:name="android.permission.INTERNET"/>
  <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
  <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>

  <!-- ADD THESE NOTIFICATION PERMISSIONS -->
  <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
  <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
  <uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM" />
  <uses-permission android:name="android.permission.USE_EXACT_ALARM" />

  <application ...>
    <!-- Existing activity -->
    <activity ...>
      ...
    </activity>

    <!-- ADD THESE RECEIVERS (inside application tag) -->
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

</manifest>
```

---

## Complete Updated File

**File:** `/lib/shared/services/notification_service.dart`

Here's the complete file with all Android changes:

```dart
import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'analytics/analytics_events.dart';
import 'analytics/analytics_tracker.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _isInitialized = false;
  static int? _pendingNavigationActivityId;
  static AnalyticsTracker _analytics = const NoopAnalyticsTracker();

  // Notification channel configuration (Android)
  static const String channelId = 'nutrition_plan_reminders';
  static const String channelName = 'Nutrition Plan Reminders';
  static const String channelDescription =
      'Reminders for your nutrition plans and meals';

  static void configure(AnalyticsTracker tracker) {
    _analytics = tracker;
  }

  static Future<void> initialize() async {
    if (_isInitialized) return;

    tz.initializeTimeZones();

    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const androidSettings = AndroidInitializationSettings('@mipmap/launcher_icon');

    const initializationSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Create Android notification channel
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

  static void _onNotificationTapped(NotificationResponse response) {
    if (response.payload == null) return;

    final activityId = int.tryParse(response.payload!);
    if (activityId == null) return;

    _analytics.trackReminderClicked(
      deviceId: 'unknown',
      activityId: activityId,
    );
    _pendingNavigationActivityId = activityId;
  }

  static Future<bool> requestPermissions() async {
    if (!_isInitialized) {
      await initialize();
    }

    // Android 13+ permission request
    if (Platform.isAndroid) {
      final androidPlugin = _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

      if (androidPlugin != null) {
        final bool? granted = await androidPlugin.requestNotificationsPermission();
        return granted ?? false;
      }
      return false;
    }

    // iOS permission request
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

  static Future<bool> areNotificationsEnabled() async {
    if (!_isInitialized) {
      await initialize();
    }

    // Android permission check
    if (Platform.isAndroid) {
      final androidPlugin = _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

      if (androidPlugin != null) {
        final bool? enabled = await androidPlugin.areNotificationsEnabled();
        return enabled ?? false;
      }
      return false;
    }

    // iOS permission check
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
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
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
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }

  static Future<void> cancelAllReminders() async {
    if (!_isInitialized) {
      await initialize();
    }

    await _plugin.cancelAll();
  }

  static Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    if (!_isInitialized) {
      await initialize();
    }

    return await _plugin.pendingNotificationRequests();
  }

  static int? getPendingNavigationActivityId() {
    final activityId = _pendingNavigationActivityId;
    _pendingNavigationActivityId = null;
    return activityId;
  }

  static bool hasPendingNavigation() {
    return _pendingNavigationActivityId != null;
  }
}
```

---

## Testing Guide

### 1. Build and Install

```bash
# Build debug for testing
flutter build apk --debug

# Uninstall old version (different signature)
adb uninstall com.milkman.mealvanaendurance

# Install new version
adb install build/app/outputs/flutter-apk/app-debug.apk

# Launch app
adb shell am start -n com.milkman.mealvanaendurance/.MainActivity
```

### 2. Test Permission Request

**Manual Steps:**
1. Open app on Android device (Android 13+)
2. Navigate to notification settings (e.g., Settings screen)
3. Tap "Enable Notifications" button
4. **Expected:** System permission dialog appears
5. Tap "Allow"
6. **Expected:** Permission granted, button shows "Notifications Enabled"

**Verify Permission:**
```bash
adb shell dumpsys package com.milkman.mealvanaendurance | grep POST_NOTIFICATIONS
# Expected: granted=true
```

### 3. Test Notification Channel

**Verify Channel Created:**
```bash
adb shell dumpsys notification | grep "nutrition_plan_reminders"

# Expected output:
# channelId=nutrition_plan_reminders
# name=Nutrition Plan Reminders
# importance=HIGH
```

**Check Channel in Settings:**
1. Open Android Settings
2. Go to Apps > Mealvana > Notifications
3. **Expected:** See "Nutrition Plan Reminders" channel
4. Tap channel
5. **Expected:** Can toggle importance, sound, vibration

### 4. Test Notification Scheduling

**Manual Steps:**
1. Create or open a nutrition plan
2. Schedule a reminder for 1 minute from now
3. **Expected:** Success message
4. Wait 1 minute
5. **Expected:** Notification appears in status bar
6. Pull down notification shade
7. **Expected:** Notification shows correct title and body
8. Tap notification
9. **Expected:** App opens and navigates to activity detail

**Verify Scheduled Notification:**
```bash
# Check pending notifications
adb shell dumpsys alarm | grep mealvana

# Expected: Shows scheduled alarm
```

### 5. Test Notification Tap

**Manual Steps:**
1. Schedule notification (as above)
2. Wait for notification to appear
3. Tap notification
4. **Expected:** App launches (or comes to foreground)
5. **Expected:** Navigates to activity detail screen
6. **Expected:** Analytics event tracked (check Mixpanel)

### 6. Test Permission Denial

**Manual Steps:**
1. Uninstall app
2. Reinstall app
3. Navigate to notification settings
4. Tap "Enable Notifications"
5. Tap "Don't allow" in system dialog
6. **Expected:** Button shows "Notifications Disabled"
7. Tap button again
8. **Expected:** Dialog explaining how to enable in Settings (since system dialog won't show again)

### 7. Test After Reboot

**Manual Steps:**
1. Schedule notification for 5 minutes from now
2. Verify notification scheduled
3. Reboot device
4. Wait for scheduled time
5. **Expected:** Notification still appears (boot receiver reschedules it)

**Verify Boot Receiver:**
```bash
# Check receiver is registered
adb shell dumpsys package com.milkman.mealvanaendurance | grep ScheduledNotificationBootReceiver

# Expected: receiver registered
```

### 8. Test Battery Optimization Impact

**Test with Battery Saver:**
1. Schedule notification
2. Enable Battery Saver mode
3. Wait for notification time
4. **Expected:** Notification still appears (exactAllowWhileIdle mode)

**Test with Doze Mode (Advanced):**
```bash
# Force device into Doze mode
adb shell dumpsys deviceidle force-idle

# Wait for notification time
# Expected: Notification still appears

# Exit Doze mode
adb shell dumpsys deviceidle unforce
```

### 9. Check Logs for Errors

```bash
# Watch logs in real-time
adb logcat | grep -E "flutter|Notification"

# Look for:
# - "Notification channel created" (success)
# - "Permission granted" (success)
# - "Notification scheduled" (success)
# - No error messages
```

---

## Troubleshooting

### Issue: Permission dialog not appearing

**Symptom:**
```dart
requestPermissions() // Returns false immediately
```

**Causes:**
1. Running on Android 12 or earlier (permission not required)
2. Permission already denied permanently
3. POST_NOTIFICATIONS not in AndroidManifest.xml

**Fix:**
```bash
# Check Android version
adb shell getprop ro.build.version.sdk
# If < 33, permission not required (behavior is normal)

# Check permission status
adb shell dumpsys package com.milkman.mealvanaendurance | grep POST_NOTIFICATIONS

# If shows "granted=false requested=true", user denied permanently
# User must manually enable in Settings > Apps > Mealvana > Permissions
```

### Issue: Notifications not appearing

**Symptom:**
Notifications scheduled but never appear.

**Causes:**
1. Channel not created
2. Permission not granted
3. Do Not Disturb enabled
4. Battery optimization killing app
5. Incorrect time zone

**Fix:**
```bash
# Verify channel exists
adb shell dumpsys notification | grep nutrition_plan_reminders

# Verify permission
adb shell dumpsys package com.milkman.mealvanaendurance | grep POST_NOTIFICATIONS

# Check DND status
adb shell dumpsys notification | grep "mInterruptionFilter"
# If = 2, DND is on

# Check battery optimization
adb shell dumpsys deviceidle whitelist | grep mealvana
# If not listed, app may be optimized

# Check pending notifications
adb logcat | grep "flutter_local_notifications"
```

### Issue: Notification appears but doesn't open app

**Symptom:**
Tapping notification does nothing or opens wrong screen.

**Causes:**
1. Payload not set correctly
2. `_onNotificationTapped` not called
3. Navigation not handling activityId

**Fix:**
```dart
// Verify payload is set
await _plugin.zonedSchedule(
  2,
  title,
  body,
  scheduledTZ,
  notificationDetails,
  payload: activityId?.toString(),  // ✅ Must be set
);

// Add logging to _onNotificationTapped
static void _onNotificationTapped(NotificationResponse response) {
  print('Notification tapped with payload: ${response.payload}');
  // ... rest of implementation
}
```

### Issue: Notifications not persisting after reboot

**Symptom:**
Scheduled notifications lost after device restart.

**Causes:**
1. RECEIVE_BOOT_COMPLETED permission missing
2. Boot receiver not registered
3. Receiver has wrong configuration

**Fix:**
```bash
# Verify permission exists
grep RECEIVE_BOOT_COMPLETED android/app/src/main/AndroidManifest.xml

# Verify receiver registered
adb shell dumpsys package com.milkman.mealvanaendurance | grep BootReceiver

# Test boot receiver
adb shell am broadcast -a android.intent.action.BOOT_COMPLETED
```

### Issue: Exact timing not working

**Symptom:**
Notifications appear 5-15 minutes late.

**Causes:**
1. Using `inexact` schedule mode
2. Missing SCHEDULE_EXACT_ALARM permission
3. Device in Doze mode

**Fix:**
```dart
// Use exact schedule mode
androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,  // ✅

// Verify permission
adb shell dumpsys package com.milkman.mealvanaendurance | grep SCHEDULE_EXACT_ALARM
```

### Issue: Build errors after changes

**Symptom:**
```
Error: Method not found: 'createNotificationChannel'
```

**Fix:**
```bash
# Clean build
flutter clean
cd android
./gradlew clean
cd ..

# Rebuild
flutter pub get
flutter build apk --debug
```

---

## Checklist

### Implementation Complete

- [ ] Channel constants added to NotificationService
- [ ] `initialize()` updated with Android channel creation
- [ ] `requestPermissions()` updated with Android handling
- [ ] `areNotificationsEnabled()` updated with Android handling
- [ ] `scheduleReminder()` updated with Android notification details
- [ ] AndroidManifest.xml updated with permissions
- [ ] AndroidManifest.xml updated with receivers
- [ ] Code builds without errors

### Testing Complete

- [ ] Permission request dialog appears on Android 13+
- [ ] Permission check returns correct status
- [ ] Notification channel visible in system settings
- [ ] Notifications appear at scheduled time
- [ ] Notification tap opens app and navigates correctly
- [ ] Notifications persist after device reboot
- [ ] Notifications work in Battery Saver mode
- [ ] Analytics events tracked correctly

---

## Resources

- [flutter_local_notifications Documentation](https://pub.dev/packages/flutter_local_notifications)
- [Android Notification Channels Guide](https://developer.android.com/training/notify-user/channels)
- [Android 13 Notification Permission](https://developer.android.com/develop/ui/views/notifications/notification-permission)
- [Android Exact Alarms](https://developer.android.com/about/versions/12/behavior-changes-12#exact-alarm-permission)

---

*Last updated: 2025-11-12 for Mealvana Endurance v1.9.0+30*
