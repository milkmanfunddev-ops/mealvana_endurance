# Final Surge — Workout Data

What a Final Surge workout object contains — planned vs completed fields, units, and the
`json_fs_v1` structured-interval shape. For a flat lookup of every field see
[field-reference.md](./field-reference.md).

---

## The workout object

Every workout returned by `UpcomingWorkouts`, `Workouts`, and `Workout/{key}` is a flat JSON
object. The only nesting is `StructuredWorkoutURLs` (a map of format → URL) and any
structured workout fetched separately. Fields group into families:

| Family | Fields |
|---|---|
| **Identity** | `WorkoutKey`, `WorkoutURL`, `WorkoutCode` |
| **Scheduling** | `WorkoutDate`, `WorkoutTime` |
| **Classification** | `WorkoutTypeName`, `WorkoutSubTypeName`, `WorkoutIcon`, `WorkoutRace`, `WorkoutCompleted` |
| **Prescription (planned)** | `PlannedTime`, `PlannedDistance`, `PlannedDistanceType`, `PlannedPace`, `PlannedPaceType` |
| **Result (completed)** | `ActualTime`, `ActualDistanceMeters`, `ActualPace` |
| **Free text / structure** | `WorkoutTitle`, `WorkoutDescription`, `HasStructuredWorkout`, `StructuredWorkoutURLs` |

Only `WorkoutDate`, `WorkoutCompleted`, `WorkoutTypeName`, and `WorkoutIcon` are guaranteed
non-null. Everything else is nullable.

---

## Units and conventions

These are the conventions that most often surprise integrators:

| Concept | Convention |
|---|---|
| **Duration** | `PlannedTime` and `ActualTime` are in **seconds**. `4800` = 80 minutes. _(confirmed in sample payloads)_ |
| **Distance** | `PlannedDistance` is a number in the unit named by `PlannedDistanceType` — `"mi"`, `"km"`, `"m"`, or `"yd"`. Swim workouts are typically expressed in `"m"` or `"yd"`. _(confirmed in sample payloads)_ |
| **Actual distance** | `ActualDistanceMeters` is **always metres**, regardless of `PlannedDistanceType`. |
| **Pace** | When present, `PlannedPace` is a `"m:ss"` string or range (e.g. `"5:40-5:55"`) and `PlannedPaceType` names the unit (`"min/mi"`, `"min/km"`). |
| **Date** | `WorkoutDate` is ISO 8601, time-zone-naive, usually at midnight (`"2025-12-23T00:00:00"`). |
| **Time of day** | `WorkoutTime` is a clock string (`"17:00:00"`, `"6:30 AM"`) when set, and `null` when the workout has no specific time. |

### Pace often lives in `WorkoutDescription`

In practice, the target pace is frequently embedded at the top of `WorkoutDescription` as an
`@`-prefixed line rather than in `PlannedPace`:

- Single target: `"@ 8:00\n\nEasy warmup, then marathon pace"`
- Range: `"@ 9:12 - 10:01\n\nNice and easy"` (also seen without spaces: `"@ 8:30-9:30"`)

`PlannedPace` / `PlannedPaceType` are often `null` even when a pace target exists in the
description, so the target pace must be read from the description text, not only from
`PlannedPace`. _(confirmed in sample payloads)_

---

## Planned workout — example

A run with a single target pace in the description:

```json
{
  "WorkoutKey": "79f28709-f623-4cb5-b99a-4c3161e6d20f",
  "WorkoutURL": "https://log.finalsurge.com/WorkoutDetails?s=f71d3644-6ae5-4910-b098-a019a515520e&id=79f28709-f623-4cb5-b99a-4c3161e6d20f",
  "WorkoutDate": "2025-12-23T00:00:00",
  "WorkoutTime": null,
  "WorkoutCode": null,
  "WorkoutTitle": "Marathon Tempo",
  "WorkoutDescription": "@ 8:00\n\nEasy warmup, then marathon pace",
  "WorkoutTypeName": "Run",
  "WorkoutSubTypeName": "Tempo",
  "WorkoutCompleted": false,
  "WorkoutRace": false,
  "WorkoutIcon": 1,
  "PlannedTime": 4800,
  "PlannedDistance": 10.0,
  "PlannedDistanceType": "mi",
  "PlannedPace": null,
  "PlannedPaceType": null,
  "ActualTime": null,
  "ActualDistanceMeters": null,
  "HasStructuredWorkout": false
}
```

