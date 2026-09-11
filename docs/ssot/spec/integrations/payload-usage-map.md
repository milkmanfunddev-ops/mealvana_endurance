# SSOT — Integrations: payload → usage map (the field manual)

**Status: RATIFIED (Xuan, 2026-09-10, ruling desk).** Drafted 2026-09-08/09 from `app@c4abec2a`; `[observed]` clauses ratified; `[divergence]`/`[gap]` clauses carry the 2026-09-10 Q-INT rulings or remain OPEN per [`OPEN-QUESTIONS.md`](OPEN-QUESTIONS.md).
Per provider: every payload field the API sends → its current disposition → its potential
usage. Sources: `app/docs/integration/api-exploration/` field references (evidence markers
preserved: *(payload)* = confirmed in samples, *(spec)* = vendor doc only) cross-checked
against the transformers at `app@c4abec2a`. The capture shortlist at §6 feeds **Q-INT26**.

**Disposition legend** — `CAPTURED` stored and consumed · `STORED-DEAD` stored, zero
readers · `BUCKETED` read only to derive a coarser value, number then dropped ·
`DISCARDED` reachable in the parsed payload, never stored · `UNHANDLED` payload type
ignored entirely · `NOT-FETCHED` endpoint exists, never called.

## 1 · TrainingPeaks

### 1.1 Planned workout
| Fields | Disposition | Potential usage |
|---|---|---|
| `Id`, `WorkoutDay`, `WorkoutType`, `Title`, `Description`, `StartTimePlanned`, `TotalTimePlanned`, `DistancePlanned` | **CAPTURED** → `activities` row | — |
| `TSSPlanned`, `IFPlanned` | **BUCKETED** — only pick easy/moderate/hard; numbers dropped | feed `activities.tss` + a persisted per-session IF → engine's `TP_PLANNED` ladder rungs (today dead) |
| `CaloriesPlanned` (kcal), `ElevationGainPlanned` | **BUCKETED into notes text** | the only provider-planned calories — a planned-day energy cross-check against F4 |
| `EnergyPlanned` (kJ), `Tags`, `StructureDisplayUnit`, `Locked`, `Hidden` | **DISCARDED** | low |

### 1.2 Completed workout — the biggest loss surface
| Fields | Disposition | Potential usage |
|---|---|---|
| `TssActual`, `IF` | **DISCARDED (never parsed)** | the engine's `TP_ACTUAL` ladder rungs — highest-value capture in the whole map |
| `HeartRateAverage/Minimum/Maximum` | DISCARDED | HR-derived IF (Q-010) without Garmin |
| `PowerAverage/Maximum`, `NormalizedPower` | DISCARDED | real cycling load; FTP calibration |
| `Calories`, `Energy` | DISCARDED | measured kcal rung for non-Garmin athletes (F22 today requires Garmin) |
| `VelocityAverage/Maximum`, `NormalizedSpeed`, `Cadence*`, `Torque*`, `Elevation*`, `Temp*` | DISCARDED | pace/mechanics analytics |
| `Rpe` (1–10), `Feeling` | DISCARDED | subjective-load signal; skip/fatigue heuristics |

**Caveat:** for **basic (non-premium) TP athletes every field in 1.2 plus TSS/IF/calories
planned returns null** — capture value concentrates on premium athletes.

### 1.3 Athlete profile (`/v1/athlete/profile`, fetched once at connect)
`FirstName/LastName/Email/Sex/BirthMonth/Weight(kg)` **CAPTURED** → `integrations.provider_athlete_*`;
`TimeZone`, `CoachedBy`, `IsPremium`, `PreferredUnits` **DISCARDED** — `IsPremium` is worth
keeping (it predicts 1.2 nulls and write-back 403s); no refresh cadence exists (Q-INT26).

### 1.4 Zones (`/v1/athlete/profile/zones`, 24 h staleness)
**CAPTURED (lossily) → `athlete_zones_json`**: only `Default` HR/power sets survive,
`WorkoutType` labels dropped; stored LTHR/FTP/maxHR/restingHR are STORED-DEAD (Q-INT19).

