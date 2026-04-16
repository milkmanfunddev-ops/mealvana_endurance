# Race Day Checklist - Integration Analysis

**Date:** 2026-04-06
**Branch:** `feature/race-day-checklist`
**Author:** AI Assistant

## Executive Summary

This document analyzes the existing events architecture in Mealvana Endurance to identify integration points for a new "Race Day Checklist" feature. The events system is mature with rich data models and well-defined patterns that the checklist feature can leverage.

---

## Current Events Architecture

### Feature Structure
```
lib/features/events/
├── application/
│   ├── events_service.dart         # CRUD operations, business logic
│   ├── active_com_service.dart     # Public race calendar integration
│   └── public_events_service.dart  # Public race discovery
├── data/
│   └── events_repository.dart      # Drift database queries
├── domain/
│   ├── event.dart                  # Main Event model ⭐
│   ├── active_com_event.dart       # External race data
│   └── public_event.dart           # Public race discovery
└── presentation/
    ├── providers/
    │   ├── events_controller.dart  # State management
    │   └── upcoming_event_provider.dart
    ├── screens/
    │   ├── event_detail_screen.dart     # Main integration point ⭐
    │   ├── event_form_screen.dart       # Create/edit events
    │   └── events_list_screen.dart      # Calendar view
    └── widgets/
        ├── event_action_buttons_card.dart  # Action buttons ⭐
        ├── event_details_card.dart
        ├── event_header_card.dart
        └── (8 more widgets)
```

---

## Event Domain Model

### Available Data Fields

The `Event` model (`lib/features/events/domain/event.dart`) contains:

#### Core Event Info
- `id` - Event UUID
- `userId` - Owner
- `activityId` - Optional link to activity/nutrition plan
- `eventType` - ActivityType enum (running, cycling, swimming, triathlon, duathlon, multisport)
- `eventSubtype` - Race distance ('marathon', 'half_marathon', '10k', '5k', etc.)

#### Event Details
- `eventName` - Race name
- `location` - Venue/city
- `registrationUrl` - Official race site
- `eventDate` - Primary race date
- `startTime` - Precise start time with timezone

#### Goals & Performance
- `goalTimeMinutes` - Target finish time
- `goalPaceMinutesPerMile` - Target pace
- `predictedFinishTimeMinutes` - AI-predicted time

#### Nutrition Planning
- `hasCarbLoading` - Carb loading plan enabled
- `carbLoadingDays` - 1, 2, 3, or 7 days
- `carbLoadingStartDate` - When carb loading begins
- Linked to nutrition plan via `activityId`

#### Race Day Logistics ⭐ (Already exists!)
- `bibNumber` - Race bib number
- `waveStartTime` - Wave/corral start time
- `packetPickupInfo` - Packet pickup instructions

#### Post-Race Results
- `actualFinishTimeMinutes` - Actual finish time
- `finalPlacement` - Overall place
- `ageGroupPlacement` - Age group place

### Key Insights

1. **Logistics fields already exist** - `bibNumber`, `waveStartTime`, `packetPickupInfo` are in the model but **underutilized in UI**
2. **Strong nutrition integration** - Events link to activities which link to nutrition plans
3. **Offline-first** - Full sync support with `needsUpload` flag
4. **Multi-sport support** - Built for running, cycling, swimming, triathlons

---

## Current UI Integration Points

### 1. Event Detail Screen ⭐ PRIMARY INTEGRATION POINT
**Location:** `lib/features/events/presentation/screens/event_detail_screen.dart`

**Current Layout:**
```
┌─────────────────────────────────┐
│  Event Details (AppBar)         │
├─────────────────────────────────┤
│  EventHeaderCard                │  ← Event name, date, location
│  - Event name                   │
│  - Date & countdown             │
│  - Location                     │
├─────────────────────────────────┤
│  EventDetailsCard               │  ← Goals, logistics
│  - Goal time                    │
│  - Goal pace                    │
│  - Bib number (if set)          │
├─────────────────────────────────┤
│  EventActionButtonsCard ⭐       │  ← ADD CHECKLIST BUTTON HERE
│  - Create Nutrition Plan        │
│  - Create Carb Loading Plan     │
│  [SPACE FOR CHECKLIST BUTTON]   │  ← New button goes here
├─────────────────────────────────┤
│  EventFooterLinks               │  ← External links
│  - Registration                 │
│  - Results                      │
└─────────────────────────────────┘
```

**Recommended Addition:**
```dart
// In EventActionButtonsCard widget
KyleSecondaryButton(
  onPressed: () => context.push('/events/$eventId/checklist'),
  text: 'View Race Day Checklist',
  icon: FontAwesomeIcons.listCheck,
),
```

### 2. Event Action Buttons Card
**Location:** `lib/features/events/presentation/widgets/event_action_buttons_card.dart`

**Current Actions:**
1. Create/View Nutrition Plan
2. Create/Edit Carb Loading Plan

