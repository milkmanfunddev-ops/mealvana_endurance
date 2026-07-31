# TrainingPeaks — Endpoints

Every TrainingPeaks Partner API endpoint: method, path, parameters, required scope, and a request +
response example. All API paths are relative to the API host
(`https://api[.sandbox].trainingpeaks.com`); OAuth paths are relative to the OAuth host
(`https://oauth[.sandbox].trainingpeaks.com`). Every authenticated request carries
`Authorization: Bearer <ACCESS_TOKEN>` and a `User-Agent` header.

Endpoints are tagged _(confirmed in sample payloads)_ (a payload exists in [`examples/`](examples/))
or _(TP spec)_ (documented by TrainingPeaks, no captured payload here).

---

## Contents

- [OAuth](#oauth)
- [Info](#info)
- [Athlete](#athlete)
- [Coach](#coach)
- [Workouts (read)](#workouts-read)
- [Workouts (write)](#workouts-write)
- [Workout of the Day](#workout-of-the-day)
- [File upload](#file-upload)
- [Events](#events)
- [Metrics](#metrics)
- [Nutrition](#nutrition)
- [Webhooks (early access)](#webhooks-early-access)
- [Status codes](#status-codes)

---

## OAuth

Full details in [`authentication.md`](authentication.md). Summary:

| Method | Path (OAuth host) | Scope | Purpose |
|---|---|---|---|
| `GET` | `/OAuth/Authorize` | — | Start the authorization_code flow |
| `POST` | `/oauth/token` | — | Exchange auth code, or refresh, for tokens _(confirmed)_ |
| `POST` | `/oauth/deauthorize` | — | Revoke the token pair |

---

## Info

### `GET /v1/info/version` _(TP spec)_

API build/version. **No scope required.**

```json
{ "Version": "2.0.1234.0", "Build": "2.0.1234 1abcd2345 Release" }
```

---

## Athlete

### `GET /v1/athlete/profile` _(confirmed in sample payloads)_

Scope: `athlete:profile`. The authenticated athlete's profile.

```json
{
  "Id": 123456,
  "FirstName": "John",
  "LastName": "Doe",
  "Email": "jdoe@example.com",
  "TimeZone": "America/Denver",
  "BirthMonth": "1980-10",
  "Sex": "m",
  "CoachedBy": 987654,
  "Weight": 87.5223617553711,
  "IsPremium": true,
  "PreferredUnits": "English"
}
```

`Weight` is **kilograms** regardless of `PreferredUnits`. `BirthMonth` is `YYYY-MM`. `Sex` is
`"m"`/`"f"`. `CoachedBy` is the coach's id, or absent/null if uncoached. See
[`athlete-data.md`](athlete-data.md).

### `GET /v1/athlete/profile/zones` _(confirmed in sample payloads)_

Scope: `athlete:profile`. All training zones — heart rate (bpm), speed (**m/s**), power (watts). See
[`athlete-data.md`](athlete-data.md) for the full structure and
[`examples/athlete-zones.json`](examples/athlete-zones.json).

### `GET /v1/athlete/zones/{zoneType}` _(TP spec)_

Scope: `athlete:profile`. One zone family. `{zoneType}` ∈ `HeartRate`, `Speed`, `Power`.

---

## Coach

All require scope `coach:athletes`. _(TP spec)_

| Method | Path | Returns |
|---|---|---|
| `GET` | `/v1/coach/profile` | `{ "CoachId": 123456, "FirstName": "...", "LastName": "..." }` |
| `GET` | `/v1/coach/athletes` | Array of athlete profile objects the coach manages |
| `GET` | `/v1/coach/assistants` | The coach's assistant coaches |
| `GET` | `/v1/coach/assistants/{assistantId}` | One assistant |
| `GET` | `/v1/coach/assistants/{assistantId}/athletes` | An assistant's athletes |
| `GET` | `/v1/coach/athletes/zones` | Zones for all athletes |
| `GET` | `/v1/coach/athletes/zones/{zoneType}` | Zones of one type for all athletes |

`GET /v1/coach/athletes` example:

```json
[
  {
    "Id": 123456, "FirstName": "Jane", "LastName": "Smith",
    "Email": "jane@example.com", "TimeZone": "America/Denver",
    "BirthMonth": "1985-03", "Sex": "f", "CoachedBy": 987654,
    "Weight": 62.5, "IsPremium": true, "PreferredUnits": "Metric"
  }
]
```

---

## Workouts (read)

Scope: `workouts:read`. Each endpoint has a **self** form and an **athlete-addressed** form
(`/{athleteId}/...`) for coach access.

### `GET /v2/workouts/{startDate}/{endDate}` _(confirmed in sample payloads)_

Also `GET /v2/workouts/{athleteId}/{startDate}/{endDate}`.

| Param | In | Notes |
|---|---|---|
| `startDate`, `endDate` | path | Local date `YYYY-MM-DD` |
| `includeDescription` | query | Optional bool; include the `Description` field |

Constraints: **range ≤ 45 days**; `endDate` ≤ 365 days in the future. The response is a **bare JSON
array** (not an envelope):

```json
[
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
    "Structure": "[{...}]"
  }
]
```

`Distance*` is metres; `TotalTime*` is decimal hours. Full field list in
[`workout-data.md`](workout-data.md). See [`examples/workout-list-response.json`](examples/workout-list-response.json).

### `GET /v2/workouts/id/{workoutId}` _(confirmed in sample payloads)_

Also `GET /v2/workouts/{athleteId}/id/{workoutId}`. One workout by id (`Int64`). Same object shape
as the range endpoint. See [`examples/workout-planned-run-structured.json`](examples/workout-planned-run-structured.json).

### `GET /v2/workouts/changed` _(TP spec)_

Also `GET /v2/workouts/{athleteId}/changed`. A change feed for incremental sync.

| Param | Notes |
|---|---|
| `date` | UTC; minimum `2000-01-01` |
| `pageSize` | Max 100 |
| `page` | Zero-based |
| `workoutTypeFilter` | Optional (swim/bike/run/…) |
| `includeDescription` | Optional bool |

```json
{
  "Deleted": [123456789],
  "Modified": [
    {
      "LastModifiedDate": "2017-09-25T17:31:28.9428265Z",
      "Id": 234567890,
      "AthleteId": 12345,
      "WorkoutType": "Bike",
      "Title": null,
      "WorkoutDay": "2017-09-13T00:00:00"
    }
  ]
}
```

### Detailed workout data — `workouts:details`, premium only _(TP spec)_

| Method | Path | Returns |
|---|---|---|
| `GET` | `/v2/workouts/id/{workoutId}/details` | Time-series channels + stats (see below) |
| `GET` | `/v2/workouts/id/{workoutId}/meanmaxes` | Mean-max power/pace curves |
| `GET` | `/v2/workouts/id/{workoutId}/timeinzones` | Time spent in each zone |

Each has an athlete-addressed `/{athleteId}/...` form. Requires a premium athlete, a **completed**
workout, and an associated workout file. `details` shape:

```json
{
  "WorkoutChannels": {
    "Channels": ["Cadence","Distance","Elevation","Latitude","Longitude",
                 "HeartRate","Power","Speed","Temperature","Grade",
                 "VerticalOscillation","StanceTime","TorqueEffectiveness"],
    "Data": [
      { "Event": "Start", "TimeOffset": 0, "Cadence": 85,
        "Distance": 0, "HeartRate": 120, "Power": 200 }
    ]
  },
  "SwimStats": { },
  "WorkoutStats": { },
  "LapStats": [ ]
}
```

---

## Workouts (write)

See [`writeback.md`](writeback.md) for full write semantics.

### `POST /v2/workouts/plan` _(TP spec)_

Scope: `workouts:plan` (+ `athlete:profile` when the athlete is the authenticated user). Create a
planned workout.

Required: `AthleteId`, `WorkoutDay`, `WorkoutType`.

```json
{
  "AthleteId": "123456",
  "WorkoutDay": "2025-12-01",
  "WorkoutType": "run",
  "Title": "Morning Run",
  "Description": "Easy recovery run",
  "StartTimePlanned": "2025-12-01T06:00:00",
  "TotalTimePlanned": 1.0,
  "DistancePlanned": 10000,
  "TSSPlanned": 50,
  "IFPlanned": 0.75,
  "CaloriesPlanned": 600,
  "ElevationGainPlanned": 100,
  "Structure": "[...]",
  "StructureDisplayUnit": "kilometer",
  "Tags": ["recovery", "easy"]
}
```

`WorkoutType` ∈ `swim, bike, run, x-train, mtb, strength, xc-ski, rowing, walk, other`. Constraints:
`WorkoutDay` within 7 days past … 1 year future (its time component is ignored);
`TotalTimePlanned` ≤ 99:59:59 (decimal hours); `DistancePlanned` ≤ 99 999 999 m; `TSSPlanned` ≤ 9999;
`IFPlanned` ≤ 5. When a valid non-RPE `Structure` is sent, `TotalTimePlanned`/`TSSPlanned`/
`IFPlanned` are **ignored and recomputed** from the structure. Basic athletes cannot create future
planned workouts (`403`).

### `PUT /v2/workouts/plan/{workoutId}` _(confirmed in sample payloads)_

Scope: `workouts:plan`. **Full-object replace** — any field omitted or sent as `null` is written as
`null`. `GET` the workout first, modify, then `PUT` the complete object back. See
[`writeback.md`](writeback.md) and [`examples/writeback-request.json`](examples/writeback-request.json).

### `DELETE /v2/workouts/id/{workoutId}` _(TP spec)_

Also `/v2/workouts/{athleteId}/id/{workoutId}`. Scope: `workouts:read` **and** `workouts:plan`.
Deletes only future/incomplete workouts. Returns `200 OK` with body `true`.

### `POST /v2/workouts/{athleteId}/id/{workoutId}/comment` _(TP spec)_

Scope: `workouts:details`. Adds a comment.

```json
{ "Value": "Great workout today!" }
```

Returns `204 No Content`.

---

## Workout of the Day

Scope: `workouts:wod`. _(TP spec)_

### `GET /v2/workouts/wod/{date}`

| Param | Notes |
|---|---|
| `date` | Today's local date (required) |
| `numberOfDays` | Consecutive days, `>1` and `≤7` |
| `includeDescription` | Optional bool |
| `workoutTypeFilter` | Optional |

```json
[
  {
    "DistancePlanned": 100000, "Id": 139283664, "IFPlanned": null,
    "StartTimePlanned": "2014-04-15T12:57:59", "TotalTimePlanned": 1,
    "TssPlanned": 80, "WorkoutFileFormats": ["erg","fit","mrc","zwo","json"],
    "WorkoutType": "Bike"
  }
]
```

### `GET /v2/workouts/wod/file/{workoutId}/?format={fileFormat}`

`format` ∈ `erg, fit, mrc, zwo, json`. Downloads the WOD file.

---

## File upload

Scope: `file:write`. Asynchronous only (synchronous upload was removed June 2023). _(TP spec)_

### `POST /v3/file`

```json
{
  "UploadClient": "MyApp v1.0",
  "Filename": "2025-11-26-15-07-22.fit",
  "Data": "base64_encoded_file_contents",
  "WorkoutDay": "2025-11-26",
  "StartTime": "2025-11-26T15:07:22",
  "SetWorkoutPublic": false,
  "Title": "Afternoon Ride",
  "Comment": "Great workout!",
  "Type": "bike",
  "WorkoutId": 123456789
}
```

Required: `UploadClient`, `Filename` (no reserved chars `/ \ ? % * : | " < > . [space]`), `Data`
(base64; gzip supported). Supported file types: **FIT, TCX, PWX**. Returns `202 Accepted` with a
`Location: /v3/status/{fileTrackingId}` header.

### `GET /v3/status/{fileTrackingId}`

Poll until `Completed` is true:

```json
{ "Completed": true, "Status": "Success", "WorkoutIds": [123456789, 123456790] }
```

`415` = unsupported file type; `422` = file already uploaded.

---

## Events

See [`athlete-data.md`](athlete-data.md) for the event object.

### `GET /v2/events/{date}` _(confirmed in sample payloads)_

Scope: `events:read`. Events on a date. `404` means **no events on that date** — a normal empty
result, not an error. Returns an array of event objects.

### `GET /v2/events/next` _(confirmed in sample payloads)_

Scope: `events:read`. The next upcoming event. May return a single object or an array. `404` means
**no upcoming events**. See [`examples/event-next-triathlon.json`](examples/event-next-triathlon.json).

```json
{
  "Id": 123456,
  "AthleteId": 54321,
  "EventDate": "2026-10-12T00:00:00",
  "EventType": "Triathlon",
  "Name": "Ironman Kona",
  "Description": "World Championship",
  "WorkoutIds": [789, 790, 791],
  "Goals": [
    { "GoalType": "Distance", "Value": 140.1, "Unit": "Miles" },
    { "GoalType": "Time",     "Value": 7.85,  "Unit": "Hours" },
    { "GoalType": "Place",    "Value": 10,    "Unit": null },
    { "GoalType": "Pr",       "Value": true,  "Unit": null }
  ]
}
```

### `POST /v2/events` _(TP spec)_

Scope: `events:write`. Required: `AthleteId`, `EventDate`, `EventType`, `Name`.

```json
{
  "AthleteId": "54321",
  "EventDate": "2020-06-12",
  "EventType": "RoadCycling",
  "Name": "Twilight Criterium",
  "Description": "Description of the event"
}
```

`EventType` values include — Running: `RoadRunning, TrailRunning, TrackRunning, CrossCountry,
Running`; Cycling: `RoadCycling, MountainBiking, Cyclocross, TrackCycling, Cycling`; Swimming:
`OpenWaterSwimming, PoolSwimming`; Multisport: `Triathlon, Xterra, Duathlon, Aquabike, Aquathon,
Multisport`; Other: `Regatta, Rowing, AlpineSkiing, NordicSkiing, SkiMountaineering, Snowshoe, Snow,
Adventure, Obstacle, SpeedSkate, Other`.

---

## Metrics

Body metrics (weight, HRV, steps, sleep, stress). _(TP spec)_

### `GET /v2/metrics/{metricId}` — scope `metrics:read`

```json
{
  "MetricId": "uuid-string",
  "AthleteId": 123456789,
  "DateTime": "2016-02-18T22:56:00",
  "UploadClient": "testapplication",
  "WeightInKilograms": 68.1,
  "HRV": 84.1,
  "Steps": 12345,
  "Stress": "Low",
  "SleepQuality": "Good"
}
```

Not every field is present on every metric.

### `GET /v2/metrics/{startDate}/{endDate}` — scope `metrics:read`, **premium only**

Also `/v2/metrics/{athleteId}/{startDate}/{endDate}`. Basic athletes receive `403`.

### `POST /v2/metrics` — scope `metrics:write`

Required: `DateTime` (local, truncated to the minute; within 1 day future … 1 year past),
`UploadClient`, and **one or more** metric fields.

```json
{
  "DateTime": "2020-06-01T06:12:34",
  "UploadClient": "MyApp v1.0",
  "WeightInKilograms": 68.1,
  "HRV": 84.1,
  "Steps": 12345,
  "Stress": "Low",
  "SleepQuality": "Good"
}
```

Returns `201 Created` with `Location: /v2/metrics/{metricId}`.

---

## Nutrition

Daily nutrition cards. See [`writeback.md`](writeback.md).

### `GET /v1/athletes/{athleteId}/nutrition` _(TP spec)_

Scope: `nutrition:read`. **Premium athletes only** (excludes trials).

| Param | Notes |
|---|---|
| `startDate`, `endDate` | Date range; `startDate` ≤ 10 years past |
| `pageSize` | Max 100 |
| `page` | Zero-based |

```json
[
  {
    "NutritionId": 111,
    "AthleteId": 123456,
    "NutritionDate": "2025-10-01T00:00:00",
    "Calories": 2200.0,
    "Carbohydrates": 105.15,
    "Fat": 22.5,
    "Protein": 75.0
  }
]
```

### `POST /v1/athletes/{athleteId}/nutrition` _(confirmed in sample payloads)_

Scope: `nutrition:write`. Required: `NutritionDate`. Optional: `Calories` (kcal),
`Carbohydrates`, `Fat`, `Protein` (grams).

```json
{
  "NutritionDate": "2025-10-01T00:00:00",
  "Calories": 2200.0,
  "Carbohydrates": 105.15,
  "Fat": 22.5,
  "Protein": 75.0
}
```

Returns `201 Created` with the created object (including `NutritionId`). See
[`examples/nutrition-entry-create.json`](examples/nutrition-entry-create.json).

### `PUT /v1/athletes/{athleteId}/nutrition/{nutritionId}` _(TP spec)_

Scope: `nutrition:write`. Same body as `POST`. The date must match the existing entry's date or be a
date that has no other nutrition card. Returns `200 OK`.

### `DELETE /v1/athletes/{athleteId}/nutrition/{nutritionId}` _(TP spec)_

Scope: `nutrition:write`. Returns `202 Accepted`.

---

## Webhooks (early access)

Scope: `webhook:write-subscriptions`. Near-real-time notifications for workout changes. _(TP spec)_

| Method | Path | Purpose |
|---|---|---|
| `POST` | `/v1/webhook/subscriptions` | Create a subscription |
| `GET` | `/v1/webhook/subscriptions` | List subscriptions |
| `PUT` | `/v1/webhook/subscriptions/{subscriptionId}` | Update a subscription |
| `DELETE` | `/v1/webhook/subscriptions/{subscriptionId}` | Delete a subscription |

Create request / response:

```json
// request
{ "AthleteId": 54321, "EventType": "workout-created",
  "WebhookUrl": "https://api.example.com/callback" }

// response
{ "Id": "0d76e887-8e8a-46f4-bb2b-2f66e4fc40ee", "AthleteId": 54321,
  "EventType": "workout-created", "WebhookUrl": "https://api.example.com/callback",
  "Active": true, "CreatedBy": 54321, "CreatedOn": "2025-07-24T21:03:05.1324848Z" }
```

Event types: `workout-created`, `workout-updated`, `workout-deleted`. When an event fires,
TrainingPeaks `POST`s to the registered `WebhookUrl` (the callback payload shape is not published).

---

## Status codes

| Code | Meaning |
|---|---|
| `200 OK` / `201 Created` / `202 Accepted` / `204 No Content` | Success |
| `302 Object moved` | Request made over insecure HTTP |
| `400 Bad Request` | Missing/incorrect required field. Body: `{ "error": "...", "error_description": "..." }` |
| `401 Unauthorized` | Bad/expired/missing `Authorization` header — refresh the token |
| `403 Forbidden` | Refused: disconnected athlete, or premium content for a basic account |
| `404 Not Found` | Resource missing — **or**, on the events endpoints, "none" (normal empty result). Nonexistent routes return an HTML error page, not JSON |
| `405 Method Not Allowed` | Method unsupported on this path |
| `415 Unsupported Media Type` | File format not FIT/TCX/PWX |
| `422 Unprocessable Entity` | File already uploaded |
| `429 Too Many Requests` | Rate limited — honor `Retry-After` |
| `500 / 501 / 503` | Server error / not implemented / unavailable — retry with backoff |

There is no hard rate-limit cap documented; the guidance is to throttle and cache reasonably.
