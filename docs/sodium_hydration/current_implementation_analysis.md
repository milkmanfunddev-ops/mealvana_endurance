# Current Hydration & Sodium Implementation — Codebase Analysis

**Analyzed:** 2026-04-09
**Source files:**
- `supabase/functions/_shared/nutrition/sweat-hydration.ts` — sweat rate, sodium concentration, environment classification
- `supabase/functions/generate-macros-v4/single-sport.ts` — during-workout hydration/sodium calculation
- `supabase/functions/generate-macros-v4/pre-workout.ts` — pre-workout hydration/sodium calculation

---

## Current Algorithm Summary

### Sweat Rate (sweat-hydration.ts:19-44)

**Base rates by category:**
```
light:    0.75 L/hr
medium:   1.25 L/hr
heavy:    2.00 L/hr
```

**Temperature adjustment:**
```ts
// Baseline: 20°C (not 22°C)
// No upper/lower clamp
tempAdjustment = 1.0 + max(0, (tempC - 20) * 0.04)
```

**Humidity:** Parameter accepted but **ignored** (prefixed with `_humidityPct`).

**Indoor adjustment:** Not implemented.

**Known sweat rate override:** Not implemented — always uses category lookup.

**Swimming sweat modifier:** Not implemented for during-workout hydration (swimming gets 0 carbs in v3 but no sweat rate reduction).

### Environment Classification (sweat-hydration.ts:5-17)

Uses **categorical buckets** (not continuous multiplier):
```
temp <= 10                     → 0.85, "cool"
temp <= 20 AND humidity <= 60  → 1.0,  "temperate"
temp <= 25 OR humidity 60-75   → 1.1,  "warm"
temp <= 30 OR humidity 75-85   → 1.2,  "hot"
else                           → 1.3,  "very_hot"
```
This is used for pre-workout sodium bump only, NOT for sweat rate calculation.

### Sodium Concentration (sweat-hydration.ts:26-31)

```
low:      550 mg/L
medium:   925 mg/L
high:    1150 mg/L
```

**Known sodium concentration override:** Not implemented.

### During-Workout Hydration (single-sport.ts:115-148)

**Flat 75% replacement** regardless of duration:
```ts
hydrationRateMlph = actualSweatRateLph * 1000 * 0.75
```

No floor, ceiling, gate, or safety check.

### During-Workout Sodium (single-sport.ts:115-148)

**Flat 60% replacement** of total sodium loss:
```ts
sodiumRateMgph = actualSweatRateLph * sodiumConcMgPerL * 0.6
```

Not derived from fluid rate — calculated independently.

### Pre-Workout Hydration (pre-workout.ts:126-227)

**Body-weight-scaled** with meal-type tiers (not time-gated):
```
Full meal (>=2.5 hr):  weightKg × 6.5 ml   range: 50%-150%
Snack (1.0-2.5 hr):   weightKg × 5.5 ml   range: 50%-150%
Top-up (<1.0 hr):      250 ml (fixed)      range: 0-500
```

### Pre-Workout Sodium (pre-workout.ts:150-156)

**Sweat-category-dependent**, not fixed:
```
baseSodium = low: 300, medium: 450, high: 600
envBump = hot/very_hot: +100, else: 0

Full meal:  mealSodium + snackSodium + topUpSodium  (range: 200-2000)
Snack:      snackSodium + topUpSodium                (range: 100-1000)
Top-up:     envBump + 100                             (range: 0-400)
```

### Post-Workout Recovery (single-sport.ts:182-202)

```
Sodium deficit = total_loss - during_sodium (60%)
Post sodium = 50% of deficit, clamped 300-700 mg

Hydration deficit = total_loss - during_hydration
Post hydration = 150% of deficit, min 500 ml
```

---

## Gap Analysis: Current Code vs. New Spec

### Sweat Rate Calculation

| Aspect | Current Code | New Spec | Delta |
|--------|-------------|----------|-------|
| **Base rates** | 0.75 / 1.25 / 2.00 | 0.90 / 1.28 / 1.66 | New uses Barnes/Baker 2019 percentiles (25th/50th/75th) instead of round numbers |
| **Temp baseline** | 20°C | 22°C | Jenkins 2023 updated baseline |
| **Temp clamp** | None (unbounded) | 0.50 – 1.80 | Prevents extreme multipliers |
| **Humidity** | Ignored | max 1.10× above 50% RH | Small effect added |
| **Indoor** | Not implemented | 1.30× | New feature |
| **Known sweat rate** | Not supported | Overrides category | New feature — eliminates biggest estimation error |
| **Swimming modifier** | Not applied to hydration | 0.4× on sweat rate | New — reduces swimming sweat estimate |
| **Overall clamp** | None | 0.3 – 3.0 L/hr | Prevents impossible values |

### Sodium Concentration

| Aspect | Current Code | New Spec | Delta |
|--------|-------------|----------|-------|
| **Categories** | low/medium/high | low/average/high | Renamed "medium" → "average" |
| **Values (mg/L)** | 550 / 925 / 1150 | 650 / 825 / 1000 | New uses Baker 2016 percentiles (25th/50th/75th). Current values are different and not well-sourced |
| **Known concentration** | Not supported | Overrides category | New feature |

### During-Workout Hydration

