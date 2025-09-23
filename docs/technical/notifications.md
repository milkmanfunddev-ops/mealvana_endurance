# Notification System Documentation

## Overview

The Mealvana Endurance app implements a comprehensive local notification system for scheduling user reminders about their nutrition plans. The system is designed to improve user engagement by reminding them to provide feedback on how well their nutrition plan worked after completing a run.

## System Architecture

### Core Components

1. **NotificationService** (`lib/shared/services/notification_service.dart`)
   - Static service managing all notification operations
   - Handles iOS-specific notification scheduling
   - Integrates with analytics for North-Star metric tracking
   - Manages notification permissions and device initialization

2. **NotificationPreference** (`lib/features/feedback/domain/feedback_data.dart`)
   - Data class defining user notification preferences
   - Supports both recurring weekly reminders and one-time notifications
   - Calculates next reminder dates based on user preferences

3. **FeedbackService** (`lib/features/feedback/application/feedback_service.dart`)
   - Orchestrates notification scheduling when users complete surveys
   - Handles notification permission requests
   - Integrates notification scheduling with survey response flow

## Notification Types

### 1. Survey Reminder Notifications

**Purpose**: Remind users to rate how well their nutrition plan worked

**Trigger**: When user completes feedback survey and opts for reminders

**Content**:
- **Title**: "How did your nutrition plan work?"
- **Body**: "Share your feedback to help us improve your fueling strategy."

**Scheduling Options**:
- **Default**: Thursday at 5:00 PM (recurring weekly)
- **Custom Day**: User-selected day of week at 5:00 PM (recurring weekly)
- **Custom Date/Time**: User-selected specific date and time (one-time or recurring)

### 2. Test Notifications

**Purpose**: Development and testing functionality

**Trigger**: Manual trigger via test button in survey screen (debug mode only)

**Content**:
- **Title**: "Test Notification 📱"
- **Body**: "This is a test notification from your nutrition app. Tap to open the app!"

**Scheduling**: 5 seconds after trigger (one-time)

## Implementation Details

### Platform Support

#### iOS Configuration ✅ **IMPLEMENTED**

**Required Setup in `ios/Runner/AppDelegate.swift`:**
```swift
import flutter_local_notifications

override func application(
  _ application: UIApplication,
  didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
) -> Bool {
  // Required for flutter_local_notifications
  FlutterLocalNotificationsPlugin.setPluginRegistrantCallback { (registry) in
    GeneratedPluginRegistrant.register(with: registry)
  }

  // Set notification center delegate for iOS 10.0+
  if #available(iOS 10.0, *) {
    UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
  }

  GeneratedPluginRegistrant.register(with: self)
  return super.application(application, didFinishLaunchingWithOptions: launchOptions)
}
```

**Permission Handling:**
- Requests alert, badge, and sound permissions when first needed
- Gracefully handles permission denials
- Checks permission status before scheduling notifications

#### Android Configuration ❌ **NOT IMPLEMENTED**

**Current Status**: AndroidManifest.xml missing required notification permissions and receivers

**Required Setup (NOT YET IMPLEMENTED):**
```xml
<!-- android/app/src/main/AndroidManifest.xml -->
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM"/>
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>

<application>
  <!-- Notification receivers for scheduling persistence -->
  <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver" />
  <receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
    <intent-filter>
      <action android:name="android.intent.action.BOOT_COMPLETED"/>
      <action android:name="android.intent.action.MY_PACKAGE_REPLACED"/>
    </intent-filter>
  </receiver>
</application>
```

### Database Integration

**User Notification Preferences** stored in `user_profiles` table:

```sql
-- Notification preference fields
notifications_enabled BOOLEAN DEFAULT 0,
default_reminder_day INTEGER DEFAULT 4,    -- Thursday (1=Monday)
default_reminder_hour INTEGER DEFAULT 17,  -- 5 PM
```

**Survey Response Integration** via `feedback` table:
- Links notification preferences to survey responses
- Tracks when reminders were requested
- Stores preferred reminder day/time

### Service Integration

#### App Startup Service Integration

**Navigation Handling**: App startup service checks for pending notification navigation:

```dart
// lib/features/app_startup/application/app_startup_service.dart
Future<String?> checkForPendingFeedback() async {
  // First check if user tapped a notification
  final notificationPlanId = NotificationService.getPendingNavigationPlanId();
  if (notificationPlanId != null) {
    return notificationPlanId; // Navigate to plan rating screen
  }
  // ... other checks
}
```

#### Analytics Integration

The notification system integrates with analytics to track the **North-Star metric funnel**:

1. **`reminder_set`** - When notification is scheduled
2. **`reminder_fired`** - When notification is delivered (manual tracking)
3. **`plan_opened_from_reminder`** - When user taps notification and opens app

