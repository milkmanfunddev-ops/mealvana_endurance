# Push Notifications Roadmap (OneSignal)

## Overview

Push notifications via **OneSignal** - a free service with unlimited mobile push notifications.

**Why OneSignal:**
- Free tier: Unlimited mobile push
- No Firebase SDK needed in Flutter code
- Works with Supabase via REST API
- Simple dashboard for testing

---

## Your Steps (10 Tasks)

### 1. Create OneSignal Account
- Go to [OneSignal Dashboard](https://onesignal.com)
- Sign up (free)
- Create a new app for "Mealvana Endurance"

### 2. Configure iOS in OneSignal
- In OneSignal dashboard: Settings > Platforms > iOS
- Choose "iOS Push Certificate" or "iOS Push Key (p8)" method
- **For p8 key (recommended):**
  - Go to [Apple Developer Portal](https://developer.apple.com/account) > Keys
  - Create new key > Enable "Apple Push Notifications service (APNs)"
  - Download the `.p8` file (save it - only downloadable once!)
  - Note the Key ID
  - Upload to OneSignal with your Team ID

### 3. Configure Android in OneSignal
- In OneSignal dashboard: Settings > Platforms > Android
- Go to [Firebase Console](https://console.firebase.google.com)
- Create project (or use existing)
- Project Settings > Cloud Messaging > Manage Service Accounts
- Create new key > Download JSON
- Upload to OneSignal (or copy Server Key + Sender ID)

### 4. Get OneSignal App ID
- In OneSignal dashboard: Settings > Keys & IDs
- Copy the **OneSignal App ID**
- Add to your `.env.dev.local` and `.env.prod.local`:
```
ONESIGNAL_APP_ID=your-onesignal-app-id-here
```

### 5. Configure Xcode for Push Notifications
- Open `ios/Runner.xcworkspace` in Xcode
- Select Runner target > Signing & Capabilities
- Click "+ Capability" > Add **Push Notifications**
- Click "+ Capability" > Add **Background Modes** > Check "Remote notifications"

### 6. Store OneSignal REST API Key in Supabase
- Get REST API Key from OneSignal: Settings > Keys & IDs
- Store in Supabase secrets:
```bash
supabase secrets set ONESIGNAL_APP_ID="your-app-id"
supabase secrets set ONESIGNAL_REST_API_KEY="your-rest-api-key"
```

### 7. Deploy Edge Function
```bash
supabase functions deploy send-push-notification
```

### 8. Run Flutter Pub Get
```bash
flutter pub get
```

### 9. Test on Real Device
- iOS push notifications require a real device (not simulator)
- Build and run on physical device
- Accept notification permission when prompted
- Send test notification from OneSignal dashboard

### 10. Verify in OneSignal Dashboard
- Check "Audience" tab to see registered devices
- Use "Messages" to send test notifications
- Monitor delivery in "Delivery" tab

---

## What's Already Done (Code)

The following has been implemented:

1. **`onesignal_flutter` package** added to `pubspec.yaml`

2. **`PushNotificationService`** created at:
   - `lib/shared/services/push_notification_service.dart`
   - Handles initialization, permission requests, user login/logout
   - Integrates with analytics tracking

3. **App startup integration**:
   - OneSignal initializes automatically on app launch
   - Users are logged in with their device ID

4. **Supabase Edge Function**:
   - `supabase/functions/send-push-notification/index.ts`
   - Send notifications to specific users or segments

5. **AppConfig** updated:
   - Added `oneSignalAppId` field
   - Reads from `ONESIGNAL_APP_ID` env variable

---

## Sending Notifications

### From OneSignal Dashboard (No Code)
1. Go to Messages > New Push
2. Select audience (All Users, Segments, or specific users)
3. Write title and message
4. Send immediately or schedule

### From Supabase Edge Function (Code)
```typescript
// Call from another edge function or database trigger
const response = await fetch(
  `${SUPABASE_URL}/functions/v1/send-push-notification`,
  {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${SUPABASE_ANON_KEY}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      external_user_ids: ['device-id-1', 'device-id-2'],
      title: 'Nutrition Reminder',
      message: 'Time to eat your pre-run meal!',
      data: { activity_id: '123' },
    }),
  }
);
```

### From Flutter App
```dart
// The app automatically registers users on startup
// To manually request permission:
await PushNotificationService.requestPermission();

// To add tags for segmentation:
PushNotificationService.addTag('sport', 'running');
PushNotificationService.addTag('gut_training', 'advanced');
```

---

## Notification Deep Linking

To handle notification taps and navigate to specific screens:

```dart
// In your app initialization or router setup:
PushNotificationService.onNotificationOpened = (payload) {
  if (payload != null) {
    final activityId = int.tryParse(payload);
    if (activityId != null) {
      // Navigate to activity detail screen
      context.push('/activity/$activityId');
    }
  }
};
```

---

## Costs

| Tier | Mobile Push | Web Push | Price |
|------|-------------|----------|-------|
| Free | Unlimited | 10,000 subscribers | $0 |
| Growth | Unlimited | 100,000 subscribers | $9/mo |

---

## Resources

- [OneSignal Flutter SDK Docs](https://documentation.onesignal.com/docs/flutter-sdk-setup)
- [OneSignal REST API](https://documentation.onesignal.com/reference/create-notification)
- [Apple APNs Key Setup](https://documentation.onesignal.com/docs/generate-an-ios-push-certificate)
- [Android FCM Setup](https://documentation.onesignal.com/docs/android-firebase-credentials)