Here `PlannedTime: 4800` is 80 minutes, `PlannedDistance: 10.0` is 10 miles, and the `@ 8:00`
in the description is an 8:00 min/mi target. More samples: a
[pace range](./examples/workout-planned-run-pace-range.json), a
[ride in km](./examples/workout-planned-bike-km.json), a
[swim in yards](./examples/workout-planned-swim-yards.json), and a
[workout with everything null](./examples/workout-planned-missing-data.json).

---

## Completed (actual) results

A workout object can also carry actual results:

| Field | Units | Notes |
|---|---|---|
| `ActualTime` | seconds | Elapsed time of the completed activity. |
| `ActualDistanceMeters` | metres (always) | Completed distance. |
| `ActualPace` | — | Present in the completed-workout field set; format not documented. |
| `WorkoutCompleted` | bool | `true` once the athlete has logged the session. |

The `Actual*` fields are defined in the schema but were **not observed populated** in the
sampled responses (which returned upcoming, not-yet-completed workouts). Treat them as
available for past-dated / completed workouts but verify against live data before depending
on them. A constructed illustration is at
[examples/workout-completed-bike.json](./examples/workout-completed-bike.json).

---

## Workout types and icons

`WorkoutIcon` is a stable integer; `WorkoutTypeName` is the human-readable string.

| Icon | Type |
|---|---|
| 1 | Run |
| 2 | Bike |
| 3 | Swim |
| 4 | Cross Training |
| 5 | Strength Training |
| 6 | Rest Day |
| 7 | Recovery |
| 8 | Other |
| 9 | Transition |
| 10 | Custom |
| 11 | Walk |

`WorkoutSubTypeName` carries a finer classification when set — e.g. `"Tempo"`, `"Long Run"`,
`"Intervals"`, `"Endurance"`. `WorkoutRace: true` marks the workout as a race.

---

## Structured workouts

