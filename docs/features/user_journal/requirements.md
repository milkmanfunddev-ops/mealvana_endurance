# User Journal Feature Requirements

## Overview
The User Journal feature allows athletes to provide feedback on their nutrition plan effectiveness after completing their run. This feature includes a rating system, text-based notes with voice-to-text capability, and a journal history view. The system integrates with the existing notification system and provides multiple entry points based on user preferences and app state.

## Feature Components

### 1. Database Schema Updates

#### 1.1 Nutrition Plan Table Modifications
**Location**: `/lib/shared/database/tables/nutrition_plans.dart`

Add the following columns to the `NutritionPlans` table:
- `runDateTime` (DateTimeColumn, nullable) - Scheduled run date and time
- `planRating` (IntColumn, nullable) - Rating value (1-3)
- `journalNotes` (TextColumn, nullable) - User's text notes about the plan

**Migration Requirements**:
- Update Drift schema version from v2 to v3
- Create migration script in `/lib/shared/database/schema_manager.dart`
- Update Supabase schema using `/supabase_user_journal_migration.sql` (created at project root)
- Update documentation in `/docs/database/drift/schema.md` and `/docs/database/supabase/tables.md`

**Supabase Migration**:
A complete SQL migration file has been created at `/supabase_user_journal_migration.sql` in the project root. This file contains:
- ALTER TABLE statements to add new columns
- Indexes for performance optimization
- Helper functions for common operations
- Row Level Security policy updates
- Verification queries and rollback scripts

#### 1.2 Domain Model Updates
**Location**: `/lib/features/nutrition_plan/domain/nutrition_plan.dart`

Add fields to `NutritionPlan` class:
```dart
final DateTime? runDateTime;  // Scheduled run date/time
final int? planRating;        // 1=Could be better, 2=Neutral, 3=Satisfied
final String? journalNotes;   // User's feedback notes
```

### 2. Plan How Well Screen

#### 2.1 Screen Implementation
**Location**: `/lib/features/user_journal/presentation/screens/plan_how_well_screen.dart`

**UI Requirements**:
- Display question: "How well did this plan work for your pre-workout needs?"
- Three rating options with emojis:
  - 😄 Satisfied (value: 3)
  - 😐 Neutral (value: 2)
  - 😬 Could be better (value: 1)
- Submit button (enabled only after selection)
- Clean, centered layout matching mockup design

**Navigation**:
- On Submit → Navigate to Voice Memo Screen
- Pass selected rating and plan ID to next screen

#### 2.2 Controller Implementation
**Location**: `/lib/features/user_journal/presentation/providers/plan_rating_controller.dart`

Following FOA AsyncNotifier pattern:
```dart
@riverpod
class PlanRatingController extends _$PlanRatingController {
  @override
  FutureOr<PlanRatingState> build() { ... }
  
  Future<void> submitRating(int rating) { ... }
}
```

### 3. Voice Memo Screen

#### 3.1 Screen Implementation
**Location**: `/lib/features/user_journal/presentation/screens/voice_memo_screen.dart`

**UI Requirements**:
- Large text input field for notes
- Microphone button for speech-to-text
- Character counter (optional)
- Save button
- Edit capability after dictation
- Auto-save on text changes with debouncing

**Speech-to-Text Integration**:
- Use native iOS/Android speech recognition
- Add dependency: `speech_to_text: ^6.6.0` to pubspec.yaml
- Request microphone permissions
- Show visual feedback during recording
- Display transcribed text in real-time

#### 3.2 Controller Implementation
**Location**: `/lib/features/user_journal/presentation/providers/voice_memo_controller.dart`

Handle:
- Speech recognition initialization
- Permission requests
- Text updates and saving
- Error handling for speech recognition failures

### 4. Voice Notes List Screen

#### 4.1 Screen Implementation
**Location**: `/lib/features/user_journal/presentation/screens/voice_notes_list_screen.dart`

**UI Requirements**:
- List of journal entries sorted by date (newest first)
- Each entry shows:
  - Date and time
  - Plan rating (emoji)
  - Preview of notes (first 2 lines)
  - Tap to view/edit full notes
- Edit and delete functionality
- Empty state for no entries

#### 4.2 Tab Integration
**Location**: `/lib/shared/widgets/tabs_screen.dart`

Add new tab:
```dart
BottomNavigationBarItem(
  icon: Icon(Icons.notes), // or custom asset
  label: 'Notes',
)
```

Add to screens list:
```dart
const VoiceNotesListScreen(),
```

### 5. Current Plan Screen Updates

#### 5.1 Run Date/Time Field
**Location**: `/lib/features/nutrition_plan/presentation/screens/current_plan_screen.dart`

**UI Requirements**:
- Add unobtrusive date/time display
- Default: Upcoming Saturday at 7:00 AM
- Format: "Run Date: Sat, Dec 14 at 7:00 AM"
- Position: Below plan title or in header area
- Make it editable with date/time picker
- Validation: No past dates allowed

#### 5.2 Save Flow Integration
Current flow:
1. User presses "Save"
2. Survey screen appears
3. After survey, notification scheduled (if enabled)

**No changes needed** - existing flow supports requirements

### 6. Navigation Flow Integration

#### 6.1 App Startup Check
**Location**: `/lib/features/app_startup/presentation/widgets/app_startup_widget.dart`

Add logic in `_handleNavigation`:
```dart
// Check for pending plan feedback
final pendingFeedbackPlan = await checkForPendingFeedback();
if (pendingFeedbackPlan != null) {
  context.go('/plan-how-well/${pendingFeedbackPlan.activityId}');
  return;
}
```

#### 6.2 Notification Tap Handler
**Location**: `/lib/shared/services/notification_service.dart`

