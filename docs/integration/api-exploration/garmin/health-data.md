# Garmin — Health API Data Model

The Health API delivers all-day wellness data — sleep, heart rate, stress, body composition, and
more _(Garmin spec — Health API §2)_. There are **12 summary types**, each delivered via push or
ping (same data model). Timestamps are **UTC Unix epoch seconds**; add `startTimeOffsetInSeconds`
for device-local time. One-per-day summaries also carry `calendarDate` (`yyyy-mm-dd`) so no timezone
math is needed _(Garmin spec — §6.2)_.

**Updated records:** a later summary with the same start time + type replaces the earlier one — the
latest always wins _(Garmin spec — §6.1)_.

| # | Type | Envelope key | Granularity |
|---|---|---|---|
| 1 | Dailies | `dailies` | 1/day |
| 2 | Epochs | `epochs` | 15-min slices |
| 3 | Sleeps | `sleeps` | 1/sleep window |
| 4 | Body composition | `bodyComps` | per measurement |
| 5 | Stress details | `stressDetails` | 1/day, 3-min values |
| 6 | User metrics | `userMetrics` | 1/day (latest) |
| 7 | Pulse ox | `pulseox` | 1/day or on-demand |
| 8 | Respiration | `allDayRespiration` | 15-min slices |
| 9 | Health snapshot | `healthSnapshot` | 2-min session |
| 10 | HRV | `hrv` | overnight |
| 11 | Blood pressure | `bloodPressures` | per reading |
| 12 | Skin temperature | `skinTemp` | overnight |

---

## 1. Daily summaries _(Garmin spec — §7.1)_

High-level view of the user's whole day ("My Day"). Full example:
[`examples/health-dailies.json`](examples/health-dailies.json).

| Field | Type | Unit | Notes |
|---|---|---|---|
| `summaryId` | string | — | |
| `calendarDate` | string | yyyy-mm-dd | |
| `startTimeInSeconds` / `startTimeOffsetInSeconds` | int | epoch s / s | |
| `activityType` | string | — | Backward-compat; always `GENERIC`, ignore. |
| `durationInSeconds` | int | s | 86400 for a full day. |
| `steps` | int | — | |
| `distanceInMeters` | float | m | |
| `activeTimeInSeconds` | int | s | |
| `activeKilocalories` | int | kcal | Activity calories only (excludes BMR). |
| `bmrKilocalories` | int | kcal | Basal metabolic rate calories. |
| `moderateIntensityDurationInSeconds` | int | s | MET 3–6. |
| `vigorousIntensityDurationInSeconds` | int | s | MET > 6. |
| `floorsClimbed` | int | — | |
| `minHeartRateInBeatsPerMinute` | int | bpm | |
| `averageHeartRateInBeatsPerMinute` | int | bpm | 7-day average. |
| `maxHeartRateInBeatsPerMinute` | int | bpm | |
| `restingHeartRateInBeatsPerMinute` | int | bpm | |
| `timeOffsetHeartRateSamples` | map | offset s → bpm | 15-s representative samples. |
| `averageStressLevel` | int | 1–100 | `-1` = insufficient data. 1–25 rest, 26–50 low, 51–75 med, 76–100 high. |
| `maxStressLevel` | int | 1–100 | |
| `stressDurationInSeconds` | int | s | Stressful range (26–100). |
| `restStressDurationInSeconds` | int | s | Rest range (1–25). |
| `activityStressDurationInSeconds` | int | s | Unreliable-during-activity. |
| `lowStressDurationInSeconds` / `mediumStressDurationInSeconds` / `highStressDurationInSeconds` | int | s | |
| `stressQualifier` | string | — | `calm`, `balanced`, `stressful`, `very_stressful`, `*_awake`, `unknown`. |
| `bodyBatteryChargedValue` / `bodyBatteryDrainedValue` | int | — | Body Battery gain/drain. |
| `stepsGoal` / `floorsClimbedGoal` / `intensityDurationGoalInSeconds` | int | — / — / s | User goals. |
| `pushes` / `pushDistanceInMeters` / `pushesGoal` | int/float | pushes / m / pushes | Wheelchair mode. |

---

## 2. Epoch summaries _(Garmin spec — §7.2)_

Wellness data in **15-minute (900 s)** slices; one record per activity type within an epoch. Example:
[`examples/health-epochs-and-user-metrics.json`](examples/health-epochs-and-user-metrics.json).

