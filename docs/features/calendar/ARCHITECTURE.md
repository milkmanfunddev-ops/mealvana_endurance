# Calendar Feature Architecture

## Core Principles

### Identity & Authentication
- **No Auth System**: App uses device-based identity only
- **User Identification**: `device_id` from `user_profiles` table
- **Data Isolation**: All queries filtered by device_id

### Nutrition Plan Philosophy
- **Manual Creation**: Users explicitly initiate nutrition plan generation
- **No Auto-Generation**: Creating an activity does NOT automatically create nutrition plan
- **Reuse Existing Flow**: Leverage existing distance/pace/gut entry screen
- **One Plan Per Activity**: Each activity can have maximum one nutrition plan

### Activity Types
- **Regular Activities**: Running workouts (biking/swimming future)
- **Events**: Special activities for races with additional features
- **Carb Loading Days**: Auto-generated activities from carb loading plans

## Navigation Structure

```
TabsScreen (Bottom Navigation)
├── Activities List (PRIMARY TAB)
│   ├── Calendar date picker (top)
│   ├── "Upcoming Event" widget (if exists)
│   └── Daily activity list (scrollable)
└── Settings
```

### Activities List Screen (Main Screen)
**Purpose**: Primary interface for viewing and managing all activities

**Components**:
1. **Calendar Picker** (top section)
   - Horizontal date selector
   - Highlights today
   - Shows selected date

2. **Upcoming Event Widget** (if upcoming event exists)
   - Shows next event name
   - Countdown to event
   - Taps → navigates to Events List Screen

3. **Daily Activity List** (scrollable)
   - Shows all activities for selected date
   - Activity types:
     - Regular activities (running icon)
     - Events (trophy icon, special styling)
     - Carb loading days (carb icon, special styling)
   - Visual indicators:
     - ✅ Has nutrition plan
     - ⚠️ Missing nutrition plan
     - 🏁 Completed
     - 📅 Planned

4. **Floating Action Button**
   - Press → Activity Creation Screen

## Screen Flows

### Flow 1: Creating Regular Activity

```
Activities List
    │
    ├─ [Tap FAB]
    │
    ▼
Activity Creation Screen
    ├─ Tabs: Running | Biking🚧 | Swimming🚧
    │
    ├─ Running Tab:
    │   └─ Distance/Pace/Gut Entry Form (existing screen)
    │       ├─ Distance (miles)
    │       ├─ Pace (optional)
    │       ├─ Date/Time
    │       ├─ Gut training level
    │       └─ Food preferences
    │
    ├─ [Complete Form & Generate Plan]
    │
    ▼
Nutrition Plan Generation
    │
    ├─ [Success]
    │
    ▼
Activities List (with new activity shown)
```

**Key Points**:
- Activity Creation Screen is tabbed (future: biking/swimming)
- Running tab contains full distance/pace/gut entry form
- Nutrition plan is generated as part of creation flow
- Returns to Activities List after completion

### Flow 2: Creating Event

```
Activities List
    │
    ├─ [Tap "Upcoming Event" Widget]
    │
    ▼
Events List Screen
    ├─ List of all user events
    ├─ Past events (grayed)
    ├─ Upcoming events (highlighted)
    │
    ├─ [Tap FAB on Events List]
    │
    ▼
Event Creation Screen (Full Screen)
    ├─ Event Type (dropdown)
    ├─ Event Name (text)
    ├─ Location (text)
    ├─ Date & Time
    ├─ Goal Time (optional)
    ├─ Registration URL (optional)
    ├─ Bib Number (optional)
    │
    ├─ [Save Event]
    │
    ▼
Event Detail Screen
    ├─ Event Information Display
    ├─ [Button: Create Nutrition Plan]
    ├─ [Button: Create Carb Loading Plan]
    │
    ├─ [Tap "Create Nutrition Plan"]
    │
    ▼
Distance/Pace/Gut Entry Screen
    ├─ Pre-populated with event distance
    │
    ├─ [Complete & Generate]
    │
    ▼
Activities List (event now has nutrition plan)
```

