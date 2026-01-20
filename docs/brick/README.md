# Brick Workout Feature

## Overview

A "brick" workout is a multi-sport training session where athletes combine two or three disciplines back-to-back (e.g., swim→run, bike→run, swim→bike→run). This feature allows Mealvana Endurance users to create combined workouts and receive unified nutrition planning that accounts for the cumulative metabolic demands and transition periods.

## Key Decisions Summary

| Decision Area | Choice |
|---------------|--------|
| Data Model | Soft delete originals, create new brick activity |
| Activity Type | New `brick` enum value with segment JSON |
| Allowed Combos | Swim/Run, Bike/Run, Swim/Bike, Swim/Bike/Run |
| Sport Order | User-defined (any order allowed) |
| Max Segments | 3 (triathlon format) |
| Nutrition Calc | Cumulative (total duration based) |
| Sync Strategy | Single record with embedded segments |

## Allowed Brick Combinations

| Brick Type | Sports | Example Use Case |
|------------|--------|------------------|
| Swim/Run | 2 sports | Aquathlon training |
| Run/Swim | 2 sports | Reverse aquathlon |
| Bike/Run | 2 sports | Classic brick workout |
| Run/Bike | 2 sports | Reverse brick |
| Swim/Bike | 2 sports | First two tri legs |
| Bike/Swim | 2 sports | Reverse order |
| Swim/Bike/Run | 3 sports | Full triathlon |
| Any 3-sport order | 3 sports | User preference |

**Constraints:**
- Minimum 2 segments
- Maximum 3 segments
- Same calendar day only
- Any sport combination allowed (including run/bike/run for duathlon-style training)

## Feature Components

### 1. Activities List Screen
- **Create Brick Button**: Appears when 2+ activities of different sports exist on same day
- **Selection Mode**: Checkboxes with numbered order indicators
- **Grouped Display**: Brick header card with nested activity cards
- **Actions**: Ungroup, View Combined, Remove individual activities

### 2. New Activity Screen (Brick Tab)
- **4th Tab Icon**: Combined sport silhouettes icon
- **Sport Checkboxes**: Select which sports to include (min 2)
- **Segment Sections**: Expandable sections for each sport's details
- **Drag to Reorder**: Change segment order after creation
- **Per-Segment Intensity**: Each segment has its own intensity level
- **Auto-populate**: Pre-fill from Training Peaks/Final Surge data

### 3. Activity Details Screen
- **Header**: Side-by-side sport icons
- **Nutrition Phases**: Before → During-Sport1 → T1 → During-Sport2 → [T2 → During-Sport3] → After
- **Transition Foods**: Dedicated recommendations for T1 and T2
- **Completion**: Mark entire brick complete at once

### 4. Adjust Macros Screen
- **Combined Totals**: Overall carbs, protein, fat, sodium, hydration
- **Expandable Breakdown**: Per-phase macro targets
- **Edit Capability**: Modify per-phase targets

## Nutrition Phases

For a swim/bike/run brick, the nutrition plan includes:

| Phase | Description | Food Type |
|-------|-------------|-----------|
| Before | Pre-workout nutrition | Standard before foods |
| During Swim | Minimal (can't eat while swimming) | Usually empty or mouth rinse |
| T1 (Transition 1) | Swim-to-bike transition | Quick carbs, gels, sports drink |
| During Bike | Main fueling opportunity | Bike-suitable foods (bars, gels, drinks) |
| T2 (Transition 2) | Bike-to-run transition | Pre-load before reduced gastric tolerance |
| During Run | Reduced tolerance | Run-suitable foods (gels, liquids) |
| After | Recovery nutrition | Standard recovery foods |

## Data Model

### Activity Record

```json
{
  "id": "uuid",
  "user_id": "uuid",
  "activity_type": "brick",
  "title": "Swim/Run Brick",
  "scheduled_date_time": "2026-01-19T08:00:00Z",
  "status": "planned",
  "brick_metadata": {
    "segment_order": ["swimming", "running"],
    "segments": [
      {
        "sport": "swimming",
        "order": 1,
        "distance_meters": 2000,
        "duration_minutes": 40,
        "pace_per_100m_seconds": 120,
        "intensity": "moderate",
        "pool_or_open_water": "pool"
      },
      {
        "sport": "running",
        "order": 2,
        "distance_miles": 6.2,
        "duration_minutes": 55,
        "pace_minutes_per_mile": 8.5,
        "intensity": "moderate"
      }
    ],
    "original_activity_ids": ["uuid1", "uuid2"],
    "created_from_existing": true
  },
  "nutrition_plan_data": { ... }
}
```

### Archived Original Activities

When creating a brick from existing activities, the originals are soft-deleted:

```json
{
  "id": "uuid1",
  "activity_type": "swimming",
  "status": "archived_for_brick",
  "brick_id": "brick-uuid",
  ...
}
```

## User Flows

### Flow 1: Create Brick from Existing Activities

```
Activities List → "Create Brick" button
    ↓
Selection Mode (checkboxes appear)
    ↓
Select 2-3 activities (numbered order)
    ↓
"Confirm (n)" button
    ↓
Brick created, originals soft-deleted
    ↓
Brick header with "Ungroup" and "View Combined"
```

### Flow 2: Create Brick from Scratch

```
Activities List → "+" FAB → Brick Tab (4th icon)
    ↓
Select sports via checkboxes
    ↓
Enter segment details (distance, pace, duration)
    ↓
Generate Macros → Adjust Macros → Create Plan
    ↓
Brick created on calendar
```

### Flow 3: Edit Brick

```
Tap brick (no nutrition plan) → New Activity Screen (Brick Tab)
    ↓
Edit segment details, reorder via drag
    ↓
Generate Macros → Adjust Macros → Create Plan
```

### Flow 4: Ungroup Brick

```
Brick → "Ungroup" button
    ↓
Delete brick activity
    ↓
Restore original activities to standalone status
    ↓
Delete brick's nutrition plan
```

### Flow 5: Remove Activity from Brick

```
Brick → X button on segment
    ↓
If 2+ segments remain: Remove and restore to standalone
    ↓
If only 1 segment would remain: Prompt to ungroup entirely
```

## Documentation Index

| Document | Description |
|----------|-------------|
| [README.md](./README.md) | This overview document |
| [schema-changes.md](./schema-changes.md) | Database schema modifications |
| [ui-flow.md](./ui-flow.md) | Detailed UI/UX specifications |
| [nutrition-algorithm.md](./nutrition-algorithm.md) | Nutrition calculation logic |
| [implementation-roadmap.md](./implementation-roadmap.md) | Phased implementation plan |

## Research Sources

- ACSM Joint Position Statement on Nutrition and Athletic Performance
- ISSN Exercise & Sports Nutrition Review
- Triathlon-specific nutrition research from PMC/PubMed
- Professional triathlon coaching protocols

## Questions for Future Consideration

1. Should we support brick workouts spanning multiple days for ultra events?
2. Should we add swim/bike/run distance presets for common race formats (Olympic, 70.3, Ironman)?
3. Should coaches be able to assign brick workouts to athletes?
4. Should we track brick completion rates and nutrition adherence separately?
