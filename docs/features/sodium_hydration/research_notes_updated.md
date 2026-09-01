# Hydration & Sodium Transparency — Consolidated Research Notes

_Generated 2026-04-20. Merges four parallel research streams: design spec extraction, Flutter code audit, edge-function audit, and web research on sweat testing._

---

## 0. Executive Summary

### The goal
Replace the current hydration/sodium bottom-sheet content on the activity details screen with a richly-structured, citation-backed transparency UI matching the designs in `/docs/features/sodium_hydration/screenshots/`, for single-sport, brick, and race workouts — pre- and during-workout — with proper handling of "known rate" (sweat-test) overrides, T1/T2 transitions, redistribution, and short-workout gates.

### What's actually broken today
1. **Algorithm is wrong.** Every single formula in `_shared/nutrition/sweat-hydration.ts` + `generate-macros-v4/single-sport.ts` + `pre-workout.ts` + `brick-workout.ts` diverges from the new spec: base sweat rates are legacy values (0.75/1.25/2.0 instead of 0.90/1.28/1.66), replacement % is flat 75% regardless of duration, humidity is **read into an `_`-prefixed arg and ignored**, there's no indoor multiplier, no 2% BW floor, no GI ceiling, no short-workout gate, no T1/T2 transition rule (300 ml fixed), no run→bike redistribution, and sodium is calculated independently as 60% of loss instead of being derived from fluid volume × concentration.
2. **Edge function data plumbing is missing user inputs.** `MacroInputV4` declares `optional_sweat_rate_lph` and `drink_sodium_mg_per_l` but **never reads them** in V4 (only legacy V1 did). `is_indoor` doesn't exist on the payload at all. No known-sodium-concentration override exists anywhere.
3. **Flutter has no sweat sodium category field.** The user profile has `sweat_rate` (light/medium/heavy) but no `sweat_sodium` / `salt_type` field. The server defaults it silently.
4. **Flutter has no sweat-test data model at all.** No known sweat rate, no known sodium concentration, no per-sport sweat profile, no test date or test conditions.
5. **Bottom-sheet UI for fluids/sodium is the "old simple card"** — just two `Text` widgets with a legacy formula string. The new carb transparency UI (`CarbTldrSection`, `CarbFullStorySection`, `TransparencyAccordion`, `TransparencyVideoSection`) exists as a template we can generalize.
6. **Transparency copy is hardcoded in Dart** (`MacroExplanationService`) with literal constants like `"0.75"` and `"550/925/1150"` — when the edge function algorithm changes, these numbers silently go wrong. This violates the CLAUDE.md "don't hardcode user-facing strings when content systems exist" rule.
7. **Brick per-segment fluid/sodium math in the sheet is wrong today** — it shows a segment total but uses the overall sport rate in the formula.
8. **Swim segment sheet is incomplete** — Fluids/Sodium cards are skipped entirely.
9. **Two parallel bottom-sheet systems** (`PhaseExplanationSheet` on activity details + `HelpBottomSheetWidget` on adjust macros screen) with divergent hardcoded copy.
10. **`generate-nutrition-plan-v3` does NOT recalculate** hydration/sodium for single-sport (good — just consumes the values). But **for bricks it re-derives transition targets from its own hardcoded duration tiers** in `brick-handler.ts:getTransitionTargets` — a latent divergence hazard.

---

## 1. Design Specification (from `/docs/features/sodium_hydration/` + screenshots)

### 1.1 Bottom-sheet structure (universal chrome)

All during-workout sheets share:
- **Tab bar at top**: `Single Sport · Known Rate · Multi-Segment · Short Workout · Redistribution · T1 / T2` (only tabs relevant to the current workout are active/visible).
- **Big header row**: `<value> planned / <value> target`, plus a pink rate chip (e.g. `560 ml/hr`) and a green range chip (e.g. `21–41 oz`). Short-workout shows `max 20 oz`. T1/T2 shows `fixed`.
- **Blurb** — a plain paragraph directly under the header (copy varies by scenario; see §1.5).
- **Optional conditions / callout blocks** (short-workout gate checklist, redistribution explanation, 2% BW warning, T1/T2 absorption note, race deficit safety pass).
- **Three expandable accordion sections** below:
  1. `Calculation` — numbered `①②③④⑤` rows with circled digits, `↓` floor, `↑` ceiling, `#` redistribution, `✓` safety check; monospace styling with teal-highlighted key numbers.
  2. `Watch: <video title>` — video thumbnail, title, `~2 min · Mealvana Education` subtitle.
  3. `The Full Story` — stacked Q&A entries, each with: bold question, body text, chip row(s), citation line, optional `TRANSPARENCY NOTE` callout, confidence pill (`HIGH/MEDIUM/LOW CONFIDENCE`), `Helpful?` 👍/👎 footer.
- **"Does this make sense?"** 👍/👎 footer on the Calculation block.

