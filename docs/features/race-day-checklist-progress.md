# Race Day Checklist - Implementation Progress

**Date:** 2026-04-06
**Branch:** `feature/race-day-checklist`
**Status:** Phase 1 Complete ✅ | Phase 2 In Progress

---

## ✅ Completed

### Phase 0: UI Foundation (Complete)
- ✅ Added "Race Day Checklist" button to Event Detail screen
- ✅ Created placeholder screen with interactive checkboxes
- ✅ Added routing `/events/:eventId/checklist`
- ✅ Items toggle checked/unchecked on tap
- ✅ Real-time progress bar (0/12, 3/12, etc.)
- ✅ Completion message when all items checked

**Files Created/Modified:**
- `lib/features/events/presentation/widgets/event_action_buttons_card.dart` (Modified)
- `lib/features/race_checklist/presentation/screens/race_checklist_screen.dart` (Created)
- `lib/shared/core/app_router.dart` (Modified)

---

### Phase 1: Database Schema (Complete)
- ✅ Created `race_checklist_items` Drift table
- ✅ Added to `AppDatabase` with code generation
- ✅ Created domain model `ChecklistItem`
- ✅ Defined checklist categories (gear, nutrition, logistics, etc.)

**Files Created:**
- `lib/shared/database/tables/race_checklist_items_table.dart`
- `lib/features/race_checklist/domain/checklist_item.dart`

**Database Schema:**
```sql
CREATE TABLE race_checklist_items (
  id TEXT PRIMARY KEY,
  event_id TEXT NOT NULL,
  user_id TEXT NOT NULL,
  category TEXT NOT NULL CHECK (category IN ('gear', 'nutrition', 'logistics', 'pre_race', 'race_morning')),
  item_name TEXT NOT NULL,
  sort_order INTEGER DEFAULT 0,
  is_checked BOOLEAN DEFAULT FALSE,
  checked_at TIMESTAMP NULL,
  notes TEXT NULL,
  is_template_item BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMP NOT NULL,
  updated_at TIMESTAMP NOT NULL,
  needs_upload BOOLEAN NULL,
  local_updated_at TIMESTAMP NULL
);
```

---

### Phase 2: Gear Template Logic (Complete)
- ✅ Created `GearTemplateService`
- ✅ Generates gear lists based on event type
- ✅ Supports gender-specific items (sports bra for females)
- ✅ Supports distance-specific items (marathon hydration, ultra headlamps)

**Supported Event Types:**
- **Running** - Essential gear + distance-specific (marathon, ultra)
- **Cycling** - Bike gear + mechanical essentials
- **Swimming** - Open water gear + wetsuit
- **Triathlon** - Combined swim/bike/run + transition gear
- **Duathlon** - Run/bike/run gear
- **Brick** - Bike + run transition training gear

**Example Generated Lists:**

**Running (Marathon, Female):**
- Running shoes
- Running shorts/pants
- Running shirt/singlet
- **Sports bra** ← Gender-specific
- Socks
- GPS watch
- Race bib
- Race belt
- Sunglasses
- **Energy gels (4-8 packets)** ← Distance-specific
- **Hydration pack** ← Distance-specific
- Salt sticks
- Blister protection

**Triathlon (Sprint, Male):**
- Transition bag
- Tri suit
- Goggles (2 pairs)
- Wetsuit
- Bike + helmet
- Cycling shoes
- Water bottles (2+)
- Running shoes with elastic laces
- Race belt
- Energy gels
- Electrolyte mix
- (25+ items total)

**Files Created:**
- `lib/features/race_checklist/application/gear_template_service.dart`

---

## 🚧 Next Steps (Phase 3 & 4)

