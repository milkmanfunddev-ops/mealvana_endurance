# Final Surge — Field Reference

Every field the Final Surge Partner API returns or accepts, in one place.

**Legend** — **Req.**: `req` = always present per the vendor spec; `opt` = nullable/optional.
Provenance is noted per section: _(confirmed in sample payloads)_ or _(Final Surge spec)_.

---

## 1. Token response — `POST /oauth/token` _(confirmed in sample payloads)_

| Field | Type | Units | Example | Req. | Notes |
|---|---|---|---|---|---|
| `access_token` | string (GUID) | — | `"REDACTED-FINAL-SURGE-TOKEN"` | req | Bearer token for all data calls. |
| `athlete` | object | — | `{ "id": …, "firstname": … }` | opt | Athlete identity. May be `null` when the same fields appear at the root. |
| `id` | string (GUID) | — | `"16238aab-bd1d-4a89-9b17-50f33630a007"` | opt | Athlete id; observed at the **root** as well as under `athlete`. |
| `firstname` | string | — | `"Brian"` | opt | Root or under `athlete`. |
| `lastname` | string | — | `"Roberds"` | opt | Root or under `athlete`. |
| `error` | string | — | `null` / `"invalid_grant"` | opt | Non-empty ⇒ failure, **on HTTP 200**. |

---

## 2. List envelope — `UpcomingWorkouts` / `Workouts` _(confirmed in sample payloads)_

| Field | Type | Example | Req. | Notes |
|---|---|---|---|---|
| `Success` | bool | `true` | req | `false` on failure. |
| `ErrorNumber` | int | `401` | opt | Error code. |
| `ErrorMessage` | string | `"Invalid or expired access token"` | opt | Error text on the list endpoints. Vendor spec names it `ErrorDescription` elsewhere. |
| `Workouts` | array | `[ {...} ]` | opt | `null` on error. |

---

## 3. Workout object _(confirmed in sample payloads)_

### Identity

| Field | Type | Units | Example | Req. | Notes |
|---|---|---|---|---|---|
| `WorkoutKey` | string (GUID) | — | `"79f28709-f623-4cb5-b99a-4c3161e6d20f"` | opt | Stable per-workout identifier; use it for `Workout/{key}` fetches. |
| `WorkoutURL` | string (URL) | — | `"https://log.finalsurge.com/WorkoutDetails?s=…&id=…"` | opt | Deep link. `?s=` is the athlete/session id, `?id=` is the `WorkoutKey`. |
| `WorkoutCode` | string | — | `"TRLTP"` | opt | Coach's plan code. |

### Scheduling

| Field | Type | Units | Example | Req. | Notes |
|---|---|---|---|---|---|
| `WorkoutDate` | string (ISO 8601, tz-naive) | — | `"2025-12-23T00:00:00"` | req | Usually midnight. |
| `WorkoutTime` | string | clock time | `"17:00:00"`, `"6:30 AM"` | opt | `null` when the workout has no set time. |

### Classification