**Key Points**:
- Events accessed via "Upcoming Event" widget
- Event Creation is full screen (not dialog)
- Events saved WITHOUT nutrition plan initially
- Event Detail Screen provides action buttons
- Nutrition plan created on-demand

### Flow 3: Creating Carb Loading Plan (Phase 2)

```
Event Detail Screen
    │
    ├─ [Tap "Create Carb Loading Plan"]
    │
    ▼
Carb Loading Protocol Selection Screen
    ├─ 0-Day (No carb loading)
    ├─ 2-Day Protocol
    ├─ 3-Day Protocol
    │
    ├─ [Select Protocol & Confirm]
    │
    ▼
Carb Loading Plan Generation
    ├─ Creates carb loading plan record
    ├─ Generates daily carb loading activities
    ├─ Inserts activities into calendar
    │
    ▼
Activities List
    ├─ Shows carb loading day activities
    │   (Day -3, Day -2, Day -1 with special styling)
```

**Key Points**:
- Only available for events
- Protocols: 0-day (none), 2-day, 3-day
- Creates separate activities in calendar
- Each carb day is tappable for detail view

### Flow 4: Viewing Activities

**Activity WITH Nutrition Plan:**
```
Activities List → [Tap Activity] → Current Plan Screen (Enhanced)
    ├─ Activity metadata (date, distance, status)
    ├─ Nutrition plan details
    ├─ Voice notes section
    └─ Completion controls
```

**Activity WITHOUT Nutrition Plan:**
```
Activities List → [Tap Activity] → Distance/Pace/Gut Entry Screen
    ├─ Pre-populated with activity distance
    ├─ Generate nutrition plan
    └─ Return to Activities List
```

**Event WITHOUT Nutrition Plan:**
```
Activities List → [Tap Event] → Event Detail Screen
    ├─ Event information
    ├─ [Button: Create Nutrition Plan]
    └─ [Button: Create Carb Loading Plan]
```

**Past Activity (Cannot Create Plans):**
```
Activities List → [Tap Past Activity] → Current Plan Screen (Read-only)
    ├─ Activity metadata
    ├─ Nutrition plan (if exists)
    ├─ Voice notes
    └─ Completion data
```

**Carb Loading Day:**
```
Activities List → [Tap Carb Day] → Carb Loading Day Detail Screen
    ├─ Shows single day carb loading info
    ├─ Meal tracking for that day
    ├─ Carb intake progress
    └─ Based on existing carb loading UI
```

## Screen Specifications

### Activities List Screen
**File**: `lib/features/calendar/presentation/screens/activities_list_screen.dart`

**Components**:
- CalendarDatePicker widget (horizontal date selector)
- UpcomingEventWidget (conditional display)
- ActivityListView (scrollable list)
- FloatingActionButton

**State Management**:
- Selected date (DateTime)
- List of activities for selected date
- Next upcoming event (if exists)

**Data Flow**:
- Watches `calendarControllerProvider`
- Filters activities by selected date
- Queries next event for widget display

### Activity Creation Screen
**File**: `lib/features/calendar/presentation/screens/activity_creation_screen.dart`

**Components**:
- TabBar (Running, Biking, Swimming)
- TabBarView:
  - Running: Distance/Pace/Gut Entry Form (existing widget)
  - Biking: "Under Construction" message
  - Swimming: "Under Construction" message

**Integration**:
- Embeds existing `DistancePaceGutEntryScreen` in Running tab
- On completion, creates activity + nutrition plan
- Navigates back to Activities List

### Events List Screen
**File**: `lib/features/calendar/presentation/screens/events_list_screen.dart`

**Components**:
- AppBar with title "Events"
- ListView of event cards
  - Past events (grayed styling)
  - Upcoming events (prominent styling)
