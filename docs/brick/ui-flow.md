# Brick Workout UI Flow

## Overview

This document details all UI components, screens, and user flows for the brick workout feature.

## 1. Activities List Screen

### Create Brick Button

**Visibility Condition:**
- Appears when 2+ activities of **different** sport types exist on the same calendar day
- Does NOT appear for same-sport activities (e.g., two runs)

**Design Specs:**
```
Location: Next to "Today's Activities" header
Style: Orange outline button with chain link icon
Text: "Create Brick"
Width: Auto-fit content
```

**Behavior:**
```
Tap "Create Brick"
    ↓
Enter Selection Mode
    ↓
Show checkboxes on all eligible activities
    ↓
Show "Cancel" and "Confirm (0)" buttons in header
```

### Selection Mode

**Header During Selection:**
```
┌─────────────────────────────────────────────┐
│ Today's Activities  [Cancel] [Confirm (n)]  │
└─────────────────────────────────────────────┘
```

**Activity Cards During Selection:**
```
┌─────────────────────────────────────────────┐
│ ○  🏃  12.0 MI RUN                          │
│      12.0 mi · 9:00/mi                      │
└─────────────────────────────────────────────┘

↓ After selection ↓

┌─────────────────────────────────────────────┐
│ ①  🏃  12.0 MI RUN                     ✓    │
│      12.0 mi · 9:00/mi                      │
└─────────────────────────────────────────────┘
```

**Selection Rules:**
- Minimum: 2 activities
- Maximum: 3 activities
- Must be different sports
- Order number appears when selected (1, 2, 3)
- Order = selection order (user defines sequence)

**Confirm Button States:**
```
"Confirm (0)" - Disabled, gray
"Confirm (1)" - Disabled, gray (need 2+ selections)
"Confirm (2)" - Enabled, orange highlight
"Confirm (3)" - Enabled, orange highlight
```

### Brick Group Display

After brick creation, activities display as a grouped card:

```
┌─────────────────────────────────────────────┐
│ 🔗 BRICK                [Ungroup] [View     │
│    WORKOUT                        Combined] │
│                                             │
│ Consecutive activities share nutrition      │
│                                             │
│ ┌─────────────────────────────────────────┐ │
│ │ 🏊 2000 M SWIM                     [X]  │ │
│ │    2000m · 2:00/100m                    │ │
│ └─────────────────────────────────────────┘ │
│                                             │
│ ┌─────────────────────────────────────────┐ │
│ │ 🏃 12.0 MI RUN                     [X]  │ │
│ │    12.0 mi · 9:00/mi                    │ │
│ └─────────────────────────────────────────┘ │
└─────────────────────────────────────────────┘
```

**Design Specs:**

| Element | Style |
|---------|-------|
| Header background | Dark purple/navy (Blackberry) |
| "BRICK WORKOUT" text | Orange (Electrolyte), Compadre font 14px |
| Chain link icon | Orange, 24px |
| Buttons | Orange outline, 12px text |
| Subtitle | Gray text, Apercu 12px |
| Nested cards | Slightly lighter background |
| X buttons | Orange outline circle |

### Tap Behavior

**Brick Without Nutrition Plan:**
```
Tap anywhere on brick group
    ↓
Navigate to New Activity Screen
    ↓
Auto-select Brick Tab (4th)
    ↓
Pre-populate with brick segment data
```

**Brick With Nutrition Plan:**
```
Tap anywhere on brick group
    ↓
Navigate to Activity Details Screen
    ↓
Show combined nutrition plan
```

### Calendar Indicators

**Multi-Sport Dots:**
- Show one dot per sport in the brick
- Colors match sport colors (blue for swim, orange for bike, green for run)
- Dots appear in segment order

```
       4
       🔵🟠   (swim/bike brick on the 4th)
```

## 2. New Activity Screen (Brick Tab)

### Sport Selector (4th Tab)

