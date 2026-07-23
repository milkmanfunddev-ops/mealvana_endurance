# TrainingPeaks — Athlete, Zones & Events

Non-workout data: the athlete profile, training zones, body metrics, and the events/calendar feed.

---

## 1. Athlete profile

`GET /v1/athlete/profile` — scope `athlete:profile`. See
[`examples/athlete-profile.json`](examples/athlete-profile.json).

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

| Field | Type | Notes |
|---|---|---|
| `Id` | int | Athlete id |
| `FirstName`, `LastName` | string | |
| `Email` | string | |
| `TimeZone` | string | IANA identifier, e.g. `America/Denver` |
| `BirthMonth` | string | `YYYY-MM` (no day) |
| `Sex` | string | `"m"` or `"f"` |
| `CoachedBy` | int | Coach's id; absent/null if uncoached |
| `Weight` | number | **kilograms**, always — regardless of `PreferredUnits` |
| `IsPremium` | bool | `true` only for full premium; **excludes trials** |
| `PreferredUnits` | string | `"English"` or `"Metric"` — a display preference only |

`PreferredUnits` affects display in TrainingPeaks' own UI; it does **not** change API units. Numeric
fields are always in the API's canonical units (kg, metres, m/s, watts).

A coach reads managed athletes' profiles via `GET /v1/coach/athletes` (scope `coach:athletes`),
returning an array of the same object shape.

---

## 2. Training zones

`GET /v1/athlete/profile/zones` — scope `athlete:profile`. Returns three zone families. See
[`examples/athlete-zones.json`](examples/athlete-zones.json).

| Family | Key | Units |
|---|---|---|
| Heart rate | `HeartRateZones` | **bpm** |
| Speed | `SpeedZones` | **metres per second** |
| Power | `PowerZones` | **watts** |

Each family holds one or more named zone sets. `SpeedZones` is keyed per sport (`Default`, `Run`,
`Swim`, …); `HeartRateZones` and `PowerZones` typically expose `Default`. Each set has thresholds
and an array of labelled zone bands (`Minimum`/`Maximum`).

```json
{
  "HeartRateZones": {
    "Default": {
      "Threshold": 164,
      "MaxHeartRate": 192,
      "RestingHeartRate": 48,
      "WorkoutType": "Default",
      "Zones": [
        { "Label": "1 - Recovery", "Minimum": 48,  "Maximum": 114 },
        { "Label": "2 - Aerobic",  "Minimum": 115, "Maximum": 143 }
      ]
    }
  },
  "SpeedZones": {
    "Default": {
      "Threshold": 4.02,
      "Zones": [
        { "Label": "1", "Minimum": 0.00, "Maximum": 2.85 },
        { "Label": "2", "Minimum": 2.85, "Maximum": 3.40 }
      ]
    },
    "Run":  { "Threshold": 4.02, "Zones": [ ] },
    "Swim": { "Threshold": 1.25, "Zones": [ ] }
  },
  "PowerZones": {
    "Default": {
      "Threshold": 250,
      "Zones": [
        { "Label": "1", "Minimum": 0,   "Maximum": 137 },
        { "Label": "2", "Minimum": 138, "Maximum": 187 }
      ]
    }
  }
}
```

| Field | Meaning | Unit |
|---|---|---|
| `Threshold` | Threshold value (FTP / LTHR / threshold speed) | watts, bpm, or m/s |
| `MaxHeartRate`, `RestingHeartRate` | HR anchors (HR family) | bpm |
| `WorkoutType` | Which sport this zone set applies to | — |
| `Zones[].Label` | Zone name/number | — |
| `Zones[].Minimum`, `Zones[].Maximum` | Band bounds | same as the family's unit |

Zones change rarely; cache them and re-fetch periodically. A single family can also be fetched via
`GET /v1/athlete/zones/{zoneType}` where `{zoneType}` ∈ `HeartRate`, `Speed`, `Power`.

---

## 3. Body metrics

`GET /v2/metrics/{metricId}` — scope `metrics:read`. Daily body metrics.

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

| Field | Type | Unit / values |
|---|---|---|
| `MetricId` | string (uuid) | |
| `AthleteId` | int | |
| `DateTime` | ISO 8601 | Local time, minute precision |
| `UploadClient` | string | Source application |
| `WeightInKilograms` | number | **kg** |
| `HRV` | number | Heart-rate variability |
| `Steps` | int | |
| `Stress` | string | e.g. `Low` / `Medium` / `High` |
| `SleepQuality` | string | e.g. `Good` / `Fair` / `Poor` |

Not every field is present on every metric; new fields may be added over time. Range reads
(`GET /v2/metrics/{startDate}/{endDate}`) are **premium only**.

---

## 4. Events / calendar

An event is a race or target on the athlete's calendar. `GET /v2/events/next` returns the next one;
`GET /v2/events/{date}` returns those on a date. Scope `events:read`. See
[`examples/event-next-triathlon.json`](examples/event-next-triathlon.json).

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

| Field | Type | Notes |
|---|---|---|
| `Id` | int | Event id |
| `AthleteId` | int | |
| `EventDate` | ISO 8601 | |
| `EventType` | string | Sport/discipline (see `POST /v2/events` in [`endpoints.md`](endpoints.md) for the full value list) |
| `Name` | string | |
| `Description` | string | |
| `WorkoutIds` | int[] | Workouts linked to this event (`Int64`) |
| `Goals` | object[] | Target goals — see below |

### Goals

| `GoalType` | `Value` | `Unit` |
|---|---|---|
| `Distance` | number | `"Miles"` (or another distance unit) |
| `Time` | number | `"Hours"` |
| `Place` | number | `null` |
| `Pr` | **boolean** (`true`/`false`) | `null` |

Note `GoalType: "Pr"` carries a **boolean** `Value`, unlike the numeric goal types.

There is no bulk "all events" endpoint — enumerate a range by querying per date (or via
`/v2/events/next`). A `404` from either events endpoint means **no events**, a normal empty result
rather than an error.

Events are created with `POST /v2/events` (scope `events:write`) — see [`endpoints.md`](endpoints.md).
