# Food Logging Feature - Design & Implementation Plan

## Overview

Add a food logging system to Mealvana Endurance that lives inside the existing Activities tab as a chronological timeline. Users can log meals via AI text parsing, AI photo recognition, manual database search, or barcode scanning. Logged foods grow a community database organically. A daily macro dashboard tracks totals.

## Design Decisions

- **Navigation**: Timeline view inside Activities tab (activities + meals interleaved chronologically)
- **Activity link**: Phase 1 = independent diary; Phase 2 = link to activity nutrition plans
- **AI**: OpenAI for both text parsing and photo recognition via Supabase Edge Functions
- **Food DB growth**: AI-verified foods auto-add to `community_foods` table, flagged as `community_sourced`, admin can promote to `admin_verified`
- **Photos**: Stored locally on device; metadata (file path, timestamp, meal link) in database
- **Daily totals**: Phase 1 = daily macro totals only (no target progress bars). Phase 2 = add targets from user profile + progress bars
- **Favorites**: Phase 2 (quick meals, recent meals, star favorites, templates from plans)
- **Image capture**: `image_picker` Flutter package
- **Portions**: AI-estimated from natural language; user can adjust with stepper
- **Phasing**: 2-phase rollout

---

## User Experience

### Timeline View (Inside Activities Tab)

The existing Activities tab calendar shows activities for the selected date. Food logging adds meal entries interleaved chronologically:

```
--- Calendar (week/month view) ---
--- Daily Macro Dashboard (totals) ---

7:00 AM  | Breakfast          | Oatmeal with blueberries, 2 eggs    | 450 cal
9:00 AM  | Morning Run 6mi    | Nutrition plan: before/during/after  |
12:00 PM | Lunch              | Grilled chicken, rice, broccoli      | 580 cal
3:00 PM  | Afternoon Snack    | Banana, almond butter                | 290 cal
5:30 PM  | Evening Bike 20mi  | Nutrition plan: before/during/after  |
7:00 PM  | Dinner             | Salmon, sweet potato, salad          | 720 cal

--- AI Text Input Bar (docked at bottom) --- [camera icon]
```

### Food Logging Entry Methods

1. **AI Text Input**: Type "grilled chicken 6oz with rice and broccoli" in the bottom input bar. OpenAI parses into individual items with estimated portions and nutrition.
2. **AI Photo**: Tap camera icon, take photo of plate. OpenAI Vision identifies foods and estimates portions.
3. **Database Search**: Search existing food database (master foods + user foods + community foods).
4. **Barcode Scan**: Existing barcode scanning system (Open Food Facts integration).
5. **Manual Entry**: Direct quantity/nutrition input.

### Meal Types

| Meal Type | Suggested Time |
|-----------|---------------|
| Breakfast | Before 10 AM |
| Morning Snack | 10 AM - 12 PM |
| Lunch | 12 PM - 2 PM |
| Afternoon Snack | 2 PM - 5 PM |
| Dinner | 5 PM - 8 PM |
| Evening Snack | After 8 PM |
| Pre-Workout | Before activity |
| Post-Workout | After activity |

Meal type is auto-suggested based on time of day but user can override.

### Daily Macro Dashboard

Displayed above the timeline. Phase 1 shows totals only:

```
Today's Nutrition
Calories: 2,040  |  Carbs: 245g  |  Protein: 125g  |  Fat: 62g  |  Sodium: 1,850mg  |  Hydration: 2.4L
```

Phase 2 adds progress bars against targets calculated from user profile.

### Meal Card (Timeline Entry)

Each logged meal appears as a card showing:
- Meal type icon + name + time
- List of food items with quantities
- Meal macro totals (calories, carbs, protein, fat)
- Photo thumbnail (if photo attached)
- Tap to expand/edit

### AI Parse Confirmation Flow

When user submits text or photo:
1. Show loading indicator
2. AI returns parsed food items with estimated nutrition
3. Show confirmation dialog with editable items:
   - Each item: name, quantity (adjustable stepper), serving description, macros
   - Option to remove items, add missing items
   - Meal type selector
4. User confirms -> entries saved to database

---

## Phase 1: Full Logging + AI + Dashboard

### 1. Database Schema (4 new Drift tables)

