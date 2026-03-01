# By-Hour Nutrition Feature - Implementation Plan

## Overview
Add a "By Hour" view to during-activity phases (during_run, during_bike, during_swim) that distributes food items into 15-minute time slots within hourly buckets. Users toggle between Summary (flat list) and By Hour (time-slotted) views.

## Design Decisions
| Decision | Choice | Rationale |
|----------|--------|-----------|
| Algorithm location | Client-side Dart | No edge function changes needed, faster iteration |
| Drink handling | Span full hour at :00, "Sip throughout hour" | Research shows drinks should be sipped, not bolused |
| Distribution strategy | Even round-robin | ACSM/ISSN: even distribution outperforms front-loading |
| Partial hours | Reduced slots (30 min = 2 slots) | Show only valid 15-min intervals |
| Min duration for toggle | 60 minutes | ACSM: during-exercise fueling mainly for >60 min events |
| Persistence | Stored in nutrition plan JSON | User drag/drop rearrangements survive app restarts |
| Drag & drop scope | Cross-hour dragging | Most flexible for user customization |
| Add food to hour | Auto-assign to best slot | Algorithm picks emptiest slot, user adjusts via drag |
| Default view | By Hour shown first | Primary feature; user toggles to Summary as needed |

---

## Screenshots Reference
See `/docs/byhour/screenshots/` for Figma designs:
1. **Summary view**: Flat food list with Summary/By Hour toggle
2. **By Hour collapsed**: Hour rows with inline macro summary (cal, carbs, sodium)
3. **By Hour expanded (Hour 1)**: 15-min timeline (:00, :15, :30, :45) with food items
4. **Food expanded**: Nutrition info + Remove button within time slot
5. **Drag & drop**: Ghost effect when dragging food between slots

---

## Data Model

### New Models (`lib/features/nutrition_plan/domain/time_slot_assignment.dart`)

```dart
class TimeSlot {
  final int hourIndex;    // 0-based (0 = Hour 1)
  final int slotIndex;    // 0-3 (:00, :15, :30, :45)
  String get displayLabel => '$hourIndex:${(slotIndex * 15).toString().padLeft(2, '0')}';
  int get absoluteMinutes => hourIndex * 60 + slotIndex * 15;
}

class TimeSlotAssignment {
  final String foodItemId;      // References FoodItemData.id
  final TimeSlot timeSlot;
  final bool isSipThroughout;   // True for drinks spanning the hour
}

class ByHourData {
  final int durationMinutes;
  final List<TimeSlotAssignment> assignments;
  int get totalHours => (durationMinutes / 60).ceil();
  int get lastHourSlotCount { ... }  // 1-4 based on remaining minutes
}
```

### PlanSection Extension
```dart
class PlanSection {
  // ... existing fields ...
  final ByHourData? byHourData;  // NEW - nullable for backward compatibility
  bool get supportsByHour => byHourData != null && byHourData!.durationMinutes >= 60;
}
```

### JSON Storage (inside existing `nutrition_plan_data` column)
```json
{
  "id": "during_run",
  "foodItems": [ ... ],
  "byHourData": {
    "durationMinutes": 180,
    "assignments": [
      { "foodItemId": "abc-123", "timeSlot": { "hourIndex": 0, "slotIndex": 0 }, "isSipThroughout": true },
      { "foodItemId": "def-456", "timeSlot": { "hourIndex": 0, "slotIndex": 1 }, "isSipThroughout": false }
    ]
  }
}
```
No database migration needed - stored in existing JSON column.

---

## Apportionment Algorithm

### Service: `lib/features/nutrition_plan/application/by_hour_apportionment_service.dart`

