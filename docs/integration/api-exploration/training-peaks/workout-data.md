# TrainingPeaks — Workout Data

The workout object is the core of the Partner API. The same object shape is returned by the range
endpoint (`GET /v2/workouts/{start}/{end}`), the single-workout endpoint
(`GET /v2/workouts/id/{id}`), and the changed-workouts feed, and is accepted by the write endpoints
(`POST`/`PUT /v2/workouts/plan`).

A workout is either **planned** (prescribed, in the future) or **completed** (recorded, in the
past). The two states use different field families.

---

## 1. Planned vs completed field families

Planned fields carry a `Planned` suffix; completed fields do not. A single workout can carry both —
a planned session that has since been completed.

| Concept | Planned field | Completed field | Unit |
|---|---|---|---|
| Duration | `TotalTimePlanned` | `TotalTime` | **decimal hours** |
| Distance | `DistancePlanned` | `Distance` | **metres** |
| Training Stress Score | `TSSPlanned` | `TssActual` | score |
| Intensity Factor | `IFPlanned` | `IF` | fraction |
| Calories | `CaloriesPlanned` | `Calories` | kcal |
| Energy | `EnergyPlanned` | `Energy` | kJ |
| Elevation gain | `ElevationGainPlanned` | `ElevationGain` | metres |
| Start time | `StartTimePlanned` | `StartTime` | ISO 8601 |

Identity/common fields appear on both: `Id` (`Int64`), `AthleteId`, `WorkoutDay`, `WorkoutType`,
`Title`, `Description`, `Tags`, `Structure`.

### Planned workout example

`GET /v2/workouts/id/123456789?includeDescription=true` —
[`examples/workout-planned-run-structured.json`](examples/workout-planned-run-structured.json):

```json
{
  "Id": 123456789,
  "AthleteId": 54321,
  "WorkoutDay": "2026-07-21T00:00:00",
  "StartTimePlanned": "2026-07-21T06:30:00",
  "WorkoutType": "Run",
  "Title": "Track Intervals",
  "Description": "4x1000m with recoveries",
  "TotalTimePlanned": 0.75,
  "DistancePlanned": 8000.0,
  "TSSPlanned": 65.0,
  "IFPlanned": 0.95,
  "ElevationGainPlanned": 45.0,
  "CaloriesPlanned": 520.0,
  "Tags": ["quality", "track"],
  "StructureDisplayUnit": "kilometer",
  "Locked": false,
  "Hidden": false,
  "Structure": "[{...}]"
}
```

`TotalTimePlanned: 0.75` = **45 minutes**. `DistancePlanned: 8000.0` = **8 km**.

### Completed workout example

A recorded ride uses the unsuffixed fields —
[`examples/workout-completed-bike.json`](examples/workout-completed-bike.json):

```json
{
  "Distance": 100000,
  "Id": 139283664,
  "StartTime": "2026-07-22T12:57:59",
  "TotalTime": 1.25,
  "WorkoutType": "Bike"
}
```

`Distance: 100000` = **100 km**. `TotalTime: 1.25` = **1 h 15 min**. `Title` may be absent on a
minimal completed workout. Completed workouts also carry performance metrics such as `TssActual`,
`IF`, `Calories`, `HeartRateAverage/Maximum`, `PowerAverage`, `NormalizedPower`, `CadenceAverage`,
`VelocityAverage`, `Rpe`, `Feeling` (full list in [`field-reference.md`](field-reference.md)).

---

## 2. Workout types

`WorkoutType` values: `swim, bike, run, x-train, mtb, strength, xc-ski, rowing, walk, other`.
TrainingPeaks has **no "rest day" type** — every named type is a real activity. On write the
lowercase forms are used; reads have been observed capitalized (`"Run"`, `"Bike"`).

---

## 3. Basic (non-premium) athletes

For basic athletes, a large set of performance/health fields return `null` on read and are ignored
on write. The identity and prescription fields (`Id`, `WorkoutDay`, `WorkoutType`, `Title`,
`Description`, `TotalTimePlanned`, `DistancePlanned`, `StartTimePlanned`) remain populated. The
nulled set includes: `TSSPlanned`, `TssActual`, `IF`, `IFPlanned`, `Calories`, `CaloriesPlanned`,
`Energy`, `EnergyPlanned`, all `Elevation*`, `VelocityAverage/Maximum`, `NormalizedSpeed/Power`,
`PowerAverage/Maximum`, `TorqueAverage/Maximum`, `HeartRate*`, `Cadence*`, `Temp*`, `Rpe`,
`Feeling`, and `Tags`. See [`examples/workout-basic-athlete-nulled.json`](examples/workout-basic-athlete-nulled.json).

