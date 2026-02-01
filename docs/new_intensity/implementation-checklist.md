# Intensity Distribution Widget Implementation Checklist

## Design Reference
![New Intensity Design](new_intensity.png)

## Overview
This document outlines the implementation plan for two new widgets:
1. **Workout Details Widget** - Distance input with "By Duration" / "By Pace" toggle
2. **Intensity Distribution Widget** - Composite bar with three-zone sliders

Both widgets will be shared across all sport types (running, cycling, swimming, brick) with sport-specific adaptations.

---

## Design Decisions (Confirmed)

| Decision | Choice |
|----------|--------|
| Slider adjustment behavior | **Proportional** - other sliders adjust proportionally when one changes |
| Cycling "By Pace" display | **Average Speed** (mph/kph) |
| Swimming pace format | **Pace per 100** (yards/meters) |
| Nutrition calculation impact | **UI only for now** - data captured but not wired to macro calculations |
| Percentage text fields | **Editable** - user can type directly or use sliders |
| Widget reuse | **Shared widgets** with sport parameter |
| Duration/Pace relationship | **Estimate from profile** but allow user override |
| Data storage | **Activity table columns** (intensity_z1_z2_pct, intensity_z3_z4_pct, intensity_z5_pct) |

---

## Component 1: Workout Details Widget

### Current State
- Running tab: Has distance + pace, but NO toggle for "By Duration" / "By Pace"
- Cycling tab: Has distance + speed (no toggle)
- Swimming tab: Has distance + pace per 100m (no toggle)
- Brick tab: Each segment has duration/distance/pace independently

### Target State (from design)
```
┌─────────────────────────────────────────┐
│  WORKOUT DETAILS                        │
│                                         │
│  Distance *                             │
│  ┌────────────────────────────────┐     │
│  │  18.0                     mi   │     │
│  └────────────────────────────────┘     │
│                                         │
│  ┌──────────────┐ ┌──────────────┐      │
│  │ By Duration  │ │   By Pace    │      │
│  └──────────────┘ └──────────────┘      │
│                                         │
│  Estimated Duration                     │
│  ┌────────────────────────────────┐     │
│  │  2:38                          │     │
│  └────────────────────────────────┘     │
└─────────────────────────────────────────┘
```

### Sport-Specific Variations

| Sport | Distance Unit | "By Pace" Label | Pace/Speed Format | Estimation Source |
|-------|---------------|-----------------|-------------------|-------------------|
| Running | miles/km | By Pace | min:sec per mile/km | User profile default pace |
| Cycling | miles/km | By Speed | mph/kph | User profile default speed |
| Swimming | yards/meters | By Pace | min:sec per 100 | User profile default swim pace |
| Brick | (per segment) | (per segment) | (varies by sport) | User profile defaults |

---

## Component 2: Intensity Distribution Widget

### Current State
- Cycling/Swimming: Simple dropdown with Zone 1-5 options
- Running: NO intensity field at all
- Database: Has `intensity_level` and `intensity_target` text columns (not percentage-based)

### Target State (from design)
```
┌─────────────────────────────────────────┐
│  INTENSITY DISTRIBUTION                 │
│                                         │
│  ████████████████████░░░░░░░░░░░░░░░█   │  <- Composite bar (green/yellow/red)
│                                         │
│  ● Conversational (Z1-Z2)    ┌────┐     │
│  ══════════════════════●     │ 70 │ %   │  <- Slider + editable text
│                              └────┘     │
│                                         │
│  ● Tempo (Z3-Z4)             ┌────┐     │
│  ════●                       │ 20 │ %   │
│                              └────┘     │
│                                         │
│  ● All-Out (Z5+)             ┌────┐     │
│  ══●                         │ 10 │ %   │
│                              └────┘     │
└─────────────────────────────────────────┘
```

### Zone Definitions (Sport-Agnostic)