- FloatingActionButton ("Create Event")

**Event Card Display**:
- Event name
- Event type (Marathon, Half-Marathon, etc.)
- Date
- Countdown (if upcoming)
- Status indicators (has nutrition plan, has carb loading)

### Event Creation Screen
**File**: `lib/features/calendar/presentation/screens/event_creation_screen.dart`

**Form Fields**:
- Event Type (dropdown) - required
- Event Name (text) - required
- Location (text)
- Date & Start Time - required
- Goal Time (hours + minutes)
- Registration URL
- Bib Number

**Validation**:
- Event name required
- Date must be in future
- Goal time format validation

**On Save**:
- Creates event record in database
- Navigates to Event Detail Screen

### Event Detail Screen
**File**: `lib/features/calendar/presentation/screens/event_detail_screen.dart`

**Sections**:
1. **Event Information Card**
   - Event name & type
   - Date & time
   - Location
   - Goal time (if set)

2. **Action Buttons**
   - "Create Nutrition Plan" (primary CTA)
     - Disabled if plan already exists
     - Shows "View Nutrition Plan" if exists
   - "Create Carb Loading Plan" (secondary CTA)
     - Shows protocol selection screen
     - Shows "Manage Carb Loading" if exists

3. **Event Metadata**
   - Registration URL (if provided)
   - Bib number (if provided)

### Current Plan Screen (Enhanced)
**File**: `lib/features/nutrition_plan/presentation/screens/current_plan_screen.dart`

**New Additions**:
- Activity metadata header
  - Activity title
  - Scheduled date/time
  - Distance
  - Status badge

**Existing Sections** (preserved):
- Nutrition plan details
- Food items by section (pre-run, during, post)
- Voice notes section
- Completion controls

## Data Models

### Activity Domain Model
```dart
class Activity {
  final String id;
  final String userId; // device_id
  final ActivityType activityType; // running, event, carbLoadingDay
  final String title;
  final DateTime scheduledDateTime;
  final ActivityStatus status; // planned, completed, skipped
  final double? distanceMiles;
  final int? durationMinutes;
  final double? paceTargetMinutesPerMile;
  final IntensityLevel? intensityLevel;
  final DateTime? completedAt;
  final int? completionRating;
  final String? completionNotes;
  final double? actualDistanceMiles;
  final int? actualDurationMinutes;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  // Computed
  bool get isEvent => activityType == ActivityType.event;
  bool get hasPlan => /* check if nutrition plan exists */;
}
```

### Event Domain Model
```dart
class Event {
  final String id;
  final String activityId; // FK to activities table
  final EventType eventType; // marathon, halfMarathon, etc.
  final String? eventName;
  final String? location;
  final String? registrationUrl;
  final String? startTime;
  final int? goalTimeMinutes;
  final double? goalPaceMinutesPerMile;
  final String? bibNumber;
  final DateTime createdAt;
  final DateTime updatedAt;
}
```

### Carb Loading Plan Domain Model (Phase 2)
```dart
class CarbLoadingPlan {
  final String id;
  final String eventId; // FK to events table
  final String userId; // device_id
  final int totalDays; // 2 or 3
  final DateTime startDate;
  final DateTime endDate;
  final int dailyCarbTargetGrams;
  final DateTime generatedAt;
  final double? adherenceScore;
}
```

## Service Layer

### CalendarService
**Responsibilities**:
- CRUD operations for activities
- CRUD operations for events
- Activity completion tracking
- Query activities by date range
- Link activities to nutrition plans

**Key Methods**:
```dart
Future<List<Activity>> getActivitiesForDate(String deviceId, DateTime date);
Future<Activity> createActivity({required String deviceId, ...});
Future<Event?> getEventForActivity(String activityId);
Future<Event> createEvent({required String activityId, ...});
Future<ActivityCompletion> completeActivity({required String activityId, ...});
```