### 1.5 Events / races
`EventDate`, `EventType`, `Name` CAPTURED via race import. `Goals[]`
(`Distance/Time/Place/Pr` + value + unit) and `WorkoutIds` — **DISCARDED**; the app's own
event page asks the athlete for exactly these goals (Xuan, 2026-09-09 — capture them to
prefill it; shortlist item 10). Events sync with `syncAll` on the same 4 h staleness
clock as workouts, 45-day window. **No provider anywhere exposes A/B/C race priority.**

### 1.6 `Structure` (structured steps)
`Length`, `IntensityClass`, `IntensityTarget.{Unit,Value,Min,Max}` (`PercentOfFtp` /
`PercentOfMaxHr` / `PercentOfThresholdHr` / `PercentOfThresholdSpeed` / `Rpe`, fractions),
`CadenceTarget`, `RepeatCount`, nested `Steps` — **BUCKETED** into the three
`intensity_z*_pct` integers; the numeric prescriptions are dropped. Potential: exact
in-workout demand modelling; TP itself recomputes TSS/IF from a valid Structure.

### 1.7 Metric object (`/v2/metrics/...`) — **NOT-FETCHED**
Documented endpoint (premium-only reads): `WeightInKilograms`, `HRV` (ms), `Steps`,
`Stress`, `SleepQuality`, `DateTime`, `UploadClient`. **This is the TP weight-staleness
fix** (ongoing weight without Garmin) and the only non-Garmin HRV source. It is a
body-metrics store — **not** CTL/ATL: no provider exposes CTL/ATL/TSB at all, so Q-INT17's
feed would have to be computed in-house from captured TSS.

### 1.8 Nutrition (write-side)
`Calories/Carbohydrates/Fat/Protein` per day — our write-back surface (TP-5 / Q-INT16).

## 2 · Final Surge

### 2.1 Workout object
| Fields | Disposition | Notes |
|---|---|---|
| `WorkoutKey/URL/Date/Time/TypeName/Title/Description`, `PlannedTime`(s), `PlannedDistance(+Type)` | **CAPTURED** | the FS producer contract (FS-2) |
| `WorkoutSubTypeName`, `PlannedPace(+Type)` | **computed then DISCARDED** (Q-INT13) | subtype feeds speed-work exclusion; pace feeds the duration ladder |
| `WorkoutIcon` (1–11 stable enum), `WorkoutCode`, `WorkoutRace` (bool) | DISCARDED | Icon is the *stable* type key (name strings vary); `WorkoutRace` could set `intensity_level=race` |
| `ActualTime`, `ActualDistanceMeters`, `ActualPace` | defined in spec, **never observed populated** | if FS ever sends completions, L-2 merge rules apply |
| `WorkoutCompleted` (bool) | DISCARDED | today every FS row stays `planned` regardless |

### 2.2 Structured steps (`json_fs_v1`)
Steps carry **real numeric targets**: `primaryTargetType` `POWER` (watts) /
`HEART_RATE` (bpm) / `PACE` (m/s) with low/high (or ramp start/finish), plus `CADENCE`
secondary and strength metadata — **BUCKETED** to the three zone integers like TP.
So FS *does* prescribe per-step watts/HR/pace; we keep only the coarse distribution.
(FS sends **no IF, no TSS, no zones, no profile** — nothing of that class was lost.)

## 3 · Garmin

### 3.1 Activity summary
| Fields | Disposition |
|---|---|
| `activityType`, `distanceInMeters`, `activeKilocalories`, HR avg/max, `durationInSeconds`, speeds→`cycling_speed_mph`/`swimming_pace_per_100m_seconds`, `averagePowerInWatts`, pace, elevation, `deviceName` | **CAPTURED** on completion (HR/power/pace columns then STORED-DEAD client-side — Q-INT20) |
| `maxPowerInWatts`, `normalizedPowerInWatts`, cadences (run/bike/swim), `steps`, start lat/lon, `manual`, `isWebUpload`, `numberOfActiveLengths` | **DISCARDED** (survive only in `activity_raw`) |
| `isParent`, `parentSummaryId` | **DISCARDED** — the multisport linkage (Q-INT23) |

