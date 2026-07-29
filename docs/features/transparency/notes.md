# Nutrition Transparency — Codebase Research Notes

Research conducted 2026-04-01 to inform the implementation plan.

---

## Current "?" Icon Locations

### Before Phase
- **File:** `lib/features/nutrition_plan/presentation/widgets/activity_detail/before_phase_widget.dart` (lines 129–156)
- **Icon:** `Icons.help_outline_rounded` (20px)
- **Trigger:** `PhaseExplanationSheet.show(context, phase: ExplanationPhase.before, ...)`
- **Shown when:** `widget.macroTargets != null`

### During Phase (Single Sport)
- **File:** `lib/features/nutrition_plan/presentation/widgets/activity_detail/during_phase_section_widget.dart` (lines 222–246)
- **Icon:** `Icons.help_outline_rounded` (20px)
- **Trigger:** `PhaseExplanationSheet.show(context, phase: ExplanationPhase.during, ...)`

### During Phase (Brick Segments)
- **File:** `lib/features/nutrition_plan/presentation/widgets/activity_detail/brick_nutrition_sections.dart` (lines 409–428)
- **Icon:** `Icons.help_outline_rounded` (20px)
- **Trigger:** `PhaseExplanationSheet.show(context, phase: _sectionIdToPhase(sectionId), ...)`
- Each segment (during-swim, T1, during-bike, T2, during-run) gets its own "?" button

### Macro Summary Row (Override Info)
- **File:** `lib/features/nutrition_plan/presentation/widgets/activity_detail/macro_summary_row.dart` (lines 306–322)
- **Icon:** `Icons.info_outline_rounded` (14px, smaller)
- **Trigger:** `_showOverrideSheet(context)` — separate override explanation sheet

---

## Current PhaseExplanationSheet

**File:** `lib/features/nutrition_plan/presentation/widgets/activity_detail/phase_explanation_sheet.dart`

- **Type:** `StatefulWidget` (needs to become `ConsumerStatefulWidget` for live updates)
- **Pattern:** `DraggableScrollableSheet` with `initialChildSize: 0.75, minChildSize: 0.4, maxChildSize: 0.95`
- **Static launcher:** `PhaseExplanationSheet.show(context, phase:, macroTargets:, bodyWeightKg:, sportLabel:, useImperial:, foods:)`
- **Content:** Expandable cards per macro, first one expanded by default
- **Service:** `const MacroExplanationService()` — pure Dart, no async

### Card Structure (current)
Each card shows:
- Header: "Carbohydrates: 194g" (actual) or "Carbohydrates: 191g" (target)
- Sub-header: "Target: 191g (range: 167-215g)" when actuals present
- Expanded content: `explanation.formulaText` (plain text) + range rationale in green box

---

## MacroExplanationService

**File:** `lib/features/nutrition_plan/application/macro_explanation_service.dart`

### MacroExplanation Data Class
```dart
class MacroExplanation {
  final String macroName;      // "Carbohydrates", "Fluids", "Sodium"
  final String value;          // "191" (target)
  final String unit;           // "g", "mL", "mg"
  final String? rangeLow;      // "167"
  final String? rangeHigh;     // "215"
  final String formulaText;    // Multi-line explanation string
  final String rangeRationale; // Why the range exists
  final String? actualValue;   // "194" (from foods)
}
```

### ExplanationPhase Enum
```dart
enum ExplanationPhase { before, during, after, transition1, transition2 }
```

### Pre-Workout Carb Formula (lines 146–178)
```
hoursBeforeEst = (pre.carbsG / weightKg).clamp(0.5, 4.0)
Formula: weight × hours_before g/kg
Range: target ±12.5%
```

### During-Workout Carb Formula (lines 234–297)
```
Step 1: Duration band from absClampRangeGPerH [bandLow, bandHigh]
Step 2: Gut training multiplier (implicit — already in stored values)
Step 3: Midpoint = carbRateGPerH
Step 4: Sport ceiling check (running=70, cycling=120, swimming=0)
Step 5: Total = rate × durationH
Range from carbsLowG / carbsHighG
```

### Duration Bands (hardcoded in formulaText)
- <60 min: 0–30 g/hr
- 60–90 min: 30–60 g/hr
- 90–150 min: 45–60 g/hr
- 2.5–4 hr: 60–90 g/hr
- >4 hr: 80–100 g/hr

### Gut Multipliers (current code values)
- Low: 0.7×
- Moderate: 0.8× (NOTE: artifact said 1.0× but user confirmed code is correct)
- High: 1.0× (NOTE: artifact said 1.2× but user confirmed code is correct)

### Sport Ceilings
- Running: 70 g/hr
- Cycling: 120 g/hr
- Swimming: 0 g/hr
- Brick/multi-sport: uses per-segment sport

### Swim Special Case (lines 258–270)
Returns hardcoded "No carb fueling is possible during swimming" explanation.

---

## MacroTargets Domain Object

**File:** `lib/features/nutrition_plan/domain/macro_targets.dart`

### Key Fields for Formula Display