**Proposed Addition:**
3. **View Race Day Checklist** (new button)

---

## Database Schema

### Events Table
**Location:** `lib/shared/database/tables/events_table.dart`

**Existing logistics fields:**
- `bibNumber` (text, nullable)
- `waveStartTime` (text, nullable)
- `packetPickupInfo` (text, nullable)

**No checklist table exists yet** - You'll need to create one.

### Proposed Checklist Table Structure

```dart
@DataClassName('RaceChecklistItem')
class RaceChecklistItemsTable extends Table {
  TextColumn get id => text().clientDefault(() => const Uuid().v4())();
  TextColumn get eventId => text().named('event_id')(); // FK to events.id
  TextColumn get userId => text().named('user_id')(); // For RLS

  // Checklist item details
  TextColumn get title => text()();
  TextColumn get category => text()(); // 'pre_race', 'race_morning', 'during_race', 'post_race'
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  BoolColumn get isCompleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get completedAt => dateTime().nullable()();

  // Optional timing
  TextColumn get scheduledTime => text().nullable()(); // "6:00 AM", "T-2 hours", etc.
  TextColumn get notes => text().nullable()();

  // Metadata
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  // Sync
  BoolColumn get needsUpload => boolean().nullable()();
  DateTimeColumn get localUpdatedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  String get tableName => 'race_checklist_items';
}
```

---

## Recommended Implementation Approach

### Phase 1: Minimal Viable Feature (MVP)
**Goal:** Get a working checklist integrated into event detail screen

1. **Create Feature Structure**
   ```bash
   lib/features/race_checklist/
   ├── application/
   │   └── checklist_service.dart
   ├── data/
   │   └── checklist_repository.dart
   ├── domain/
   │   └── checklist_item.dart
   └── presentation/
       ├── providers/
       │   └── checklist_controller.dart
       ├── screens/
       │   └── race_checklist_screen.dart
       └── widgets/
           ├── checklist_category_section.dart
           └── checklist_item_tile.dart
   ```

2. **Database Migration**
   - Create Supabase migration for `race_checklist_items` table
   - Add Drift table definition
   - Run code generation

3. **Default Checklist Templates**
   - Create JSON templates for common race types (5K, 10K, half marathon, marathon, triathlon)
   - Store in `assets/config/race_checklist_templates.json`
   - Auto-populate when user creates checklist

4. **UI Integration**
   - Add button to `EventActionButtonsCard`
   - Create `RaceChecklistScreen` with sections:
     - Pre-Race (1-7 days before)
     - Race Morning
     - During Race
     - Post-Race

5. **Routing**
   ```dart
   // Add to app_router.dart
   GoRoute(
     path: 'events/:eventId/checklist',
     builder: (context, state) {
       final eventId = state.pathParameters['eventId']!;
       return RaceChecklistScreen(eventId: eventId);
     },
   ),
   ```

### Phase 2: Smart Features
**Goal:** Make checklist intelligent based on event data

1. **Auto-populate from Event Data**
   - "Pick up bib #[bibNumber]" (uses event.bibNumber)
   - "Wave start time: [waveStartTime]" (uses event.waveStartTime)
   - "Pre-race meal: [X hours before]" (uses nutrition plan timing)
   - "Start carb loading on [date]" (uses event.carbLoadingStartDate)

2. **Nutrition Plan Integration**
   - Link checklist items to nutrition plan
   - "Consume [X]g carbs at T-[Y] hours" (from pre-run nutrition)
   - "Pack [N] energy gels" (from during-run nutrition)
   - "Hydration: [X]oz per hour" (from nutrition plan)

3. **Time-Based Reminders**
   - Notifications for time-sensitive items
   - "T-3 hours: Eat pre-race meal"
   - "T-30 min: Apply sunscreen"

### Phase 3: Advanced Features
**Goal:** Multi-user and coach features

1. **Coach Sharing**
   - Coach can create checklist template for athlete
   - Athlete can check off items, coach can monitor progress

2. **Templates Library**
   - User can save custom templates
   - Share templates with other users
   - Community-contributed templates

3. **Analytics**
   - Track which checklist items correlate with race performance
   - "Athletes who complete 90%+ of checklist finish 5% faster on average"

---

## Example Checklist Items by Category

### Pre-Race (7 days before)
- [ ] Register for race (if not done)
- [ ] Plan travel and accommodation
- [ ] Start carb loading protocol (if applicable)
- [ ] Review course map and elevation profile
- [ ] Test race day outfit and shoes
- [ ] Prepare gear list

### Pre-Race (3 days before)
- [ ] Pick up race packet and bib
- [ ] Pin bib to race shirt
- [ ] Lay out complete race day outfit
- [ ] Charge GPS watch and headphones
- [ ] Prep nutrition (gels, chews, drinks)
- [ ] Plan race morning logistics