### 3.2 Wellness (per type)
| Type | Disposition | Notable unread content |
|---|---|---|
| dailies | partially CAPTURED (`bmr`/`active` kcal feed the engine) | resting HR, HR band, stress levels, body battery — STORED-DEAD |
| bodyComps | CAPTURED (weight/BF → `users`) | body water %, muscle/bone mass, BMI — STORED-DEAD |
| userMetrics | STORED-DEAD (`vo2_max`, `fitness_age`); `vo2MaxCycling`, `enhanced` DISCARDED | VO2max-based fitness tier |
| sleeps | STORED-DEAD | sleep score, stages, respiration, SpO2 |
| stressDetails, epochs | STORED-DEAD | stress/body-battery timelines; 15-min activity slices |
| **hrv, pulseOx, respiration, healthSnapshot, bloodPressures, skinTemp** | **UNHANDLED** — `garmin-push` has no case for these types | HRV (`lastNightAvg` ms) is the recovery signal of record |
| activityDetails samples/laps | deliberately never persisted (G-3) — **DECIDED not to record for now (Xuan, 2026-09-09); revisit condition: an engine that consumes samples** | — |

## 4 · Runna & VDOT O2 (brief)
Runna (ICS): `UID`, `DTSTART`, duration (3-source ladder), `SUMMARY`-derived
title/distance/subtype/intensity/pace, `DESCRIPTION`→notes — CAPTURED; `LOCATION`,
`LAST-MODIFIED` parsed-not-stored; no actuals/identity/zones exist. VDOT: planned
event fields CAPTURED; `steps[].target` pace/HR bands **fetched, never read**; no VDOT
score, no actuals, no profile exposed.

## 5 · Cross-cutting availability (asked 2026-09-09)
- **Sweat/hydration/sodium**: no provider exposes any (Garmin's `percentHydration` is
  body-water %, not fluid loss). Manual entry / external sweat sensors remain the source.
- **HRV/recovery**: TP Metric `HRV` (NOT-FETCHED) and Garmin `hrv` type (UNHANDLED).
- **Planned calories**: TP only (`CaloriesPlanned`).
- **Race priority (A/B/C)**: nobody exposes it; TP `Goals[]` is the nearest signal.
- **CTL/ATL/TSB**: nobody exposes it — any feed must be computed from captured TSS.