### Device ID Provider
**File**: `lib/shared/providers/device_id_provider.dart`

```dart
@riverpod
Future<String> deviceId(DeviceIdRef ref) async {
  final database = ref.watch(appDatabaseProvider);
  final userProfile = await database.getCurrentUserProfile();
  if (userProfile == null) {
    throw Exception('No user profile found');
  }
  return userProfile.deviceId;
}
```

## Database Schema

### Activities Table
**Primary storage for all activity types**

```sql
CREATE TABLE activities (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,  -- device_id
  activity_type TEXT NOT NULL,  -- 'running', 'event', 'carbLoadingDay'
  title TEXT NOT NULL,
  scheduled_date_time TIMESTAMP NOT NULL,
  status TEXT NOT NULL DEFAULT 'planned',
  distance_miles REAL,
  duration_minutes INTEGER,
  pace_target_minutes_per_mile REAL,
  intensity_level TEXT,
  completed_at TIMESTAMP,
  completion_rating INTEGER,
  completion_notes TEXT,
  actual_distance_miles REAL,
  actual_duration_minutes INTEGER,
  notes TEXT,
  created_at TIMESTAMP NOT NULL,
  updated_at TIMESTAMP NOT NULL,
  deleted_at TIMESTAMP,

  INDEX idx_activities_user_date (user_id, scheduled_date_time),
  INDEX idx_activities_type (activity_type)
);
```

### Events Table
**Extends activities with event-specific data**

```sql
CREATE TABLE events (
  id TEXT PRIMARY KEY,
  activity_id TEXT UNIQUE NOT NULL REFERENCES activities(id) ON DELETE CASCADE,
  event_type TEXT NOT NULL,  -- 'marathon', 'halfMarathon', etc.
  event_name TEXT,
  location TEXT,
  registration_url TEXT,
  start_time TEXT,
  goal_time_minutes INTEGER,
  goal_pace_minutes_per_mile REAL,
  bib_number TEXT,
  created_at TIMESTAMP NOT NULL,
  updated_at TIMESTAMP NOT NULL,

  INDEX idx_events_activity (activity_id)
);
```

## Implementation Checklist

### Phase 1 Immediate (This Week)
- [ ] Create Activities List Screen
- [ ] Create Activity Creation Screen (tabbed)
- [ ] Create Events List Screen
- [ ] Create Event Creation Screen (full screen)
- [ ] Create Event Detail Screen
- [ ] Add Device ID Provider
- [ ] Update Current Plan Screen (add activity metadata)
- [ ] Update TabsScreen (use Activities List as primary)
- [ ] Delete activity_creation_dialog.dart
- [ ] Delete event_creation_dialog.dart
- [ ] Connect Activity Creation to distance/pace/gut entry
- [ ] Test end-to-end flows

### Phase 2 (Carb Loading)
- [ ] Create Carb Loading Protocol Selection Screen
- [ ] Implement carb loading plan generation
- [ ] Create carb loading day activities
- [ ] Carb loading day detail view
- [ ] Protocol modification logic

## Testing Strategy

### Unit Tests
- CalendarService CRUD operations
- Date range filtering
- Activity status transitions
- Device ID provider

### Integration Tests
- Activity creation with nutrition plan
- Event creation flow
- Navigation between screens
- Data persistence

### E2E Tests
- Complete activity creation flow
- Complete event creation flow
- View activity with/without plan
- Carb loading plan creation (Phase 2)

## Migration Notes

### From Current Implementation
1. **Remove Dialogs**: Delete activity_creation_dialog.dart and event_creation_dialog.dart
2. **Refactor TabsScreen**: Change primary tab from Calendar to Activities List
3. **Update Routing**: Add routes for new screens
4. **Data Migration**: No database changes needed (already implemented)

### Backward Compatibility
- Existing nutrition plans unaffected
- User profiles remain device-based
- Food preferences preserved
- Voice notes integration unchanged