**Tracking Methods** (`lib/shared/services/analytics_service.dart`):

```dart
// Track when reminder is scheduled
static Future<void> trackReminderSet({
  required String planId,
  required String remindAtIso,
}) async { ... }

// Track when reminder notification fires
static Future<void> trackReminderFired({
  required String planId,
}) async { ... }

// Track when user opens app from notification
static Future<void> trackPlanOpenedFromReminder({
  required String planId,
  required String screen,
}) async { ... }
```

## User Flow

### 1. Survey Completion Flow

```
User Completes Survey
    ↓
User Selects "Yes" to Reuse Plan
    ↓
User Chooses Reminder Option:
    • Thursday 5PM (recurring)
    • Saturday 5PM (recurring)
    • Custom date/time
    • No reminder needed
    ↓
FeedbackService.submitSurveyResponse()
    ↓
NotificationService.requestPermissions()
    ↓ (if granted)
NotificationService.scheduleReminder()
    ↓
Analytics: trackReminderSet()
```

### 2. Notification Interaction Flow

```
Scheduled Notification Fires
    ↓
User Taps Notification
    ↓
NotificationService._onNotificationTapped()
    ↓
Analytics: trackPlanOpenedFromReminder()
    ↓
Store planId for navigation
    ↓
App Startup Service Checks Pending Navigation
    ↓
Navigate to Plan Rating Screen
```

## Key Features

### Intelligent Scheduling

**NotificationPreference.getNextReminderDate()** intelligently calculates:
- **Recurring**: Next occurrence of selected day/time
- **One-time**: Specific custom date/time
- **Smart handling**: If current time is past selected day/time, schedules for next week

### Permission Management

**Graceful Degradation**:
- Requests permissions only when user wants notifications
- Continues app functionality if permissions denied
- Clear feedback to user about permission status

### Analytics Integration

**North-Star Metric Tracking**:
- Tracks complete reminder lifecycle for business metrics
- Associates all events with specific planId for funnel analysis
- Integrates with Mixpanel via RudderStack pipeline

### Cross-Platform Considerations

**Current Status**:
- ✅ **iOS**: Fully implemented and tested
- ❌ **Android**: Service code ready, manifest configuration missing

## Configuration

### Dependencies

```yaml
# pubspec.yaml
dependencies:
  flutter_local_notifications: ^19.4.1
  timezone: ^0.10.0
```

### Initialization

**App Startup** (`lib/features/app_startup/application/app_startup_service.dart`):
```dart
// Initialize notification service during app startup
await NotificationService.initialize();
```

### Development Testing

**Test Button** available in survey screen (debug mode only):
- Schedules test notification in 5 seconds
- Tests permission flow and notification delivery
- Validates analytics tracking integration

## Current Limitations

### Android Support
- **Missing**: AndroidManifest.xml permissions and receivers
- **Impact**: Notifications won't work on Android devices
- **Resolution**: Add required Android configuration

### Notification Delivery Tracking
- **Challenge**: Cannot detect actual notification delivery on iOS
- **Current**: Manual tracking via `trackReminderFired()` method
- **Future**: Consider server-side tracking for delivery confirmation

### Permission Persistence
- **Current**: Requests permissions each time notification needed
- **Future**: Cache permission status to avoid repeated requests

## Future Enhancements

### Enhanced Scheduling Options
- Multiple reminder types (pre-run, post-run, weekly check-ins)
- Smart scheduling based on user's typical running schedule
- Location-based reminders (geofencing)

### Rich Notifications
- Action buttons (rate now, remind later, cancel)
- Rich media content (nutrition plan preview)
- Progress updates (weekly nutrition plan summaries)

### Advanced Analytics
- Notification engagement rates
- Optimal reminder timing analysis
- A/B testing for notification content

## Technical Reference

### Key Files
- **NotificationService**: `lib/shared/services/notification_service.dart`
- **NotificationPreference**: `lib/features/feedback/domain/feedback_data.dart`
- **FeedbackService**: `lib/features/feedback/application/feedback_service.dart`
- **Analytics Integration**: `lib/shared/services/analytics_service.dart`
- **Database Schema**: `lib/shared/database/tables/user_profiles.dart`
- **iOS Configuration**: `ios/Runner/AppDelegate.swift`

### Database Methods
- **Update Preferences**: `AppDatabase.updateUserNotificationPreferences()`
- **Survey Tracking**: `FeedbackRepository.saveSurveyResponse()`

### Analytics Events
- `reminder_set`: Notification scheduled
- `reminder_fired`: Notification delivered
- `plan_opened_from_reminder`: User tapped notification

This notification system provides a solid foundation for user engagement while maintaining clean architecture patterns and comprehensive analytics tracking for business metrics.