# TrainingPeaks — Field Reference

One lookup table per object for every documented TrainingPeaks field: name, type, unit, example, and
notes. Units follow the API-wide conventions (metres, decimal hours, kilograms, m/s, watts, bpm,
grams) — see [`README.md`](README.md#units--read-these-first).

---

## OAuth token response

`POST /oauth/token`

| Field | Type | Unit | Example | Notes |
|---|---|---|---|---|
| `access_token` | string | — | `<ACCESS_TOKEN>` | Bearer token for API calls |
| `token_type` | string | — | `bearer` | |
| `expires_in` | int | **seconds** | `3600` | Documented 600, observed up to 3600 |
| `refresh_token` | string | — | `<REFRESH_TOKEN>` | Used to obtain new tokens |
| `scope` | string | — | `athlete:profile workouts:read` | Space-delimited granted scopes |

---

## Athlete profile

`GET /v1/athlete/profile`

| Field | Type | Unit | Example | Notes |
|---|---|---|---|---|
| `Id` | int | — | `123456` | Athlete id |
| `FirstName` | string | — | `John` | |
| `LastName` | string | — | `Doe` | |
| `Email` | string | — | `jdoe@example.com` | |
| `TimeZone` | string | — | `America/Denver` | IANA identifier |
| `BirthMonth` | string | — | `1980-10` | `YYYY-MM`, no day |
| `Sex` | string | — | `m` | `"m"` or `"f"` |
| `CoachedBy` | int | — | `987654` | Coach id; absent/null if uncoached |
| `Weight` | number | **kg** | `87.522` | Always kg, ignores `PreferredUnits` |
| `IsPremium` | bool | — | `true` | Excludes trial subscriptions |
| `PreferredUnits` | string | — | `English` | `"English"` or `"Metric"`; display only |

---

## Training zones

`GET /v1/athlete/profile/zones` — three families: `HeartRateZones` (bpm), `SpeedZones` (**m/s**),
`PowerZones` (watts). Each family maps set names (`Default`, `Run`, `Swim`, …) to a zone set.

| Field | Type | Unit | Example | Notes |
|---|---|---|---|---|
| `Threshold` | number | watts / bpm / m/s | `250` | FTP / LTHR / threshold speed |
| `MaxHeartRate` | int | bpm | `192` | HR family only |
| `RestingHeartRate` | int | bpm | `48` | HR family only |
| `WorkoutType` | string | — | `Default` | Sport the set applies to |
| `Zones[].Label` | string | — | `1 - Recovery` | Zone name/number |
| `Zones[].Minimum` | number | family unit | `48` | Band lower bound |
| `Zones[].Maximum` | number | family unit | `114` | Band upper bound |

---

## Workout object

`GET /v2/workouts/...`, `POST`/`PUT /v2/workouts/plan`. Planned fields carry a `Planned` suffix;
completed fields do not.

### Identity & common

| Field | Type | Unit | Example | Notes |
|---|---|---|---|---|
| `Id` | int (`Int64`) | — | `123456789` | Workout id |
| `AthleteId` | int | — | `54321` | |
| `WorkoutDay` | ISO 8601 | — | `2026-07-21T00:00:00` | Calendar day; time ignored on write |
| `WorkoutType` | string | — | `Run` | `swim/bike/run/x-train/mtb/strength/xc-ski/rowing/walk/other` |
| `Title` | string | — | `Track Intervals` | May be absent |
| `Description` | string | — | `4x1000m ...` | Free text; returned when `includeDescription=true` |
| `Tags` | string[] | — | `["quality","track"]` | Null for basic athletes |
| `Structure` | string(JSON) | — | `"[{...}]"` | JSON-encoded interval array (see below) |
| `StructureDisplayUnit` | string | — | `kilometer` | Preferred display unit for `Structure` |
| `Locked` | bool | — | `false` | |
| `Hidden` | bool | — | `false` | |

### Planned fields

| Field | Type | Unit | Example | Notes |
|---|---|---|---|---|
| `StartTimePlanned` | ISO 8601 | — | `2026-07-21T06:30:00` | Planned start time of day |
| `TotalTimePlanned` | number | **decimal hours** | `0.75` | `0.75` = 45 min; max 99:59:59 |
| `DistancePlanned` | number | **metres** | `8000.0` | Max 99 999 999 |
| `TSSPlanned` | number | score | `65.0` | Max 9999; recomputed if `Structure` present |
| `IFPlanned` | number | fraction | `0.95` | Max 5; recomputed if `Structure` present |
| `CaloriesPlanned` | number | kcal | `520.0` | |
| `EnergyPlanned` | number | kJ | `2500` | |
| `ElevationGainPlanned` | number | metres | `45.0` | |

### Completed fields

| Field | Type | Unit | Example | Notes |
|---|---|---|---|---|
| `StartTime` | ISO 8601 | — | `2026-07-22T12:57:59` | Actual start |
| `TotalTime` | number | **decimal hours** | `1.25` | `1.25` = 1 h 15 min |
| `Distance` | number | **metres** | `100000` | `100000` = 100 km |
| `TssActual` | number | score | `82.0` | |
| `IF` | number | fraction | `0.78` | |
| `Calories` | number | kcal | `1150` | |
| `Energy` | number | kJ | — | |
| `ElevationGain` | number | metres | `640` | Also `ElevationLoss`, `ElevationMinimum/Average/Maximum` |
| `HeartRateAverage` | int | bpm | `141` | Also `HeartRateMinimum`, `HeartRateMaximum` |
| `PowerAverage` | int | watts | `198` | Also `PowerMaximum` |
| `NormalizedPower` | int | watts | `214` | |
| `NormalizedSpeed` | number | m/s | — | |
| `VelocityAverage` | number | m/s | `22.2` | Also `VelocityMaximum` |
| `TorqueAverage` | number | N·m | — | Also `TorqueMaximum` |
| `CadenceAverage` | int | rpm/spm | `87` | Also `CadenceMaximum` |
| `TempMin` / `TempAvg` / `TempMax` | number | °C | — | |
| `Rpe` | int | 1–10 | `6` | Rate of perceived exertion |
| `Feeling` | int | — | `4` | Subjective feeling |

> For **basic athletes**, the performance/health fields above (and `TSSPlanned`, `IFPlanned`,
> `CaloriesPlanned`, `ElevationGainPlanned`, `Tags`) return `null` and are ignored on write.

---

## `Structure` segment (decoded)

The `Structure` string decodes to an array of these segments.

| Field | Type | Unit | Example | Notes |
|---|---|---|---|---|
| `Type` | string | — | `Step` | `"Step"` or `"Repetition"` |
| `Length.Unit` | string | — | `Minute` | `Second` / `Minute` / `Hour` / `Meter` |
| `Length.Value` | int | per `Unit` | `10` | Duration or distance |
| `IntensityClass` | string | — | `WarmUp` | `WarmUp` / `Active` / `Rest` / `CoolDown` |
| `Name` | string | — | `Warm Up` | Optional label |
| `IntensityTarget.Unit` | string | — | `PercentOfFtp` | `PercentOfFtp` / `PercentOfMaxHr` / `PercentOfThresholdHr` / `PercentOfThresholdSpeed` / `Rpe` |
| `IntensityTarget.Value` | number | fraction | `0.95` | `0.95` = 95 %; integer for `Rpe` |
| `IntensityTarget.MinValue` / `MaxValue` | number | fraction | `1.00` / `1.10` | Target range; `Value` is midpoint |
| `CadenceTarget.MinValue` / `MaxValue` | int | rpm | `90` / `100` | Optional |
| `OpenDuration` | bool | — | `false` | Flexible duration above `Length` minimum |
| `RepeatCount` | int | — | `4` | `Repetition` only |
| `Steps` | array | — | `[{...}]` | `Repetition` only; nested steps |

---

## Event object

`GET /v2/events/next`, `GET /v2/events/{date}`, `POST /v2/events`

| Field | Type | Unit | Example | Notes |
|---|---|---|---|---|
| `Id` | int | — | `123456` | Event id |
| `AthleteId` | int | — | `54321` | |
| `EventDate` | ISO 8601 | — | `2026-10-12T00:00:00` | |
| `EventType` | string | — | `Triathlon` | Discipline (see `POST /v2/events` value list) |
| `Name` | string | — | `Ironman Kona` | |
| `Description` | string | — | `World Championship` | |
| `WorkoutIds` | int[] (`Int64`) | — | `[789,790,791]` | Linked workouts |
| `Goals[].GoalType` | string | — | `Distance` | `Distance` / `Time` / `Place` / `Pr` |
| `Goals[].Value` | number or bool | per goal | `140.1` | **boolean** for `Pr`, numeric otherwise |
| `Goals[].Unit` | string | — | `Miles` | `Miles`, `Hours`, or `null` |

---

## Metric object

`GET /v2/metrics/{metricId}`, `POST /v2/metrics`

| Field | Type | Unit | Example | Notes |
|---|---|---|---|---|
| `MetricId` | string (uuid) | — | `uuid-string` | |
| `AthleteId` | int | — | `123456789` | |
| `DateTime` | ISO 8601 | — | `2016-02-18T22:56:00` | Local, minute precision |
| `UploadClient` | string | — | `MyApp v1.0` | Source app |
| `WeightInKilograms` | number | **kg** | `68.1` | |
| `HRV` | number | ms | `84.1` | Heart-rate variability |
| `Steps` | int | count | `12345` | |
| `Stress` | string | — | `Low` | e.g. Low/Medium/High |
| `SleepQuality` | string | — | `Good` | e.g. Good/Fair/Poor |

---

## Nutrition object

`GET`/`POST`/`PUT /v1/athletes/{athleteId}/nutrition`

| Field | Type | Unit | Example | Notes |
|---|---|---|---|---|
| `NutritionId` | int | — | `111` | Assigned on create |
| `AthleteId` | int | — | `123456` | |
| `NutritionDate` | ISO 8601 | — | `2026-07-21T00:00:00` | Required; one card per day |
| `Calories` | number | kcal | `2500.0` | |
| `Carbohydrates` | number | **grams** | `320.0` | |
| `Fat` | number | **grams** | `70.0` | |
| `Protein` | number | **grams** | `120.0` | |

---

## File upload

`POST /v3/file` → `GET /v3/status/{fileTrackingId}`

| Field | Type | Example | Notes |
|---|---|---|---|
| `UploadClient` | string | `MyApp v1.0` | Required |
| `Filename` | string | `2025-11-26.fit` | Required; no reserved chars |
| `Data` | string (base64) | `...` | Required; gzip supported; FIT/TCX/PWX |
| `WorkoutDay` | ISO 8601 | `2025-11-26` | Optional override |
| `StartTime` | ISO 8601 | `2025-11-26T15:07:22` | Optional override |
| `SetWorkoutPublic` | bool | `false` | Optional |
| `Title` | string | `Afternoon Ride` | Optional |
| `Comment` | string | `Great workout!` | Optional |
| `Type` | string | `bike` | Optional sport |
| `WorkoutId` | int | `123456789` | Optional; link to planned workout |
| `Completed` (status) | bool | `true` | Poll response |
| `Status` (status) | string | `Success` | Poll response |
| `WorkoutIds` (status) | int[] | `[123456789]` | Created workout ids |

---

## Webhook subscription

`.../v1/webhook/subscriptions`

| Field | Type | Example | Notes |
|---|---|---|---|
| `Id` | string (uuid) | `0d76e887-...` | Assigned on create |
| `AthleteId` | int | `54321` | |
| `EventType` | string | `workout-created` | `workout-created/updated/deleted` |
| `WebhookUrl` | string | `https://api.example.com/callback` | Receives POST callbacks |
| `Active` | bool | `true` | Enable/disable |
| `CreatedBy` | int | `54321` | |
| `CreatedOn` | ISO 8601 | `2025-07-24T21:03:05Z` | |