| Zone | Label | Color | Description |
|------|-------|-------|-------------|
| Z1-Z2 | Conversational | Green (#4CAF50) | Easy effort, can hold conversation |
| Z3-Z4 | Tempo | Yellow/Orange (#FFC107) | Moderate-hard effort |
| Z5+ | All-Out | Red (#F44336) | Maximum effort, race pace |

### Slider Behavior - Proportional Adjustment Algorithm

When user changes Zone X from `oldValue` to `newValue`:
```
delta = newValue - oldValue
remainingZones = [zones except X]
totalRemaining = sum of remainingZones values

for each zone in remainingZones:
    proportion = zone.value / totalRemaining
    zone.value -= delta * proportion
    zone.value = clamp(zone.value, 0, 100)

// Normalize to ensure sum = 100
normalize all zones
```

**Edge Cases:**
- If sum != 100 after adjustment, normalize proportionally
- Minimum value for any zone: 0%
- Maximum value for any zone: 100%
- If only one zone has value > 0, that zone cannot be reduced (others locked at 0)

---

## Implementation Tasks

### Phase 1: Database Schema Updates

- [x] **1.1** Add intensity distribution columns to `activities_table.dart`
  ```dart
  IntColumn get intensityZ1Z2Pct => integer().nullable().named('intensity_z1_z2_pct')();
  IntColumn get intensityZ3Z4Pct => integer().nullable().named('intensity_z3_z4_pct')();
  IntColumn get intensityZ5Pct => integer().nullable().named('intensity_z5_pct')();
  ```

- [x] **1.2** Add user default pace/speed columns to `user_profiles.dart`
  ```dart
  RealColumn get defaultRunningPaceMinPerMile => real().nullable().named('default_running_pace_min_per_mile')();
  RealColumn get defaultCyclingSpeedMph => real().nullable().named('default_cycling_speed_mph')();
  IntColumn get defaultSwimmingPacePer100Sec => integer().nullable().named('default_swimming_pace_per_100_sec')();
  ```

- [ ] **1.3** Run `flutter pub run build_runner build` to regenerate Drift code

- [x] **1.4** Update Supabase schema with matching columns (migration SQL)

- [x] **1.5** Schema stays at v3 (intensity columns are part of v3 schema)

### Phase 2: Domain Models

- [x] **2.1** Create `IntensityDistribution` domain model
  ```dart
  // lib/features/nutrition_plan/domain/intensity_distribution.dart
  class IntensityDistribution {
    final int conversationalPct; // Z1-Z2
    final int tempoPct;          // Z3-Z4
    final int allOutPct;         // Z5+

    // Validation, copyWith, JSON serialization
  }
  ```

- [ ] **2.2** Create `WorkoutEstimate` domain model for duration/pace calculations
  ```dart
  class WorkoutEstimate {
    final Duration estimatedDuration;
    final double? estimatedPace; // null if user provided pace directly
    // ...
  }
  ```

### Phase 3: Shared Widgets

- [x] **3.1** Create `IntensityDistributionWidget`
  - Location: `lib/shared/widgets/kyle_design/inputs/intensity_distribution_widget.dart`
  - Props: `IntensityDistribution value`, `ValueChanged<IntensityDistribution> onChanged`, `bool enabled`
  - Contains: CompositeBar + 3 ZoneSliderRows

- [x] **3.2** Create `IntensityCompositeBar` widget
  - Horizontal bar with colored segments proportional to zone percentages
  - Smooth corners, proper segment sizing

- [x] **3.3** Create `IntensityZoneSlider` widget
  - Single row: colored dot + label + slider + editable percentage field
  - Slider uses zone color for track
  - TextField for direct percentage input

- [x] **3.4** Create `WorkoutDetailsWidget`
  - Location: `lib/features/nutrition_plan/presentation/widgets/new_activity/shared/workout_details_widget.dart`
  - Props: `ActivityType sport`, distance/duration/pace values, callbacks
  - Contains: Distance input + toggle + estimated field

- [x] **3.5** Create `DurationPaceToggle` widget
  - Segmented control with "By Duration" / "By Pace" (or "By Speed" for cycling)
  - Sport-aware label changes

### Phase 4: Form State Updates

- [x] **4.1** Update `RunningFormState` to include:
  - `IntensityDistribution intensity`
  - `DurationPaceMode mode` (byDuration / byPace)
  - `Duration? estimatedDuration`

- [x] **4.2** Update `CyclingFormState` similarly

- [x] **4.3** Update `SwimmingFormState` similarly

- [x] **4.4** Update `BrickSegmentInput` to include intensity per segment
  - Add `IntensityDistribution? intensity` field
  - Default to 70/20/10 when segment is created

### Phase 5: Controller Updates

- [x] **5.1** Add intensity methods to `RunningInputController`
  - `updateIntensityDistribution(IntensityDistribution)`
  - `updateDurationPaceMode(DurationPaceMode)`
  - `_estimateDuration()` - calculate from distance + user default pace

- [x] **5.2** Add similar methods to `CyclingInputController`
  - Uses speed instead of pace

- [x] **5.3** Add similar methods to `SwimmingInputController`
  - Uses pace per 100

- [x] **5.4** Update `BrickInputController` if needed

### Phase 6: Tab Content Integration

- [x] **6.1** Update `RunningTabContent`
  - Replace current distance/pace inputs with `WorkoutDetailsWidget`
  - Add `IntensityDistributionWidget` after workout details

- [x] **6.2** Update `CyclingTabContent`
  - Replace current distance/speed + intensity dropdown
  - Use shared widgets

- [x] **6.3** Update `SwimmingTabContent`
  - Replace current distance/pace + intensity dropdown
  - Use shared widgets

- [x] **6.4** Update `BrickTabContent`
  - Add intensity distribution to each segment card
  - Intensity section collapsed by default within each segment
  - Each sport segment (swim, bike, run) has independent intensity values

### Phase 7: Activity Repository Updates

- [x] **7.1** Update `ActivitiesRepository` to save/load intensity distribution
- [x] **7.2** Update Activity domain model to include intensity distribution
- [ ] **7.3** Update activity edit flow to load/save intensity

### Phase 8: Testing

- [x] **8.1** Unit tests for `IntensityDistribution` model
  - Proportional adjustment algorithm
  - Edge cases (0%, 100%, normalization)
  - **Result**: 31 tests passing

- [x] **8.2** Widget tests for `IntensityDistributionWidget`
  - Slider interactions
  - Text field editing
  - Composite bar rendering
  - **Result**: 14 tests passing

- [x] **8.3** Integration tests for form state
  - Verify intensity persists through save/load cycle
  - **Result**: 96 total tests passing (all intensity feature tests)

### Phase 9: Polish & Edge Cases

- [x] **9.1** Handle keyboard dismissal properly
- [x] **9.2** Add haptic feedback on slider changes
- [x] **9.3** Ensure accessibility (slider labels, semantic actions)
- [ ] **9.4** Test on various screen sizes
- [x] **9.5** Add loading/disabled states

---

## File Structure (New Files)

```
lib/
├── features/nutrition_plan/
│   ├── domain/
│   │   └── intensity_distribution.dart          # NEW
│   └── presentation/
│       └── widgets/
│           └── new_activity/
│               └── shared/
│                   ├── workout_details_widget.dart      # NEW
│                   └── intensity_distribution_widget.dart # NEW
└── shared/
    └── widgets/
        └── kyle_design/
            └── inputs/
                ├── intensity_composite_bar.dart    # NEW
                ├── intensity_zone_slider.dart      # NEW
                └── duration_pace_toggle.dart       # NEW
```

---

## Resolved Questions

| Question | Decision |
|----------|----------|
| Brick intensity | **Per-segment** - each sport segment has its own intensity distribution |
| Default values | **70/20/10** - 70% Conversational, 20% Tempo, 10% All-Out |
| Persistence timing | **Save on Generate only** - form state is local until user commits |
| Migration | Default to null, show "Not specified" in activity detail |

---

## Dependencies

- None identified (uses existing Kyle Design patterns)

---

## Estimated Effort

| Phase | Tasks | Complexity |
|-------|-------|------------|
| Phase 1 | Database | Low |
| Phase 2 | Domain Models | Low |
| Phase 3 | Shared Widgets | **High** (new slider logic) |
| Phase 4 | Form States | Medium |
| Phase 5 | Controllers | Medium |
| Phase 6 | Tab Integration | Medium |
| Phase 7 | Repository | Low |
| Phase 8 | Testing | Medium |
| Phase 9 | Polish | Low |

---

## References

- Design: `/docs/new_intensity/new_intensity.png`
- Existing intensity dropdown: `lib/features/nutrition_plan/presentation/widgets/new_activity/cycling_tab_content.dart`
- Kyle input components: `lib/shared/widgets/kyle_design/inputs/`
- Activities table: `lib/shared/database/tables/activities_table.dart`