**`food_log_meals_table.dart`** - Meal containers

| Column | Type | Notes |
|--------|------|-------|
| id | UUID PK | |
| user_id | text | FK |
| meal_type | text | breakfast, lunch, dinner, morning_snack, afternoon_snack, evening_snack, pre_workout, post_workout |
| logged_at | dateTime | When the meal was eaten |
| log_date | dateTime | Calendar date (for daily grouping) |
| notes | text? | |
| needs_upload, local_updated_at, created_at, updated_at, deleted_at | standard sync cols | |

**`food_log_entries_table.dart`** - Individual food items within a meal

| Column | Type | Notes |
|--------|------|-------|
| id | UUID PK | |
| food_log_meal_id | text FK | Parent meal |
| user_id | text | |
| food_id | text? | FK to foods (master DB) |
| user_food_id | text? | FK to user_foods |
| community_food_id | text? | FK to community_foods |
| food_name, food_display_name | text | Denormalized snapshot |
| quantity | real (default 1.0) | Servings |
| serving_description | text? | "1 large bowl", "6 oz" |
| carbs_per_serving | real? | Denormalized |
| protein_per_serving | real? | Denormalized |
| fat_per_serving | real? | Denormalized |
| calories_per_serving | int? | Denormalized |
| sodium_mg | int? | Denormalized |
| fluid_ml_per_serving | real? | Denormalized |
| ai_source | text? | text_parse, photo_parse, manual, database_search, barcode_scan |
| ai_confidence | real? | 0.0-1.0 |
| original_input | text? | Raw AI input |
| needs_upload, local_updated_at, created_at, updated_at, deleted_at | standard sync cols | |

**`food_log_photos_table.dart`** - Photo metadata (files stay local on device)

| Column | Type | Notes |
|--------|------|-------|
| id | UUID PK | |
| user_id | text | |
| food_log_meal_id | text? FK | |
| food_log_entry_id | text? FK | |
| local_file_path | text | Absolute device path |
| file_name | text | |
| file_size_bytes | int? | |
| captured_at | dateTime | |
| ai_processing_status | text | pending, processing, completed, failed |
| ai_result_json | text? | Cached AI parse result |
| needs_upload, created_at, deleted_at | standard sync cols | |

**`community_foods_table.dart`** - AI-verified foods that grow the DB organically

| Column | Type | Notes |
|--------|------|-------|
| id | UUID PK | |
| name, display_name, display_name_plural, description | text | |
| serving_amount, serving_unit, serving_description | serving info | |
| calories_per_serving | int? | |
| carbs_per_serving | real? | |
| protein_per_serving | real? | |
| fat_per_serving | real? | |
| sodium_mg | int? | |
| fluid_ml_per_serving | real? | |
| verification_status | text | community_sourced, ai_verified, admin_verified |
| ai_source_model | text? | e.g. "gpt-4o" |
| usage_count | int (default 1) | Times this food has been logged |
| created_by_user_id | text? | Who first logged it |
| original_input | text? | |
| needs_upload, created_at, updated_at | standard sync cols | |

**Modified existing files:**
- `lib/shared/database/app_database.dart` - Add 4 tables to `@DriftDatabase`, bump schemaVersion 3 -> 4
- `lib/shared/services/sync/sync_coordinator.dart` - Add `food_log_meals: ['users']` and `community_foods: []` to dependency graph
- Supabase `app_config.current_schema_version` -> 4
- New migration: `supabase/migrations/YYYYMMDDHHMMSS_add_food_logging_tables.sql`

### 2. Feature Module Structure