| Field | Type | Unit | Notes |
|---|---|---|---|
| `summaryId` | string | — | |
| `startTimeInSeconds` / `startTimeOffsetInSeconds` | int | epoch s / s | |
| `activityType` | string | — | See Appendix values below. |
| `durationInSeconds` | int | s | Usually 900; less mid-epoch. |
| `activeTimeInSeconds` | int | s | Active time for this type; per-type active times sum to duration. |
| `steps` | int | — | |
| `distanceInMeters` | float | m | |
| `activeKilocalories` | int | kcal | Activity only. |
| `met` | float | MET | Metabolic Equivalent of Task. |
| `intensity` | string | — | `SEDENTARY`, `ACTIVE`, `HIGHLY_ACTIVE`. |
| `meanMotionIntensity` / `maxMotionIntensity` | float | 0–7 | Accelerometer abstraction. |
| `pushes` / `pushDistanceInMeters` | int/float | pushes / m | Wheelchair mode. |

Epoch `activityType` values _(Garmin spec — Health Appendix A)_: `WALKING`, `RUNNING`,
`WHEELCHAIR_PUSH`, `SEDENTARY`, `GENERIC`, `SLEEP`.

---

## 3. Sleep summaries _(Garmin spec — §7.3)_

Sleep duration and classified levels over an overnight window. Example:
[`examples/health-sleep.json`](examples/health-sleep.json).

| Field | Type | Unit | Notes |
|---|---|---|---|
| `summaryId` / `calendarDate` | string | — / yyyy-mm-dd | |
| `startTimeInSeconds` / `startTimeOffsetInSeconds` | int | epoch s / s | |
| `durationInSeconds` | int | s | Sleep only (excludes awake/unmeasurable). |
| `unmeasurableSleepInSeconds` | int | s | |
| `deepSleepDurationInSeconds` / `lightSleepDurationInSeconds` / `remSleepInSeconds` / `awakeDurationInSeconds` | int | s | REM only on REM-capable devices. |
| `totalNapDurationInSeconds` | int | s | |
| `sleepLevelsMap` | map | — | `deep`/`light`/`awake`/`rem` → arrays of `{startTimeInSeconds,endTimeInSeconds}`. |
| `validation` | string | — | `MANUAL`, `DEVICE`, `OFF_WRIST`, `AUTO_TENTATIVE`, `AUTO_FINAL`, `AUTO_MANUAL`, `ENHANCED_TENTATIVE`, `ENHANCED_FINAL`. |
| `timeOffsetSleepRespiration` | map | offset s → breaths/min | |
| `timeOffsetSleepSpo2` | map | offset s → % | SpO2-enabled devices only. |
| `overallSleepScore` | map | — | `{value, qualifierKey}`; `EXCELLENT` 90–100, `GOOD` 80–89, `FAIR` 60–79, `POOR` <60. |
| `sleepScores` | map | — | Per-component qualifiers: `totalDuration`, `stress`, `awakeCount`, `remPercentage`, `restlessness`, `lightPercentage`, `deepPercentage`. |
| `naps` | list | — | `{napDurationInSeconds, napStartTimeInSeconds, napValidation, napOffsetInSeconds}`. |

_(confirmed in sample payloads)_ Delivered records also include `sleepScoreQuality`,
`overallSleepScore`, `sleepQualityScore`, `sleepDurationScore`, `restlessMomentsCount`.

---

## 4. Body composition summaries _(Garmin spec — §7.4)_

Biometric data — manual weight entry (time + weight only) or full metrics from a Garmin Index scale.
Example: [`examples/health-body-composition.json`](examples/health-body-composition.json).

| Field | Type | Unit |
|---|---|---|
| `summaryId` | string | — |
| `measurementTimeInSeconds` / `measurementTimeOffsetInSeconds` | int | epoch s / s |
| `weightInGrams` | int | g |
| `bodyFatInPercent` | float | % (0–100) |
| `bodyWaterInPercent` | float | % (0–100) |
| `muscleMassInGrams` | int | g |
| `boneMassInGrams` | int | g |
| `bodyMassIndex` | float | — |

_(confirmed in sample payloads)_ Some deliveries use `percentFat` / `percentHydration` /
`weightInGrams` / `boneMassInGrams` / `muscleMassInGrams` / `bmi`.

---

## 5. Stress details summaries _(Garmin spec — §7.5)_

3-minute stress averages (1–100) and a Body Battery timeline for a day. Example:
[`examples/health-stress-detail.json`](examples/health-stress-detail.json).

| Field | Type | Unit | Notes |
|---|---|---|---|
| `summaryId` / `calendarDate` | string | — / yyyy-mm-dd | |
| `startTimeInSeconds` / `startTimeOffsetInSeconds` | int | epoch s / s | |
| `durationInSeconds` | int | s | |
| `timeOffsetStressLevelValues` | map | offset s → 1–100 | Negatives: `-1` off-wrist, `-2` large motion, `-3` not enough data, `-4` recovering, `-5` unidentified. |
| `timeOffsetBodyBatteryValues` | map | offset s → 0–100 | |
| `bodyBatteryDynamicFeedbackEvent` | map | — | `{eventStartTimeInSeconds, bodyBatteryLevel}` (`VERY_LOW`/`LOW`/`MODERATE`/`HIGH`). |
| `bodyBatteryActivityEvents` | list | — | `{eventType, eventStartTimeInSeconds, eventStartTimeOffsetInSeconds, duration, bodyBatteryImpact}`; `eventType` ∈ `SLEEP`, `RECOVERY`, `NAP`, `ACTIVITY`, `STRESS`. |

