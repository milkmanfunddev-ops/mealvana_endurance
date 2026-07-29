> Mirrored from Notion: https://www.notion.so/daily_macro_calc_iteration5_spec-328e3fdb754c80149d4ec49f61f6e502
> Last edited (Notion): 2026-03-19T19:31:00.000Z
> **Authoritative source is Notion.** Edit there and re-mirror.

# Macro Calculator — Iteration 5 Spec

Adds Garmin and TrainingPeaks/Final Surge API integration. No new nutritional formulas — every formula from Iterations 1–4 is unchanged. What changes is where inputs come from: measured platform data replaces manual input and formula estimates wherever available.

The core addition is a set of "resolve" functions between data sources and the pipeline. The pipeline never checks "is Garmin connected?" — it receives resolved values and produces the same output regardless of source. This means the pipeline is testable without platform mocks.

---

## New Inputs (in addition to Iterations 1–4)

### Platform Connection (system-level, set via OAuth)

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| garmin_connected | boolean | false | Whether athlete authorized Garmin Health API |
| tp_connected | boolean | false | Whether athlete authorized TrainingPeaks or Final Surge |

### Garmin Activity Data (per completed session, from Activity API)

Available only in RETROSPECTIVE mode after device sync.

| Field | Garmin API Field | Type | Replaces |
| --- | --- | --- | --- |
| garmin_session_kcal | ActiveKilocalories | int | sessionCost() formula |
| garmin_avg_hr | AverageHeartRateInBeatsPerMinute | int | Can derive IF if TP unavailable |
| garmin_duration_sec | DurationInSeconds | int | Planned duration |
| garmin_sport_type | ActivityType | string | Cross-check sport |

### Garmin Daily Summary (from Health API, once per day after sync)

| Field | Garmin API Field | Type | Replaces |
| --- | --- | --- | --- |
| garmin_daily_active_kcal | ActiveKilocalories | int | NEAT formula (NEAT = this − session_kcal) |
| garmin_daily_bmr_kcal | BmrKilocalories | int | Cunningham/Mifflin-St Jeor RMR |
| garmin_daily_total_kcal | TotalKilocalories | int | Cross-check only |
| garmin_weight_kg | Body Composition endpoint | float | Athlete weight (if Index scale paired) |
| garmin_body_fat_pct | Body Composition endpoint | float | LBM/FFM derivation |

### TrainingPeaks / Final Surge Data

| Field | Source | Mode | Replaces |
| --- | --- | --- | --- |
| tp_planned_IF | Planned workout | PROSPECTIVE | Zone distribution → IF |
| tp_planned_TSS | Planned workout | PROSPECTIVE | duration × IF² × 100 |
| tp_planned_duration_hr | Planned workout | PROSPECTIVE | User-entered duration |
| tp_actual_IF | Post-workout analysis | RETROSPECTIVE | Planned IF |
| tp_actual_TSS | Post-workout analysis | RETROSPECTIVE | Planned TSS |
| tp_tomorrow_planned | Tomorrow's calendar | PROSPECTIVE | Manual tomorrow flag |
| tp_CTL | Performance chart | Both | weekly_hours → volume tier |
| tp_ATL | Performance chart | Both | weekly_load_ratio = ATL / CTL |

### No New User-Facing Inputs

Athlete authorizes platforms once (OAuth). Existing manual inputs remain as fallbacks.

### Output (extended from v4)

```
{ carb_g, prot_g, fat_g, tdee, rmr, session_kcal, neat_kcal, tef_kcal,
  mode, ea, ea_status, sources, delta }
```

`sources` tracks which source was used per variable. `delta` is populated in retrospective mode.

---

## New Formulas

### 22. resolveSessionData(session, mode, garmin_activity, tp_data)

For a single session, select best available source for each variable:

```
SESSION KCAL:
  if mode == RETROSPECTIVE AND garmin_activity.ActiveKilocalories exists:
    → garmin value.  source: GARMIN
  else:
    → sessionCost(sport, duration, IF, weight).  source: FORMULA

IF:
  if mode == RETROSPECTIVE AND tp_data.actual_IF exists:
    → tp actual.  source: TP_ACTUAL
  elif tp_data.planned_IF exists:
    → tp planned.  source: TP_PLANNED
  else:
    → zoneDistributionToIF(session percentages).  source: ZONE_DIST

TSS:
  if mode == RETROSPECTIVE AND tp_data.actual_TSS exists:  → tp actual
  elif tp_data.planned_TSS exists:  → tp planned
  else:  → duration_hr × IF² × 100

DURATION:
  if mode == RETROSPECTIVE AND garmin_activity.DurationInSeconds exists:
    → garmin value / 3600
  elif tp_data.planned_duration exists:  → tp planned
  else:  → session.duration_hr

If kcal_source is FORMULA, recompute session_kcal with the resolved IF and duration.

return { session_kcal, IF, TSS, duration, kcal_source, if_source }
```

### 23. resolveNEAT(mode, garmin_daily, session_kcal_total, rmr, volume_tier, day_mod, lifestyle)

```
if mode == RETROSPECTIVE AND garmin_daily.ActiveKilocalories exists:
  neat = garmin_daily.ActiveKilocalories − session_kcal_total
  neat = max(neat, 0)       // guard against negative
  source = GARMIN
else:
  neat = calculateNEAT(rmr, volume_tier, day_mod, lifestyle)   // Iter 3 formula
  source = FORMULA

return { neat, source }
```

### 24. resolveRMR(garmin_daily, athlete)

```
if garmin_daily.BmrKilocalories exists:
  → garmin value.  source: GARMIN
else:
  → calculateRMR(athlete).  source: FORMULA
```

### 25. resolveTomorrow(tp_data, manual_tomorrow)

```
if tp_data.tomorrow_planned exists:
  → { tss, duration_hr, is_race } from TP calendar.  source: TP_CALENDAR
elif manual_tomorrow exists:
  → manual values.  source: MANUAL
else:
  → null (no pre-load)
```

### 26. resolveWeeklyRatio(tp_data, manual_ratio)

```
if tp_data.ATL AND tp_data.CTL AND tp_data.CTL > 0:
  → ATL / CTL.  source: TP
else:
  → manual_ratio or 1.0.  source: MANUAL
```

### CTL → Volume Tier (extends Formula 12)

When TP provides CTL, replaces weekly_hours for volume tier:

| CTL | Volume Tier | base_neat |
| --- | --- | --- |
| < 30 | RECREATIONAL | 0.30 |
| ≥30 and < 55 | MODERATE | 0.25 |
| ≥55 and < 85 | SERIOUS | 0.20 |
| ≥85 and < 120 | HIGH_VOLUME | 0.17 |
| ≥ 120 | PROFESSIONAL | 0.13 |

### 27. recalculateAfterSync(prospective_plan, garmin_activity, garmin_daily, tp_actual)

Re-runs full pipeline in RETROSPECTIVE mode, computes deltas for UX.

```
retro_plan = dailyMacros_v5(..., mode=RETROSPECTIVE, garmin_activity, garmin_daily, tp_actual)

delta = {
  carb:  retro_plan.carb_g − prospective_plan.carb_g,
  prot:  retro_plan.prot_g − prospective_plan.prot_g,
  fat:   retro_plan.fat_g − prospective_plan.fat_g,
  tdee:  retro_plan.tdee − prospective_plan.tdee,
  session_kcal: retro_plan.session_kcal − prospective_plan.session_kcal,
}

return { plan: retro_plan, delta, sources: retro_plan.sources }
```

### 28. dailyMacros_v5 (updated assembly)

Same pipeline as v4 but inputs pass through resolve functions first.

```
1.  Resolve global inputs:
    rmr = resolveRMR(garmin_daily, athlete)
    tomorrow = resolveTomorrow(tp_data, manual_tomorrow)
    weekly_ratio = resolveWeeklyRatio(tp_data, manual_ratio)
    If garmin provides weight/BF: update athlete profile

2.  Resolve per-session data:
    For each session: resolveSessionData(session, mode, garmin_act, tp_sess)

3–9. Run Iteration 4 pipeline (Steps 1–9) with resolved values
     Step 8 NEAT: resolveNEAT() instead of always formula

10. Track sources in output object

11. Return { ..., sources, delta }
```

---

## Test Cases

Test cases are provided in a separate file (`iteration5_tests.md`) and should be run after implementation is complete. All Iteration 1–4 tests must also still pass with no connected platforms.