---

## 4. The `Structure` interval model

`Structure` describes a workout as an ordered sequence of intensity/duration targets. It is
delivered as a **JSON string** (a string field whose contents are JSON) — decode it, and the top
level is an **array** of segments.

`StructureDisplayUnit` (e.g. `"kilometer"`) is a sibling field indicating the preferred display unit
and does not change the encoded values.

### Segment types

Each array element is one of two segment types, distinguished by `Type`:

- **`"Step"`** — a single block with a `Length` and (optionally) an `IntensityTarget`.
- **`"Repetition"`** — a `RepeatCount` and a nested `Steps` array repeated that many times.

### Step fields

| Field | Type | Meaning |
|---|---|---|
| `Type` | string | `"Step"` |
| `Length` | object | `{ "Unit": "...", "Value": <int> }` — duration/distance of the step |
| `IntensityClass` | string | `WarmUp`, `Active`, `Rest`, `CoolDown` |
| `Name` | string | Optional label, e.g. `"Warm Up"` |
| `IntensityTarget` | object | `{ "Unit": "...", "Value": <fraction>, "MinValue": …, "MaxValue": … }` |
| `CadenceTarget` | object | Optional; `{ "MinValue": …, "MaxValue": … }` in rpm |
| `OpenDuration` | bool | Optional; flexible duration above the `Length` minimum |

### `Length.Unit` values and scale

| `Unit` | Meaning | `Value` scale |
|---|---|---|
| `Second` | Time | integer seconds |
| `Minute` | Time | integer minutes |
| `Hour` | Time | integer hours |
| `Meter` | Distance | integer metres |

### `IntensityTarget.Unit` values and scale

| `Unit` | Target metric | `Value` scale |
|---|---|---|
| `PercentOfFtp` | Power vs FTP | fraction (`0.95` = 95 % FTP) |
| `PercentOfMaxHr` | Heart rate vs max | fraction (`0.88` = 88 % max HR) |
| `PercentOfThresholdHr` | Heart rate vs threshold | fraction |
| `PercentOfThresholdSpeed` | Speed vs threshold | fraction |
| `Rpe` | Rate of perceived exertion | integer (no fraction) |

`MinValue`/`MaxValue` bound a target range; `Value` is the midpoint. Percentages are **decimals** —
`0.60` means 60 %, not 60.

### Decoded `Structure` example

The `Structure` string from the planned run above, decoded
([`examples/workout-structure-decoded.json`](examples/workout-structure-decoded.json)):

```json
[
  {
    "Type": "Step",
    "Length": { "Unit": "Minute", "Value": 10 },
    "IntensityClass": "WarmUp",
    "Name": "Warm Up",
    "IntensityTarget": { "Unit": "PercentOfFtp", "Value": 0.60 }
  },
  {
    "Type": "Repetition",
    "RepeatCount": 4,
    "Steps": [
      {
        "Type": "Step",
        "Length": { "Unit": "Minute", "Value": 3 },
        "IntensityClass": "Active",
        "IntensityTarget": { "Unit": "PercentOfFtp", "Value": 1.05,
                             "MinValue": 1.00, "MaxValue": 1.10 }
      },
      {
        "Type": "Step",
        "Length": { "Unit": "Minute", "Value": 2 },
        "IntensityClass": "Rest",
        "IntensityTarget": { "Unit": "PercentOfFtp", "Value": 0.55 }
      }
    ]
  },
  {
    "Type": "Step",
    "Length": { "Unit": "Minute", "Value": 10 },
    "IntensityClass": "CoolDown",
    "IntensityTarget": { "Unit": "PercentOfFtp", "Value": 0.60 }
  }
]
```

This encodes: 10 min @ 60 % FTP warm-up → 4 × (3 min @ 105 % FTP + 2 min @ 55 % FTP) →
10 min @ 60 % FTP cool-down.

### `Structure` on write

When a workout is created or updated with a valid non-RPE `Structure`, TrainingPeaks **recomputes**
`TotalTimePlanned`, `TSSPlanned`, and `IFPlanned` from the structure and ignores any values sent for
those fields. For distance-based structures, missing speed thresholds in the athlete's profile leave
the computed fields empty.

---

## 5. Dates and times

`WorkoutDay` is the calendar day (`YYYY-MM-DD` or full ISO 8601); on writes its time component is
ignored. `StartTime`/`StartTimePlanned` carry the time of day. On file upload, `WorkoutDay` and
`StartTime` may be given without a timezone (used verbatim as local time) or with an offset (in which
case TrainingPeaks converts to the athlete's timezone for display).