```dart
// DuringRunMacros
during.carbRateGPerH          // Final carb rate after all adjustments
during.carbTotalG             // Total carbs = rate × duration
during.absClampRangeGPerH     // [min, max] — the duration band range
during.carbsLowG / carbsHighG // Display range bounds

// RunMetrics
metrics.durationH             // Duration in hours (e.g. 1.5)
metrics.durationMin           // Duration in minutes (e.g. 90)

// PreRunMacros
preRun.carbsG                 // Target carbs
preRun.carbsLowG / carbsHighG // Range bounds

// Brick Data
brickPhaseTargets?.duringSegments  // List<BrickSegmentMacroTarget>
brickSegments                      // List<BrickSegment> from activity
```

### BrickSegmentMacroTarget
```dart
segmentOrder, sport, durationMinutes,
carbsG, carbsLowG, carbsHighG,
sodiumMg, waterMl, etc.
```

---

## Gut Training Widget

**File:** `lib/shared/widgets/kyle_design/buttons/segmented_control.dart` (lines 123–150)

### Widget: KyleGutTrainingSegmentedControl
```dart
const KyleGutTrainingSegmentedControl({
  required this.selected,    // GutTraining enum
  required this.onChanged,   // ValueChanged<GutTraining>
  this.showValues = false,   // Show "0.7 g/kg/h" etc.
});
```

### GutTraining Enum
**File:** `lib/features/auth/domain/user_preferences.dart`
```dart
enum GutTraining { low, moderate, high }
```

### Display Extension (lines 279–302)
- LOW → "0.7 g/kg/h"
- MODERATE → "0.8 g/kg/h"
- HIGH → "1.0 g/kg/h"

### Save Flow
1. `ref.read(settingsControllerProvider.notifier).saveAllPreferences(gutTrainingLevel: level)`
2. → `_saveProfile()` → `userRepository.updateUserProfile(profile)` → Drift + Supabase sync
3. → `ref.invalidate(currentUserProvider)`

---

## Personal Carb Target Settings

**File:** `lib/features/settings/presentation/screens/nutrition_targets_screen.dart`

### Input Pattern
- `TextFormField` with `TextInputType.numberWithOptions(decimal: true)`
- `FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))`
- Hint: "Auto" (means use algorithm default)
- Sport-specific: separate controllers for run/bike/swim carb rates

### NutritionTargetOverrides Domain
**File:** `lib/features/nutrition_plan/domain/nutrition_target_overrides.dart`
```dart
class NutritionTargetOverrides {
  duringRun: DuringActivityOverrides?
  duringCycling: DuringActivityOverrides?
  duringSwimming: DuringActivityOverrides?
}

class DuringActivityOverrides {
  carbRateGPerH: double?
  sodiumRateMgPerH: double?
  fluidRateMlPerH: double?
}
```

### Save Flow
1. Build `NutritionTargetOverrides` from parsed fields
2. `NutritionTargetGuardrails.clampAll(overrides)` — safety clamp
3. `ref.read(settingsControllerProvider.notifier).saveNutritionTargetOverrides(overrides)`
4. → `userRepository.updateUserProfile(...)` → `ref.invalidate(currentUserProvider)`

### Override Application (nutrition_sections_builder.dart lines 152–159)
```dart
final overrides = settings?.nutritionTargetOverrides;
final duringOv = overrides?.getDuring(activityType);
final duringActive = durationMin >= 90;  // Only apply for >=90 min
```

---

## Settings Provider

**Provider:** `settingsControllerProvider`
**File:** `lib/features/settings/presentation/providers/settings_controller.dart`

### SettingsState Key Fields
```dart
gutTrainingLevel: GutTraining
nutritionTargetOverrides: NutritionTargetOverrides?
weightPounds: double?
unitSystem: UnitSystem
```

### Access Pattern
```dart
final settingsAsync = ref.watch(settingsControllerProvider);
settingsAsync.whenData((state) {
  state.gutTrainingLevel;
  state.nutritionTargetOverrides?.duringRun?.carbRateGPerH;
});
```

---

## Video Player

**File:** `lib/features/education/presentation/screens/video_player_screen.dart`

### Widget
```dart
class VideoPlayerScreen extends ConsumerStatefulWidget {
  const VideoPlayerScreen({
    required this.title,
    required this.videoUrl,
  });
}
```

- Uses `video_player` + `chewie` packages
- Material progress bar with `AppColors.orange`
- Auto-play: false, full screen support

### Education Content Table
```sql
education_content (id, title, description, thumbnail_url, video_url, content_type, 
                   duration_seconds, sort_order, is_published, tags)
```

### Video Mapping
- Pre-workout fueling: id `04cd30a9-4081-46c7-a79d-cbc3a5b85794`, title "Mealvana 101 - 1.1", URL `https://milkman-dev.s3.us-east-2.amazonaws.com/me_videos/me101_1.1.mp4`, 97 seconds
- During-workout fueling: **No video yet** — use placeholder

---

## Brick Macro Service

**File:** `lib/features/nutrition_plan/application/brick_macro_service.dart`