| Field | Type | Units | Example | Req. | Notes |
|---|---|---|---|---|---|
| `WorkoutTypeName` | string | — | `"Run"`, `"Bike"`, `"Swim"`, `"Walk"`, `"Rest Day"`, `"Recovery/Rehab"` | req | Human-readable sport/type. |
| `WorkoutSubTypeName` | string | — | `"Tempo"`, `"Long Run"`, `"Intervals"` | opt | Finer classification. |
| `WorkoutIcon` | int | — | `1`–`11` | req | Icon enum — see [workout-data.md § types and icons](./workout-data.md#workout-types-and-icons). |
| `WorkoutRace` | bool | — | `true` | opt | Marks the workout as a race. |
| `WorkoutCompleted` | bool | — | `false` | req | `true` once logged. |

### Free text

| Field | Type | Units | Example | Req. | Notes |
|---|---|---|---|---|---|
| `WorkoutTitle` | string | — | `"Marathon Tempo"` | opt | May be `null` or `""`. |
| `WorkoutDescription` | string | — | `"@ 8:00\n\nEasy warmup, then marathon pace"` | opt | Free text; **often carries the target pace** as a leading `@`-line. |

### Prescription (planned)

| Field | Type | Units | Example | Req. | Notes |
|---|---|---|---|---|---|
| `PlannedTime` | int | **seconds** | `4800` | opt | `4800` = 80 min. |
| `PlannedDistance` | number | per `PlannedDistanceType` | `10.0`, `2000.0` | opt | Numeric distance. |
| `PlannedDistanceType` | string | — | `"mi"`, `"km"`, `"m"`, `"yd"` | opt | Unit for `PlannedDistance`. |
| `PlannedPace` | string | per `PlannedPaceType` | `"5:40-5:55"` | opt | Often `null`; pace may instead be in `WorkoutDescription`. |
| `PlannedPaceType` | string | — | `"min/mi"`, `"min/km"` | opt | Unit for `PlannedPace`. |

### Result (completed) — defined; not observed populated in samples

| Field | Type | Units | Example | Req. | Notes |
|---|---|---|---|---|---|
| `ActualTime` | int | **seconds** | `5730` | opt | Completed elapsed time. |
| `ActualDistanceMeters` | number | **metres (always)** | `48280.0` | opt | Independent of `PlannedDistanceType`. |
| `ActualPace` | — | — | — | opt | Format not documented. |

### Structure

| Field | Type | Units | Example | Req. | Notes |
|---|---|---|---|---|---|
| `HasStructuredWorkout` | bool | — | `true` | opt | Whether a structured breakdown is available. |
| `StructuredWorkoutURLs` | object | — | `{ "fit": …, "json_garmin_v1": …, "json_fs_v1": …, "mrc": …, "zwo": … }` | opt | Format → download URL; a value is `null` when that format is unavailable. |

---

## 4. Structured workout — `json_fs_v1` _(Final Surge spec)_

### Base object

| Field | Type | Units | Example | Req. | Notes |
|---|---|---|---|---|---|
| `workoutId` | string | — | `"0000000000000"` | req | Workout identifier. |
| `workoutName` | string | — | `"Test Workout"` | req | Builder name. |
| `sport` | string | — | `"RUNNING"`, `"CYCLING"`, `"SWIMMING"` | req | Sport. |
| `poolLength` | int | pool units | `25` | cond | Swimming only. |
| `poolLengthUnit` | string | — | `"METRIC"`, `"STATUTE"` | cond | Swimming only. |
| `steps` | array | — | `[ {...} ]` | req | Ordered steps; each has a `type`. |

### Step fields (`WorkoutStep`, `WorkoutRampStep`, `WorkoutRepeatStep`)

| Field | Type | Units | Example | Notes |
|---|---|---|---|---|
| `type` | string | — | `"WorkoutStep"` | `WorkoutStep` / `WorkoutRampStep` / `WorkoutRepeatStep`. |
| `intensity` | string | — | `"WARMUP"` | `ACTIVE`, `REST`, `WARMUP`, `COOLDOWN`. |
| `title` | string | — | `"Easy Warm Up"` | Optional label. |
| `comment` | string | — | `"Wake up your legs"` | Optional details. |
| `durationType` | string | — | `"TIME"` | `TIME`, `DISTANCE`, `OPEN`. |
| `durationValue` | number | seconds (`TIME`) / metres (`DISTANCE`) | `600.0` | `null` for `OPEN`. |
| `primaryTargetType` | string | — | `"POWER"` | `POWER` (watts), `HEART_RATE` (bpm), `PACE` (m/s), or `OPEN`. |
| `primaryTargetValueLow` | number | target unit | `175.0` | Low of the primary range (`WorkoutStep`). |
| `primaryTargetValueHigh` | number | target unit | `225.0` | High of the primary range (`WorkoutStep`). |
| `primaryTargetValueStart` | number | target unit | `200.0` | Ramp start (`WorkoutRampStep`). |
| `primaryTargetValueFinish` | number | target unit | `300.0` | Ramp finish (`WorkoutRampStep`). |
| `secondaryTargetType` | string | — | `"CADENCE"` | Cadence (rpm/spm). Requires a primary target. |
| `secondaryTargetValueLow` | number | rpm/spm | `20.0` | Low of the cadence range. |
| `secondaryTargetValueHigh` | number | rpm/spm | `50.0` | High of the cadence range. |
| `repeatValue` | number | — | `2.0` | Repeat count (`WorkoutRepeatStep`). |
| `steps` | array | — | `[ {...} ]` | Nested steps (ramp expansion / repeat body). |
| `strokeType` | string | — | `null` | Swim/strength metadata. |
| `equipmentType` | string | — | `null` | Strength metadata. |
| `exerciseCategory` | string | — | `null` | Strength metadata. |
| `exerciseName` | string | — | `null` | Strength metadata. |
| `weightValue` | number | — | `null` | Strength metadata. |
| `weightDisplayUnit` | string | — | `null` | Strength metadata. |

> Target-value units follow `primaryTargetType`: **watts** for `POWER`, **bpm** for
> `HEART_RATE`, **metres/second** for `PACE`.

---

## 5. ProfileInfo — `GET` / `POST /API/v1/ProfileInfo` _(Final Surge spec)_

| Field | Type | Max length | Req. | Notes |
|---|---|---|---|---|
| `uniqueid` | string | 200 | opt | Partner's unique identifier for the athlete. `null` until written. |
| `profile` | string | 3000 | opt | Additional partner-scoped data. `null` until written. |
| `Success` | bool | — | req | Envelope status. |
| `ErrorNumber` | int | — | opt | Error code. |
| `ErrorDescription` | string | — | opt | Error text (note: `Description`, not `Message`, on this endpoint). |

---

## 6. Uploads — `POST /API/v1/uploads` _(Final Surge spec)_

`multipart/form-data`. Returns HTTP `201` when the file is queued.

| Field | Type | Max length | Req. | Notes |
|---|---|---|---|---|
| `file` | file | — | req | Encoded FIT or TCX data. |
| `workout-id` | string | 50 | opt | Partner's workout identifier. |
| `workout-title` | string | 200 | opt | Ignored when merging into a titled workout. |
| `workout-description` | string | 3000 | opt | Ignored when merging into a described workout. |
| `workout-notes` | string | 3000 | opt | Stored as "Post Workout Notes". |

---

## 7. LoginToken — `POST /API/v1/LoginToken` _(Final Surge spec)_

| Field | Type | Req. | Notes |
|---|---|---|---|
| `Token` | string | — | Auto-login token; expires within 10 seconds. Use at `https://beta.finalsurge.com/LoginWithToken?t=<token>`. |
| `Success` | bool | req | Envelope status. |
| `ErrorNumber` | int | opt | Error code. |
| `ErrorDescription` | string | opt | Error text. |
