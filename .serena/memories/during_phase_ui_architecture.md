# During-Phase UI Architecture & Data Flow

## Overview
The during-activity nutrition section uses a **dual-view system**:
- **Summary view**: Flat list of all food items (like before/after sections)
- **By Hour view**: Time-slotted visualization with 15-minute granularity (for activities ≥60 min)

## Architecture Layers

### 1. Widget Hierarchy
```
ActivityDetailScreen
├── DuringPhaseSectionWidget (ConsumerStatefulWidget)
│   └── _buildByHourContent() or _buildSummaryContent()
│       ├── ByHourView (StatelessWidget)
│       │   └── List.generate(totalHours)
│       │       └── HourBucketWidget (StatefulWidget per hour)
│       │           ├── Hour header (collapsible)
│       │           ├── _buildSipThroughoutSection() [optional]
│       │           ├── _buildTimeSlotTimeline()
│       │           │   └── TimeSlotRow (per 15-min slot)
│       │           │       ├── Time label (0:00, 0:15, etc.)
│       │           │       ├── Dot + vertical line
│       │           │       └── _buildDraggableFoodItem()
│       │           │           └── LongPressDraggable<TimeSlotAssignment>
│       │           │               └── _TimeSlotFoodItem
│       │           │                   └── DismissibleFoodItem
│       │           └── ADD TO HOUR X button
│       └── Summary view
│           └── DismissibleFoodItem × N
```

### 2. Key Data Models

#### TimeSlot
- **hourIndex**: 0-based hour (0 = Hour 1, 1 = Hour 2)
- **slotIndex**: 0-3 within hour (0 = :00, 1 = :15, 2 = :30, 3 = :45)
- **displayLabel**: e.g., "0:00", "1:30", "2:45"
- **absoluteMinutes**: Total minutes from activity start

#### TimeSlotAssignment
- **foodItemId**: Reference to FoodItemData.id
- **timeSlot**: TimeSlot object (hour + slot)
- **isSipThroughout**: Boolean (for drinks across full hour)
- **adjustedQuantity**: Optional scaled quantity for this hour's portion
- **timingCategory**: Enum (sipThroughout, quickConsume, slowConsume, electrolyte)

#### ByHourData
- **durationMinutes**: Total activity duration
- **assignments**: List<TimeSlotAssignment>
- **totalHours**: Calculated (ceil of duration/60), min 1
- **totalFullHours**: Calculated (floor of duration/60)
- **slotCountForHour(hourIndex)**: Returns 4 for full hours, 1-3 for partial final hour
- **assignmentsForHour(hourIndex)**: Filters assignments to specific hour
- **assignmentsForSlot(TimeSlot)**: Filters assignments to specific slot

#### PlanSection
- **id**: "before_run", "during_run", "after_run", "during_cycling", "during_swim"
- **title**: Display title with sport awareness (e.g., "During Run")
- **subtitle**: Optional timing context (e.g., "Every 45-60 minutes")
- **foodItems**: List<FoodItemData> (flat list for summary view)
- **byHourData**: Optional ByHourData (initialized on first "By Hour" toggle)
- **carbsTarget, proteinTarget, fatTarget, sodiumTarget, fluidsTarget**: Phase-specific targets

#### TimingCategory Enum
```dart
enum TimingCategory {
  sipThroughout,    // Drinks: sipped throughout hour
  quickConsume,     // Gels, chews: placed after quiet zone
  slowConsume,      // Bars, real food: after quiet zone
  electrolyte       // Supplements: discrete events only
}
```

Derived from template_foods DB via `TimingCategory.fromFoodProperties()`:
- Priority: supplements → liquids → electrolytes → gels/chews → everything else

## Visual Layout Explained

### Hour Bucket (Collapsed)
```
Hour 1  350 cal · 75g carbs · 400mg sodium ▶
```
- Left: "Hour 1" label
- Center: Inline macro summary (actual values only)
- Right: Chevron icon

### Hour Bucket (Expanded)
```
Hour 1  350 cal · 75g carbs · 400mg sodium ▼
─────────────────────────────────────────────
  ┌─ Sip Throughout
  │  [Food item - Dismissible]
  │  [Another drink - Dismissible]
  └─
  0:00 ● [Food item - Draggable] ← Solid food
       │  Sip throughout hour
       │
  0:15 ●
       │
  0:30 ● [Gel item - Draggable]
       │
  0:45 ● [Bar item - Draggable]
         (end of vertical line here if last slot)
  
  [ADD TO HOUR 1 button]
```

### Sip Throughout Section (in hour bucket)
- **Background**: Section color at 0.07 opacity (very light)
- **Border**: 0.22 opacity, sm border radius
- **Header**: "Sip Throughout" label + "Not tied to a specific minute mark." subtitle
- **Items**: DismissibleFoodItem widgets stacked
- **When shown**: Only if assignments with isSipThroughout or timingCategory == sipThroughout exist

### Time Slot Row
- **Time label**: 44px wide, "0:00", "0:15", etc. (bold if has items)
- **Dot + line**: 20px wide
  - 8×8 circle (filled if has items, faded if empty)
  - Vertical line below dot (faded, gray)
  - Line stops before last slot in hour