```
lib/features/food_log/
├── domain/
│   ├── food_log_meal_type.dart       # Enum: breakfast/lunch/dinner/snacks/pre+post workout
│   ├── food_log_meal.dart            # Meal with computed macro totals
│   ├── food_log_entry.dart           # Single food item with source tracking
│   ├── food_log_photo.dart           # Photo metadata model
│   ├── daily_macro_summary.dart      # Aggregated daily macros (totals only Phase 1)
│   ├── ai_parse_result.dart          # OpenAI response models
│   └── timeline_item.dart            # Sealed class: ActivityTimelineItem | MealTimelineItem
├── application/
│   ├── food_log_service.dart         # Orchestrator: logFromText, logFromPhoto, logManual
│   ├── ai_parsing_service.dart       # Calls edge functions for text/photo parsing
│   ├── photo_service.dart            # Camera capture, gallery pick, base64 conversion
│   └── daily_macro_calculator.dart   # Aggregate daily macros from all meals
├── data/
│   ├── food_log_repository.dart      # SyncableRepository, CRUD, offline-first
│   └── community_foods_repository.dart # Search + auto-create from AI results
└── presentation/
    ├── providers/
    │   ├── food_log_controller.dart           # AsyncNotifier, watches selectedDate
    │   ├── daily_macro_controller.dart        # AsyncNotifier, watches food log changes
    │   └── ai_food_parse_controller.dart      # Manages AI parse state
    ├── screens/
    │   ├── add_food_log_screen.dart            # Full-screen entry: AI input, search, manual
    │   └── meal_detail_screen.dart             # View/edit single meal + entries
    └── widgets/
        ├── daily_macro_dashboard.dart          # Macro totals above timeline
        ├── meal_card.dart                      # Meal card in timeline
        ├── food_log_entry_tile.dart            # Single food row with quantity
        ├── ai_text_input_bar.dart              # Natural language input docked at bottom
        ├── ai_photo_button.dart                # Camera/gallery button
        ├── ai_parse_result_widget.dart         # Confirmation dialog for AI results
        ├── food_search_delegate.dart           # Search existing food database
        ├── quantity_adjuster_widget.dart        # Serving size stepper
        ├── meal_type_selector.dart             # Breakfast/lunch/dinner picker
        └── timeline_item_widget.dart           # Renders activity or meal card
```

### 3. Edge Functions (OpenAI)

**`supabase/functions/parse-food-text/index.ts`**
- Input: `{ text: "grilled chicken 6oz with rice", user_id: "..." }`
- Calls OpenAI `gpt-4o-mini` with structured JSON output
- Matches parsed items against `foods` and `community_foods` tables
- Returns: `{ success: true, items: [{ name, quantity, serving_description, nutrition..., matched_food_id?, is_new_food }] }`

**`supabase/functions/parse-food-photo/index.ts`**
- Input: `{ image_base64: "...", user_id: "..." }`
- Calls OpenAI `gpt-4o` Vision API
- Same matching + response format as text parser

**`supabase/functions/_shared/ai/food-matching.ts`**
- Shared logic: search `foods` table (exact), search `community_foods` (fuzzy), flag new foods

**Required**: Add `OPENAI_API_KEY` to Supabase Edge Function secrets.

### 4. Timeline Integration (Key UI Change)

**`lib/features/food_log/domain/timeline_item.dart`** - Sealed union:
```dart
sealed class TimelineItem implements Comparable<TimelineItem> {
  DateTime get sortTime;
}
class ActivityTimelineItem extends TimelineItem { ... }
class MealTimelineItem extends TimelineItem { ... }
```

**Modify `activities_list_screen.dart`**:
1. Watch `foodLogControllerProvider` alongside `activitiesControllerProvider`
2. Merge activities + meals into `List<TimelineItem>`, sort by `sortTime`
3. Render via pattern matching in SliverList builder
4. Add `DailyMacroDashboard` as SliverToBoxAdapter above timeline (totals only in Phase 1)
5. Add `AiTextInputBar` docked at bottom of screen (above tab bar)

**Modify `calendar_day_indicators.dart`**: Add `foodLog` indicator type for calendar dots.

**Add routes to `app_router.dart`**: `/food-log/add`, `/food-log/meal/:mealId`

### 5. Key Patterns to Follow

| Pattern | Existing Example to Copy |
|---------|-------------------------|
| SyncableRepository | `user_foods_repository.dart` |
| AsyncNotifier controller | `activities_controller.dart` |
| Offline-first CRUD | `user_food_crud_service.dart` |
| Edge function calls | `llm_nutrition_plan_service.dart` |
| Drift table definition | `carb_loading_day_meals_table.dart` |
| Timeline card rendering | `activity_card.dart` |
| DAO pattern | `foods_dao.dart` |
| Photo handling | `image_picker` package (add to pubspec.yaml) |
| Daily totals | Show sums only (no progress bars); targets deferred to Phase 2 |