```
Input: List<FoodItemData> foods, int durationMinutes
Output: ByHourData

1. Calculate totalHours = ceil(durationMinutes / 60)
2. Separate: drinks (isDrink=true) vs solids (isDrink=false)
3. Distribute drinks round-robin across hours:
   - Each drink → :00 slot of assigned hour, isSipThroughout=true
4. Distribute solids round-robin across hours
5. Within each hour, assign solids to slots:
   - Prefer :15, :30, :45 (leave :00 for drinks)
   - Fall back to :00 if other slots used
   - Multiple items can stack on same slot
6. Partial last hour: only generate valid slots (e.g., 30 min → slots 0,1)
```

### Auto-Assign (for "+ ADD TO HOUR X")
```
1. If drink: always assign to :00 of target hour
2. Find first empty preferred slot (:15, :30, :45, then :00)
3. If all occupied: stack on least-populated slot
```

### Research Backing
- ACSM: 30-90g carbs/hour for events >60 min
- ISSN: Even distribution with frequent intervals (every 10-15 min) outperforms infrequent
- No evidence supports front-loading during exercise
- Later hours: shift toward liquids (v2 enhancement)
- 15-min intervals: matches natural feeding patterns, prevents bolus GI distress

---

## Controller Changes

### `lib/features/nutrition_plan/presentation/providers/activity_detail_controller.dart`

New methods:
```dart
Future<void> initializeByHourData(String category)
// Run apportionment when user first sees By Hour view

Future<void> moveFoodToTimeSlot(String foodId, String category, TimeSlot newTimeSlot)
// Drag & drop: update assignment's timeSlot

Future<void> addFoodItemToHour(dynamic food, String category, int targetHourIndex, {double? customAmount})
// Add food to flat list + create TimeSlotAssignment in target hour

Future<void> deleteFoodItemByHour(String foodId, String category)
// Remove from flat list + remove from byHourData assignments
```

Modified methods:
- `_updateSectionFoods()` → Keep byHourData in sync on any food CRUD
- `swapFoodItem()` → Update foodItemId in existing TimeSlotAssignment

---

## Widget Architecture

```
ActivityDetailScreen (existing, modified)
  └─ DuringPhaseSectionWidget (NEW) ← replaces inline during section rendering
      ├─ Section Header ("DURING BIKE" with sport icon)
      ├─ TwoOptionPillSlider (EXISTING) [Summary | By Hour]
      ├─ MacroSummaryRow (EXISTING) — overall section totals
      ├─ [Summary mode]: Existing flat food list with DismissibleFoodItem
      └─ [By Hour mode]: ByHourView (NEW)
          └─ Column of HourBucketWidget (NEW)
              ├─ Collapsed: "Hour 1  350 cal · 75g carbs · 400mg sodium"
              └─ Expanded:
                  ├─ TimeSlotRow (NEW) for :00, :15, :30, :45
                  │   ├─ Time label + dot + timeline line
                  │   └─ DraggableFoodItem (NEW)
                  │       ├─ 6-dot drag handle
                  │       ├─ LongPressDraggable wrapper
                  │       └─ DismissibleFoodItem (EXISTING) → ExpandableFoodItemWidget (EXISTING)
                  └─ "+ ADD TO HOUR X" button
```

### New Widget Files
| File | Purpose |
|------|---------|
| `during_phase_section_widget.dart` | Main container with toggle |
| `by_hour_view.dart` | Column of hour buckets |
| `hour_bucket_widget.dart` | Collapsible hour with macro summary |
| `time_slot_row.dart` | Timeline row with food items |
| `draggable_food_item.dart` | Drag-enabled food item wrapper |

All in: `lib/features/nutrition_plan/presentation/widgets/activity_detail/`

### Existing Widgets Reused
| Widget | File | Usage |
|--------|------|-------|
| `TwoOptionPillSlider` | `lib/shared/widgets/kyle_design/inputs/two_option_pill_slider.dart` | Summary/By Hour toggle |
| `MacroSummaryRow` | `.../widgets/activity_detail/macro_summary_row.dart` | Section + per-hour summaries |
| `DismissibleFoodItem` | `.../widgets/activity_detail/dismissible_food_item.dart` | Swipe delete/swap |
| `ExpandableFoodItemWidget` | `.../widgets/activity_detail/expandable_food_item_widget.dart` | Food display + expand |