- **Food items**: Expanded region with draggable items
  - Drag handle (6-dot icon) on left
  - DismissibleFoodItem on right
  - For drinks: "Sip throughout hour" subtitle below item

### Food Item Adjustments
When **adjustedQuantity** is set on TimeSlotAssignment:
1. Quantity string is scaled: "3 gels" becomes "1 gel"
2. Nutritional values are scaled by ratio: (adjustedQty / originalQty)
3. Example: 3 bars (300 cal total) split across 3 hours = 1 bar (100 cal) per hour

## View Toggle System

### DuringPhaseSectionWidget
- **_showByHour** local state: boolean
- **_canShowByHour**: durationMinutes >= 60
- **TwoOptionPillSlider widget**: Shows when _canShowByHour is true
  - Left: "Summary" (white/orange when selected)
  - Right: "By Hour" (white/orange when selected)

### Initialization
- **initState()**: If durationMinutes >= 60, sets _showByHour = true
- **onInitializeByHour callback**: Triggered on first toggle (or auto at init) if byHourData is null
  - Called from screen: `controller.initializeByHourData(category, durationMinutes)`

## Timing Category Labels & Visual Mapping

### Summary View
No explicit labels shown - foods appear in list order.

### By Hour View
- **Sip Throughout**: Grouped in dedicated container at top of hour with "Sip Throughout" header
- **Time-slotted items**: Appear on timeline by their slotIndex
  - Displayed order: sipThroughout items first (if hour has any), then time slots in order
  - No explicit category labels shown in UI (only "Sip throughout hour" subtitle for drinks)

### Category-to-Display Logic (inferred from code)
- **sipThroughout** (drinks):
  - `isSipThroughout = true` on assignment
  - Shows in dedicated "Sip Throughout" section
  - Subtitle: "Sip throughout hour"
  - Not tied to specific time slot

- **quickConsume** (gels, chews):
  - Placed in time slot rows normally
  - No special visual distinction currently

- **slowConsume** (bars, real food):
  - Placed in time slot rows normally
  - No special visual distinction currently

- **electrolyte** (supplements):
  - Placed in time slot rows normally
  - No special visual distinction currently

## Drag and Drop (By Hour View)
- **LongPressDraggable<TimeSlotAssignment>** on each food item
  - Long press delay: 300ms
  - Haptic feedback enabled
  - Feedback widget: 60% of screen width, 0.85 opacity
  - Child when dragging: 0.3 opacity

- **DragTarget<TimeSlotAssignment>** on each TimeSlotRow
  - Highlights with section color at 0.08 opacity when drop target is active
  - onAcceptWithDetails: calls `onMoveFoodToTimeSlot(foodId, category, sourceSlot, newSlot)`

## Macro Summary Display

### Row Layout (always visible)
Shows actual/target values in format: `actual/target unit LABEL`

### Content varies by phase:
- **Before section**: Carbs | Fluids | Sodium
- **During section**: Carbs | Fluids | Sodium
- **After section**: Carbs | Protein | Sodium

### Colors
- **Actual value**: Dynamic color from `ActivityDetailHelpers.getMacroDeviationColor()`
  - Green/default if close to target
  - Yellow/orange if off by 10-25%
  - Red if off by >25%
- **Target value & unit**: Default onSurface color
- **Slash separator**: onSurface color

## State Management Flow

### Adding Food to Hour
1. User taps "ADD TO HOUR X" button
2. Calls `onAddFoodToHour(category, hourIndex)`
3. Screen sets `pendingAddFoodHourIndex` on controller
4. Screen navigates to swap-food screen
5. After swap, food is inserted with hour+slot assignment

### Moving Food Between Slots
1. User drags food item from one slot
2. TimeSlotRow (destination) accepts drag
3. Calls `onMoveFoodToTimeSlot(foodId, category, sourceSlot, newSlot)`
4. Controller updates assignment in byHourData

### Deleting Food
1. User swipes left (summary) or swipes in TimeSlotRow
2. Calls `onDeleteFood(foodId, category)`
3. Controller removes from foodItems and byHourData assignments

### Updating Quantity
1. User taps quantity on DismissibleFoodItem
2. Calls `onUpdateQuantity(foodId, category, newQuantity)`
3. For by-hour view, adjustedQuantity is recalculated

## Key Code Locations
- **Activity detail screen**: `/lib/features/nutrition_plan/presentation/screens/activity_detail_screen.dart`
- **During phase widget**: `/lib/features/nutrition_plan/presentation/widgets/activity_detail/during_phase_section_widget.dart`
- **By hour view**: `/lib/features/nutrition_plan/presentation/widgets/activity_detail/by_hour_view.dart`
- **Hour bucket**: `/lib/features/nutrition_plan/presentation/widgets/activity_detail/hour_bucket_widget.dart`
- **Time slot row**: `/lib/features/nutrition_plan/presentation/widgets/activity_detail/time_slot_row.dart`
- **Data models**: `/lib/features/nutrition_plan/domain/time_slot_assignment.dart`, `nutrition_plan.dart`
- **Food item**: `/lib/features/nutrition_plan/presentation/widgets/activity_detail/dismissible_food_item.dart`
- **Macro summary**: `/lib/features/nutrition_plan/presentation/widgets/activity_detail/macro_summary_row.dart`