### 6. Architecture Decisions

1. **Denormalized nutrition in entries**: Snapshot at log time prevents retroactive changes from altering history
2. **Three food FK columns** (food_id, user_food_id, community_food_id): Type-safe, proper FKs; AI entries start with none and get community_food_id after confirmation
3. **Separate meals + entries tables**: Follows carb loading pattern; enables meal-level ops (photos, delete all)
4. **Community foods = separate table**: Isolates from admin-curated `foods` table; promotion is a future admin action
5. **Sealed class for timeline**: Dart 3 exhaustive matching ensures all item types handled in UI

---

## Phase 2: Activity Linking + Favorites + Reports (deferred)

- Link food logs to activities (actual vs planned comparison widget)
- Daily macro targets from user profile + progress bars on dashboard
- `food_log_favorites_table.dart` + `meal_templates_table.dart`
- Quick meals, recent meals, star favorites
- Templates from nutrition plan suggestions ("Log your planned pre-run meal?")
- Dietitian report generation (PDF with embedded photos)
- Additional screens: `favorites_screen.dart`, `reports_screen.dart`

---

## Screens for Figma Design

### Screen 1: Activities Tab - Timeline View (Modified)
- Calendar at top (existing)
- **NEW**: Daily macro dashboard (totals strip) below calendar
- **NEW**: Timeline mixing activity cards and meal cards chronologically
- **NEW**: AI text input bar docked at bottom with camera icon
- Existing FAB for creating activities remains unchanged

### Screen 2: AI Text Input & Parse Confirmation
- User types natural language in bottom bar
- Loading spinner while AI parses
- Confirmation sheet slides up showing:
  - Parsed food items (editable list)
  - Each item: name, quantity stepper, serving description, macro preview
  - Meal type selector (auto-suggested from time)
  - Remove/add item buttons
  - "Log Meal" confirm button

### Screen 3: AI Photo Capture & Parse Confirmation
- Camera viewfinder (or gallery picker)
- After capture: photo thumbnail + loading spinner
- Same confirmation sheet as text parse (with photo thumbnail)

### Screen 4: Add Food Log Screen (Full-Screen)
- Meal type selector at top
- Search bar for food database
- Recent/frequent foods section
- Manual entry option
- Barcode scan button
- AI text input alternative

### Screen 5: Meal Detail Screen
- Meal header (type, time, photo)
- List of food entries with nutrition
- Edit/delete individual entries
- Meal total macros
- Add more items button
- Notes field

### Screen 6: Meal Card (Timeline Component)
- Compact card showing:
  - Meal type icon + name + time
  - 2-3 food item names (truncated if more)
  - Calorie total badge
  - Photo thumbnail (if exists)
  - Tap to expand to Meal Detail

### Screen 7: Daily Macro Dashboard (Component)
- Horizontal strip showing:
  - Calories, Carbs, Protein, Fat, Sodium, Hydration totals
  - Phase 2: progress bars against targets

---

## Verification Strategy

### Automated Tests
- Edge function integration tests: text parsing, photo parsing, food matching
- Flutter integration tests: macro calculation accuracy, offline-first CRUD, timeline sorting, sync flow

### Manual Testing Checklist
- [ ] Log food via text AI: "grilled chicken with rice" produces correct parsed items
- [ ] Log food via photo AI: camera capture returns recognized foods
- [ ] Log food from database search: existing foods searchable and addable
- [ ] Daily macro dashboard shows correct totals
- [ ] Timeline shows meals + activities in chronological order
- [ ] Calendar shows food log indicator dots
- [ ] Edit entry quantity recalculates meal + daily totals
- [ ] Delete entry/meal updates dashboard
- [ ] Offline logging works (airplane mode) with needs_upload flag
- [ ] Dirty records sync on next connection
- [ ] Community foods auto-created from new AI-identified foods
- [ ] Photos save locally, metadata persists in database
- [ ] Schema migration triggers delete-and-resync correctly (v3 -> v4)

### Build Validation
- `dart run build_runner build --delete-conflicting-outputs` succeeds
- `flutter analyze` passes
- Existing tests continue to pass