Pre-workout sheets have the same structure but only a single relevant tab (there's no known-rate/multi-segment/etc. for pre-workout).

### 1.2 Scenarios covered

| Scenario | Tab | Trigger |
|---|---|---|
| Pre-workout hydration | (no tabs) | Before-phase fluid card |
| Pre-workout sodium | (no tabs) | Before-phase sodium card |
| During — single sport | `Single Sport` | Non-brick workout |
| During — known rate | `Known Rate` | User has entered a known sweat rate |
| During — multi-segment | `Multi-Segment` | Brick/tri, no redistribution needed |
| During — short workout | `Short Workout` | `duration < 60 min AND temp < 30°C` |
| During — redistribution | `Redistribution` | Run hits GI ceiling, shortfall shifted to bike |
| During — T1 / T2 | `T1 / T2` | Transition segment between swim→bike or bike→run |
| During — sodium (all workouts) | (same sheet) | Sodium card in any during scenario |

### 1.3 Formulas (spec source of truth)

**Effective sweat rate**
```
base = known_sweat_rate / 1000   OR   {LIGHT:0.90, MEDIUM:1.28, HEAVY:1.66} L/hr
temp_mult     = clamp(1.0 + (temp_c - 22) * 0.04, 0.50, 1.80)
humidity_mult = clamp(1.0 + max(0, humidity_pct - 50) * 0.002, 1.0, 1.10)
indoor_mult   = 1.30 if is_indoor else 1.0
effective     = clamp(base * temp_mult * humidity_mult * indoor_mult, 0.3, 3.0) L/hr
swim_segment_effective = effective * 0.4
```

**Sodium concentration**
```
sodium_conc = known_sodium_mg_per_L   OR   {LOW:650, AVERAGE:825, HIGH:1000} mg/L
```

**Replacement % by total duration**
```
<60 min   → 0.30 (soft; gated)
60–90     → 0.50
90–150    → 0.60
150–240   → 0.70
240+      → 0.80
```

**Short-workout gate** (applies to both pre- and during):
```
gate = duration_min < 60 AND temp_c < 30
# gate bypassed if temp ≥ 30
```

**Single-sport during**
```
recommended_ml_hr = effective * 1000 * replacement_pct
total_loss_ml     = effective * 1000 * (duration_min / 60)
max_deficit_ml    = body_weight_kg * 1000 * 0.02
floor_ml_hr       = max(0, (total_loss - max_deficit) / (duration_min / 60))
recommended       = max(recommended, floor_ml_hr)
gi_ceiling        = {RUN:800, BIKE:1200}[sport]
ceiling_ml_hr     = min(gi_ceiling, effective * 1000)  # 100% sweat rate cap
fluid_ml_hr       = min(recommended, ceiling_ml_hr)
sodium_mg_hr      = (fluid_ml_hr / 1000) * sodium_conc
```

**Multi-segment**
```
total_duration    = sum(segments.duration_min)
replacement_pct   = lookup(total_duration)
total_loss        = sum_per_segment(effective * swim_mod * duration)
transitions       = detect(swim→bike => T1, bike→run => T2)
transition_intake = len(transitions) * 300 ml  # FIXED 300 ml each
required_total    = total_loss * replacement_pct
floor_total       = max(0, total_loss - 2% BW in ml)
remaining_required = max(0, required_total - transition_intake)
remaining_floor    = max(0, floor_total    - transition_intake)
drinkable_hours   = sum(non-swim segment durations / 60)
recommended_ml_hr = remaining_required / drinkable_hours
floor_ml_hr       = remaining_floor / drinkable_hours
# per-segment ceiling = min(sport GI, effective * 1000)
```

**Run→bike redistribution**
```
for each run segment: if floor_ml_hr > 800:
    shortfall_total = (floor_ml_hr - 800) * run_duration_hr
    add_per_hr      = shortfall_total / total_bike_hours
    for each bike segment:
        bike.fluid = min(bike.fluid + add_per_hr, 1200)  # re-cap at bike GI
```

**Sodium** (all contexts)
```
sodium_mg_hr = (fluid_ml_hr / 1000) * sodium_conc
t.sodium_mg  = 0.3 * sodium_conc   # transition 300 ml * conc/1000
```

**Pre-workout tiers** (by time before workout)
```
gate: workout_duration < 60 AND temp < 30 → no plan

Tier 1 (≥120 min): fluid = BW * 6 ml [range BW*5..BW*7]; sodium = 450 mg [300..600]
Tier 2 (10–120):   fluid = 250 ml fixed [200..300];       sodium = 150 mg [100..200]
Tier 3 (<10):      fluid = 0, sodium = 0
```

**Safety check**
```
net_deficit_pct = (total_loss - total_intake) / (body_weight_kg * 1000)
>3% → "Significant dehydration expected..."
>2% → "Even at recommended intake you may lose >2% BW..."
```

### 1.4 Constants (spec block, verbatim)

```
SWEAT_RATE_PERCENTILES  = {LIGHT:0.90, MEDIUM:1.28, HEAVY:1.66} L/hr (Barnes/Baker 2019, n=1303)
SODIUM_PERCENTILES      = {LOW:650, AVERAGE:825, HIGH:1000} mg/L (Baker 2016, n=506)
SWIMMING_SWEAT_MODIFIER = 0.4
TRANSITION_FLUID_ML     = 300
TEMP_BASELINE_C         = 22     # was 20 in current impl
TEMP_COEFFICIENT        = 0.04
HUMIDITY_BASELINE_PCT   = 50
HUMIDITY_COEFFICIENT    = 0.002
INDOOR_MULTIPLIER       = 1.30
MIN_SWEAT_RATE          = 0.3 L/hr
MAX_SWEAT_RATE          = 3.0 L/hr
DEFICIT_THRESHOLD       = 0.02 (2% BW)
GI_CEILING_RUN          = 800 ml/hr
GI_CEILING_BIKE         = 1200 ml/hr
PRE_FLUID_ML_PER_KG     = 6 (range 5..7)
PRE_SODIUM_TIER1_MG     = 450 (range 300..600)
PRE_FLUID_TIER2_ML      = 250 (range 200..300)
PRE_SODIUM_TIER2_MG     = 150 (range 100..200)
PRE_TIME_FULL_PROTOCOL  = 120 min
PRE_TIME_TOPUP          = 10 min
```

### 1.5 Copy — blurb strings (verbatim from screenshots/transparency md)

| Card | Copy |
|---|---|
| Pre-fluids Tier 1 | "The goal before a workout is to start **euhydrated** — at your normal baseline, not loaded or depleted. With 3 hours available, you have time for the full protocol: sip 390 ml gradually, let it absorb, and aim for pale yellow urine before you head out." |
| Pre-fluids Tier 2 | "Not enough time for the full protocol. 250 ml is all that can meaningfully absorb before exercise begins. Sip it steadily — don't chug it just before you start." |
| Pre-fluids Tier 3 | "Too late for structured pre-hydration. A few small sips are fine for comfort, but fluid taken now won't absorb before exercise begins. Focus on the during-workout plan instead." |
| Pre-sodium | "Pre-workout sodium keeps the fluid you drink in your body rather than sending it straight to your bladder. Without sodium, much of what you consume before exercise is excreted before you even start." |
| During-fluids (single/known) | "Your fluid target starts with a duration-based replacement strategy, then two overrides are applied: a **floor** that raises the target if needed to keep you within 2% body weight loss, and a **ceiling** that caps it at what your gut can absorb and what's safe for blood sodium. The final recommendation is always between those two bounds." |
| During-fluids (multi/redistribution) | "In a race or brick, the replacement strategy is based on **total event duration** — not just this leg. When the run leg can't absorb enough to stay within 2% body weight loss, the shortfall is redistributed here where your gut has more capacity." |
| During-fluids short gate | "This workout is short and conditions are mild — no structured hydration plan needed. **Drink to thirst.** If you want a number, aim for no more than 10 oz. Don't exceed 20 oz." |
| During-fluids T1/T2 | "Transitions are brief, fixed hydration windows — not a calculated segment. The 300 ml target isn't derived from your sweat rate; it's a conservative bolus sized for what you can comfortably take in during a 2–5 minute stop. **T1** bridges the swim gap and offsets wetsuit heat. **T2** is your last easy opportunity before running GI tolerance drops." |
| During-sodium | "Your sodium target is a simple multiplication of your fluid intake rate by your sweat sodium concentration. Dial in your test results if you have one." |

Full Q&A copy and chip strings: see §B.4–B.7 of the design-spec agent report (in this doc abbreviated; full verbatim copy lives in `transparency_*.md` files — those are the source of truth, **not** a Dart literal).

### 1.6 Confidence pill assignments

- **HIGH**: base sweat rate tiers, 2% BW threshold, 5–7 ml/kg pre-fluid, 80% at 240+ min, sodium concentration percentiles, euhydration concept, ACSM 300–600 mg pre-sodium.
- **MEDIUM**: temperature coefficient, humidity multiplier, 50%/60%/70% replacement tiers, self-report sodium indicators, 100% sodium replacement principle, NATA 10–120 min fluid.
- **LOW**: indoor 1.30× multiplier, <60 min 30% soft target, T1/T2 transition fluid amount.

### 1.7 Test cases (summary from `hydration_sodium_calc_tests.md`)

Reference athlete: 70 kg MEDIUM outdoor 22°C 50% (unless stated). Tolerances: ml/hr ±5%, L/hr ±0.01, deficit ±0.1%. Full table in §D of design-spec agent report. Key categories:
- Base rate lookup + known-rate override
- Temp/humidity/indoor multiplier clamps
- Combined effective sweat rate (including swim 0.4×)
- Replacement % lookup (duration boundaries)
- Short-workout gate (duration × temp bypass)
- Single-sport integration (4 cases covering floor/ceiling overrides, short gate, deficit flag)
- Multi-segment integration (Olympic tri, brick)
- Redistribution (heavy sweater, run capped, bike receives shortfall, safety flag)
- Edge cases (zero duration, zero BW, negative temp, extreme humidity, swim-only)
- Pre-workout gate, tier selection by boundaries (120, 10), all three tiers, combined Tier 1+2 top-up

---

## 2. Current Flutter Implementation

### 2.1 Entry point — activity details "?" flow

Activity details screen lives at `lib/features/nutrition_plan/presentation/screens/activity_detail_screen.dart` (note: under `nutrition_plan`, not `activities`). Every "?" tap calls `PhaseExplanationSheet.show(...)` — a single unified bottom sheet that renders Carbs + Fluids + Sodium (+ Protein on after) as stacked cards.

"?" buttons live in:
- `before_phase_widget.dart:141-154`
- `during_phase_section_widget.dart:232-253`
- `brick_nutrition_sections.dart:416-456` (per segment)
- `nutrition_sections_builder.dart:569-597`

### 2.2 Primary sheet widget

`lib/features/nutrition_plan/presentation/widgets/activity_detail/phase_explanation_sheet.dart` (597 lines):
- `DraggableScrollableSheet` (initialSize 0.75, min 0.4, max 0.95).
- Single `_expandedMacro` state — only one macro card can be expanded at a time.
- Line 304–378 `_buildCarbTransparencyCard` is the new rich UI (TL;DR, video, Full Story).
- Line 490–595 `_buildExplanationCard` is the **old simple card** — used by Fluids and Sodium today. Just shows `formulaText` and `rangeRationale` as plain `Text`.

### 2.3 Copy source (violates content rule)

`lib/features/nutrition_plan/application/macro_explanation_service.dart` (1481 lines, pure-Dart, no Riverpod, no ContentService):
- `_beforeExplanations` (153–261)
- `_duringExplanations` (265–451) — handles brick + swim
- `_afterExplanations` (455–554)
- `_transitionExplanations` (558–608) — hardcoded T1 20g/150mg/200ml, T2 25g/100mg/150ml

All hydration/sodium text is **literal Dart strings** with hardcoded constants like `0.75`, `0.60`, `550/925/1150` — none of these are read from `MacroTargets`, so the displayed math drifts when the algorithm changes.

### 2.4 Data model today (`lib/features/nutrition_plan/domain/macro_targets.dart`)

**`PreRunMacros`** — has `fluidsMl`, `fluidsLowMl/HighMl`, `sodiumMg`, `sodiumLowMg/HighMg`.

**`DuringRunMacros`** — has `fluidRateMlPerH`, `fluidTotalMl`, `sodiumRateMgPerH`, `sodiumTotalMg`, low/high bands. **Carb-only derivation fields** (`sportCeilingGPerH`, `rawBandLowGPerH`, `rawBandHighGPerH`, `gutMultiplier`) exist but no equivalents for fluids or sodium.

**`BrickSegmentMacroTarget`** — has `waterMl/waterLowMl/waterHighMl`, `sodiumMg/sodiumLowMg/sodiumHighMg`, and rich carb-only derivation fields (`rawBandLowGPerH`, `scaledBandLowGPerH`, `gutMultiplier`, `sportCeilingGPerH`, `brickPenalty`, `cumulativeDurationMin`).

**`BrickTransitionMacroTarget`** — hardcoded T1/T2: `waterMl`, `sodiumMg`, `carbsG`, + low/high. Currently tied to a duration-tier table, not "300 ml fixed" × transitions.

**Gaps the new spec requires** (none of these exist on `MacroTargets`):
- `sweatRateLPerH` (effective) — so we can display "1.29 L/hr effective"
- `sodiumConcMgPerL` — so we can display "825 mg/L"
- `replacementPercent` (0.30..0.80)
- `environmentalCategory` / individual temp, humidity, indoor breakdowns
- `floorMlPerH`, `ceilingMlPerH`
- `safetyFlags` list
- Per-segment versions of all of the above for bricks
- Known-rate vs category-derived indicator

### 2.5 User profile (`lib/shared/database/tables/user_profiles.dart` + `lib/features/auth/domain/user_preferences.dart`)

**Exists**: `sweatRate` (`SweatRateCat` enum: `light`/`medium`/`heavy`), `weightPounds`, `gutTrainingLevel`, `runsWithWaterBottle` (unused in calc).

**Missing** (all need to be added):
- Sweat sodium category field (no `sweatSodium` / `saltType` / `sweatSodiumCategory` column anywhere)
- Known sweat rate override (`knownSweatRateMlPerHour` or similar)
- Known sodium concentration override (`knownSodiumConcMgPerL`)
- Per-sport sweat profile (current field is global; spec + web research say sport-specific is meaningful)
- Sweat-test metadata (test date, test temperature, test sport, test method/source)

### 2.6 Activity-level environment inputs

Environment inputs (`temperatureC`, `humidityPct`, `isIndoor`) live **only in form controllers** (`cycling_input_controller.dart:32-33`, `brick_input_controller.dart:35-38`) before being POSTed to the edge function. They are **not persisted on the activity** (`activities_table.dart` has no temp/humidity/indoor columns). `ActivityCompletion` has `weatherConditions/temperatureFahrenheit/humidityPercent` but that's post-workout logging, not plan input.

**Consequence**: the transparency sheet cannot show "at 24°C, 65% humidity, outdoor" unless we either (a) add these columns to `activities`, or (b) return them inside `nutritionPlanData` JSON from the edge function.

### 2.7 ContentService integration

`lib/features/content/application/content_service.dart` exists and is the canonical Supabase-backed key-value content system. **Neither `PhaseExplanationSheet` nor `MacroExplanationService` uses it.** All hydration/sodium copy is hardcoded Dart literals. This violates CLAUDE.md.

Video URLs are also hardcoded:
```dart
static const _preWorkoutVideoUrl =
  'https://milkman-dev.s3.us-east-2.amazonaws.com/me_videos/me101_1.1.mp4';
```

### 2.8 Reusable transparency building blocks (can generalize)

- `TransparencyAccordion` (`transparency_accordion.dart`) — animated collapse/expand, chevron rotation, theme-aware.
- `CarbFullStorySection` — consumes `StorySection[]`, supports inline edits (`InlineEditType.gutTraining`, `InlineEditType.personalTarget`).
- `CarbTldrSection` — renders formula lines with `FormulaSegment` (`accent`/`op`/`dim`/`result` visual styles) + optional `stepNumber` (`①` etc.).
- `TransparencyVideoSection` — video accordion with lazy load.

**Recommendation**: generalize `CarbTransparencyData` → `NutrientTransparencyData` with the same TL;DR + Full Story + video structure, and extend `MacroExplanationService` to emit it for fluids/sodium. Then `PhaseExplanationSheet` can stop special-casing `if (macroName == 'Carbohydrates')` at line 283 and render all three macros uniformly.

### 2.9 Brick per-segment math bug

`_duringExplanations` lines 384–448: for brick segments, reads `brickSegment.waterMl/sodiumMg` (correct) BUT displays the formula using `during.fluidRateMlPerH` / `during.sodiumRateMgPerH` — the **overall** rates, not segment rates. The numbers don't multiply to the displayed total.

### 2.10 Swim segment bug

`_duringExplanations:290-305` short-circuits to a carbs-zero card for swim and returns — **no Fluids/Sodium cards render for swim segments at all**.

### 2.11 Two-help-system divergence

`PhaseExplanationSheet` (activity details) + `HelpBottomSheetWidget` (adjust macros screen at `help_bottom_sheet_widget.dart:90-99`) have independent hardcoded copy. Sodium help says "~50-70%" while the algorithm uses 60%. Should consolidate.

### 2.12 Client-side offline fallback calculator

`lib/features/nutrition_plan/data/offline_macro_calculator.dart` exists for when the edge function is unavailable. It uses a **completely different** formula set (fluid rate by duration+MET thresholds; flat 250 mg/hr sodium; 6.0 × weightKg pre-water). Does not consider sweat rate category, sodium category, temperature, humidity, or indoor at all. Will need to be rewritten to match the new algorithm (or marked deprecated/removed).

---

## 3. Edge-Function Implementation

### 3.1 Active functions

- `supabase/functions/generate-macros-v4/` — production macro generator. Flutter calls via `macro_generation_service.dart:461` and `brick_macro_service.dart:85`.
- `supabase/functions/generate-nutrition-plan-v3/` — production plan generator. Flutter calls via `nutrition_plan_service.dart:348`.
- `_shared/nutrition/sweat-hydration.ts` — shared helpers: `classifyEnvironment`, `baseSweatRateFromCategory`, `sodiumConcentrationFromCategory`, `calculateActualSweatRate`.

### 3.2 What's wrong in `sweat-hydration.ts`

```ts
// Lines 19-24: BASE RATES ARE LEGACY VALUES
light: 0.75,  medium: 1.25,  heavy: 2.0    // spec wants 0.90 / 1.28 / 1.66

// Lines 26-31: SODIUM VALUES ARE LEGACY
low: 550, medium: 925, high: 1150            // spec wants 650 / 825 / 1000
// Also: category named `medium` — spec wants `average`

// Lines 33-44: FORMULA HAS 5 DEFECTS
const baseRate = baseSweatRateFromCategory(baseCategory);
let tempAdjustment = 1.0;
if (tempC !== null && tempC > 20) {                 // ❌ baseline 20, spec 22
  tempAdjustment = 1.0 + Math.max(0, (tempC - 20) * 0.04);
  // ❌ no clamp — spec wants [0.50, 1.80]
}
// ❌ `_humidityPct` prefixed with underscore — NEVER READ
// ❌ no is_indoor multiplier
// ❌ no overall 0.3–3.0 L/hr clamp
// ❌ no known-rate override
return baseRate * tempAdjustment;
```

### 3.3 What's wrong in `single-sport.ts`

```ts
// Lines 129-138: FLAT 75% REGARDLESS OF DURATION
const hydrationRateMlph = Math.round(actualSweatRateLph * 1000 * 0.75);
// ❌ spec wants duration-scaled 0.30/0.50/0.60/0.70/0.80

// Lines 135-137: SODIUM CALCULATED INDEPENDENTLY
const sodiumRateMgph = Math.round(actualSweatRateLph * sodiumConcMgPerL * 0.6);
// ❌ spec wants sodium = (fluid_ml_hr / 1000) * sodium_conc  — derived from fluid

// Missing entirely:
// ❌ short-workout gate (<60 min && <30°C)
// ❌ 2% BW floor
// ❌ GI ceiling (800 run / 1200 bike)
// ❌ 100% sweat rate hyponatremia cap
// ❌ safety flags
// ❌ swimming 0.4× modifier (later code zeros swim fluid entirely at line 639)

// Lines 427-428 declare optional_sweat_rate_lph and drink_sodium_mg_per_l
// but NEITHER IS READ in V4 (legacy V1 used them).
```

### 3.4 What's wrong in `brick-workout.ts`

```ts
// Lines 267-282: per-segment re-runs the same flat 75% formula over its own duration
// ❌ spec wants total-workout-duration-based replacement %, shared pool across segments

// Lines 340-372: TRANSITION TARGETS HARDCODED BY DURATION TIERS
if (totalDurationMin < 90)         { 0, 0, 0 }
else if (totalDurationMin < 180)   { 0, 0, 50 }
else if (totalDurationMin < 420) { /* tier values */ }
// ❌ spec wants fixed 300 ml each transition, (300/1000)*conc sodium

// Missing entirely:
// ❌ swim 0.4× modifier feeding the total-loss budget
// ❌ run→bike redistribution when run capped at 800 ml/hr
// ❌ proper detection of swim→bike (T1) vs bike→run (T2) transitions
//    (current uses i===0 so a bike→run-only brick would still call it "T1")
```

### 3.5 What's wrong in `pre-workout.ts`

Current (lines 170-209) gates by `hoursBefore` meal-type windows (`>=2.5h`, `>=1h`, `<1h`) — **wrong windows**. Spec wants time-based (`>=120min`, `10-120min`, `<10min`). Tier 2 uses `BW × 5.5 ml` — spec wants **fixed 250 ml**. Tier 3 uses 250 ml — spec wants **0 ml**.

Sodium (lines 150-156) uses `sweatSodiumCat + envBump`: 300–700+ mg. Spec wants **fixed 450 / 150 / 0** by tier, decoupled from sweat sodium and environment.

No short-workout pre-gate (`duration < 60 && temp < 30`) is implemented.

### 3.6 Payload flow

- **Client round-trip** (no direct invoke). `generate-macros-v4` response is cached in `MacroTargets` then sent to `generate-nutrition-plan-v3` as `PlanInputV2` payload.
- Payload shape (`nutrition_plan_service.dart:136-194`):
  ```json
  {
    "macro_targets": {
      "pre_run":  {carbs_g, protein_g, fat_g, sodium_mg, water_ml, ...low/high},
      "during_run": {carbs_g, sodium_mg, water_ml, ...low/high},
      "post_run": {carbs_g, protein_g, sodium_mg, water_ml, ...low/high}
    },
    "brick_segments": [...],    // brick only
    "brick_phases":   {...}     // brick only
  }
  ```
- **Not carried forward to plan function**: `sweat_rate_category`, `sweat_sodium`, `temp_c`, `humidity_pct`, `sweat_rate_lph`, `sodium_conc_mg_per_l`. (Macros response includes `sweat_rate_lph/sodium_conc_mg_per_l/environment_label/environment_multiplier` at lines 758-761 of `single-sport.ts` but Flutter doesn't forward them.)

### 3.7 Does plan function recalculate?

- **Single-sport**: **No.** No LLM. Deterministic solvers (template → rule → LP). Grep of `sweat|hydration_rate|sodium_rate|calculateActualSweatRate` returns zero non-test matches. `adjustTargetsForOverrides` widens ranges but never mutates `sodium_mg`/`water_ml`. ✅
- **Brick**: **Yes** — `brick-handler.ts:56-142` `getTransitionTargets` recomputes T1/T2 from its own hardcoded duration tiers as a fallback. In practice the client payload populates `input.brick_phases.transitions`, so the fallback only fires if macros payload is malformed. But it exists as a latent divergence. **Needs to be deleted or zeroed** when we adopt the new spec.
- Post-workout for bricks: `brick-handler.ts:582-592` passes `post_run` through unchanged. ✅

### 3.8 Output contract returned to client

Macros v4 response has fluid/sodium totals + rates + low/high on each phase (pre/during/post) + per-segment for bricks + `sweat_rate_lph`, `sodium_conc_mg_per_l`, `environment_label`, `environment_multiplier`. These last four are not currently wired to anything Flutter-side.

Plan v3 response: echoes `macro_targets` + foods. Each `FoodResult` carries `sodium_mg` and `fluids_ml` so meal-level totals are implicit via aggregation.

### 3.9 Required changes to payloads

1. Add to `MacroInputV4`:
   - `is_indoor: bool` (new)
   - `known_sweat_rate_ml_hr: float?` (new; use this INSTEAD of declaring `optional_sweat_rate_lph` which is dead code)
   - `known_sodium_concentration_mg_L: float?` (new)
   - Switch `sweat_sodium_category` enum values `low/medium/high` → `low/average/high` (or keep `medium` as alias for compatibility; see open questions).
2. Add to `MacroTargets` return (so Flutter can render the breakdown faithfully):
   - Per-phase + per-segment `sweat_rate_lph`, `temp_mult`, `humidity_mult`, `indoor_mult`, `effective_sweat_rate_lph`, `sodium_conc_mg_per_l`, `replacement_pct`, `floor_ml_per_h`, `ceiling_ml_per_h`, `safety_flags[]`, `tested` bool (known rate used).
3. Return `temp_c`/`humidity_pct`/`is_indoor` on the plan response so the activity detail sheet can display "at 22°C, 55%, outdoor" without re-fetching from form state.

### 3.10 Files to change

| File | What |
|---|---|
| `_shared/nutrition/sweat-hydration.ts` | Rewrite rates, multipliers, add overrides, known-rate, swimming 0.4× |
| `generate-macros-v4/single-sport.ts` | Rewrite `calculateDuringWorkoutHydration` with duration-scaled %, floor, ceiling, gate, safety flags |
| `generate-macros-v4/pre-workout.ts` | Rewrite `calculatePreWorkoutTargets` with time-based tiers, fixed 250/450/etc., pre-gate |
| `generate-macros-v4/brick-workout.ts` | Rewrite multi-segment hydration with total-duration replacement, 300 ml transitions, redistribution |
| `generate-macros-v4/types.ts` | Extend return types to include derivation breakdown |
| `generate-nutrition-plan-v3/brick-handler.ts` | Delete `getTransitionTargets` hardcoded tiers (or reduce to zero-default) |
| Unit tests: `single-sport.test.ts`, new hydration/sodium test files matching `hydration_sodium_calc_tests.md` |

---

## 4. Sweat Testing — Web Research Summary

### 4.1 Standard at-home sweat rate test

Protocol (Precision Fuel & Hydration / TrainingPeaks / CTS / USA Triathlon consensus):
1. Empty bladder. Weigh nude. → `A`
2. Weigh starting fluid. → `X`
3. Workout.
4. Weigh remaining fluid. → `Y`. Post-weight nude. → `B`. Subtract 300 ml per bathroom visit.
5. `sweat_rate_L_per_hr = ((A − B) + (X − Y)) / duration_hours`

**Minimum inputs**: pre-weight, post-weight, fluid consumed, duration. **Recommended**: urine subtraction, temperature, humidity, sport, intensity (RPE).

**Reliability**: day-to-day CV ~5–7% in controlled conditions. Minimum 2–3 tests for a baseline; 1–2 tests per sport per climate tier (cool/moderate/hot) for a rich profile.

### 4.2 Sodium concentration

No validated DIY chemical test. Best self-assessment is **PF&H 6-indicator checklist**:
1. White salt stains on clothing after exercise
2. Sweat tastes very salty / stings cuts / burns eyes
3. Dizziness on standing after sweating
4. Muscle cramping with heavy sweating
5. Underperformance in heat
6. Strong salt cravings after exercise

3–4 yes → likely high sodium loser; 5–6 yes → very likely.

**Commercial tests** (for users who want a precise number):
- **Gatorade Gx Patch** — $24.99/2-pack, photo analysis via app, ±ballpark accuracy (16% hardware failure, significant variability)
- **LEVELEN** — $249 2-sport kit, lab-analyzed, highest accuracy
- **Precision Fuel & Hydration Advanced Sweat Test** — ~$75–$200, in-clinic iontophoresis
- **Emerging wearables**: FLOWBIO S1 (£329), hDrop Gen 2

**Typical concentration range**: 200–2,000 mg/L population; ~826 mg/L mean for endurance athletes (Taylor & Machado-Moreira 2019, n=1,303 reviewed by GSSI; Baker 2016 n=506 mean 826 ± 239 mg/L).

**5-tier map** usable for settings UI:
| Tier | Label | mg/L |
|---|---|---|
| 1 | Very Low | <400 |
| 2 | Low | 400–700 |
| 3 | Moderate | 700–1,100 |
| 4 | High | 1,100–1,600 |
| 5 | Very High | >1,600 |

### 4.3 Variability by sport / conditions

- Swimmers: 0.32–0.37 L/hr in-water (water cools efficiently)
- Runners: 0.8–1.8 L/hr typical
- Cyclists: 0.6–1.5 L/hr
- Higher temp → higher sweat rate (linear)
- Higher intensity → higher sweat rate
- Sodium concentration increases with sweat rate (gland reabsorption lag)
- Between-person sodium variation: mostly genetic; within-person over time: mostly heat-acclimation and dietary sodium
- Heat acclimation reduces sweat sodium 30–60% after 10 days of heat training (reversible)
- Sodium tier is stable long-term (genetic); sweat rate should be re-tested 1–2×/year or when conditions change significantly
- Single test does NOT generalize across sports

### 4.4 UX patterns from other apps

- **Precision Fuel & Hydration**: questionnaire-first ("how salty do you think your sweat is?" 5-point), in-person sweat test optional; 4 sodium product strengths (250/500/1000/1500 mg) matched to tested profile
- **LEVELEN**: test-first, lab-delivered profile by email (sweat rate, mg/L, mg/hr, product formulation)
- **Gatorade Gx**: patch → category (light/mod/heavy) + mg estimate; "weakest link" reviewed as lacking per-hour actionable targets
- **INFINIT**: tiered categorical inputs ("light/mod/heavy" + "low/med/salty") drive custom product formulation

### 4.5 Recommended data model for Mealvana

```
SweatProfile {
  id: uuid
  user_id: uuid (FK)
  sport: enum [run, bike, swim, brick, other]

  // Sweat rate
  sweat_rate_ml_per_hour: int?            // null → use category default
  sweat_rate_source: enum?                // [self_calculated, commercial_test, estimated]
  sweat_rate_test_date: date?
  sweat_rate_test_temp_c: float?          // conditions at test
  sweat_rate_test_humidity_pct: float?

  // Sodium
  sodium_mg_per_liter: int?               // null → use tier default
  sodium_source: enum?                    // [lab_test, patch_test, questionnaire]
  sodium_test_date: date?
  sodium_self_assessment_tier: int?       // 1-5 from PF&H questionnaire

  // Raw test inputs (optional, for self-calculated)
  weight_before_kg, weight_after_kg, fluid_consumed_ml,
  urine_passed_ml, session_duration_min, exercise_intensity_rpe

  // Sodium self-assessment booleans (optional)
  has_salt_stains, sweat_tastes_salty, stings_eyes,
  cramps_in_heat, underperforms_in_heat, salt_cravings
}
```

**Why per-sport**: run ≈ 1.5× swim sweat rate; profiles don't interchange.

**Defaults** (when no test entered):
| Sport | Sweat rate ml/hr | Sodium mg/L |
|---|---|---|
| Run | 1,000 | 900 |
| Bike | 800 | 800 |
| Swim | 400 | 800 |
| Brick | (use run) | (use run) |

### 4.6 Recommended settings UX flow (web researcher's proposal)

**Entry**: "Your Sweat Profile" card in settings → "Using default estimates — personalize your hydration."

**Path A — Guided in-app test wizard** (primary):
1. Sport selection
2. Pre-test checklist: weigh yourself nude, weigh bottle → record pre-weight, bottle weight
3. Post-test entry: post-weight, remaining fluid, duration, urinated? temp/humidity (auto from weather if permitted)
4. Calculation + plain-language interpretation
5. Sodium self-assessment (6-indicator checklist) OR "I have a lab result" shortcut
6. Summary + replacement % slider (default 75%; 50–90%)

**Path B — Direct entry**: form for users who already have test data.

**Display back**: headline is the derived per-hour target; inputs are collapsible secondary detail.

**Environmental adjustment**: ±15% modifier for "warmer/similar/cooler than my test" so users don't need to re-test for every condition.

**Re-test prompts**: soft nudge after 12 months, or when workout conditions differ by >15°F from test conditions, or when user starts a new sport.

---

## 5. Key Open Decisions for the Planning Conversation

(These will be asked as follow-up questions via AskUserQuestion, not decided in this document.)

1. **Sweat profile granularity**: per-sport vs. single global profile vs. hybrid (global + per-sport override)?
2. **Sweat-test UX**: guided in-app test wizard vs. direct-entry form only vs. both?
3. **Sodium category rename**: spec says `low/average/high` but current code/profile uses `medium` — rename with migration, or keep `medium` as alias?
4. **Environment on activity**: persist `temp_c`/`humidity_pct`/`is_indoor` on the `activities` table, or embed them in `nutritionPlanData` JSON?
5. **Copy source**: hardcoded in Dart (fast to ship), ContentService keys (matches CLAUDE.md rule but more plumbing), or Sanity CMS (richest but most work)?
6. **Transparency widget strategy**: generalize `CarbTransparencyData` → `NutrientTransparencyData` and reuse (recommended), or build fluids/sodium-specific widgets?
7. **When to recompute**: server-only (current) vs. client-side recomputation on every sheet open (so UI stays fresh when user edits their profile)?
8. **Replacement % override slider**: expose to users (advanced) or hardcode the duration lookup table?
9. **Offline fallback calculator**: rewrite to match new algorithm, or delete and show "hydration unavailable offline" message?
10. **Brick transparency for swim segments**: show a "no drinking during swim — T1 will cover the deficit" message, or hide fluids/sodium cards entirely?
11. **Plan-function recalculation fallback**: delete `getTransitionTargets` entirely, or keep as a zero-default?
12. **Rollout strategy**: deploy new algorithm to dev first + A/B compare, ship as `generate-macros-v5`, or in-place migration of v4?
13. **Test migration**: port `hydration_sodium_calc_tests.md` to Deno tests first (TDD) vs. after implementation?
14. **Adjust macros help sheet consolidation**: merge with activity-details sheet or leave as separate simpler help?
15. **Who owns the "known rate" sweat test UX**: settings-only, or inline edit from the transparency sheet itself (matching current carb sheet's `InlineEditType` pattern)?