When a workout has structured steps, its object sets `HasStructuredWorkout: true` and carries
a `StructuredWorkoutURLs` map. Fetch the `json_fs_v1` member (see
[endpoints.md § 5](./endpoints.md#5-get-structuredworkouturlsjson_fs_v1)) to download the full
interval breakdown in Final Surge's native format.

### Structured object (`json_fs_v1`) _(Final Surge spec)_

The base object:

| Field | Required | Type | Notes |
|---|---|---|---|
| `workoutId` | Yes | string | Workout identifier. |
| `workoutName` | Yes | string | Name from the workout builder. |
| `sport` | Yes | string | `RUNNING`, `CYCLING`, or `SWIMMING`. |
| `poolLength` | Conditional | int | Swimming only — pool length. |
| `poolLengthUnit` | Conditional | string | Swimming only — `METRIC` or `STATUTE`. |
| `steps` | Yes | array | The workout steps (see below). Each element has a `type`. |

### Step types

Each entry in `steps` (and nested `steps`) is one of three types, distinguished by `type`:

**`WorkoutStep`** — one segment of work with a duration and optional targets.

| Field | Type | Notes |
|---|---|---|
| `intensity` | string | `ACTIVE`, `REST`, `WARMUP`, or `COOLDOWN`. |
| `title` | string, optional | Short label for the step. |
| `comment` | string, optional | Details / reminders for the step. |
| `durationType` | string | `TIME`, `DISTANCE`, or `OPEN` (athlete marks complete). |
| `durationValue` | number | `TIME` → **seconds**; `DISTANCE` → **metres**; `OPEN` → `null`. |
| `primaryTargetType` | string, optional | `POWER` (watts), `HEART_RATE` (bpm), or `PACE` (**metres/second**). `null` = no target. |
| `primaryTargetValueLow` / `primaryTargetValueHigh` | number, optional | Low/high of the primary target range, in the unit above. |
| `secondaryTargetType` | string, optional | `CADENCE` (rpm/spm). Requires a primary target. |
| `secondaryTargetValueLow` / `secondaryTargetValueHigh` | number, optional | Low/high of the secondary (cadence) range. |

**`WorkoutRampStep`** — the athlete builds up or down between two targets over the step.

| Field | Type | Notes |
|---|---|---|
| `steps` | array | The ramp expressed as a series of `WorkoutStep`s, for consumers that do not support ramps. |
| `intensity`, `title`, `comment` | — | As for `WorkoutStep`. |
| `durationType` | string | `TIME` or `DISTANCE` (`OPEN` is not allowed for ramps). |
| `durationValue` | number | Seconds (`TIME`) or metres (`DISTANCE`). |
| `primaryTargetType` | string | `POWER`, `HEART_RATE`, or `PACE`. |
| `primaryTargetValueStart` / `primaryTargetValueFinish` | number | Start and finish of the ramp, in the target unit. |

**`WorkoutRepeatStep`** — a block repeated N times; may nest further repeats/ramps/steps.

| Field | Type | Notes |
|---|---|---|
| `repeatValue` | number | How many times to repeat the contained `steps`. |
| `steps` | array | The steps to repeat. |

Steps may also carry strength-specific fields (`strokeType`, `equipmentType`,
`exerciseCategory`, `exerciseName`, `weightValue`, `weightDisplayUnit`) which are `null` for
endurance steps.

### Example _(Final Surge spec)_

A trimmed excerpt showing a warmup step, a ramp, and a 2× repeat block (targets in watts,
durations in seconds):

```json
{
  "workoutId": "0000000000000",
  "workoutName": "Test Workout",
  "sport": "RUNNING",
  "poolLength": null,
  "poolLengthUnit": null,
  "steps": [
    {
      "type": "WorkoutStep",
      "intensity": "WARMUP",
      "title": "Easy Warm Up",
      "durationType": "TIME",
      "durationValue": 600.0,
      "primaryTargetType": "POWER",
      "primaryTargetValueLow": 175.0,
      "primaryTargetValueHigh": 225.0,
      "secondaryTargetType": "CADENCE",
      "secondaryTargetValueLow": 20.0,
      "secondaryTargetValueHigh": 50.0
    },
    {
      "type": "WorkoutRampStep",
      "intensity": "ACTIVE",
      "title": "Build up to some speed",
      "durationType": "TIME",
      "durationValue": 240.0,
      "primaryTargetType": "POWER",
      "primaryTargetValueStart": 200.0,
      "primaryTargetValueFinish": 300.0,
      "steps": []
    },
    {
      "type": "WorkoutRepeatStep",
      "repeatValue": 2.0,
      "steps": [
        {
          "type": "WorkoutStep",
          "intensity": "ACTIVE",
          "title": "Run Hard",
          "durationType": "TIME",
          "durationValue": 120.0,
          "primaryTargetType": "POWER",
          "primaryTargetValueLow": 350.0,
          "primaryTargetValueHigh": 400.0
        },
        {
          "type": "WorkoutStep",
          "intensity": "REST",
          "title": "Quick Break",
          "durationType": "TIME",
          "durationValue": 30.0,
          "primaryTargetType": "OPEN"
        }
      ]
    }
  ]
}
```

The full multi-repeat vendor example is in
`docs/final_surge/Final-Surge-Partner-API-Uploads.pdf`.

A simplified illustrative sample using a `Steps` / `Duration` / `IntensityTarget` shape is
also kept at
[examples/structured-workout-json-fs-v1.json](./examples/structured-workout-json-fs-v1.json)
and [examples/structured-workout-with-ramp.json](./examples/structured-workout-with-ramp.json)
for quick reference; the field-level `json_fs_v1` schema above is the authoritative one.
