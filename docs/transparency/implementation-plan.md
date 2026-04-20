# Nutrition Transparency v1 — Carbs Only

## Context

The app already has "?" icons on Before/During phase headers that open `PhaseExplanationSheet` — a bottom sheet with expandable cards per macro (Carbs, Fluids, Sodium). Each card shows a formula and range rationale as plain text.

The goal is to **upgrade the Carbs card** in the existing sheet to a richer design with:
1. A "TL;DR" section showing a conversational pseudocode formula (always visible)
2. A collapsible "Watch" video accordion
3. A collapsible "Full Story" accordion with Q&A sections, citations, and inline edits for gut training + personal carb target

**No thumbs up/down feedback.** Fluids/Sodium cards remain unchanged.

---

## Decisions (from user Q&A)

| Decision | Answer |
|---|---|
| Scope | Carbs only — replace carbs card, keep fluids/sodium as-is |
| UI pattern | Keep existing `PhaseExplanationSheet` bottom sheet, replace carbs card content |
| Feedback | No thumbs up/down |
| Inline edits | Functional — reuse gut training + personal carb target widgets, save & recalc live |
| Video | ME101 1.1 for preworkout; placeholder for during-workout |
| Variants | Context-specific only — no switcher; each brick segment has its own "?" |
| Gut training values | 0.7 / 0.8 / 1.0 (current code is correct) |
| TL;DR style | "Narrative formula" — conversational lines with green-highlighted values |
| Full Story content | Hardcoded (like today's MacroExplanationService) |
| Accordion state | TL;DR always visible; Video + Full Story collapsed by default |
| Pre-workout TL;DR | Short narrative: "You eat 1g per kg..." + formula + ±12.5% range |
| During-workout TL;DR | Full stepped narrative formula (duration band → gut → midpoint → ceiling → result) |
| Brick penalty | Show as extra line in TL;DR when applicable |
| Personal target step | Only show when the user has an active override |
| Swim segment | Simplified zero-state message, not full formula |
| Live update on save | Yes — formula/targets recalculate in-sheet after gut/personal target save |

---

## Edge Function & Data Pipeline Changes

### Problem
The TL;DR and Full Story sections need intermediate calculation values that the edge function computes internally but doesn't fully return (or Flutter drops during parsing).

### Data Gap Analysis

**Single Sport (`generate-macros-v4/single-sport.ts`):**

| Data needed | Status | Fix |
|---|---|---|
| Gut multiplier (e.g. 0.8) | Returned as `during_gut_multiplier` but **Flutter drops it** | Parse in `macro_generation_service.dart` |
| Sport ceiling (e.g. 70) | Returned as `during_sport_ceiling_g_per_h` but **Flutter drops it** | Parse in `macro_generation_service.dart` |
| Raw band low/high (pre-gut) | **NOT returned** — only gut-scaled `band_low`/`band_high` | Add `during_raw_band_low_g_per_h` and `during_raw_band_high_g_per_h` to edge fn response |
| Scaled band low/high | Returned as `during_band_low_g_per_h`/`during_band_high_g_per_h` and stored as `absClampRangeGPerH` | Already available |

**Brick Segments (`generate-macros-v4/brick-workout.ts`):**

| Data needed | Status | Fix |
|---|---|---|
| Per-segment carb rate (g/hr) | Returned as `carbs_rate_g_per_h` but **Flutter drops it** | Add field to `BrickSegmentMacroTarget`, parse it |
| Per-segment raw band low/high | **NOT returned** | Add to segment response |
| Per-segment scaled band low/high | **NOT returned** | Add to segment response |
| Per-segment gut multiplier | **NOT returned** | Add to segment response |
| Per-segment sport ceiling | **NOT returned** | Add to segment response |
| Per-segment brick penalty | **NOT returned** (calculated as `brickPenalty` var) | Add to segment response |
| Total event time (cumulative) | **NOT returned** but can sum `durationMinutes` from segments | Derive client-side OR add |

### Changes Required

#### 1. Edge Function: `single-sport.ts`
**File:** `supabase/functions/generate-macros-v4/single-sport.ts`

Add 2 new fields to the response (lines ~716-717 area):
```typescript
// Existing:
during_band_low_g_per_h: duringCarbs.band_low,     // gut-scaled
during_band_high_g_per_h: duringCarbs.band_high,    // gut-scaled
during_gut_multiplier: duringCarbs.gut_multiplier,
during_sport_ceiling_g_per_h: duringCarbs.sport_ceiling,

// NEW — raw duration band (before gut multiplier):
during_raw_band_low_g_per_h: getDurationCarbBand(durationMin)[0],
during_raw_band_high_g_per_h: getDurationCarbBand(durationMin)[1],
```

Also update `calculateDuringWorkoutCarbs()` to return `raw_band_low` and `raw_band_high`:
```typescript
return {
  rate_gph: ...,
  band_low: Math.round(scaledLow),    // existing (gut-scaled)
  band_high: Math.round(scaledHigh),   // existing (gut-scaled)
  raw_band_low: baseLow,              // NEW (pre-gut)
  raw_band_high: baseHigh,            // NEW (pre-gut)
  gut_multiplier: gutMult,
  sport_ceiling: sportCeiling,
};
```

#### 2. Edge Function: `brick-workout.ts`
**File:** `supabase/functions/generate-macros-v4/brick-workout.ts`

Add transparency fields to each `duringSegments.push()` call (lines ~266-281):
```typescript
duringSegments.push({
  // Existing:
  segment_order, sport, duration_minutes,
  carbs_g, carbs_rate_g_per_h, ...

  // NEW transparency fields:
  raw_band_low_g_per_h: getDurationCarbBand(cumulativeDurationMin)[0],
  raw_band_high_g_per_h: getDurationCarbBand(cumulativeDurationMin)[1],
  scaled_band_low_g_per_h: carbResult.band_low,
  scaled_band_high_g_per_h: carbResult.band_high,
  gut_multiplier: carbResult.gut_multiplier,
  sport_ceiling_g_per_h: carbResult.sport_ceiling,
  brick_penalty: brickPenalty,
  cumulative_duration_min: cumulativeDurationMin,
});
```

Note: Need to track `cumulativeDurationMin` as we iterate segments.

#### 3. Flutter: `DuringRunMacros` domain model
**File:** `lib/features/nutrition_plan/domain/macro_targets.dart`

Add new fields:
```dart
class DuringRunMacros {
  // ... existing fields ...
  
  // NEW transparency fields:
  final double? gutMultiplier;        // e.g. 0.8
  final int? sportCeilingGPerH;       // e.g. 70
  final double? rawBandLowGPerH;      // pre-gut band low
  final double? rawBandHighGPerH;     // pre-gut band high
}
```

#### 4. Flutter: `BrickSegmentMacroTarget` domain model
**File:** `lib/features/nutrition_plan/domain/macro_targets.dart`

Add new fields:
```dart
class BrickSegmentMacroTarget {
  // ... existing fields ...
  
  // NEW transparency fields:
  final double? carbsRateGPerH;
  final double? rawBandLowGPerH;
  final double? rawBandHighGPerH;
  final double? scaledBandLowGPerH;
  final double? scaledBandHighGPerH;
  final double? gutMultiplier;
  final int? sportCeilingGPerH;
  final double? brickPenalty;         // 0.8 for run-after-bike, 1.0 otherwise
  final int? cumulativeDurationMin;
}
```

#### 5. Flutter: Parse new fields in `macro_generation_service.dart`
**File:** `lib/features/nutrition_plan/application/macro_generation_service.dart`

Update `DuringRunMacros` construction (line ~548) to include:
```dart
gutMultiplier: _toDoubleOrNull(macrosData['during_gut_multiplier']),
sportCeilingGPerH: _toDoubleOrNull(macrosData['during_sport_ceiling_g_per_h'])?.toInt(),
rawBandLowGPerH: _toDoubleOrNull(macrosData['during_raw_band_low_g_per_h']),
rawBandHighGPerH: _toDoubleOrNull(macrosData['during_raw_band_high_g_per_h']),
```

#### 6. Flutter: Parse new fields in `brick_macro_service.dart`
**File:** `lib/features/nutrition_plan/application/brick_macro_service.dart`

Update `BrickSegmentMacroTarget` construction (line ~562) to include:
```dart
carbsRateGPerH: _toDoubleOrNull(segmentData['carbs_rate_g_per_h']),
rawBandLowGPerH: _toDoubleOrNull(segmentData['raw_band_low_g_per_h']),
rawBandHighGPerH: _toDoubleOrNull(segmentData['raw_band_high_g_per_h']),
scaledBandLowGPerH: _toDoubleOrNull(segmentData['scaled_band_low_g_per_h']),
scaledBandHighGPerH: _toDoubleOrNull(segmentData['scaled_band_high_g_per_h']),
gutMultiplier: _toDoubleOrNull(segmentData['gut_multiplier']),
sportCeilingGPerH: _toDoubleOrNull(segmentData['sport_ceiling_g_per_h'])?.toInt(),
brickPenalty: _toDoubleOrNull(segmentData['brick_penalty']),
cumulativeDurationMin: (segmentData['cumulative_duration_min'] as num?)?.toInt(),
```

### Deployment Order
1. Deploy edge function changes first (backward compatible — new fields are additive)
2. Deploy Flutter changes — new fields are nullable, so old responses without them still parse fine

---

## Files to Modify

### 1. `MacroExplanationService` → new structured carb data
**File:** `lib/features/nutrition_plan/application/macro_explanation_service.dart`

Currently returns `MacroExplanation` with flat `formulaText` string. We need a richer data model for the new carbs card.

**New class: `CarbTransparencyData`** — structured data for the TL;DR + Full Story:

```dart
CarbTransparencyData {
  // TL;DR formula lines (each has plain text + highlighted values)
  List<FormulaLine> tldrLines;  // e.g. "Your **60 min run** falls in the **0–30 g/hr** band"
  
  // Phase-specific
  ExplanationPhase phase;
  
  // Pre-workout specific
  double? bodyWeightKg;
  double? hoursBefore;
  
  // During-workout specific
  int? durationMin;
  String? sportName;
  List<double>? bandRange;  // [low, high] g/hr
  double? gutMultiplier;
  String? gutLevel;
  double? midpointGPerH;
  int? sportCeiling;
  bool? isCapped;
  double? brickPenaltyFactor;  // 0.8 when run-after-bike
  double? personalTargetGPerH;  // only when override active & >=90min
  double? finalRateGPerH;
  double? durationH;
  double? totalG;
  
  // Swim zero-state
  bool isSwimZero;
  
  // Range
  int? rangeLow;
  int? rangeHigh;
  String? rangeText;  // "42–54g"
  
  // Video
  String? videoUrl;
  String? videoTitle;
  
  // Full Story Q&A sections
  List<StorySection> storySections;
  
  // Transparency note
  String? transparencyNote;
}
```

**Add new method:** `getCarbTransparencyData(phase, macroTargets, bodyWeightKg, ...)` that returns this structured data. Keep existing `getExplanations()` intact for fluids/sodium.

### 2. `PhaseExplanationSheet` → new carbs card
**File:** `lib/features/nutrition_plan/presentation/widgets/activity_detail/phase_explanation_sheet.dart`

**Changes:**
- Convert to `ConsumerStatefulWidget` (needs to watch `settingsControllerProvider` for live updates)
- For the Carbs card: replace current `_buildExplanationCard()` with `_buildCarbTransparencyCard()` which renders:
  - **TL;DR section** (always visible): "TL;DR" label + narrative formula lines with `AppColors.electrolyte` highlighted values
  - **Video accordion** (collapsed): Embeds video player or navigates to `VideoPlayerScreen`
  - **Full Story accordion** (collapsed): Q&A sections + inline edits
- For Fluids/Sodium cards: keep existing `_buildExplanationCard()` unchanged

### 3. New widget: `CarbTldrSection`
**File:** `lib/features/nutrition_plan/presentation/widgets/activity_detail/carb_tldr_section.dart` (NEW)

Renders the narrative formula with green-highlighted values using `RichText` / `TextSpan`. Each line is a `FormulaLine` with segments that are either plain or highlighted.

### 4. New widget: `CarbFullStorySection`
**File:** `lib/features/nutrition_plan/presentation/widgets/activity_detail/carb_full_story_section.dart` (NEW)

Renders the Q&A accordion with:
- Story sections (question + answer + optional citation)
- Inline gut training edit (reuses `KyleGutTrainingSegmentedControl`)
- Inline personal carb target edit (reuses `TextFormField` pattern from `NutritionTargetsScreen`)
- Save buttons that call `settingsControllerProvider.notifier` methods
- Transparency note at the bottom

### 5. New widget: `TransparencyVideoSection`
**File:** `lib/features/nutrition_plan/presentation/widgets/activity_detail/transparency_video_section.dart` (NEW)

Accordion that either:
- Navigates to `VideoPlayerScreen` on tap (simpler, leverages existing video player)
- Or embeds a compact video player inline (more complex)

**Recommendation:** Navigate to `VideoPlayerScreen` — simpler, reuses existing code.

### 6. Accordion widget (shared)
**File:** `lib/features/nutrition_plan/presentation/widgets/activity_detail/transparency_accordion.dart` (NEW)

Simple reusable accordion widget (title + chevron + collapsible panel) used by both Video and Full Story sections. Similar pattern to what exists in `PhaseExplanationSheet` but as a standalone reusable widget.

---

## Data Flow for Live Updates

When user changes gut training or personal carb target inside the Full Story:

1. User taps Save on inline edit
2. Call `ref.read(settingsControllerProvider.notifier).saveAllPreferences(gutTrainingLevel: newLevel)` or `saveNutritionTargetOverrides(overrides)`
3. `settingsControllerProvider` state updates
4. `PhaseExplanationSheet` (now a `ConsumerStatefulWidget`) watches `settingsControllerProvider`
5. On state change, re-call `MacroExplanationService.getCarbTransparencyData()` with new values
6. Widget rebuilds with updated formula lines and targets

**Important:** The actual `MacroTargets` object (from the edge function) won't recalculate live — that requires a full macro regeneration. The TL;DR formula can recalculate locally using the same logic as `MacroExplanationService` since it's pure Dart math. We'll show the updated formula immediately, and note that the full plan will update on next refresh.

---

## Video Mapping

| Phase | Video | URL |
|---|---|---|
| Pre-workout carbs | Mealvana 101 - 1.1 | `https://milkman-dev.s3.us-east-2.amazonaws.com/me_videos/me101_1.1.mp4` |
| During-workout carbs | Placeholder | Show "Coming soon" state |

Load via `education_content` table or hardcode URL for v1 (hardcode is simpler, matches the "hardcode content" decision).

---

## Full Story Content (Hardcoded — EXACT copy from HTML artifacts)

**IMPORTANT:** All Full Story copy below is taken verbatim from the HTML artifacts in this directory. The TL;DR narrative formula is the ONLY section that deviates from the artifacts (uses conversational pseudocode per user decision). Everything else must match exactly.

### Pre-Workout Carbs (from `pre-workout-carb.html`)

**Q: Why carbs before a workout?**
Your muscles run on glycogen — stored from the carbs you eat. During exercise your body burns through it continuously. Fuller stores mean **better performance, focus, and a lower chance of hitting the wall.**

**Q: Why does timing change how much you need?**
Your digestive system needs time to convert food into fuel. Researchers found athletes benefit from **1–4g per kg, consumed 1–4 hours before exercise** — roughly 1g per hour of lead time.
*Citation: Kerksick et al., 2017 — ISSN Position Stand: Nutrient Timing*

**Q: Why a range and not one exact number?**
Real food doesn't come in precise grams — a banana might be 25g or 28g. The underlying research is also a range because digestion rates and glycogen stores vary individually. **{rangeLow}–{rangeHigh}g reflects that honestly.**

**Q: Shouldn't a harder workout mean more carbs?**
Not in the pre-workout calculation. Intensity influences **when** you should eat — harder workouts need a longer lead time. The gram target stays at 1g/kg/hr regardless of intensity.
*Citation: Kerksick et al., 2017*

**Transparency note:**
The **±12.5% range** is Mealvana's design choice to bridge precise math and real food portioning — not from research. Everything else here is.

### During-Workout Carbs — Single Sport (from `during-workout-or-brick-or-race-carb-variants.html`)

**Q: Why does duration set the starting range?**
Your body can't replenish muscle glycogen while exercising — consumed carbs maintain blood glucose and slow depletion instead. The longer you go, the more you need. Research gives us reliable absorption ranges by duration.
*Data chips: <60 min · 0–30 g/hr | 60–90 min · 30–60 g/hr | 90–150 min · 45–60 g/hr | 150–240 min · 60–90 g/hr | >240 min · 80–100 g/hr*
*Citation: Jeukendrup (2014) — Sports Medicine; Kerksick et al. (2017) — ISSN Position Stand*
**Transparency note:** No single study gives these exact bands with these specific minute cutoffs. The research anchors two points: minimal intake under 60 min (Carter et al. 2004 — mouth rinse research), and up to 90 g/hr for very long efforts (Jeukendrup 2004). The five bands are **Mealvana's interpolation**. The direction is well-supported. The specific cutoffs are ours.

**Q: What is gut training and why does it matter?**
Athletes who consistently fuel during workouts upregulate the transporters that move carbs from gut to bloodstream. Your gut training level scales the entire band up or down.
*Data chips: Low · 0.7× | Moderate · 1.0× | High · 1.2×*
*Citation: Jeukendrup (2017) — Training the Gut for Athletes; Costa et al. (2019)*
*[Inline edit: gut training selector]*

**Q: Why doesn't body weight change the target?**
During-exercise carb recommendations are **not body-weight dependent.** The limiting factor is gut absorption capacity — and that doesn't scale with body weight.
*Citation: Jeukendrup (2014) — "There is no rationale for expressing carbohydrate recommendations per kilogram of body weight."*

**Q: Why does sport type set a ceiling?**
Running's vertical impact stresses the gut, limiting carb processing. Cycling's stable position removes that stress — cyclists can sustain nearly double the carb rate of runners. Gut training expands your band, but the sport ceiling is the hard limit it can never exceed. A highly gut-trained runner capped at **70 g/hr** on the run can realize the full benefit of their training up to **120 g/hr** on the bike.
*Data chips: Running · max 70 g/hr | Cycling · max 120 g/hr | Swimming · 0 g/hr*
*Citation: Pfeiffer et al. (2012) — GI Problems in Endurance Sports*

**Q: Why does your personal target override the algorithm?** *(only shown if override exists)*
For efforts of 90 minutes or longer, your personal carb rate replaces the algorithm's midpoint. A newer athlete may start at 30 g/hr to avoid GI distress. An experienced athlete may push to 80 g/hr on a long ride. The algorithm gives you the science. Your personal target gives you the control.
*Tip: Personal targets only apply for efforts of 90 min or longer.*
*[Inline edit: personal carb target input]*

### During-Workout Carbs — Brick/Race (from `during-workout-or-brick-or-race-carb-variants.html`)

**Q: Why does the band use total event time, not run time?**
Glycogen depletion is cumulative — your body doesn't reset when you dismount the bike. By the time you start the run, you've already been burning fuel for **{cumulativeMin} minutes**. Using only the run duration ({segmentMin} min) would dramatically underestimate how depleted you are and recommend a carb rate suited for a fresh runner, not one who has swum {swimMin} minutes and biked {bikeHours} hours.
*Citation: V4 algorithm — Mealvana cumulative time model*

**Q: What is the brick penalty?**
Running after cycling reduces your gut's ability to absorb carbohydrates. During the bike leg, blood is diverted away from the gut to working muscles. Transitioning to running — with its additional vertical impact — compounds this effect. The 20% reduction reflects the reduced splanchnic blood flow and mechanical stress during the early run.
*Citation: Van Wijck et al. (2012) — Splanchnic hypoperfusion during exercise*

*(Then same gut training Q&A + personal target Q&A as single sport)*

### During-Workout Carbs — Swim = 0 (from `during-workout-or-brick-or-race-carb-variants.html`)

**Q: Why is the target zero during swimming?**
Swimming is the only endurance sport where fueling during the activity is physically impossible. You cannot eat or drink while in open water or a pool without stopping. All carbohydrate intake is therefore shifted to the pre-swim meal, and to T1 where you have a brief window to consume calories before the bike leg begins.

**Q: Does the swim time still count toward total event time?**
Yes — and this is important. Even though you consume 0g during the swim, your body is still burning glycogen for the entire duration. The swim time is fully included in the cumulative elapsed time used to determine your carb band on the bike and run segments. A {swimMin}-minute swim means the bike segment starts at {swimMin}+ minutes of cumulative depletion, not zero.

**Q: What should I eat before the swim?**
Your pre-workout carb targets account for the full race duration. See the **Before Workout** section for your pre-swim meal targets. T1 transition nutrition is shown separately in the race fueling plan.

---

## Reusable Widgets & Providers

| What | Where | How to Reuse |
|---|---|---|
| Gut training selector | `KyleGutTrainingSegmentedControl` in `lib/shared/widgets/kyle_design/buttons/segmented_control.dart` | Pass `selected` + `onChanged`, call `settingsControllerProvider.notifier.saveAllPreferences()` |
| Personal carb target input | `TextFormField` pattern from `lib/features/settings/presentation/screens/nutrition_targets_screen.dart` | Replicate field + save via `settingsControllerProvider.notifier.saveNutritionTargetOverrides()` |
| Video player | `VideoPlayerScreen` in `lib/features/education/presentation/screens/video_player_screen.dart` | Navigate with `title` + `videoUrl` |
| Settings state | `settingsControllerProvider` in `lib/features/settings/presentation/providers/settings_controller.dart` | Watch for gut training + overrides |
| Bottom sheet pattern | `PhaseExplanationSheet.show()` + `DraggableScrollableSheet` | Already in place, just modify card content |
| Green highlight color | `AppColors.electrolyte` | Used throughout app for accent |

---

## Implementation Order

### Phase A: Data Pipeline (edge function + domain models)
1. **Edge function: single-sport.ts** — Add `during_raw_band_low_g_per_h`, `during_raw_band_high_g_per_h` to response
2. **Edge function: brick-workout.ts** — Add transparency fields per segment (raw band, scaled band, gut multiplier, sport ceiling, brick penalty, cumulative duration)
3. **Deploy edge functions** (backward compatible, additive fields)
4. **Flutter domain models** — Add new nullable fields to `DuringRunMacros` + `BrickSegmentMacroTarget` + `copyWith` + `toJson` + `fromJson` + `==` + `hashCode`
5. **Flutter parsing** — Update `macro_generation_service.dart` and `brick_macro_service.dart` to parse new fields

### Phase B: Transparency UI
6. **Data model** — Create `CarbTransparencyData`, `FormulaLine`, `StorySection` classes
7. **Service** — Add `getCarbTransparencyData()` to `MacroExplanationService`
8. **TL;DR widget** — `CarbTldrSection` with narrative formula rendering
9. **Accordion widget** — Reusable `TransparencyAccordion`
10. **Video section** — `TransparencyVideoSection` (navigate to VideoPlayerScreen)
11. **Full Story widget** — `CarbFullStorySection` with Q&A + inline edits
12. **Integration** — Update `PhaseExplanationSheet` to use new carb card, convert to ConsumerStatefulWidget
13. **Live updates** — Wire up settings provider watching + recalculation

---

## Verification

1. **Pre-workout carb "?"**: Tap → bottom sheet opens → Carbs card shows TL;DR with `body weight × hours before` formula, green values → Video accordion → Full Story with 4 Q&A + transparency note
2. **During-workout carb "?"** (single sport, short): Shows duration band formula, no personal target step
3. **During-workout carb "?"** (single sport, >=90 min with override): Shows full formula including personal target override step
4. **Brick segment "?"**: Each segment shows context-specific formula (bike/run/swim)
5. **Swim "?"**: Shows simplified zero-state
6. **Inline gut edit**: Change level → Save → formula updates live in sheet
7. **Inline personal target edit**: Change value → Save → formula updates live
8. **Fluids/Sodium cards**: Unchanged from current behavior
9. **Video tap**: Navigates to VideoPlayerScreen with correct video