| Aspect | Current Code | New Spec | Delta |
|--------|-------------|----------|-------|
| **Replacement %** | Flat 75% always | Duration-scaled: 30/50/60/70/80% | Major change — current over-recommends for short workouts, under-recommends for ultra |
| **<60 min gate** | None | "Drink to thirst" + 30% conservative guardrail | New — avoids unnecessary structured plans |
| **Floor (2% BW)** | None | min intake to stay within 2% BW loss | New safety feature |
| **Ceiling (GI + hyponatremia)** | None | Running 800, Cycling 1200 ml/hr; capped at 100% sweat rate | New safety feature |
| **Multi-segment transitions** | None | T1/T2 at 300 ml each | New — reduces per-segment rate requirements |
| **Run→bike redistribution** | None | If run ceiling hit, shift shortfall to bike | New — handles multi-sport GI constraints |
| **Safety check** | None | Flags >2% and >3% BW deficit | New |

### During-Workout Sodium

| Aspect | Current Code | New Spec | Delta |
|--------|-------------|----------|-------|
| **Calculation** | Independent: sweat_rate × conc × 0.6 | Derived: (fluid_ml_hr / 1000) × conc | Fundamental redesign — sodium now rides on fluid |
| **Replacement target** | 60% of total sodium loss | 100% of sodium in consumed fluid | Different approach: current replaces a % of loss; new matches sweat concentration in whatever you drink |
| **Floor/ceiling** | None | Inherits from fluid algorithm | New |
| **Gate/duration logic** | None | Inherits from fluid algorithm | New |

### Pre-Workout Hydration

| Aspect | Current Code | New Spec | Delta |
|--------|-------------|----------|-------|
| **Gating** | By meal type (>=2.5h / >=1h / <1h) | By time (>=120min / 10-120min / <10min) + workout gate | Different time boundaries |
| **Tier 1 fluid** | weightKg × 6.5 ml | weightKg × 6 ml/kg (range: 5-7) | Slightly lower midpoint; explicit ACSM range |
| **Tier 2 fluid** | weightKg × 5.5 ml | 250 ml (fixed) | Major change — current scales by weight, new is fixed |
| **Tier 3 fluid** | 250 ml | 0 (sips only) | New says too late for structured intake |
| **Workout gate** | None | <60 min AND <30°C → no plan | New |

### Pre-Workout Sodium

| Aspect | Current Code | New Spec | Delta |
|--------|-------------|----------|-------|
| **Approach** | Sweat-category-dependent, complex formula | Fixed by time window: 450 / 150 / 0 mg | Major simplification |
| **Tier 1** | baseSodium + envBump (300-700+) | 450 mg (range 300-600) | Simplified, evidence-based |
| **Tier 2** | snackSodium + topUpSodium (150-400) | 150 mg (range 100-200) | Simplified |
| **Rationale** | Replace anticipated loss | Retain consumed fluid (different purpose) | Conceptual shift |

### Post-Workout Recovery

| Aspect | Current Code | New Spec | Delta |
|--------|-------------|----------|-------|
| **Coverage** | Implemented (sodium 50% deficit capped 300-700; hydration 150% deficit min 500) | Not covered in new spec | New spec doesn't address post-workout yet — keep current? |

---

## Key Code Locations for Migration

| File | Lines | What to Change |
|------|-------|---------------|
| `supabase/functions/_shared/nutrition/sweat-hydration.ts` | 19-24 | Update base sweat rates: 0.75→0.90, 1.25→1.28, 2.0→1.66 |
| `supabase/functions/_shared/nutrition/sweat-hydration.ts` | 26-31 | Update sodium concentrations: 550→650, 925→825, 1150→1000 |
| `supabase/functions/_shared/nutrition/sweat-hydration.ts` | 33-44 | Rewrite: add humidity, indoor, known rate, clamping, temp baseline 22°C |
| `supabase/functions/_shared/nutrition/sweat-hydration.ts` | 5-17 | `classifyEnvironment` — may still be used for pre-workout envBump; needs review |
| `supabase/functions/generate-macros-v4/single-sport.ts` | 115-148 | Rewrite `calculateDuringWorkoutHydration`: duration-scaled %, floor/ceiling, gate |
| `supabase/functions/generate-macros-v4/single-sport.ts` | 182-202 | `calculatePostWorkoutHydration` — keep as-is? New spec doesn't cover this |
| `supabase/functions/generate-macros-v4/pre-workout.ts` | 126-227 | Rewrite `calculatePreWorkoutTargets` hydration/sodium: time-gated, fixed sodium |
| `supabase/functions/generate-macros-v3/index.ts` | ~838-956 | Multi-segment (brick/tri) hydration needs T1/T2 transitions + redistribution |

### New Code Needed

| Component | Description |
|-----------|-------------|
| **Duration-scaled replacement %** | Lookup function: <60→0.30, 60-90→0.50, etc. |
| **Floor/ceiling calculation** | 2% BW floor, GI ceiling (800 running, 1200 cycling), 100% sweat cap |
| **Gate logic** | <60 min AND <30°C → drink-to-thirst message |
| **Multi-segment hydration** | T1/T2 detection, transition fluid, redistribution from run→bike |
| **Safety check** | >2% and >3% BW deficit flags |
| **Swimming sweat modifier** | 0.4× applied to effective sweat rate |
| **Indoor multiplier** | 1.30× when is_indoor=true |
| **Known rate/concentration** | Accept and use override values from athlete profile |

---

## Database / Profile Changes Likely Needed

| Field | Status | Notes |
|-------|--------|-------|
| `sweater_type` | Exists | Values need to stay compatible (light/medium/heavy) |
| `sweat_sodium_category` | Exists | Rename "medium" → "average" in code (or map) |
| `known_sweat_rate_ml_hr` | **New** | Optional float, overrides sweater_type |
| `known_sodium_concentration_mg_L` | **New** | Optional float, overrides salt_type |
| `is_indoor` | **New** | Boolean on activity, not profile |
| `salt_type` indicators | **New** | Self-report UI for sodium category (white residue, stinging eyes, etc.) |
