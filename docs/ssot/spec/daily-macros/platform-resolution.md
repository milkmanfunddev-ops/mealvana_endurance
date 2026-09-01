# SSOT — Daily Macros: Platform Data Resolution (Garmin / TrainingPeaks / Final Surge)

**Status: RECORDED — awaiting ratification** (2026-07-28). Source: Notion
`daily_macro_calc_iteration5_spec` (Formulas 22–27). **Engine:** B. **Conformance target:**
`calculate-daily-macros/formulas/resolve.ts` (name match only — not yet diffed).

## The rule
> Measured beats planned; planned beats estimated. Where a device or a coaching platform actually
> knows a number, that number is used instead of our formula — but the calculation itself never
> changes.

**Iteration 5 adds no nutritional formulas.** Every formula in Iterations 1–4 is untouched. What
changes is *where inputs come from*. The architectural commitment stated by the SSOT: **the
pipeline never asks "is Garmin connected?"** — it receives already-resolved values and produces the
same output regardless of origin, which is what makes it testable without platform mocks.

## Available platform data

### Garmin activity (per completed session, Activity API — `RETROSPECTIVE` only)
| Field | Garmin API field | Replaces |
|---|---|---|
| `garmin_session_kcal` | `ActiveKilocalories` | `sessionCost()` |
| `garmin_avg_hr` | `AverageHeartRateInBeatsPerMinute` | can derive IF if TP unavailable — **derivation unspecified**, see [Q-010](OPEN-QUESTIONS.md#q-010) |
| `garmin_duration_sec` | `DurationInSeconds` | planned duration |
| `garmin_sport_type` | `ActivityType` | cross-check on sport |

### Garmin daily summary (Health API, once per day after sync)
| Field | Garmin API field | Replaces |
|---|---|---|
| `garmin_daily_active_kcal` | `ActiveKilocalories` | the NEAT formula (NEAT = this − session kcal) |
| `garmin_daily_bmr_kcal` | `BmrKilocalories` | Cunningham / Mifflin-St Jeor RMR |
| `garmin_daily_total_kcal` | `TotalKilocalories` | cross-check only |
| `garmin_weight_kg` | Body Composition | athlete weight (Index scale) |
| `garmin_body_fat_pct` | Body Composition | LBM / FFM derivation |

### TrainingPeaks / Final Surge
| Field | Source | Mode | Replaces |
|---|---|---|---|
| `tp_planned_IF` | planned workout | `PROSPECTIVE` | zone distribution → IF |
| `tp_planned_TSS` | planned workout | `PROSPECTIVE` | `duration × IF² × 100` |
| `tp_planned_duration_hr` | planned workout | `PROSPECTIVE` | user-entered duration |
| `tp_actual_IF` | post-workout analysis | `RETROSPECTIVE` | planned IF |
| `tp_actual_TSS` | post-workout analysis | `RETROSPECTIVE` | planned TSS |
| `tp_tomorrow_planned` | tomorrow's calendar | `PROSPECTIVE` | manual tomorrow flag |
| `tp_CTL` | performance chart | both | weekly hours → volume tier |
| `tp_ATL` | performance chart | both | `weekly_load_ratio = ATL / CTL` |

No new user-facing input: the athlete authorizes once via OAuth, and every existing manual input
remains as a fallback.

---

## Formula 22 — `resolveSessionData(session, mode, garmin_activity, tp_data)`

Per session, each variable resolves down its own priority ladder:

```
SESSION KCAL
  RETROSPECTIVE and garmin ActiveKilocalories present  → Garmin        [GARMIN]
  else                                                 → sessionCost() [FORMULA]

IF
  RETROSPECTIVE and tp actual_IF present               → TP actual     [TP_ACTUAL]
  elif tp planned_IF present                           → TP planned    [TP_PLANNED]
  else                                                 → zoneDistributionToIF()  [ZONE_DIST]

TSS
  RETROSPECTIVE and tp actual_TSS present              → TP actual
  elif tp planned_TSS present                          → TP planned
  else                                                 → duration_hr × IF² × 100

DURATION
  RETROSPECTIVE and garmin DurationInSeconds present   → garmin / 3600
  elif tp planned_duration present                     → TP planned
  else                                                 → session.duration_hr
```

**If `kcal_source` is `FORMULA`, session kcal is recomputed with the *resolved* IF and duration** —
not the originally submitted ones. Ladders resolve independently and per session, so a day can mix
sources (session 1 `GARMIN`, session 2 `FORMULA`).

Note the asymmetry the ladders create: in retrospective mode with Garmin, **session kcal is
measured while carb demand is still modelled** — carb demand always runs Formula 5 on the resolved
IF and duration. This is why a large Garmin-vs-formula kcal gap moves fat and TDEE a lot while
barely moving carb.

---

## Formula 23 — `resolveNEAT(...)`

```
if RETROSPECTIVE and garmin_daily.ActiveKilocalories present:
  neat   = max(garmin_daily.ActiveKilocalories − session_kcal_total, 0)   # negative guarded
  source = GARMIN
else:
  neat   = calculateNEAT(rmr, volume_tier, day_mod, lifestyle)            # Iteration 3
  source = FORMULA
```

The clamp at 0 handles the real timing case where the daily summary lags the activity, making
daily active kcal *lower* than the session it should contain.

| Mode | Garmin daily | session kcal | NEAT | source |
|---|---|---|---|---|
| `RETROSPECTIVE` | 1200 | 820 | 380 | `GARMIN` |
| `RETROSPECTIVE` | 700 | 820 | **0** (clamped) | `GARMIN` |
| `RETROSPECTIVE` | null | 820 | 378 (formula) | `FORMULA` |
| `PROSPECTIVE` | connected | — | 378 (formula) | `FORMULA` — always |

---

## Formula 24 — `resolveRMR` → see [`rmr.md`](rmr.md)

---

## Formula 25 — `resolveTomorrow(tp_data, manual_tomorrow)`

```
tp_data.tomorrow_planned present  → { tss, duration_hr, is_race } from TP   [TP_CALENDAR]
elif manual_tomorrow present      → manual values                            [MANUAL]
else                              → null (no pre-load)
```

TP wins over a manual flag when both are set.

## Formula 26 — `resolveWeeklyRatio(tp_data, manual_ratio)`

```
if ATL and CTL present and CTL > 0 → ATL / CTL          [TP]
else                               → manual_ratio or 1.0 [MANUAL]
```

The `CTL > 0` guard is explicit: CTL = 0 falls back to manual rather than dividing by zero.
CTL 70 / ATL 85 → 1.21.

## Athlete profile auto-update

If Garmin body composition supplies weight or body-fat percentage, the athlete profile is updated
and the new values propagate through **everything** weight-dependent: baseline macros, session
cost, carb demand, LBM/FFM, the fat floor and both clamps. Example: weight 74.2 kg with BF 15.5 %
→ LBM 62.7 → protein base `1.8 × 62.7 = 113 g`.

---

## Formula 27 — `recalculateAfterSync(...)`

Re-runs the full pipeline in `RETROSPECTIVE` mode and reports the movement for the UX:

```
retro_plan = dailyMacros_v5(..., mode = RETROSPECTIVE, garmin_activity, garmin_daily, tp_actual)

delta = {
  carb:         retro.carb_g       − prospective.carb_g,
  prot:         retro.prot_g       − prospective.prot_g,
  fat:          retro.fat_g        − prospective.fat_g,
  tdee:         retro.tdee         − prospective.tdee,
  session_kcal: retro.session_kcal − prospective.session_kcal,
}

return { plan: retro_plan, delta, sources: retro_plan.sources }
```

**A skipped workout is a first-class case:** no Garmin activity synced → the retrospective run
reverts to a rest day (`session_kcal = 0`, carb back to ≈ baseline).

---

## Worked end-to-end example (verified)

Reference athlete, 90-min run, `BASE`, ratio 1.0, Garmin + TP connected, Garmin daily
`ActiveKilocalories = 1200`:

| Variable | Prospective (morning) | Retrospective (post-sync) | Source change |
|---|---|---|---|
| RMR | 1908 (Cunningham) | 1920 (Garmin BMR) | `FORMULA → GARMIN` |
| Session kcal | 1205 (formula, IF 0.74) | 892 (Garmin measured) | `FORMULA → GARMIN` |
| IF | 0.74 (TP planned) | 0.76 (TP actual) | `TP_PLANNED → TP_ACTUAL` |
| Carb demand | 69 g | 74 g | recalculated from IF |
| NEAT | 378 (formula) | 308 (= 1200 − 892) | `FORMULA → GARMIN` |
| TEF | 387 (iterative) | 346 (iterative) | always `FORMULA` |
| **carb** | 369 | 374 | +5 |
| **prot** | 130 | 130 | unchanged |
| **fat** | 209 | 161 | −48 |
| **TDEE** | 3878 | 3466 | −412 |

Cross-checks: retro TDEE = `(1920 + 308 + 892) / 0.9 = 3466.7` ✓ (fat above floor, so the closed
form applies); retro fat = `(3466 − 1496 − 520) / 9 = 161.1` ✓; retro carb = `300 + 73.5` where the
IF-0.76 rate is `40 + 0.6 × 15 = 49 g/hr` over 1.5 hr ✓.

**The insight the SSOT draws from this**: measured session cost (892) is far below the formula
estimate (1205), which drops TDEE by 412 kcal. Carb barely moves — it keys off IF, not kcal — but
fat, the residual, absorbs almost the whole difference.

## Regression requirement

With `garmin_connected = false` and `tp_connected = false`, output must be **identical to
Iteration 4** for the same inputs, and no `GARMIN` or `TP*` source tags may appear anywhere in the
output. Every Iteration 1–4 case must still pass unchanged.

## `sources` object

Must carry a source tag for: `rmr`, `neat`, `session_kcal` (array, one per session), `IF` (array,
one per session), `tomorrow`, `weekly_ratio`. Tag vocabulary observed across the ladders:
`GARMIN`, `TP_ACTUAL`, `TP_PLANNED`, `TP`, `TP_CALENDAR`, `ZONE_DIST`, `FORMULA`, `MANUAL`. The
SSOT does not fully specify the object's shape — see [Q-012](OPEN-QUESTIONS.md#q-012).

## Deferred by the SSOT (explicitly, not oversights)
- **CTL staleness detection** — a CTL over 30 days old is used anyway; deferred to "v2.1".
- **HR-derived IF** — listed as a capability of `garmin_avg_hr` and referenced by an edge case
  ("TP IF takes priority over Garmin HR-derived IF"), but no derivation is given and the IF ladder
  in Formula 22 has no Garmin rung. See [Q-010](OPEN-QUESTIONS.md#q-010).
