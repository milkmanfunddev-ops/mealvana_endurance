> Mirrored from Notion: https://www.notion.so/daily_macro_calc_iteration5_tests-328e3fdb754c8084b164d40cb9a32fd9
> Last edited (Notion): 2026-03-19T19:31:00.000Z
> **Authoritative source is Notion.** Edit there and re-mirror.

# Macro Calculator — Iteration 5 Test Cases

Run these against the implementation. All Iteration 1–4 tests must also still pass with no connected platforms (regression).

Reference athlete: Male, 34yr, 75kg, 178cm, BF 14.7% → LBM 64kg, RMR 1908. Serious tier, DESK lifestyle.
Tolerances: carb/prot ±5%, fat ±15%, TDEE ±5%.

---

## Data Source Priority — Session kcal

| Mode | Garmin Available? | Expected Source | Notes |
| --- | --- | --- | --- |
| RETROSPECTIVE | ActiveKcal = 892 | GARMIN (892) | Measured replaces formula |
| RETROSPECTIVE | null | FORMULA | Falls back to sessionCost() |
| PROSPECTIVE | Connected but no activity yet | FORMULA | Activity data doesn't exist pre-workout |
| PROSPECTIVE | Not connected | FORMULA | Same as Iter 1–4 |

## Data Source Priority — IF

| Mode | TP Available? | Expected Source |
| --- | --- | --- |
| RETROSPECTIVE | actual_IF = 0.82 | TP_ACTUAL (0.82) |
| RETROSPECTIVE | planned_IF = 0.74, no actual | TP_PLANNED (0.74) |
| PROSPECTIVE | planned_IF = 0.74 | TP_PLANNED (0.74) |
| Either | null | ZONE_DIST (from app input) |

## Data Source Priority — NEAT

| Mode | Garmin Daily? | Session kcal | Expected NEAT | Source |
| --- | --- | --- | --- | --- |
| RETRO | ActiveKcal = 1200 | 820 | 380 | GARMIN |
| RETRO | ActiveKcal = 700 | 820 | 0 (clamped, negative guarded) | GARMIN |
| RETRO | null | 820 | 378 (formula) | FORMULA |
| PROSPECTIVE | Connected | n/a | 378 (formula, always in prospective) | FORMULA |

## Data Source Priority — RMR

| Garmin Daily? | Expected RMR | Source |
| --- | --- | --- |
| BmrKilocalories = 1920 | 1920 | GARMIN |
| null, LBM known | 1908 (Cunningham) | FORMULA |
| null, no LBM | 1698 (Mifflin-St Jeor) | FORMULA |

## Data Source Priority — Tomorrow & Weekly Ratio

