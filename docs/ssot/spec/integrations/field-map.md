# SSOT — Integrations: field map (provider data point → database column → consumer)

**Status: RATIFIED (Xuan, 2026-09-10, ruling desk).** Drafted 2026-09-08/09 from `app@c4abec2a`; `[observed]` clauses ratified; `[divergence]`/`[gap]` clauses carry the 2026-09-10 Q-INT rulings or remain OPEN per [`OPEN-QUESTIONS.md`](OPEN-QUESTIONS.md). The per-field mapping matrix Xuan asked for: for every data
point a platform can give us, where it lands in our tables and who reads it. Lifecycle
rules: [`lifecycle.md`](lifecycle.md); contested cells: [`OPEN-QUESTIONS.md`](OPEN-QUESTIONS.md).

Legend for the "lands in" column: a real table.column means it is written today;
**discarded** = computed by the transformer, never written (Q-INT13); **never fed** = a
consumer slot exists but no extractor populates it; **unavailable** = no provider exposes it.

## 1. Identity & athlete profile

| Data point | Garmin | TrainingPeaks | Final Surge | Lands in | Consumer / precedence |
|---|---|---|---|---|---|
| Name | literal `'Garmin Connect'` (no identity by design) | ✅ profile | ✅ first+last | `integrations.provider_athlete_name` | Onboarding prefill: **TP, then FS** — never Garmin/VDOT (`onboarding_preview_providers.dart:175-277`) |
| Email | ✗ | ✅ in API — deliberately **not copied** into onboarding | ✅ | `integrations.provider_athlete_email` | Prefill: TP then FS; TP email write not confirmed in code — verify before ratifying this cell |
| Weight | ✅ bodyComps, **grams**, push + 90-day backfill at connect | ✅ profile, kg | ✗ | Garmin → `garmin_health_data(body_composition)` + mirror `users.weight_pounds`; TP → `integrations.provider_athlete_weight_kg` | **Garmin first, then TP** (onboarding); engine uses Garmin body-comp with 30-day staleness cut (F24 ladder territory) |
| Body fat % | ✅ bodyComps | ✗ | ✗ | `users.body_fat_pct` + `integrations.provider_athlete_body_fat_pct` | Engine (LBM for Cunningham when no Garmin BMR) |
| **Height** | ✗ (only a Women's-Health pregnancy field, ruled out as unreliable) | ✗ | ✗ | **unavailable** | Manual onboarding entry is the only source — a permanent fact, worth ratifying so nobody goes looking |
| Birth month/year | ✗ | ✅ `"YYYY-MM"` (day defaults to the 1st) | ✗ | `integrations.provider_athlete_birth_month` | Prefill: TP only |
| Gender | ✗ | ✅ `'m'`/`'f'` | ✗ | `integrations.provider_athlete_gender` | Prefill: TP only |
| Training zones | ✗ | ✅ `/v1/athlete/profile/zones` | ✗ | `integrations.athlete_zones_json` (24 h staleness refresh) | TP transformer's zone→intensity derivation (whose output is then discarded — Q-INT13) |
| Race calendar | ✗ | ✅ `/v2/events` | ✗ | event/race import (`training_peaks_sync_service.dart:478+`) | Race-day features |

## 2. Workout / session fields (`activities`)

| Data point | Garmin (completion/insert) | TrainingPeaks (planned) | Final Surge (planned) | Lands in | Consumer |
|---|---|---|---|---|---|
| Sport | activity type map, unknown → `'other'` | Run/Walk→running, Bike/MTB→cycling, Swim→swimming, **Rowing→cycling** (Q-INT15) | Run/Walk→running (Walk forced easy), Bike, Swim, else `'other'`; only Rest Day dropped | `activity_type` | Engine F4 BASE_RATE; `'other'` excluded from insights |
| Title | `activityName` else `"Garmin {sport}"` | ✅ | ✅ | `title` | Display |
| Scheduled time | **measured start (overwrites planned)** — L-9.3, Q-INT11 | planned, 07:00 default | planned, 07:00 default | `scheduled_date_time` (naive local) | Engine day bucketing (open intake) |
| Planned/actual time | `actual_time` on completion | `planned_time` | `planned_time` | two-time model (ratified 2026-08-14) | F22 / display |
| Duration | measured min (`>= 0` guard) | always non-null int (from decimal-hours `TotalTime`) | **deliberately NULL when distance or pace present** (Q-INT12) | `duration_minutes` (+ `actual_duration_minutes` Garmin) | `SessionInputResolver` single ladder → engine |
| Distance | measured, replaces planned **incl. 0**; omitted leaves planned | meters → miles | planned; swims force `distance_miles` NULL, meters computed then **discarded** | `distance_meters` / `distance_miles` | Duration ladder (distance×pace), display |
| Pace min/max | ✗ | not provided (derivable) | computed → **discarded** | `pace_min/max_minutes_per_mile` **never fed by FS/TP** | Duration ladder reads `pace_target_minutes_per_mile` |
| Heart rate | ✅ avg + max | ✗ | ✗ | `average_heart_rate`, `max_heart_rate` | **Unused** — HR-derived IF is Q-010 (RULED, deferred) |
| Calories | ✅ `activeKilocalories` | `caloriesPlanned` computed → **discarded** (folded into notes text) | ✗ | `calories_burned` | F22: measured kcal beats F4 formula (dashboard `_sessionKcal`) |
| **TSS** | ✗ | `tssPlanned` computed → **discarded** | ✗ | `activities.tss` — column exists, engine week-query selects it, **never populated by any provider** (Q-INT13) | Engine week inputs |
| **IF** | ✗ (HR unused) | `ifPlanned` computed → **discarded** | ✗ | no column; engine derives IF from zone %s (F3) else zoneless 70/20/10 default | Engine F3/F4 |
| Zone / intensity distribution | ✗ | zone-derived, computed → **discarded** | inferred, computed → **discarded** | `intensity_z1_z2_pct`/`z3_z4`/`z5` — **never fed by any provider** | Engine F3 (falls back zoneless) |
| Workout subtype | ✗ | computed → **discarded** | computed → **discarded** (Runna/VDOT *do* write it) | `workout_subtype` | `CarbsPerHourService` speed-work exclusion — blind to FS/TP (Q-INT13) |
| Device | ✅ (literal `"unknown"` dropped) | ✗ | ✗ | `garmin_device_name` | Verified-chip attribution |
| Structured workout / description | ✗ | `includeDescription` | fetched when flagged | `notes` (cleaned text) | Display; TP write-back appends into the TP copy (TP-5) |

## 3. Training-load & wellness (beyond single sessions)

| Data point | Source | Lands in | Consumer | State |
|---|---|---|---|---|
| **CTL / ATL** | TP metrics API (scope granted) | **nowhere — no endpoint call, no column** | Engine slots exist and are ratified: `tp_data.CTL` → volume tier (F12 CTL variant: <30 recreational … ≥120 professional), `ATL/CTL` → weekly ratio F26 (`calculate-daily-macros-v6/formulas/resolve.ts:379-523`, `spec/daily-macros/neat-tef.md`) | **never fed** → Q-INT17. The spec and engine both speak CTL; no extractor exists. Xuan's "TCL/ACL" question lands exactly here. |
| Daily active/BMR kcal | Garmin dailies (push/backfill) | `garmin_health_data(daily)` | Engine: BMR→RMR (F24), active kcal→NEAT measurement | live |
| Sleep, stress, epochs, user metrics | Garmin push | `garmin_health_data(sleep/stress/epoch/user_metrics)` | **zero consumers** | stored-unused → Q-INT1 |
| Raw activity payloads | Garmin push only | `garmin_health_data(activity_raw/…)` | forensics only | Q-INT1 retention |
| Per-second samples, GPS, laps, power | Garmin activityDetails | **never persisted** (summary only) | — | the system's one true discard (G-3) |
| Weekly hours (fallback) | athlete manual input | onboarding answers | F12 volume tier when CTL absent — i.e. **always**, today | live |

## 4. Garmin history depth (the platform-less athlete)

Facts, for the "how far back can we go" question `[observed + Garmin spec]`:
- Backfill retrieves data recorded **before registration or purged by retention** — depth is
  unbounded in principle, requested in windows: **90 days max per request** (Health/
  Women's), **30 days max per request** (Activity summaries); chained windows allowed,
  duplicates → 409 (`docs/integration/api-exploration/garmin/endpoints.md` §Backfill).
- The binding constraint: **per-user backfill is limited to 1 month of requests since first
  connection** — deep history must be pulled in the athlete's first month, ideally at
  connect (`api-exploration/garmin/README.md` §Rate limits). Production key throughput:
  10,000 days-of-data/min.
- App today requests only `body_composition` + `user_metrics` (90 days) at connect;
  **`activities` backfill is supported by the edge function but deliberately excluded from
  defaults** (`garmin-backfill/index.ts:48-67`). Note: the function clamps windows at 90
  days, above Garmin's 30-day Activity max — an activities request over 30 days would be
  rejected upstream → Q-INT18.
- Retrospective pattern capability already exists: `TrainingInsightService` digests imported
  history into heavy/light **weekdays** (top-2/bottom-2 by average minutes per occurrence),
  gated on ≥7-day window, ≥3 sessions or one long session, and ≥4 distinct trained weekdays
  (`lib/features/onboarding/application/training_insight_service.dart:15-40,177-207`).
  Completed Garmin activities are explicitly usable inputs. Whether to run this for
  Garmin-only athletes (backfill a month of activities at connect → insights without a
  forward calendar) is a product decision → **Q-INT18**.
