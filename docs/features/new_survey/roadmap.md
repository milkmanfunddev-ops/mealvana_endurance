# New Survey Feature Implementation Roadmap

## Overview
Replace the existing feedback drawer with a two-screen survey flow that better captures user confidence, reuse intent, and specific feedback about nutrition plans. **This implementation includes local notifications for reminder scheduling.**

## Architecture Approach
Following FOA (Feature-Oriented Architecture) principles with clear separation between:
- **Presentation Layer**: UI screens and controllers
- **Application Layer**: Business logic and services
- **Domain Layer**: Data models and entities  
- **Data Layer**: Repositories and Drift database integration
- **Shared Services**: NotificationService for local notifications

## Key Requirements Summary
- **Trigger**: After user presses "Save" on nutrition plan screen
- **Navigation**: After survey completion → navigate to tabs screen
- **Database**: Modify existing `feedback` table (no backward compatibility needed)
- **Notifications**: Local notifications using flutter_local_notifications
- **Default Reminder**: Thursday 5:00 PM with recurring/one-time options
- **Analytics**: Track survey interactions and notification preferences in Mixpanel
- **Storage**: User notification preferences stored in Drift only

## Phase 1: Database Setup

### 1.1 Provide DDL for Manual Execution
- [ ] **Provide DDL statements for manual execution in Supabase client**
- [ ] **Developer Action**: Execute DDL in Supabase console

**DDL to Execute in Supabase Client:**

**1. Modify Feedback Table:**
```sql
ALTER TABLE public.feedback 
ADD COLUMN IF NOT EXISTS confidence_level INTEGER CHECK (confidence_level BETWEEN 1 AND 5),
ADD COLUMN IF NOT EXISTS confidence_label TEXT,
ADD COLUMN IF NOT EXISTS reuse_intent TEXT CHECK (reuse_intent IN ('yes', 'maybe', 'no')),
ADD COLUMN IF NOT EXISTS reminder_requested BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS missed_reasons TEXT[], -- Array for single selection + other text  
ADD COLUMN IF NOT EXISTS missed_other TEXT,
ADD COLUMN IF NOT EXISTS reminder_day_of_week INTEGER, -- 1=Monday, 4=Thursday, 6=Saturday
ADD COLUMN IF NOT EXISTS reminder_hour INTEGER DEFAULT 17, -- Default 5 PM
ADD COLUMN IF NOT EXISTS reminder_minute INTEGER DEFAULT 0,
ADD COLUMN IF NOT EXISTS reminder_recurring BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS device_id TEXT;
```

**2. Update Users Table:**
```sql
ALTER TABLE public.users 
ADD COLUMN IF NOT EXISTS notifications_enabled BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS default_reminder_day INTEGER DEFAULT 4, -- Thursday
ADD COLUMN IF NOT EXISTS default_reminder_hour INTEGER DEFAULT 17, -- 5 PM
ADD COLUMN IF NOT EXISTS default_reminder_minute INTEGER DEFAULT 0,
ADD COLUMN IF NOT EXISTS default_reminder_recurring BOOLEAN DEFAULT FALSE;
```

### 1.2 Update Drift Schema
- [ ] Modify existing `feedback` table in Drift schema to match Supabase
- [ ] Update `users` table in Drift schema to match Supabase
- [ ] Generate migration for local database: `dart run drift_dev make-migrations`
- [ ] Run code generation: `dart run build_runner build --delete-conflicting-outputs`

## Phase 2: Dependencies Setup

### 2.1 Add Flutter Local Notifications Dependency
- [ ] Add `flutter_local_notifications: ^19.4.1` to pubspec.yaml
- [ ] Add `timezone` package for scheduling support
- [ ] Run `flutter pub get`

### 2.2 iOS Notification Setup