| Test | TP Available? | Manual Input? | Expected Source |
| --- | --- | --- | --- |
| TP calendar has tomorrow | TSS=180, dur=2.5hr | Manual flag also set | TP_CALENDAR (TP wins) |
| No TP, manual flag | null | is_race=true | MANUAL |
| Neither | null | null | null (no pre-load) |
| TP CTL=70, ATL=85 | CTL=70, ATL=85 | manual_ratio=1.0 | TP (ratio = 85/70 = 1.21) |
| No TP, manual ratio | null | manual_ratio=1.15 | MANUAL (1.15) |
| TP CTL=0 (division guard) | CTL=0 | manual_ratio=1.0 | MANUAL (CTL=0, can't divide) |

## Retrospective Recalculation — Deltas

Morning plan vs. post-sync. Verify deltas computed correctly.

| Test | Prospective | Actual (Retro) | Expected Delta Direction |
| --- | --- | --- | --- |
| Harder than planned | session_kcal=1205, IF=0.74 | Garmin kcal=1400, TP IF=0.82 | carb up, tdee up, fat adjusts |
| Easier than planned | session_kcal=1297, IF=0.93 | Garmin kcal=950, TP IF=0.80 | carb down, tdee down, fat adjusts |
| Workout skipped | session_kcal=1205, carb=369g | No Garmin activity synced | Reverts to rest-day: carb≈300g, session_kcal=0 |
| Garmin NEAT lower | NEAT=378 (formula) | Garmin daily NEAT=210 | TDEE down. Fat down. Carb/prot unchanged. |
| Duration longer | dur=1.5hr | Garmin dur=2.0hr | session_kcal up, carb_demand up |

## Weight/BF Auto-Update from Garmin

| Test | Garmin Body Comp | Expected |
| --- | --- | --- |
| Scale syncs new weight | weight_kg = 74.2 | All weight-dependent calcs use 74.2 |
| Scale syncs new BF% | body_fat_pct = 15.5 | LBM = 74.2 × (1−0.155) = 62.7. Protein base = 1.8 × 62.7 = 113g |
| No scale data | null | Uses existing profile values |

## CTL → Volume Tier

| CTL | Expected Tier | base_neat |
| --- | --- | --- |
| 0 | RECREATIONAL | 0.30 |
| 20 | RECREATIONAL | 0.30 |
| 30 (boundary) | MODERATE | 0.25 |
| 45 | MODERATE | 0.25 |
| 55 (boundary) | SERIOUS | 0.20 |
| 65 | SERIOUS | 0.20 |
| 85 (boundary) | HIGH_VOLUME | 0.17 |
| 100 | HIGH_VOLUME | 0.17 |
| 120 (boundary) | PROFESSIONAL | 0.13 |
| 130 | PROFESSIONAL | 0.13 |

## Regression — No Platforms Connected

| Test | Expected |
| --- | --- |
| garmin_connected=false, tp_connected=false | Output identical to Iteration 4 for same inputs |
| All resolve functions return FORMULA/MANUAL/ZONE_DIST | No GARMIN or TP source tags in output |
| Every Iter 1–4 test case still passes | Algorithm works identically without integrations |

## End-to-End with Simulated Platform Data

Reference athlete, 90-min run, BASE phase, ratio 1.0. Garmin + TP connected. Garmin daily ActiveKilocalories = 1200.

| Variable | Prospective (morning) | Retrospective (post-sync) | Source Change |
| --- | --- | --- | --- |
| RMR | 1908 (Cunningham) | 1920 (Garmin BMR) | FORMULA → GARMIN |
| Session kcal | 1205 (formula, IF=0.74) | 892 (Garmin measured) | FORMULA → GARMIN |
| IF | 0.74 (TP planned) | 0.76 (TP actual) | TP_PLANNED → TP_ACTUAL |
| Carb demand | 69g (from IF 0.74) | 74g (from IF 0.76) | Recalculated |
| NEAT | 378 (formula) | 308 (Garmin: 1200 − 892) | FORMULA → GARMIN |
| TEF | 387 (iterative) | 346 (iterative) | Always FORMULA |
| Final carb | 369g | 374g | +5g |
| Final prot | 130g | 130g | Unchanged |
| Final fat | 209g | 161g | −48g |
| TDEE | 3878 | 3466 | −412 kcal |

Key insight: Garmin measured session kcal (892) is much lower than formula estimate (1205) for this session. This drops TDEE by 412 kcal. Carb barely changes (+5g, from slightly higher actual IF) but fat drops 48g because fat is the residual that absorbs TDEE changes.

## Edge Cases

| Test | Expected |
| --- | --- |
| Garmin syncs mid-day but daily summary not yet complete | Use Garmin activity data for session kcal; use formula NEAT (daily not available yet) |
| TP planned IF exists but Garmin also has HR data | TP IF takes priority over Garmin HR-derived IF |
| Garmin daily ActiveKcal < session_kcal (timing issue) | NEAT = max(0, daily − session). Clamped, not negative. |
| Multiple sessions: Garmin has data for 1st but not 2nd | 1st session: GARMIN source. 2nd session: FORMULA source. Mixed sources per session. |
| TP CTL exists but is very old (>30 days stale) | Still use it — staleness detection is a v2.1 feature |
| Weight auto-update would change all Iter 1–4 outputs | Verify weight propagates: baseline macros, session cost, carb demand, fat floor all recalculated |
| sources object in output | Must contain: rmr, neat, session_kcal (array), IF (array), tomorrow, weekly_ratio. Each with source tag. |
