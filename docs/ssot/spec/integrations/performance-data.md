# SSOT — Integrations: sports-performance data (thresholds, zones, load metrics)

**Status: RATIFIED (Xuan, 2026-09-10, ruling desk).** Drafted 2026-09-08/09 from `app@c4abec2a`; `[observed]` clauses ratified; `[divergence]`/`[gap]` clauses carry the 2026-09-10 Q-INT rulings or remain OPEN per [`OPEN-QUESTIONS.md`](OPEN-QUESTIONS.md). The deep companion to [`field-map.md`](field-map.md): every
sports-specific performance datum — FTP, lactate threshold, pace/power/HR zones, CSS,
VO2max, VDOT, IF, TSS, CTL/ATL, sweat metrics — with its exact wire field, storage path,
and consumers. Contested cells: [`OPEN-QUESTIONS.md`](OPEN-QUESTIONS.md). App-repo-relative
paths.

> The headline finding: the app **collects far more performance data than it uses**. The
> only performance inputs that reach a calculation today are the sweat family, weekly
> hours, the zone-distribution percentages (FS/TP only), and two Zone-2 pace prefills.
> Everything else — LTHR, FTP, power, VO2max, measured HR, TSS — is stored dead or never
> stored. Each dead item is a Q-INT19/Q-INT20 cell: wire it, or ratify it as
> deliberately unused.

## P-1 — Athlete-level thresholds & zones

### P-1.1 TrainingPeaks zones (`integrations.athlete_zones_json`) `[observed]`
Fetched from `GET /v1/athlete/profile/zones` (`training_peaks_api_client.dart:466-482`),
cached with 24 h staleness (`training_peaks_sync_service.dart:637-676`). Wire → parse
(`lib/features/integrations/domain/athlete_zones.dart:25-65`):

| Wire field | Meaning | Parsed? | Stored JSON path |
|---|---|---|---|
| `HeartRateZones.Default.Threshold` | **LTHR** (bpm) | ✅ (only the `Default` set; other sets discarded) | `$.heartRateZones.threshold` |
| `HeartRateZones.Default.MaxHeartRate` / `.RestingHeartRate` | max / resting HR | ✅ | `$.heartRateZones.maxHeartRate` / `.restingHeartRate` |
| `HeartRateZones.Default.Zones[]` | HR zone bands | ✅ | `$.heartRateZones.zones[]` |
| `SpeedZones.<Sport>.Threshold` | **threshold speed** (m/s), per sport | ✅ all sports | `$.speedZones.<Sport>.threshold` |
| `SpeedZones.<Sport>.Zones[]` | pace zone bands | ✅ | `$.speedZones.<Sport>.zones[]` |
| `PowerZones.Default.Threshold` | **FTP** (watts) | ✅ (`Default` only) | `$.powerZones.threshold` |
| `PowerZones.Default.Zones[]` | power zone bands | ✅ | `$.powerZones.zones[]` |
| `*.WorkoutType` | set label | ✗ discarded | — |

Consumers of the stored zones:

| Derived value | Consumer | State |
|---|---|---|
| Run Z2 midpoint → min/mi | New-Activity run pace prefill (`running_input_controller.dart:238-263`) | **live** |
| Swim Z2 → sec/100m | swim pace prefill (`swimming_input_controller.dart:239-269`) | **live** |
| `thresholdPaceMinPerMile`, `estimatedPaceMinPerMile()`, `intensityLevelForHrPercent()` | providers/helpers exist | **zero call sites** |
| FTP (`$.powerZones.threshold`), LTHR, max/resting HR | — | **NOBODY READS** |

**The zone→intensity derivation is a no-op** `[divergence → Q-INT19]`: `AthleteZones` is
threaded through the TP transformer to `_classifyIntensity`
(`training_peaks_transformer.dart:925-947`), whose FTP and maxHR branches carry "we could
refine" comments and fall through to fixed percentage thresholds
(`intensity_distribution_mapper.dart:39-47`). The entire zones fetch changes no engine
output.

### P-1.2 Manual athlete entries (`users`) `[observed]`
| Column | Writer | Consumer |
|---|---|---|
| `cycling_ftp_watts` | Sport settings screen only (`sport_settings_screen.dart:186-232` → `upsert-user-profile/index.ts:250`) | Display + AI-coach profile blob only — **never any fuel/macro calculation**; not in Drift |
| `swimming_css_seconds_per_100m` (critical swim speed) | same path | same — display only |
| `prefers_cycling_power`, `prefers_swimming_pace` | **NOBODY WRITES** | **NOBODY READS** |
| `sweat_rate`, `sweat_sodium`, `known_sweat_rate_ml_per_hour`, `known_sodium_concentration_mg_per_liter` | onboarding/settings | **LIVE** → `generate-macros-v4/single-sport.ts:634-642,835-841` |
| `sweat_test_date`, `sweat_test_source` | settings | provenance display only |
| `default_running_pace` / `cycling_speed` / `swimming_pace` | settings | pass-through only, no calculation |
| `typical_weekly_hours` | onboarding | **LIVE** — F12 volume tier (`calculate-daily-macros-v6/pipeline.ts:514-516`) |
| LTHR, threshold pace, VO2max, VDOT, max HR, resting HR, CTL, ATL | **columns do not exist** | — |

`integrations.threshold_pace_min_per_mile` exists in Postgres (`dev_schema.txt:2305`) with
**zero Dart/TS references** — orphan column → Q-INT25.