### Race Morning
- [ ] Wake up at [time]
- [ ] Eat pre-race meal ([time] before start)
- [ ] Bathroom stop
- [ ] Apply sunscreen
- [ ] Apply anti-chafe
- [ ] Double-check gear (watch, gels, hydration)
- [ ] Arrive at venue ([time])
- [ ] Warm up routine
- [ ] Final bathroom stop
- [ ] Get to corral/starting area

### During Race
- [ ] Start watch at gun/mat
- [ ] Hit nutrition targets (every X miles)
- [ ] Monitor pace vs goal
- [ ] Stay present and focused
- [ ] Execute race plan

### Post-Race
- [ ] Cool down walk
- [ ] Rehydrate and refuel
- [ ] Stretch
- [ ] Ice bath (if applicable)
- [ ] Log results in app
- [ ] Download race photos
- [ ] Thank volunteers and supporters

---

## Integration with Existing Features

### Nutrition Plan
- Link checklist items to nutrition plan activities
- Auto-generate nutrition checklist items from plan
- Example: "Pack 8 energy gels (4 per hour)" from during-run plan

### Carb Loading
- Auto-generate carb loading checklist when plan is created
- Daily reminders: "Day 3 of 7: Consume [X]g carbs today"
- Link to carb loading meal plans

### Coach Mode
- Coach can view athlete's checklist completion status
- Coach can create/modify checklist templates for athletes
- Progress tracking: "15/20 items completed (75%)"

### Calendar Integration
- Show checklist completion status on calendar view
- Visual indicator: ✅ Checklist complete, ⚠️ Items pending

---

## Technical Implementation Notes

### State Management (Riverpod)

```dart
@riverpod
class RaceChecklistController extends _$RaceChecklistController {
  ChecklistService get _service => ref.read(checklistServiceProvider);

  @override
  Future<List<ChecklistItem>> build(String eventId) async {
    return _service.getChecklistForEvent(eventId);
  }

  Future<void> toggleItem(String itemId, bool isCompleted) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await _service.toggleChecklistItem(itemId, isCompleted);
      return _service.getChecklistForEvent(eventId);
    });
  }

  Future<void> addCustomItem(String title, String category) async {
    // Add custom checklist item
  }
}
```

### Offline-First Considerations

- Checklist state must work offline
- Sync completed items when online
- Handle conflicts (local completion vs remote changes)
- Use `needsUpload` flag for dirty tracking

### FOA Compliance

✅ **Separation of Concerns:**
- **Domain:** `ChecklistItem` model (pure data)
- **Data:** `ChecklistRepository` (Drift queries)
- **Application:** `ChecklistService` (business logic)
- **Presentation:** `ChecklistController` (state management)

✅ **Dependency Direction:**
- Presentation → Application → Domain ← Data

---

## Next Steps

### Immediate Actions

1. **Create Feature Skeleton**
   ```bash
   mkdir -p lib/features/race_checklist/{application,data,domain,presentation/{providers,screens,widgets}}
   touch lib/features/race_checklist/domain/checklist_item.dart
   touch lib/features/race_checklist/presentation/screens/race_checklist_screen.dart
   ```

2. **Define Domain Model**
   - Create `ChecklistItem` class
   - Define categories enum
   - Add validation rules

3. **Create Database Table**
   - Add `RaceChecklistItemsTable` to Drift schema
   - Create Supabase migration
   - Run `flutter pub run build_runner build`

4. **Add Routing**
   - Update `app_router.dart`
   - Add route for `/events/:eventId/checklist`

5. **Build MVP UI**
   - Simple checklist screen with checkboxes
   - Basic add/remove item functionality
   - Integration with event detail screen

### Questions to Resolve

1. **Template Strategy:**
   - Hardcoded templates vs. user-editable?
   - Backend-managed templates (ContentService) vs. local JSON?

2. **Sharing Model:**
   - Personal checklists only?
   - Coach-shared templates?
   - Community templates?

3. **Notification Strategy:**
   - Time-based push notifications?
   - Simple reminders or smart timing based on race start?

4. **Analytics:**
   - Track checklist completion rates?
   - Correlate with race performance?

---

## Files to Review Before Starting

1. `lib/features/events/domain/event.dart` - Event model
2. `lib/features/events/presentation/screens/event_detail_screen.dart` - Integration point
3. `lib/features/events/presentation/widgets/event_action_buttons_card.dart` - Button location
4. `lib/shared/database/tables/events_table.dart` - Database schema
5. `lib/features/carb_loading/` - Similar feature for reference patterns

---

## References

- **FOA Architecture:** `/docs/technical/foa-architecture.md`
- **Database Sync:** `/docs/technical/sync-architecture.md`
- **Riverpod Patterns:** `/docs/technical/andrea/andrea_riverpod_autogenerate_new.txt`
- **Content Management:** `/docs/technical/content-management.md`

---

**Status:** Ready for implementation
**Estimated Effort:** 3-5 days for MVP, 1-2 weeks for Phase 2
