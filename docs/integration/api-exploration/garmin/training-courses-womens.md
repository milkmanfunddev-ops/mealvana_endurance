# Garmin — Training, Courses & Women's Health APIs

Three more GCDP APIs. **Training** and **Courses** write data *into* a user's Garmin Connect account
(partner → Garmin, CRUD); **Women's Health** reads menstrual-cycle data *out* (Garmin → partner,
webhook). Everything below is _(Garmin spec)_ unless marked otherwise.

---

# Training API v2 _(Garmin spec — Training API V2 1.0)_

Lets partners import **workouts** and **workout schedules** into Garmin Connect for supported sport
types. Requires the `WORKOUT_IMPORT` user permission. All four CRUD operations are supported on each
type. Endpoints and response codes: [`endpoints.md`](endpoints.md#training-api-v2-partner--garmin).

## Workout object

A workout has metadata plus a list of **segments** (individual sports); each segment has **steps**.

- Single-sport workout: one segment, up to **100 steps**.
- Multisport workout (`sport: MULTI_SPORT`): up to **25 segments** and **250 steps** total; set
  `isSessionTransitionEnabled: true` for transitions.

### Workout fields

| Field | Type | Notes |
|---|---|---|
| `workoutId` | long | Server-assigned (omit on create). |
| `ownerId` | long | Required for updates. |
| `workoutName` | string | |
| `description` | string | ≤1024 chars. |
| `sport` | string | `MULTI_SPORT`, or single: `RUNNING`, `CYCLING`, `LAP_SWIMMING`, `STRENGTH_TRAINING`, `CARDIO_TRAINING`, `GENERIC`, `YOGA`, `PILATES`. |
| `estimatedDurationInSecs` / `estimatedDistanceInMeters` | int/double | Server-calculated; ignored on write. |
| `poolLength` / `poolLengthUnit` | double / string | For `LAP_SWIMMING`. Unit `YARD` or `METER`; `null` = unspecified pool. |
| `workoutProvider` / `workoutSourceId` | string | Display / internal provider (≤20 chars). |
| `isSessionTransitionEnabled` | boolean | Multisport transitions. |
| `segments` | list | See below. |
| `createdDate` / `updatedDate` | string | Server-set. |

### Segment fields

`segmentOrder` (int), `sport` (as above), `estimatedDurationInSecs`/`estimatedDistanceInMeters`
(server-calc, null for single-segment), `poolLength`/`poolLengthUnit`, and `steps` (list).

### Step fields

A step is `type: "WorkoutStep"` (a real step) or `type: "WorkoutRepeatStep"` (a repeat block wrapping
a sub-list of steps).

| Field | Type | Notes |
|---|---|---|
| `type` | string | `WorkoutStep` \| `WorkoutRepeatStep`. |
| `stepId` | long | Server-assigned. |
| `stepOrder` | int | |
| `intensity` | string | `REST`, `WARMUP`, `COOLDOWN`, `RECOVERY`, `ACTIVE`, `INTERVAL`, `MAIN` (swim). |
| `description` | string | ≤512 chars. |
| `durationType` | string | `TIME`, `DISTANCE`, `HR_LESS_THAN`, `HR_GREATER_THAN`, `CALORIES`, `OPEN`, `POWER_LESS_THAN`, `POWER_GREATER_THAN`, `REPS`, `FIXED_REST`, plus swim: `REPETITION_SWIM_CSS_OFFSET`, `FIXED_REPETITION`. |
| `durationValue` / `durationValueType` | double / string | Value; modifier `PERCENT` for HR/power. |
| `targetType` | string | `SPEED`, `HEART_RATE`, `CADENCE`, `POWER`, `GRADE`, `RESISTANCE`, `POWER_3S/10S/30S/LAP`, `SPEED_LAP`, `HEART_RATE_LAP`, `PACE` (m/s), `OPEN`. `null` for swim. |
| `targetValue` / `targetValueLow` / `targetValueHigh` / `targetValueType` | double/string | Zone (HR 1–5, power 1–7) or custom range. |
| `secondaryTargetType` + `secondaryTarget*` | — | Accessory target (cycling; swim `SWIM_INSTRUCTION`, `SWIM_CSS_OFFSET`, `PACE_ZONE`). |
| `repeatType` / `repeatValue` | string / double | Repeat blocks: `REPEAT_UNTIL_STEPS_CMPLT`, `REPEAT_UNTIL_TIME/DISTANCE/CALORIES`, `REPEAT_UNTIL_HR_*`, `REPEAT_UNTIL_POWER_*`. |
| `skipLastRestStep` | boolean | Auto-`true` for `LAP_SWIMMING`. |
| `strokeType` | string | Swim: `BACKSTROKE`, `BREASTSTROKE`, `BUTTERFLY`, `FREESTYLE`, `MIXED`, `IM`, `RIMO`, `CHOICE`. |
| `drillType` | string | Swim: `KICK`, `PULL`, `BUTTERFLY`. |
| `equipmentType` | string | Swim: `NONE`, `SWIM_FINS`, `SWIM_KICKBOARD`, `SWIM_PADDLES`, `SWIM_PULL_BUOY`, `SWIM_SNORKEL`. |
| `exerciseCategory` / `exerciseName` | string | Strength/cardio/HIIT/yoga/pilates (see Appendix A & B in `Training_API_V2_1/Appendix A and B.xlsx`). |
| `weightValue` / `weightDisplayUnit` | double / string | Strength; value in kg, unit `KILOGRAM`/`POUND`. |

### Example — single-sport workout

```json
{
  "ownerId": 12345, "workoutName": "TEST", "description": "TEST", "sport": "CYCLING",
  "poolLength": null, "poolLengthUnit": null,
  "workoutProvider": "example", "workoutSourceId": "example", "isSessionTransitionEnabled": false,
  "segments": [ {
    "segmentOrder": 1, "sport": "CYCLING",
    "steps": [
      { "type": "WorkoutStep", "stepOrder": 1, "intensity": "ACTIVE",
        "durationType": "DISTANCE", "durationValue": 1000, "durationValueType": "METER",
        "targetType": "OPEN" },
      { "type": "WorkoutRepeatStep", "stepOrder": 2, "repeatType": "REPEAT_UNTIL_STEPS_CMPLT",
        "repeatValue": 4, "steps": [
          { "type": "WorkoutStep", "stepOrder": 3, "intensity": "ACTIVE",
            "durationType": "DISTANCE", "durationValue": 100, "durationValueType": "METER" } ] }
    ] } ]
}
```

Spec-derived sample bodies: [`examples/training-workout-single.json`](examples/training-workout-single.json),
[`training-workout-multisport.json`](examples/training-workout-multisport.json).

## Workout schedule object

Schedules a previously-created workout for a date.

| Field | Notes |
|---|---|
| `scheduleId` | Server-assigned. |
| `workoutId` | The workout to schedule. |
| `date` | `YYYY-MM-DD`. |

```json
{ "scheduleId": 123, "workoutId": 123, "date": "2019-01-31" }
```

See [`examples/training-schedule.json`](examples/training-schedule.json).

---

# Courses API _(Garmin spec — Courses API 1.0.1)_

Imports navigable **courses** (route geo-points + informational course points) into Garmin Connect;
they sync directly to the device. Requires `COURSE_IMPORT`. CRUD endpoints + response codes:
[`endpoints.md`](endpoints.md#courses-api-partner--garmin).

## Course object

| Object / field | Type | Notes |
|---|---|---|
| `courseId` | long | Server-assigned. |
| `elapsedSeconds` | double | |
| `courseName` | string | Required, non-empty. |
| `description` | string | |
| `distance` | double | Total meters (required). |
| `elevationGain` / `elevationLoss` | double | Meters (required). |
| `activityType` | string | `RUNNING`, `HIKING`, `OTHER`, `MOUNTAIN_BIKING`, `TRAIL_RUNNING`, `ROAD_CYCLING`, `GRAVEL_CYCLING`. |
| `speedMetersPerSecond` | double | |
| `coordinateSystem` | string | `WGS84`, `GCJ02`, `BD09`. |
| `geoPoints` | list | Required, non-empty. Each: `latitude`, `longitude`, `elevation` (double), optional `information` (a course point). |

### Course point (`information`)

| Field | Type | Notes |
|---|---|---|
| `coursePointType` | string | e.g. `GENERIC`, `SUMMIT`, `VALLEY`, `WATER`, `FOOD`, `DANGER`, `FIRST_AID`, `AID_STATION`, `SPRINT`, `SEGMENT_START`, `SEGMENT_END`, `ENERGY_GEL`, `SPORTS_DRINK`, `MILE_MARKER`, `CHECKPOINT`, `SHARP_CURVE`, `STEEP_INCLINE`, `TUNNEL`, `BRIDGE`, `CROSSING`, `TRANSITION`, … |
| `name` | string | Label. |
| `segmentUuid` | string | Only for `SEGMENT_START` / `SEGMENT_END`. |

### Sizing rules

- Provide course points ~every 100 m to match Garmin's elevation/point calcs; omitted elevation is
  supplemented by Garmin's corrected elevation.
- Up to **50 courses** may sync at once. Embedded turn navigation supported for courses ≤200 miles;
  TCX/GPX export (older devices) limited to 100 miles. Up to ~10,000 geo-points (consecutive points
  ≤100 m apart) ≈ 600 miles.

```json
{
  "courseName": "example gravel cycling", "distance": 8561.08,
  "elevationGain": 115.27, "elevationLoss": 4.44, "activityType": "GRAVEL_CYCLING",
  "coordinateSystem": "WGS84",
  "geoPoints": [
    { "latitude": 46.425274, "longitude": 11.685595, "elevation": 1300.0 },
    { "latitude": 46.474929, "longitude": 11.745668, "elevation": 0.0, "distance": 13698.295,
      "information": { "name": "water", "coursePointType": "WATER" } }
  ]
}
```

See [`examples/course.json`](examples/course.json).

---

# Women's Health API _(Garmin spec — Women's API 1.0.4)_

Delivers **Menstrual Cycle Tracking (MCT)** schedule data (not symptoms) via push/ping, envelope key
`mct`. Requires the `MCT_EXPORT` permission in addition to general consent. A response is a JSON
array of **0–1** MCT summaries. Pull/backfill: [`endpoints.md`](endpoints.md#womens-health-api).

## MCT summary fields

| Field | Type | Notes |
|---|---|---|
| `summaryId` | string | |
| `periodStartDate` | string | yyyy-mm-dd. |
| `dayInCycle` | int | nth day in cycle. |
| `periodLength` | int | Typical period length (days). |
| `currentPhase` | int | Numeric phase. |
| `currentPhaseType` | string | e.g. `MENSTRUAL`, `SECOND_TRIMESTER`. |
| `lengthOfCurrentPhase` | int | Days. |
| `daysUntilNextPhase` | int | Days. |
| `fertileWindowStart` / `lengthOfFertileWindow` | int | Days (non-pregnant cycles). |
| `predictedCycleLength` | int | Days. |
| `isPredictedCycle` | boolean | |
| `cycleLength` | int | User-logged length (days). |
| `lastUpdatedTimeInSeconds` | int | epoch s. |
| `hasSpecifiedCycleLength` / `hasSpecifiedPeriodLength` | boolean | User-provided flags. |
| `pregnancySnapshot` | object | Empty `{}` unless pregnant. |

### Pregnancy snapshot

`title`, `originalDueDate`, `dueDate`, `pregnancyCycleStartDate` (dates), `numOfBabies` (e.g.
`SINGLE`), `weightGoalUserInput` (`{heightInCentimeters, weightInGrams}`), and `bloodGlucoseList`
(each `{valueInMilligramsPerDeciliter, logType, reportTimestampInSeconds}`; `logType` ∈ `BEFOREMEAL`,
`AFTERMEAL`, `BEFOREBED`, `OTHER`).

```json
{ "mct": [ {
  "summaryId": "x153a9f3-176e4715000", "periodStartDate": "2021-01-04", "dayInCycle": 1,
  "periodLength": 5, "currentPhase": 1, "currentPhaseType": "MENSTRUAL", "lengthOfCurrentPhase": 5,
  "daysUntilNextPhase": 5, "fertileWindowStart": 11, "lengthOfFertileWindow": 7,
  "predictedCycleLength": 28, "isPredictedCycle": true, "cycleLength": 28,
  "lastUpdatedTimeInSeconds": 1610150400, "hasSpecifiedCycleLength": false,
  "hasSpecifiedPeriodLength": false, "pregnancySnapshot": {}
} ] }
```

See [`examples/womens-mct.json`](examples/womens-mct.json) and
[`womens-mct-pregnancy.json`](examples/womens-mct-pregnancy.json).