## 6 · The capture shortlist (→ Q-INT26, one ruling)
**Storage convention (direction item 4, 2026-09-09):** every captured quantity that can
arrive from more than one source gets its own per-source typed column (e.g. TP session
kcal lands beside Garmin's `calories_burned`, never into it); precedence is applied only
at read time by the ratified resolution ladder, so priority can be re-ruled without
re-ingesting. Ordered by leverage; each names its Q-row where one exists:
1. **TP completed `TssActual` + `IF`** → `tss_actual` + `if_actual` columns — lights up
   the engine's dead `TP_ACTUAL` rungs (Q-INT13/Q-INT17 dependency).
2. **TP planned `TSSPlanned`/`IFPlanned`** → `tss_planned` + `if_planned` columns — the
   planned/actual split (L-2) applied to load metrics (Xuan, 2026-09-10). The F22 ladder
   reads `if_actual > if_planned > zone-derived > 70/20/10 default` (its ratified order,
   now with named storage); the engine's derived IF stays computed at read, never stored.
   The existing never-written `activities.tss` column retires with the hygiene batch.
   Future third source for `if_actual`: HR-vs-LTHR derivation (Q-010 deferred; needs the
   Q-INT19 zones wiring).
3. **`parentSummaryId` (+`isParent`)** → column or `brick_metadata` — unblocks brick
   verification B-2/B-5 (Q-INT23).
4. **TP Metric endpoint fetch** (weight, HRV) on the 24 h staleness clock — fixes TP
   weight staleness; premium-gated.
5. **Zones → consumption**: FS/TP FTP/LTHR wired into intensity classification and
   `users.cycling_ftp_watts` prefill (Q-INT19).
6. **FS `WorkoutSubTypeName` + pace min/max, TP subtype** onto the row (Q-INT13 as
   drafted).
7. **TP `IsPremium`** onto `integrations` — predicts null-field behaviour + write-back 403.
8. **All currently-unhandled Garmin push types** — `hrv`, `pulseOx`, `respiration`,
   `healthSnapshot`, `bloodPressures`, `skinTemp` — handled into `garmin_health_data`
   ("we should record this" — Xuan, 2026-09-09; widened from hrv-only per the
   lose-nothing direction).
9. **TP `Calories` (completed) + `CaloriesPlanned`** — record-only numeric columns,
   nullable for basic athletes: F4 stays authoritative; accumulate F4-vs-TP-vs-Garmin
   history so the accuracy comparison can be ruled later on data (Xuan, 2026-09-09
   artifact thread). Promoting completed Calories to a measured-kcal rung is a separate
   F22 ruling (today that rung is Garmin-only by ratified text).
10. **FS `WorkoutRace` / TP `Goals[]`** → race flags + race-goal prefill for the app's
    event page (display + fueling tiers) — "we need this" (Xuan, 2026-09-09). Cadence:
    daily is sufficient — the handback may split events onto a daily clock instead of the
    4 h workout clock; manual Sync Now still forces a fresh pull. **Far-future races, per provider
    (alternating design — Xuan, 2026-09-09: hot window ≈1 month at normal cadence, since
    coaches plan ~a month ahead; a separate low-cadence pass reaches up to 12 months for
    races only):**
    - **TP needs no long scan for races** — its dedicated events endpoints
      (`/v2/events/next`, `/v2/events/{date}`) return the race calendar directly and are
      already called by `syncAll`; confirm the `/events/next` horizon in the handback.
      (TP's *workouts* endpoint is capped at 45 days per request — documented — so any
      workout-window widening there would chunk; races don't need it.)
    - **FS has no events API** — races are workouts with `WorkoutRace=true`, and the
      14-day forward limit is the app's own clamp (`final_surge_sync_service.dart:141`),
      not a documented FS cap (`Workouts?StartDate&EndDate` accepts arbitrary ranges per
      the docs; server-side limits unverified — probe once). Handback: a daily/weekly
      long-horizon FS pass (chunked, out to 12 months) importing only race-flagged rows,
      keeping the hot path fast.
Deliberately NOT shortlisted: per-sample streams (G-3 discard **decided** by Xuan
2026-09-09 — temporary, dated, revisit when an engine consumes samples), step-level
prescriptions (revisit when an engine consumes them), sleep/stress/epoch consumption
(product features, not capture).

## 7 · Bucketing methods (every BUCKETED field's algorithm — direction item 5)
Per Xuan (2026-09-09): a bucketed field's method is documented here, and the raw value is
ALSO captured (per-source column, direction item 4) so re-bucketing never needs re-ingest.
1. **`intensity_level` from TP** (`training_peaks_transformer.dart:676-724`), first match
   wins: IFPlanned ≥1.0 race · ≥0.9 hard · ≥0.75 moderate · else easy → else
   TSSPlanned÷TotalTimePlanned (TSS/hr) ≥100 hard · ≥60 moderate · else easy → else
   title/tag keywords (race|competition → race; tempo|threshold|interval|speed|hard →
   hard; easy|recovery|warm → easy; long|endurance → moderate) → default moderate.
2. **`intensity_level` from FS** (`final_surge_transformer.dart:613-636`): WorkoutRace →
   race; else WorkoutSubTypeName keywords (easy|recovery → easy; tempo|threshold|
   interval|speed → hard; long → moderate); default moderate. No numeric inputs exist.
3. **Zone distribution** (`intensity_z1_z2/z3_z4/z5` = conversational/tempo/all-out) from
   structured steps, duration-weighted per step
   (`intensity_distribution_mapper.dart:37-47`): %FTP ≤0.75 conversational · ≤1.00 tempo ·
   else all-out; %maxHR ≤0.80 · ≤0.95; RPE ≤4 · ≤7. Unstructured workouts fall to
   conservative heuristic patterns (easy/recovery 95/5/0, long-run 80/15/5, …).
4. **`CaloriesPlanned`/`ElevationGainPlanned` → notes text** — not a numeric bucket;
   superseded by record-only capture (shortlist #9).
5. **Runna SUMMARY parsing** — keyword subtype (Race, Long Run, Tempo, …) → intensity via
   the same keyword classes; pace kept only when 4.0–20.0 min/mi.
6. **VDOT** — `eventType`/`crossTrainingEffort` (easy/moderate/hard) map 1:1 to
   `intensity_level`.
Ratifying this section makes each method a contract: changing a threshold becomes an
erratum with regenerated vectors, not a silent code edit.