**📚 Full Documentation**: [Flutter Local Notifications Plugin](https://pub.dev/packages/flutter_local_notifications)

#### iOS Setup Summary (Developer Required)

**Key Setup Steps from Plugin Documentation:**
1. **AppDelegate Configuration**: Add notification delegate and plugin registrant callback
2. **Permission Handling**: Configure when to request notification permissions  
3. **Background Processing**: Enable background notification handling

**Required iOS Changes:**
- [ ] **Developer Action**: Update `ios/Runner/AppDelegate.swift` with notification delegate setup
- [ ] **Developer Action**: Add notification capabilities in Xcode project settings if needed
- [ ] **Future**: May need App Store Connect configuration for notification entitlements

**AppDelegate.swift Setup (Developer Required):**
```swift
// ios/Runner/AppDelegate.swift
import UIKit
import Flutter
import flutter_local_notifications

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Required for notification handling
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
    }
    
    // Required for background notification processing  
    FlutterLocalNotificationsPlugin.setPluginRegistrantCallback { (registry) in
      GeneratedPluginRegistrant.register(with: registry)
    }
    
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
```

**📖 Reference Plugin Documentation**: 
- [iOS Setup Guide](https://pub.dev/packages/flutter_local_notifications#ios-setup)
- [Notification Actions](https://pub.dev/packages/flutter_local_notifications#notification-actions)
- [Background Handling](https://pub.dev/packages/flutter_local_notifications#notification-actions)

## Phase 3: Shared Services Layer

### 3.1 Create Static NotificationService
- [ ] Create static `NotificationService` class in `lib/shared/services/`
- [ ] Implement notification initialization
- [ ] Add permission request methods
- [ ] Implement notification scheduling (one-time and recurring)
- [ ] Add notification cancellation methods
- [ ] Integrate with timezone package for proper scheduling
- [ ] Handle iOS-specific implementation

**Key Static Methods:**
```dart
class NotificationService {
  static Future<void> initialize()
  static Future<bool> requestPermissions()
  static Future<void> scheduleReminder(DateTime scheduledDate, bool recurring, String title, String body)
  static Future<void> cancelAllReminders()
  static Future<bool> areNotificationsEnabled()
}
```

**Location:** `lib/shared/services/notification_service.dart`

**No Riverpod Provider Needed** - Service will be used as static methods

## Phase 4: Domain Layer

### 4.1 Create Domain Models
- [ ] Modify existing `FeedbackData` model to include survey fields
- [ ] Create `ConfidenceLevel` enum (1-5 with labels: not_at_all, a_little, somewhat, very, extremely)
- [ ] Create `ReuseIntent` enum (yes, maybe, no)  
- [ ] Create `MissedReason` enum for single-select feedback options
- [ ] Create `NotificationPreference` model
- [ ] Add JSON serialization support for new fields

**Location:** `lib/features/feedback/domain/` (extend existing)

## Phase 5: Data Layer

### 5.1 Update Existing Repository
- [ ] Modify `FeedbackRepository` to handle new survey fields
- [ ] Update `saveFeedback()` method for extended data model
- [ ] Add notification preference storage methods
- [ ] Maintain Drift and Supabase sync for feedback data
- [ ] Add user preference methods for notification settings

**Location:** `lib/features/feedback/data/` (modify existing)

## Phase 6: Application Layer

### 6.1 Update Feedback Service
- [ ] Modify existing `FeedbackService` to handle survey data
- [ ] Integrate with `NotificationService` for reminder scheduling
- [ ] Add validation logic for survey responses
- [ ] Implement analytics tracking for survey events
- [ ] Handle notification permission flows

**Key Analytics Events to Track:**
- `survey_started`
- `survey_page_1_completed` 
- `survey_completed`
- `reminder_requested`
- `notification_permission_granted/denied`
- `reminder_scheduled`

**Location:** `lib/features/feedback/application/` (modify existing)

## Phase 7: Presentation Layer

### 7.1 Update Feedback Controllers
- [ ] Modify existing `FeedbackController` using AsyncNotifier pattern
- [ ] Extend state management for two-page survey flow
- [ ] Add navigation logic between survey pages
- [ ] Integrate with `NotificationService` for reminder scheduling
- [ ] Handle form validation for both pages
- [ ] Integrate with ContentService for UI text
- [ ] Add analytics tracking for user interactions

**Location:** `lib/features/feedback/presentation/controllers/` (modify existing)

### 7.2 Create Survey Screens

#### Page 1: Confidence & Reuse Screen
- [ ] Create `SurveyPage1Screen` widget
- [ ] Implement confidence level selector (1-5 scale with labels)
- [ ] Implement reuse intent selector (yes/maybe/no)
- [ ] Add "Next" button with validation
- [ ] Style according to Material Design 3
- [ ] Add progress indicator (Page 1 of 2)

#### Page 2: Conditional Feedback & Reminder Screen  
- [ ] Create `SurveyPage2Screen` widget
- [ ] **If "yes" selected**: Show reminder scheduling options
  - [ ] Day of week selector (default Thursday)
  - [ ] Time selector (default 5:00 PM)  
  - [ ] One-time vs recurring toggle
  - [ ] Request notification permissions when needed
- [ ] **If "maybe/no" selected**: Show "What missed?" single-select options
  - [ ] Radio buttons for: Too generic, Too much effort, GI issues, Wrong timing, Foods not right, Amounts not right, Other
  - [ ] Text area for "Other" option
- [ ] Add "Complete Survey" submit button
- [ ] Show success message after submission
- [ ] Navigate to tabs screen after completion

**Location:** `lib/features/feedback/presentation/screens/`

### 7.3 Create Reusable Widgets
- [ ] Create `ConfidenceSelector` widget (1-5 scale with emoji/labels)
- [ ] Create `ReuseIntentSelector` widget (yes/maybe/no buttons)
- [ ] Create `MissedReasonsSelector` widget (single-select radio buttons)
- [ ] Create `ReminderScheduler` widget (day/time/recurring selector)
- [ ] Create `SurveyProgressIndicator` widget
- [ ] Create `SurveySuccessMessage` widget

**Location:** `lib/features/feedback/presentation/widgets/`

## Phase 8: Navigation Integration

### 8.1 Update App Router
- [ ] Add routes for survey screens
- [ ] Configure navigation parameters for survey flow
- [ ] Ensure proper navigation back to tabs screen

```dart
GoRoute(
  path: '/survey/confidence',
  name: 'survey_confidence',
  builder: (context, state) => const SurveyPage1Screen(),
),
GoRoute(
  path: '/survey/feedback',
  name: 'survey_feedback', 
  builder: (context, state) => const SurveyPage2Screen(),
),
```

### 8.2 Update Nutrition Plan Results Screen
- [ ] Remove feedback drawer integration completely
- [ ] Integrate survey trigger after "Save" button is pressed
- [ ] Navigate to survey page 1 after successful plan save
- [ ] Ensure survey completion navigates to tabs screen
- [ ] Handle survey dismissal/cancellation gracefully

### 8.3 Add Settings Screen Integration
- [ ] Add notification preferences section to settings
- [ ] Allow users to enable/disable reminders
- [ ] Show current notification settings
- [ ] Allow modification of reminder time/day preferences
- [ ] Add "Test Notification" button for user verification

## Phase 9: Testing

### 9.1 Unit Tests
- [ ] Test domain models and enums
- [ ] Test notification service methods
- [ ] Test repository methods with new survey fields
- [ ] Test controller state management for survey flow
- [ ] Test reminder scheduling logic

### 9.2 Widget Tests
- [ ] Test survey screen widgets
- [ ] Test navigation flow between pages
- [ ] Test form validation on both pages
- [ ] Test conditional logic (yes vs maybe/no flows)
- [ ] Test reminder scheduling widgets

### 9.3 Integration Tests
- [ ] Test complete survey flow end-to-end
- [ ] Test notification permission requests
- [ ] Test notification scheduling and cancellation
- [ ] Test data persistence in Drift
- [ ] Test analytics event tracking
- [ ] Test error handling for notification failures

### 9.4 Notification Testing
- [ ] Test notifications across device reboots
- [ ] Test one-time vs recurring notifications
- [ ] Test notification permission edge cases
- [ ] Test notification tap behavior (app launch)
- [ ] Test notification display on both iOS and Android

## Phase 10: Code Cleanup

### 10.1 Remove Old Feedback Drawer Code
- [ ] Remove `FeedbackDrawer` widget completely
- [ ] Clean up unused feedback drawer components  
- [ ] Update any references to old feedback drawer system
- [ ] Remove feedback drawer imports and dependencies

**No Data Migration Required** - Will use existing feedback data structure with new columns

## Phase 11: Analytics & Monitoring

### 11.1 Analytics Integration
- [ ] Track survey interactions in Mixpanel:
  - `survey_started`
  - `survey_page_1_completed`
  - `survey_confidence_selected` (with level)
  - `survey_reuse_intent_selected` (with intent)
  - `reminder_requested`
  - `notification_permission_requested`
  - `notification_permission_granted/denied`
  - `reminder_scheduled` (with time/recurring status)
  - `survey_completed`
  - `survey_abandoned` (if user exits mid-flow)

### 11.2 Error Monitoring
- [ ] Add Sentry error tracking for:
  - Notification scheduling failures
  - Permission request failures
  - Survey submission failures
  - Database sync issues
- [ ] Set up alerts for critical failures
- [ ] Monitor notification delivery rates

### 11.3 Success Metrics
- [ ] Track survey completion rates
- [ ] Monitor notification permission grant rates  
- [ ] Track reminder setup completion rates
- [ ] Monitor user engagement with notifications

## Phase 12: Documentation & Architecture Updates

### 12.1 Update Architecture Documentation
- [ ] Update `/docs/technical/README.md` to include NotificationService
- [ ] Document notification architecture and flow
- [ ] Add notification setup instructions for developers
- [ ] Document analytics events for survey feature

### 12.2 Code Documentation
- [ ] Add comprehensive inline documentation for NotificationService
- [ ] Document survey flow logic and conditional branches
- [ ] Add code examples for notification scheduling
- [ ] Document platform-specific setup requirements

### 12.3 Developer Documentation
- [ ] Create setup guide for iOS notification configuration
- [ ] Document Android manifest requirements
- [ ] Create troubleshooting guide for notification issues
- [ ] Document testing procedures for notifications

## Phase 13: Deployment Coordination

### 13.1 Developer Database Tasks
- [ ] **Developer Action**: Execute provided DDL in Supabase staging console
- [ ] **Developer Action**: Execute provided DDL in Supabase production console
- [ ] **Developer Action**: Verify table structure changes in both environments

### 13.2 App Deployment
- [ ] Deploy app with survey feature
- [ ] **No Database Deployment Required** - Developer handles DDL execution
- [ ] Monitor initial usage and error rates
- [ ] Verify notification delivery on iOS

### 13.3 Post-Deployment Monitoring
- [ ] Monitor survey completion rates
- [ ] Track notification permission grant rates
- [ ] Watch for any notification-related crashes
- [ ] Monitor user feedback on new survey experience

## Implementation Order

**Recommended implementation sequence:**
1. **Dependencies & Platform Setup** (Phase 2) - Add flutter_local_notifications, configure Android/iOS
2. **Database Changes** (Phase 1) - Modify feedback table, update Drift schema  
3. **Shared Services** (Phase 3) - Create NotificationService with Riverpod provider
4. **Domain Models** (Phase 4) - Update existing models with survey fields
5. **Data & Application Layers** (Phase 5-6) - Update repositories and services
6. **UI Implementation** (Phase 7) - Create survey screens and widgets
7. **Navigation Integration** (Phase 8) - Update router and plan results screen
8. **Testing** (Phase 9) - Comprehensive testing including notifications
9. **Platform-Specific Setup** (Phase 10.3) - iOS developer tasks
10. **Complete remaining phases** (Phase 10-13)

## Time Estimate

- **Phase 1-2:** 2-3 hours (DDL provided + iOS setup)
- **Phase 3:** 3-4 hours (Static NotificationService implementation)
- **Phase 4-6:** 4-5 hours (Domain, Data, Application layers)
- **Phase 7-8:** 6-7 hours (UI screens and navigation)
- **Phase 9:** 3-4 hours (Testing iOS notifications)
- **Phase 10-13:** 2-3 hours (Cleanup and coordination)

**Total:** ~20-26 hours (reduced with simplified approach)

## Developer Requirements

### **iOS Developer Tasks Required:**
- Execute provided DDL in Supabase console (staging & production)
- Update `ios/Runner/AppDelegate.swift` with notification delegate
- Configure notification capabilities in Xcode project settings if needed
- Test notification permissions and scheduling on iOS devices
- Potential App Store Connect configuration for notification entitlements

### **No Android Setup Required:**
- iOS-only implementation for initial release

## Key Considerations

### FOA Compliance
- Maintain strict separation between layers
- Controllers handle ALL business logic (including notification scheduling)
- Screens handle ONLY UI logic
- Use ContentService for all text
- NotificationService as shared service, not feature-specific

### Notification Architecture
- Initialize NotificationService in app startup sequence
- Handle permission requests gracefully with user choice
- Support both one-time and recurring reminders
- Persist scheduled notifications across device reboots
- Handle timezone differences appropriately

### State Management
- Use Riverpod AsyncNotifier pattern for survey controller
- Implement proper error handling with AsyncValue.guard
- Generate providers with @riverpod annotation
- Handle notification permission states in controller

### Analytics Integration
- Track survey interactions comprehensively in Mixpanel
- Monitor notification permission grant/denial rates
- Track reminder scheduling success/failure
- Measure user engagement with scheduled notifications

### User Experience
- Keep survey perceivably short (2 pages max)
- Provide clear feedback after submission with success message
- Handle notification permission edge cases gracefully
- Navigate to tabs screen after completion
- Default to Thursday 5 PM for reminders
- Allow customization in settings screen

### Data Privacy & Storage
- Store all survey and notification data in Drift only
- Associate responses with device_id
- No PII collection required
- Follow privacy best practices for notification content

## Success Criteria

- [ ] Survey completion rate > 50%
- [ ] Average time to complete < 2 minutes  
- [ ] Notification permission grant rate > 30%
- [ ] Zero data loss during submission
- [ ] Notifications work consistently across device reboots
- [ ] Smooth transition from old feedback drawer system
- [ ] Positive user feedback on new survey experience

## Risk Mitigation

### Notification-Related Risks:
- **Permission Denial**: Graceful fallback when notifications are denied
- **Platform Differences**: Thorough testing on both iOS and Android
- **Battery Optimization**: Document potential issues with Android battery optimization
- **iOS Developer Dependency**: Plan iOS setup tasks early in development cycle

### Technical Risks:
- **Complex State Management**: Use established AsyncNotifier patterns
- **Database Migration**: Careful testing of feedback table modifications
- **Navigation Flow**: Ensure proper back navigation and edge case handling

## Notes

- **iOS Developer Coordination**: Schedule iOS setup tasks early and coordinate with developer availability
- **Platform Testing**: Extensive testing required on both platforms for notifications  
- **Analytics Monitoring**: Set up comprehensive tracking to measure feature success
- **Gradual Rollout**: Consider feature flag for gradual rollout to monitor adoption
- **User Education**: May need in-app messaging to explain new survey benefits