---

## Implementation Phases

### Phase 1: Domain Models & Algorithm (Day 1)
- [ ] Create `time_slot_assignment.dart` with TimeSlot, TimeSlotAssignment, ByHourData
- [ ] Add `byHourData` to PlanSection (constructor, copyWith, fromJson, toJson)
- [ ] Create `by_hour_apportionment_service.dart`
- [ ] Unit tests for algorithm and serialization

### Phase 2: Controller Integration (Day 2)
- [ ] Add initializeByHourData, moveFoodToTimeSlot, addFoodItemToHour, deleteFoodItemByHour
- [ ] Modify _updateSectionFoods for byHourData sync
- [ ] Modify swapFoodItem for byHourData sync
- [ ] Run codegen

### Phase 3: Basic By-Hour UI (Days 3-4)
- [ ] Create DuringPhaseSectionWidget with toggle
- [ ] Create ByHourView
- [ ] Create HourBucketWidget (collapsible, per-hour macros)
- [ ] Create TimeSlotRow (timeline visualization)
- [ ] Wire into activity_detail_screen.dart

### Phase 4: Drag & Drop (Days 5-6)
- [ ] Create DraggableFoodItem with drag handle
- [ ] Implement LongPressDraggable + DragTarget
- [ ] Cross-hour dragging
- [ ] Wire "+ ADD TO HOUR X" button
- [ ] "Sip throughout hour" label for drinks

### Phase 5: Brick Integration & Polish (Day 7)
- [ ] Modify brick_nutrition_sections.dart for during segments
- [ ] Edge cases (no duration, duration changes)
- [ ] Persistence verification
- [ ] Analytics events

### Phase 6: Testing (Day 8)
- [ ] Algorithm unit tests
- [ ] Serialization round-trip tests
- [ ] Controller integration tests
- [ ] Manual testing matrix

---

## Files to Create
```
lib/features/nutrition_plan/domain/time_slot_assignment.dart
lib/features/nutrition_plan/application/by_hour_apportionment_service.dart
lib/features/nutrition_plan/presentation/widgets/activity_detail/during_phase_section_widget.dart
lib/features/nutrition_plan/presentation/widgets/activity_detail/by_hour_view.dart
lib/features/nutrition_plan/presentation/widgets/activity_detail/hour_bucket_widget.dart
lib/features/nutrition_plan/presentation/widgets/activity_detail/time_slot_row.dart
lib/features/nutrition_plan/presentation/widgets/activity_detail/draggable_food_item.dart
test/features/nutrition_plan/application/by_hour_apportionment_service_test.dart
test/features/nutrition_plan/domain/time_slot_assignment_test.dart
```

## Files to Modify
```
lib/features/nutrition_plan/domain/nutrition_plan.dart (add byHourData to PlanSection)
lib/features/nutrition_plan/presentation/providers/activity_detail_controller.dart (new methods + sync)
lib/features/nutrition_plan/presentation/screens/activity_detail_screen.dart (use DuringPhaseSectionWidget)
lib/features/nutrition_plan/presentation/widgets/activity_detail/brick_nutrition_sections.dart (by-hour for during segments)
```

---

## Testing Matrix
| Scenario | Expected |
|----------|----------|
| Activity < 60 min | No toggle, flat list only |
| Activity = 60 min | 1 hour, 4 slots |
| Activity = 90 min | 2 hours: H1 (4 slots), H2 (2 slots) |
| Activity = 180 min | 3 hours, 4 slots each |
| Brick during-bike 2h | Toggle on during-bike section |
| Close/reopen app | Time slots persist |
| Add in summary view | Appears in best slot in by-hour |
| Delete in by-hour | Removed from both views |
| Drag H1→H3 | Assignment updates, macros recalculate |
| All drinks, no solids | All at :00 with sip labels |
| 12-hour ultra | 12 hours, even distribution |