Modify `_onNotificationTapped`:
- Extract plan ID from payload
- Navigate to `/plan-how-well/{activityId}`
- Track analytics event (existing)

#### 6.3 Test Notification Handler
**Location**: `/lib/features/feedback/presentation/screens/survey_screen.dart`

Modify test notification button action:
- If active plan exists with past run date → Navigate to Plan How Well screen
- Otherwise → Show standard test notification

### 7. Business Logic

#### 7.1 Pending Feedback Service
**Location**: `/lib/features/user_journal/application/pending_feedback_service.dart`

```dart
class PendingFeedbackService {
  Future<NutritionPlan?> checkForPendingFeedback() {
    // Get latest saved plan
    // Check if runDateTime is in the past
    // Check if planRating is null (not yet rated)
    // Return plan if feedback pending, null otherwise
  }
  
  Future<void> saveFeedback(int activityId, int rating, String notes) {
    // Update the activity-owned plan with rating and notes
    // Clear from pending feedback queue
  }
}
```

#### 7.2 Repository Updates
**Location**: `/lib/features/nutrition_plan/data/nutrition_plan_repository.dart`

Add methods:
- `updatePlanRunDateTimeForActivity(int activityId, DateTime runDateTime)`
- `updatePlanFeedbackForActivity(int activityId, int rating, String notes)`
- `getPlansPendingFeedback()` - Returns activity-owned plans with past run dates and no rating

### 8. Navigation Routes

Add to router configuration:
```dart
GoRoute(
  path: '/plan-how-well/:activityId',
  builder: (context, state) => PlanHowWellScreen(
    activityId: int.parse(state.pathParameters['activityId']!),
  ),
),
GoRoute(
  path: '/voice-memo/:activityId',
  builder: (context, state) => VoiceMemoScreen(
    activityId: int.parse(state.pathParameters['activityId']!),
    rating: state.extra as int,
  ),
),
```

### 9. Testing Requirements

#### 9.1 Manual Testing Scenarios
1. **Save Plan → Survey → Notification → Feedback Flow**
   - Create and save a plan
   - Complete survey
   - Enable notifications
   - Wait for notification
   - Tap notification → Should open Plan How Well screen

2. **No Notification Flow**
   - Create plan with run date/time
   - Disable notifications or decline in survey
   - Close app
   - After run date/time passes, open app
   - Should automatically show Plan How Well screen

3. **Test Notification Flow**
   - Save a plan with past run date
   - Go to survey screen
   - Tap test notification button
   - Should navigate to Plan How Well screen

4. **Speech-to-Text Flow**
   - Navigate to Voice Memo screen
   - Tap microphone button
   - Grant permissions if needed
   - Speak test phrase
   - Verify text appears correctly
   - Edit text manually
   - Save and verify persistence

#### 9.2 Edge Cases to Test
- Multiple plans with different run dates
- Plan with no run date set
- Speech recognition failures
- Microphone permission denied
- Very long journal notes (>5000 characters)
- Editing/deleting old journal entries
- App killed during feedback flow

### 10. Implementation Order

1. **Phase 1: Database & Models**
   - Update database schema
   - Run migrations
   - Update domain models
   - Update Supabase schema

2. **Phase 2: Core Screens**
   - Implement Plan How Well screen
   - Implement Voice Memo screen
   - Implement Voice Notes List screen
   - Add Notes tab to navigation

3. **Phase 3: Integration**
   - Add run date/time to Current Plan screen
   - Update app startup logic
   - Modify notification handlers
   - Update test notification behavior

4. **Phase 4: Testing & Polish**
   - Manual testing of all flows
   - Fix edge cases
   - UI polish and animations
   - Performance optimization

### 11. Dependencies to Add

```yaml
dependencies:
  speech_to_text: ^6.6.0  # For voice-to-text functionality
```

### 12. Content Service Keys

Add to `/assets/config/content_defaults.json`:
```json
{
  "ui_text": {
    "plan_how_well_title": "How well did this plan work for your pre-workout needs?",
    "rating_satisfied": "Satisfied",
    "rating_neutral": "Neutral",
    "rating_could_be_better": "Could be better",
    "voice_memo_placeholder": "Tap to add notes about your nutrition plan...",
    "voice_notes_empty": "No journal entries yet",
    "voice_notes_title": "Voice notes"
  }
}
```

### 13. Analytics Events (Future)

When analytics are re-enabled, track:
- `plan_feedback_started` - User opens Plan How Well screen
- `plan_rating_submitted` - Rating submitted with value
- `journal_notes_saved` - Notes saved with word count
- `speech_to_text_used` - Voice input utilized
- `journal_entry_edited` - Existing entry modified
- `journal_entry_deleted` - Entry removed

### 14. Offline Support

All features must work offline:
- Store feedback locally in Drift database
- Sync to Supabase when connection available
- Handle conflicts with last-write-wins strategy
- Show appropriate UI feedback for sync status

### 15. Accessibility

- Ensure all interactive elements have proper labels
- Support VoiceOver/TalkBack
- Minimum touch targets of 44x44 points
- High contrast mode support
- Text scaling support

## Success Criteria

1. Users can rate their nutrition plan effectiveness after runs
2. Users can add text notes using keyboard or voice input
3. Users can view, edit, and delete past journal entries
4. System correctly identifies when feedback is due
5. Navigation works from notifications and app startup
6. All data persists locally and syncs when online
7. Feature follows FOA architecture patterns
8. UI matches provided mockups

## Out of Scope

- Audio recording and playback (only text notes)
- Sharing journal entries
- Exporting journal data
- Advanced analytics or insights
- Push notifications (only local notifications)
- Multiple ratings per plan (one rating only)

## Open Questions (Resolved)

All questions have been addressed in the requirements above based on user responses.

---

*Last Updated: [Current Date]*
*Version: 1.0*