**Design:**
```
┌──────────────────────────────────────────────────┐
│   🏃      🚴      🏊      👥🏊🏃                   │
│   RUN    BIKE    SWIM    BRICK                  │
└──────────────────────────────────────────────────┘
```

**Brick Icon:**
- Combined silhouettes: overlapping swimmer + cyclist + runner miniatures
- Size: 40x40px
- Label: "BRICK" in Apercu 10px

### Brick Tab Content

When Brick tab is selected:

```
┌──────────────────────────────────────────────────┐
│ Select sports for your brick:                    │
│                                                  │
│ ☑ Swimming                                       │
│ ☐ Cycling                                        │
│ ☑ Running                                        │
│                                                  │
│ Drag to reorder:                                 │
│ ┌────────────────────────────────────────────┐   │
│ │ ≡ 1. Swimming                          ▼   │   │
│ └────────────────────────────────────────────┘   │
│ ┌────────────────────────────────────────────┐   │
│ │ ≡ 2. Running                           ▼   │   │
│ └────────────────────────────────────────────┘   │
└──────────────────────────────────────────────────┘
```

**Checkbox Rules:**
- Minimum 2 checked at all times
- Attempting to uncheck when only 2 selected shows validation message
- Checking/unchecking dynamically shows/hides segment sections
- Order of segments shown matches drag order, not checkbox order

### Segment Sections

Each segment is an expandable accordion with sport-specific inputs:

**Swimming Segment:**
```
┌──────────────────────────────────────────────────┐
│ ▼ Swimming Segment                               │
│                                                  │
│ Distance           [2000      ] meters           │
│ Duration           [40        ] minutes          │
│ Pace               [2:00      ] /100m            │
│ Pool or Open Water [Pool        ▼]               │
│ Water Temperature  [24        ] °C               │
│ Intensity          [Moderate    ▼]               │
└──────────────────────────────────────────────────┘
```

**Cycling Segment:**
```
┌──────────────────────────────────────────────────┐
│ ▼ Cycling Segment                                │
│                                                  │
│ Distance           [25.0      ] miles            │
│ Duration           [75        ] minutes          │
│ Speed              [20.0      ] mph              │
│ Terrain            [Rolling     ▼]               │
│ Indoor/Outdoor     [Outdoor     ▼]               │
│ Elevation Gain     [500       ] ft               │
│ Intensity          [Moderate    ▼]               │
└──────────────────────────────────────────────────┘
```

**Running Segment:**
```
┌──────────────────────────────────────────────────┐
│ ▼ Running Segment                                │
│                                                  │
│ Distance           [6.2       ] miles            │
│ Duration           [55        ] minutes          │
│ Pace               [8:52      ] /mile            │
│ Intensity          [Moderate    ▼]               │
└──────────────────────────────────────────────────┘
```

### Drag to Reorder

**Drag Handle:**
- Left side of each segment card
- Three horizontal lines (≡) icon
- Touch target: 44x44px

**Drag Behavior:**
- Long press to initiate drag
- Card lifts with shadow
- Other cards animate to make space
- Drop updates order numbers
- Segment order stored in brick_metadata

### Generate Macros Button

**Location:** Bottom of screen (same as single-sport screens)

**Validation Before Generating:**
1. At least 2 sports selected
2. All required fields filled for each segment
3. Durations > 0

**Behavior:**
```
Tap "Generate Macros"
    ↓
Show loading indicator
    ↓
Call generate-macros edge function with brick data
    ↓
Navigate to Adjust Macros Screen
```

## 3. Adjust Macros Screen (Brick Mode)

### Header

```
┌──────────────────────────────────────────────────┐
│ ← Adjust Your Macros                             │
│                                                  │
│ 🏊 | 🏃  SWIM/RUN BRICK                          │
│     2000m swim + 6.2mi run                       │
│     95 min total · Moderate                      │
└──────────────────────────────────────────────────┘
```

### Combined Totals View