---

## 6. User metrics summaries _(Garmin spec — §7.6)_

Per-user calculated fitness metrics, keyed by `calendarDate` (latest value only). Example:
[`examples/health-epochs-and-user-metrics.json`](examples/health-epochs-and-user-metrics.json).

| Field | Type | Unit | Notes |
|---|---|---|---|
| `summaryId` / `calendarDate` | string | — / yyyy-mm-dd | |
| `vo2Max` | float | ml/kg/min | Maximal oxygen uptake. |
| `vo2MaxCycling` | float | ml/kg/min | Included only when available. |
| `fitnessAge` | int | years | |
| `enhanced` | boolean | — | `true` = new Fitness Age algorithm. |

---

## 7. Pulse ox summaries _(Garmin spec — §7.7)_

Blood-oxygen (SpO2). `onDemand: false` = all-day/acclimation averages; `onDemand: true` = spot
checks (`durationInSeconds` 0).

| Field | Type | Unit | Notes |
|---|---|---|---|
| `summaryId` / `calendarDate` | string | — / yyyy-mm-dd | |
| `startTimeInSeconds` / `startTimeOffsetInSeconds` | int/float | epoch s / s | |
| `durationInSeconds` | int | s | 0 for on-demand. |
| `timeOffsetSpo2Values` | map | offset s → % | 1 sample/min. |
| `onDemand` | boolean | — | |

---

## 8. Respiration summaries _(Garmin spec — §7.8)_

Breathing rate throughout day/sleep/activities, in 15-minute records.

| Field | Type | Unit |
|---|---|---|
| `summaryId` | string | — |
| `startTimeInSeconds` / `startTimeOffsetInSeconds` | float/int | epoch s / s |
| `durationInSeconds` | int | s |
| `timeOffsetEpochToBreaths` | map | offset s → breaths/min |

---

## 9. Health snapshot summaries _(Garmin spec — §7.9)_

A 2-minute (`durationInSeconds` 120) cardiovascular session bundling several metrics.

| Field | Type | Notes |
|---|---|---|
| `summaryId` / `calendarDate` | string | |
| `startTimeInSeconds` / `startTimeOffsetInSeconds` (a.k.a. `offsetStartTimeInSeconds`) | float/int | epoch s / s |
| `durationInSeconds` | int | 120 |
| `summaries` | list | Per-metric objects, each `{summaryType, minValue, maxValue, avgValue, epochSummaries: {sec → value}}`. `summaryType` ∈ `heart_rate`, `respiration`, `stress`, `spo2`, `rmssd_hrv`, `sdrr_hrv`. |

---

## 10. HRV summaries _(Garmin spec — §7.10)_

Overnight heart-rate variability (RMSSD).

| Field | Type | Unit |
|---|---|---|
| `summaryId` / `calendarDate` | string | — / yyyy-mm-dd |
| `startTimeInSeconds` / `startTimeOffsetInSeconds` | float/int | epoch s / s |
| `durationInSeconds` | int | s |
| `lastNightAvg` | int | ms |
| `lastNight5MinHigh` | int | ms |
| `hrvValues` | map | offset s → rmssd (ms) |

---

## 11. Blood pressure summaries _(Garmin spec — §7.11)_

From an Index BPM device or manual entry.

| Field | Type | Unit | Notes |
|---|---|---|---|
| `summaryId` | string | — | |
| `measurementTimeInSeconds` / `measurementTimeOffsetInSeconds` | int | epoch s / s | |
| `systolic` / `diastolic` | int | mmHg | |
| `pulse` | int | bpm | |
| `sourceType` | string | — | `MANUAL` or `DEVICE`. |

---

## 12. Skin temperature _(Garmin spec — §7.12)_

Sleep-window skin-temperature deviation.

| Field | Type | Unit | Notes |
|---|---|---|---|
| `summaryId` / `calendarDate` | string | — / yyyy-mm-dd | |
| `avgDeviationCelsius` | float | °C | Deviation from baseline (may be negative). |
| `durationInSeconds` | int | s | |
| `startTimeInSeconds` / `startTimeOffsetInSeconds` | int | epoch s / s | |

---

## Appendices _(Garmin spec)_

- **Wellness intensity** (`intensity`): `SEDENTARY`, `ACTIVE`, `HIGHLY_ACTIVE`.
- **MET**: Metabolic Equivalent of Task, estimated from biometrics + heart rate.
- **Motion intensity**: 0 (still) – 7 (constant sharp motion), minute-level.