- Calls Supabase edge function with brick-specific payload
- Returns `MacroTargets` with `brickPhaseTargets.duringSegments` for per-segment data
- Override application uses `0.8` multiplier for range (lines 206–220)
- No explicit "brick penalty" field in the domain model — the penalty is baked into the edge function response values

### Note on Brick Penalty
The brick penalty (0.8× for run-after-bike) is calculated server-side in the edge function and already reflected in the returned `carbRateGPerH` and `carbTotalG` values. To show it in the TL;DR formula, we'd need to either:
- Reverse-engineer it from the values (fragile)
- Add it as an explicit field in `BrickSegmentMacroTarget` (cleaner, requires edge function change)
- Hardcode the knowledge that run-after-bike always gets 0.8× (pragmatic for v1)

---

## Offline Macro Calculator

**File:** `lib/features/nutrition_plan/data/offline_macro_calculator.dart`

Confirms gut training multipliers (line 186–190):
```dart
final gutRate = {
  'low': 0.7,
  'moderate': 0.8,
  'high': 1.0,
}[gutTraining] ?? 0.8;
```

---

## Edge Function Data Flow — What's Returned vs What's Needed

### Single Sport (`generate-macros-v4/single-sport.ts`)

The `calculateDuringWorkoutCarbs()` function (line 77-109) computes:
```
baseLow, baseHigh = getDurationCarbBand(durationMin)  // raw band
gutMult = getGutTrainingMultiplier(gutTraining)        // 0.7/0.8/1.0
scaledLow = baseLow * gutMult                          // gut-scaled band
scaledHigh = baseHigh * gutMult
carbRate = (scaledLow + scaledHigh) / 2                // midpoint
sportCeiling = getSportCarbCeiling(activityType)       // 70/120/0
finalRate = min(carbRate, sportCeiling)                 // capped rate
```

Returns: `rate_gph`, `band_low` (=scaledLow), `band_high` (=scaledHigh), `gut_multiplier`, `sport_ceiling`

Edge function response (line 713-734) includes:
- `during_rate_g_per_h` — final rate (after ceiling cap, after override)
- `during_total_g` — rate × duration
- `during_band_low_g_per_h` / `during_band_high_g_per_h` — GUT-SCALED band (NOT raw)
- `during_gut_multiplier` — multiplier value
- `during_sport_ceiling_g_per_h` — ceiling value
- `during_abs_clamp_range_g_per_h` — same as band_low/band_high
- **MISSING**: `during_raw_band_low_g_per_h` / `during_raw_band_high_g_per_h` (baseLow/baseHigh)

Flutter parsing (`macro_generation_service.dart` line 542-584):
- Parses: rate, total, fluids, sodium, mass_norm_rate, abs_clamp_range, ranges
- **DROPS**: `during_gut_multiplier`, `during_sport_ceiling_g_per_h`

### Brick Segments (`generate-macros-v4/brick-workout.ts`)

Per-segment calculation (lines 195-281):
```
prevSport = segments[segIdx - 1].sport
brickPenalty = (sport === "running" && prevSport === "cycling") ? 0.80 : 1.0
carbResult = calculateDuringWorkoutCarbs(cumulativeDurationMin, ...)
adjustedCarbRate = override ?? (carbResult.rate_gph * brickPenalty)
```

Segment response includes: `segment_order`, `sport`, `duration_minutes`, `carbs_g`, `carbs_rate_g_per_h`, `sodium_mg`, `water_ml`, ranges
**MISSING**: `raw_band_low/high`, `scaled_band_low/high`, `gut_multiplier`, `sport_ceiling`, `brick_penalty`, `cumulative_duration_min`

Flutter parsing (`brick_macro_service.dart` line 561-586):
- Parses: segmentOrder, sport, durationMinutes, carbsG, carbsLow/High, sodium, water
- **DROPS**: `carbs_rate_g_per_h` (even though it's in the response!)

### Key Finding: `absClampRangeGPerH` Stores Gut-Scaled Values
The field `during_abs_clamp_range_g_per_h` in the response = `[duringCarbs.band_low, duringCarbs.band_high]` = `[scaledLow, scaledHigh]` (line 731-734 of single-sport.ts). These are AFTER gut multiplier, not the raw duration band.

For the TL;DR formula we need both:
- Raw band (from getDurationCarbBand): e.g., "60 min run → 30–60 g/hr"
- Scaled band (after gut): e.g., "× 0.8 gut = 24–48 g/hr"

---

## Design Artifacts

HTML mockups saved in this directory:
- `pre-workout-carb.html` — Pre-workout carbs transparency design
- `during-workout-or-brick-or-race-carb-variants.html` — During-workout with single/brick/swim variants

### Artifact Design Elements NOT Implementing in v1
- Thumbs up/down feedback rows
- Variant switcher (Single Sport | Brick/Race | Swim) — using context-specific instead
- Event timeline strip (Swim → T1 → Bike → T2 → Run ← now)
- Inline video embed (navigating to VideoPlayerScreen instead)