```
┌──────────────────────────────────────────────────┐
│ TOTAL MACRO TARGETS                         [?]  │
│                                                  │
│ 🥖 Carbohydrates    142g                    [✏️] │
│ 🥩 Protein          35g                     [✏️] │
│ 🧈 Fat              15g                     [✏️] │
│ 🧂 Sodium           1200mg                  [✏️] │
│ 💧 Hydration        1500ml                  [✏️] │
│                                                  │
│ ▼ View Phase Breakdown                           │
└──────────────────────────────────────────────────┘
```

### Expandable Phase Breakdown

When expanded:

```
┌──────────────────────────────────────────────────┐
│ ▲ Phase Breakdown                                │
│                                                  │
│ BEFORE                                           │
│   Carbs: 45g | Protein: 10g | Sodium: 200mg     │
│                                                  │
│ DURING SWIM                                      │
│   Carbs: 0g (no eating during swim)             │
│                                                  │
│ T1 TRANSITION                                    │
│   Carbs: 20g | Sodium: 150mg | Water: 200ml     │
│                                                  │
│ DURING RUN                                       │
│   Carbs: 35g | Sodium: 400mg | Water: 500ml     │
│                                                  │
│ AFTER                                            │
│   Carbs: 42g | Protein: 25g | Sodium: 450mg     │
└──────────────────────────────────────────────────┘
```

### Edit Macros Dialog

Same as single-sport mode, but allows editing per-phase or total values.

## 4. Activity Details Screen (Brick Mode)

### Header Design

**Side-by-Side Sport Icons:**
```
┌──────────────────────────────────────────────────┐
│ ←                                           ⋮    │
│                                                  │
│        🏊          |          🏃                 │
│                                                  │
│         SWIM/RUN BRICK                           │
│    2000m swim + 6.2mi run                        │
│                                                  │
│    Saturday, January 19, 2026                    │
│    8:00 AM · 95 minutes                          │
└──────────────────────────────────────────────────┘
```

**Design Specs:**
- Icons: 48px each
- Divider: Vertical line, 1px, gray
- Title: Compadre 20px, white
- Subtitle: Apercu 14px, gray
- Background: Geometric pattern with sport colors blended

### Nutrition Sections

**Section Order:**
1. Before
2. During Swim (if swimming in brick)
3. T1 Transition (if applicable)
4. During Bike (if cycling in brick)
5. T2 Transition (if applicable)
6. During Run (if running in brick)
7. After

**Section Header Design:**
```
┌──────────────────────────────────────────────────┐
│ 🏊 DURING SWIM                                   │
│                                                  │
│ No foods recommended - mouth rinse only          │
└──────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────┐
│ 🔄 T1 TRANSITION                                 │
│    Quick fueling between swim and run            │
│                                                  │
│ ┌────────────────────────────────────────────┐   │
│ │ 🍌 1 Energy Gel                            │   │
│ │    Carbs: 25g | Sodium: 50mg               │   │
│ └────────────────────────────────────────────┘   │
│                                                  │
│ ┌────────────────────────────────────────────┐   │
│ │ 💧 8oz Sports Drink                        │   │
│ │    Carbs: 14g | Sodium: 100mg | Water: 240ml│   │
│ └────────────────────────────────────────────┘   │
└──────────────────────────────────────────────────┘
```

**Transition Section Icons:**
- T1: Rotating arrows icon 🔄
- T2: Rotating arrows icon 🔄

### Complete Workout

**Button:** "Mark Complete" at bottom

**Behavior:**
```
Tap "Mark Complete"
    ↓
Show completion dialog (same as single-sport)
    ↓
Mark entire brick as completed
    ↓
Update status to 'completed'
```

## 5. Widget Component Specs

### BrickGroupCard Widget

```dart
class BrickGroupCard extends StatelessWidget {
  final Activity brick;
  final List<BrickSegment> segments;
  final VoidCallback onUngroup;
  final VoidCallback onViewCombined;
  final Function(int index) onRemoveSegment;
}
```