### P-1.3 Garmin user metrics `[observed — stored dead]`
`user_metrics` pushes carry `vo2Max`, `fitnessAge` (`_shared/garmin/types.ts:248-255`);
persisted to `garmin_health_data(user_metrics)` as `$.vo2_max`, `$.fitness_age`
(`garmin-push/index.ts:1146-1150`). `vo2MaxCycling` and `enhanced` are dropped at the type
boundary. **No query anywhere selects `data_type='user_metrics'`** — VO2max is stored and
never read. Same class: daily `resting_heart_rate`, avg/max/min HR, stress levels, and
epoch HR/intensity — all persisted, all unread → Q-INT1/Q-INT20.

### P-1.4 VDOT O2 `[observed]`
**No endpoint exposes the VDOT score** (`docs/integration/api-exploration/vdot-o2/field-reference.md:93-105`)
— nor zones, race equivalencies, or completed actuals. Per-step `target` pace/HR bands are
fetched and **never read** (`vdot_transformer.dart:295-322` renders intensity/duration into
notes text only). VDOT contributes zero performance data despite being a pace platform.

## P-2 — Session-level metrics (`activities`)

| Datum | Who writes | Who reads | State |
|---|---|---|---|
| `intensity_z1_z2_pct`/`z3_z4`/`z5` (zone distribution) | **TP + FS transformers only** (`training_peaks_transformer.dart:364`, `final_surge_transformer.dart:250` → `activity_mapper.dart:363-367`). Manual create, Garmin, Runna, VDOT: never | engine F3 via `daily_macro_service.dart:700-712`; fallback **70/20/10** (`session_input_resolver.dart:78-80`) | live but partial |
| **IF** | nobody — no column; TP `ifPlanned` computed → discarded | engine derives via `zoneDistributionToIF` (F3), always `ZONE_DIST` source | never persisted |
| **TSS** | **NOBODY** — `TrainingPeaksTransformResult.tssPlanned` populated (`:362`) with zero read sites; no mapper/sync/edge writes `activities.tss` | engine selects it, always NULL → always `FORMULA` branch (`TSS = durHr × IF² × 100`, `resolve.ts:208-210`) | dead column → Q-INT25/Q-INT13 |
| `intensity_level` (easy/moderate/hard/race) | all transformers (TP infers from `IFPlanned` → `TSSPlanned/time` → keywords, `:676-724`) + manual | engine + Vana (`_shared/vana/macros.ts:40` `is_race`) | live |
| `average_heart_rate`, `max_heart_rate` | Garmin only (`mappers.ts:121-122`, completion `:348-353`) | **NOBODY** — not in Drift, never reaches client; `ActivityCompletion` fields exist but call sites never pass them | server-only dead → Q-INT20 |
| `cycling_power_watts` | Garmin `averagePowerInWatts` only (`mappers.ts:149-151`) | **NOBODY** | dead → Q-INT20 |
| `average_pace_minutes_per_mile` | Garmin (`mappers.ts:135-139`) | gap-filler presence check only | dead → Q-INT20 |
| `pace_target_minutes_per_mile`, `cycling_speed_mph`, `swimming_pace_per_100m_seconds` | TP/FS/Runna/manual (+ Garmin for the last two) | duration ladder + display | live |
| `intensity_target` (`zone_1`/`rpe_3`) | manual create only | round-tripped, no formula reads | inert |
| `maxPowerInWatts`, `normalizedPowerInWatts` (Garmin); `PowerAverage`, `NormalizedPower`, `TssActual`, `IF`, `Rpe`, HR stats (TP) | — | — | **discarded at ingest**; samples survive only in `activity_detail_raw` |
| Running power | — | — | not supplied by any provider, not modelled |
| Structured-workout step targets (TP `IntensityTarget`, FS, VDOT `steps[].target`) | consumed **only** to pick a 3-bucket intensity zone; the numeric watts/pace/HR prescription is then discarded (`training_peaks_transformer.dart:815-947`, `final_surge_transformer.dart:1662-1697`) | — | discarded → Q-INT13 |

## P-3 — Load metrics (CTL / ATL / IF ladders)
The engine's platform rungs are **dead**: `tp_data` (ATL/CTL/tomorrow) and `tp_sessions`
(per-session TP actuals) are never populated by any caller — the predecessor is annotated
`null, // tp_session — not yet wired` (`calculate-daily-macros/pipeline.ts:239`). IF always
resolves `ZONE_DIST`, TSS always `FORMULA`, volume tier always weekly-hours
(`ctlToVolumeTier(tp_data?.CTL)` → null, `pipeline.ts:515`). → **Q-INT17**.

## P-4 — Storage adequacy (performance data)
What the schema is missing or carrying dead, for the "do we have the right structure"
question — each a Q-INT19/Q-INT20/Q-INT25 cell:
1. **No storage target** for: LTHR / threshold HR, VO2max (as a typed column), VDOT score,
   CTL/ATL, per-session IF, normalized power, per-step prescriptions.
2. **Dead columns** carried: `activities.tss` (never written), `activities.cycling_ftp_watts`,
   `activities.swimming_css_seconds_per_100m`, `activities.swimming_speed_per_100m`,
   `integrations.threshold_pace_min_per_mile`, `users.prefers_cycling_power`,
   `users.prefers_swimming_pace`.
3. **Server-only columns invisible to the client** (no Drift column): `average_heart_rate`,
   `max_heart_rate`, `cycling_power_watts`, `average_pace_minutes_per_mile`.
4. **Lossy zone storage**: only the `Default` HR/power sets survive; per-set `WorkoutType`
   labels dropped — a per-sport LTHR (run vs bike) cannot be represented.

## Explicitly NOT ruled here
Whether HR should derive IF (Q-010, RULED deferred); the F3/F4 formulas
(`session-demand.md`); the sweat-model math (`generate-macros-v4` specs).