### Phase 3: Data Layer & State Management
**To Do:**
1. Create `ChecklistRepository` for CRUD operations
   - `getChecklistForEvent(eventId)` - Load all items for an event
   - `toggleItem(itemId, isChecked)` - Toggle checked state
   - `addCustomItem(eventId, itemName)` - Add custom gear
   - `deleteItem(itemId)` - Remove item
   - `initializeChecklistForEvent()` - Generate initial list using GearTemplateService

2. Create `ChecklistController` with Riverpod
   - State management for checklist items
   - Handle loading/error states
   - Persist changes to database

3. Wire up the screen to use real data
   - Replace hardcoded items with controller state
   - Load event details to get event type and user gender
   - Generate checklist on first visit
   - Persist checked state

**Estimated Time:** 2-3 hours

---

### Phase 4: Supabase Migration & Sync
**To Do:**
1. Create Supabase migration for `race_checklist_items` table
2. Add Row Level Security (RLS) policies
3. Test sync with Supabase (upload/download checklist items)

**Estimated Time:** 1-2 hours

---

## 📊 Architecture Overview

```
User Flow:
Event Detail Screen
  └─> Click "Race Day Checklist" button
       └─> RaceChecklistScreen
            ├─> ChecklistController (Riverpod)
            │    └─> ChecklistRepository (Drift)
            │         └─> race_checklist_items table
            ├─> GearTemplateService
            │    └─> Generates items based on event type + gender
            └─> UI displays interactive checklist
```

**Data Flow:**
1. User opens checklist for Event X
2. Controller checks if checklist exists for Event X
3. If not, generate using `GearTemplateService.generateGearList()`
   - Fetch event type from `events` table
   - Fetch user gender from `user_profiles` table
   - Generate appropriate gear list
   - Save to `race_checklist_items` table
4. Display checklist with current checked state
5. User taps item → Toggle `is_checked` in database
6. Progress bar updates in real-time

---

## 🧪 Testing Status

### Manual Testing
- ✅ Button appears on Event Detail screen
- ✅ Navigation to checklist screen works
- ✅ Items can be checked/unchecked
- ✅ Progress bar updates correctly
- ✅ Completion message shows at 100%

### Database Testing
- ⏳ Pending - Need to wire up repository
- ⏳ Pending - Need to test persistence
- ⏳ Pending - Need to test Supabase sync

### Unit Testing
- ⏳ Pending - `GearTemplateService` tests
- ⏳ Pending - `ChecklistRepository` tests
- ⏳ Pending - `ChecklistController` tests

---

## 📝 Implementation Notes

### Gender Detection
User gender is available from `user_profiles.gender`:
- Values: 'male', 'female', 'other'
- Located at: `lib/shared/database/tables/user_profiles.dart:33-34`

### Event Type Detection
Event type is available from `events.event_type`:
- Type: `ActivityType` enum
- Values: running, cycling, swimming, triathlon, duathlon, multisport, brick
- Located at: `lib/features/events/domain/event.dart:55`

### Distance Detection
Event distance available from `events.event_subtype`:
- Type: String
- Examples: 'marathon', 'half_marathon', '10k', '5k', 'ultra_50k', 'ironman', 'half_ironman'
- Located at: `lib/features/events/domain/event.dart:56`

### Future Enhancements
- 📅 Time-based reminders (T-3 days: "Pack your race bag")
- 🎨 Custom categories (nutrition, logistics, pre-race, race morning)
- 🔄 Sync checklist templates from Supabase (coach-created)
- 📊 Analytics (which items correlate with race performance)
- 🤝 Coach sharing (coach creates template, athlete checks off)

---

## 🔗 Related Documentation
- [Integration Analysis](/docs/features/race-day-checklist-integration-analysis.md)
- [Gear Lists Reference](/docs/features/race-day-checklist-gear-lists.md)
- [FOA Architecture](/docs/technical/foa-architecture.md)
- [Database Sync](/docs/technical/sync-architecture.md)

---

**Status:** Ready for Phase 3 implementation
**Next Action:** Create ChecklistRepository and ChecklistController