### BrickSegmentCard Widget

```dart
class BrickSegmentCard extends StatelessWidget {
  final BrickSegment segment;
  final int order;
  final VoidCallback? onRemove;
  final bool showRemoveButton;
}
```

### BrickSportSelector Widget

```dart
class BrickSportSelector extends StatelessWidget {
  final Set<String> selectedSports;
  final List<String> orderedSports;
  final Function(String sport, bool selected) onToggle;
  final Function(int oldIndex, int newIndex) onReorder;
}
```

### BrickSegmentInput Widget

```dart
class BrickSegmentInput extends StatelessWidget {
  final String sport;
  final BrickSegment? initialData;
  final Function(BrickSegment) onChanged;
  final bool expanded;
  final VoidCallback onToggleExpanded;
}
```

## 6. Navigation Routes

### New Routes

```dart
// Add to app router
GoRoute(
  path: '/brick/:brickId',
  builder: (context, state) => BrickDetailScreen(
    brickId: state.pathParameters['brickId']!,
  ),
),

GoRoute(
  path: '/brick/new',
  builder: (context, state) => NewActivityScreen(
    initialTab: SportTab.brick,
    brickSegments: state.extra as List<BrickSegment>?,
  ),
),
```

### Navigation Methods

```dart
// Navigate to brick creation from existing activities
void navigateToBrickCreation(List<Activity> activities) {
  final segments = activities.map((a) => a.toBrickSegment()).toList();
  context.push('/brick/new', extra: segments);
}

// Navigate to brick detail/edit
void navigateToBrick(Activity brick) {
  if (brick.nutritionPlanData != null) {
    context.push('/brick/${brick.id}');
  } else {
    context.push('/brick/new', extra: brick.brickSegments);
  }
}
```

## 7. Animations

### Selection Mode Entry
- Checkboxes fade in from left (200ms)
- Activity cards slide right slightly to make room (150ms)
- Header buttons fade in from top (200ms)

### Brick Group Creation
- Selected cards animate together (300ms)
- Group border draws around them (200ms)
- Header fades in (200ms)

### Segment Reorder
- Card lifts with elevation shadow
- Other cards slide smoothly (200ms)
- Drop animation (150ms)

### Ungroup
- Group border fades out (200ms)
- Cards separate and slide to standalone positions (300ms)
- X buttons fade out (200ms)

## 8. Error States

### Cannot Create Brick
```
┌──────────────────────────────────────────────────┐
│ ⚠️ Cannot create brick                           │
│                                                  │
│ You need at least 2 activities of different      │
│ sports to create a brick workout.                │
│                                                  │
│                                      [OK]        │
└──────────────────────────────────────────────────┘
```

### Minimum Sports Required
```
┌──────────────────────────────────────────────────┐
│ ⚠️ Minimum 2 sports required                     │
│                                                  │
│ A brick workout must include at least 2          │
│ different sports.                                │
│                                                  │
│                                      [OK]        │
└──────────────────────────────────────────────────┘
```

### Remove Last Segment Warning
```
┌──────────────────────────────────────────────────┐
│ ⚠️ Ungroup brick?                                │
│                                                  │
│ Removing this activity would leave only 1 sport. │
│ Would you like to ungroup this brick?            │
│                                                  │
│              [Cancel]    [Ungroup]               │
└──────────────────────────────────────────────────┘
```

## 9. Accessibility

### Screen Reader Labels
- "Create brick workout button"
- "Select activities for brick. Currently X selected."
- "Brick workout containing swim and run"
- "Reorder swim segment. Currently position 1 of 2."
- "Remove swim from brick"

### Touch Targets
- All interactive elements: minimum 44x44px
- Checkboxes: 48x48px touch area
- Drag handles: 44x44px

### Color Contrast
- All text meets WCAG 2.1 AA standards
- Selection states have both color AND shape changes
- Numbers on selected items are high contrast (white on orange)
