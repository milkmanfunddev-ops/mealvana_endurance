# Garmin — Activity API Data Model

The Activity API delivers **completed, device-recorded fitness activities** (runs, rides, swims,
multisport) that the user intentionally started on a Garmin wearable or cycling computer _(Garmin
spec — Activity API §2)_. Five summary types: activity summaries, activity details (with
samples/laps), manually-updated activities, activity files (FIT/TCX/GPX), and Move IQ events.

All timestamps are **UTC Unix epoch seconds**; `startTimeOffsetInSeconds` is added to derive device-
local time (not a standard timezone offset) _(Garmin spec — §6.1)_.

## Activity summary fields _(Garmin spec — §7.1)_

| Field | Type | Unit | Notes |
|---|---|---|---|
| `summaryId` | string | — | Unique summary identifier. |
| `activityId` | string/int | — | Activity ID at Garmin Connect. |
| `activityName` | string | — | Garmin Connect activity name. |
| `activityType` | string | — | See [Activity types](#activity-types). |
| `startTimeInSeconds` | int | epoch s (UTC) | Activity start. |
| `startTimeOffsetInSeconds` | int | s | Add to start time for device-local time. |
| `durationInSeconds` | int | s | Monitoring-period length. |
| `distanceInMeters` | float | m | |
| `activeKilocalories` | int | kcal | Includes activity + BMR calories. |
| `averageHeartRateInBeatsPerMinute` | int | bpm | |
| `maxHeartRateInBeatsPerMinute` | float | bpm | |
| `averageSpeedInMetersPerSecond` | float | m/s | |
| `maxSpeedInMetersPerSecond` | float | m/s | |
| `averagePaceInMinutesPerKilometer` | float | min/km | |
| `maxPaceInMinutesPerKilometer` | float | min/km | |
| `averageBikeCadenceInRoundsPerMinute` | float | rpm | |
| `maxBikeCadenceInRoundsPerMinute` | float | rpm | |
| `averageRunCadenceInStepsPerMinute` | float | spm | |
| `maxRunCadenceInStepsPerMinute` | float | spm | |
| `averageSwimCadenceInStrokesPerMinute` | float | strokes/min | |
| `numberOfActiveLengths` | int | — | Pool lengths. |
| `steps` | int | — | |
| `totalElevationGainInMeters` | float | m | |
| `totalElevationLossInMeters` | float | m | |
| `startingLatitudeInDegree` | float | ° | |
| `startingLongitudeInDegree` | float | ° | |
| `deviceName` | string | — | Device model. `"unknown"` when unidentified; always `"unknown"` for manual activities. |
| `manual` | boolean | — | Not recorded on-device / created on Garmin Connect. |
| `isWebUpload` | boolean | — | Uploaded via the Garmin Connect web app. |
| `isParent` | boolean | — | `true` → parent of child activities (e.g. `MULTI_SPORT`). |
| `parentSummaryId` | string | — | Parent's `summaryId` (child legs of a multisport). |
| `pushes` / `averagePushCadenceInPushesPerMinute` / `maxPushCadenceInPushesPerMinute` | int/float | pushes, pushes/min | Wheelchair-mode only. |

_(confirmed in sample payloads)_ Real push bodies additionally carry `userId`, `userAccessToken`,
`elevationGainInMeters`, `elevationLossInMeters`, `averagePowerInWatts`, `maxPowerInWatts`,
`normalizedPowerInWatts`. See [`examples/push-activity-run.json`](examples/push-activity-run.json),
[`push-activity-bike.json`](examples/push-activity-bike.json),
[`push-activity-swim.json`](examples/push-activity-swim.json).

```json
{ "activities": [ {
  "userId": "<USER_ID>", "userAccessToken": "<USER_ACCESS_TOKEN>",
  "summaryId": "act-run-001", "activityType": "running", "activityName": "Easy Morning Run",
  "durationInSeconds": 2700, "startTimeInSeconds": 1711612800, "startTimeOffsetInSeconds": -18000,
  "distanceInMeters": 5200, "activeKilocalories": 380,
  "averageHeartRateInBeatsPerMinute": 142, "maxHeartRateInBeatsPerMinute": 168,
  "averageRunCadenceInStepsPerMinute": 172, "averageSpeedInMetersPerSecond": 1.93,
  "averagePaceInMinutesPerKilometer": 8.65, "elevationGainInMeters": 35, "elevationLossInMeters": 40,
  "deviceName": "Garmin Forerunner 965"
} ] }
```

## Manually-updated activities _(Garmin spec — §7.2)_

Same field set as summaries, for activities the user edited directly on Garmin Connect (not device-
uploaded). `deviceName` is always `"unknown"`; `manual: true`. Envelope key
`manuallyUpdatedActivities`. See
[`examples/push-manually-updated-activity.json`](examples/push-manually-updated-activity.json).

## Activity details (samples + laps) _(Garmin spec — §7.3)_

An activity detail wraps a `summary` object (all fields above) plus an optional `samples` list and
`laps` list. Samples are empty for manual activities or unsupported devices; sampling can be as
frequent as once per second. **24-hour duration cap** — longer activities are only available as
Activity Files.

### Sample fields

| Field | Type | Unit | Notes |
|---|---|---|---|
| `startTimeInSeconds` | int | epoch s | Sample time. |
| `latitudeInDegree` / `longitudeInDegree` | float | ° | Decimal degrees. |
| `elevationInMeters` | float | m | |
| `airTemperatureCelcius` | float | °C | |
| `heartRate` | int | bpm | |
| `speedMetersPerSecond` | float | m/s | Not for pool swims. |
| `stepsPerMinute` | float | spm | |
| `totalDistanceInMeters` | float | m | Cumulative. |
| `powerInWatts` | float | W | |
| `bikeCadenceInRPM` | float | rpm | |
| `swimCadenceInStrokesPerMinute` | float | strokes/min | Not for pool swims. |
| `directWheelchairCadence` | float | pushes/min | Wheelchair mode. |
| `timerDurationInSeconds` | int | s | "Timer time." |
| `clockDurationInSeconds` | int | s | Real-world clock time. |
| `movingDurationInSeconds` | int | s | Time above threshold speed. Not for pool swims. |

Invariant: `movingDurationInSeconds ≤ timerDurationInSeconds ≤ clockDurationInSeconds` _(Garmin
spec)_.

### Lap fields

| Field | Type | Unit |
|---|---|---|
| `startTimeInSeconds` | int | epoch s |

_(confirmed in sample payloads)_ Delivered lap objects also include `durationInSeconds`,
`distanceInMeters`, `averageHeartRate`, `maxHeartRate`, `averageSpeedInMetersPerSecond`, and samples
also carry `runCadenceInStepsPerMinute` / `swimCadenceInStrokesPerMinute` / `powerInWatts`. Full body:
[`examples/push-activity-detail.json`](examples/push-activity-detail.json).

```json
{ "activityDetails": [ {
  "userId": "<USER_ID>", "summaryId": "act-run-001",
  "summary": { "activityType": "running", "durationInSeconds": 2700, "startTimeInSeconds": 1711612800,
               "startTimeOffsetInSeconds": -18000, "distanceInMeters": 5200 },
  "samples": [ { "startTimeInSeconds": 1711612800, "latitudeInDegree": 39.0997,
                 "longitudeInDegree": -94.5786, "elevationInMeters": 271.4, "heartRate": 118,
                 "speedMetersPerSecond": 1.7, "runCadenceInStepsPerMinute": 164 } ],
  "laps": [ { "startTimeInSeconds": 1711612800, "durationInSeconds": 900, "distanceInMeters": 1700,
              "averageHeartRate": 136, "maxHeartRate": 152, "averageSpeedInMetersPerSecond": 1.89 } ]
} ] }
```

## Multisport / parent-child _(Garmin spec)_

A `MULTI_SPORT` (triathlon/duathlon/brick) activity arrives as a **parent** (`isParent: true`) plus
**child** legs that reference it via `parentSummaryId`. Transition legs (T1/T2) appear as their own
`TRANSITION_*` activity type. See
[`examples/push-activity-multisport.json`](examples/push-activity-multisport.json).

## Activity Files _(Garmin spec — §7.4)_

Raw device files (`FIT`, `TCX`, or `GPX`), available **ping-only** (not push). The ping body carries
`fileType`, `activityType`, `deviceName`, `startTimeInSeconds`, `activityId`, `activityName`,
`manual`, and a `callbackURL` addressing the file by `id`+`token`. The URL is valid **24 hours** and
one download; repeats return `410`. Parsers/schemas: TCX (`TrainingCenterDatabasev2.xsd`),
GPX (topografix), FIT (`developer.garmin.com/fit`).

## Move IQ events _(Garmin spec — §7.5)_

Auto-detected activity spans (not user-initiated). Envelope key `moveIQActivities`. Fields:
`summaryId`, `calendarDate` (`yyyy-mm-dd`), `startTimeInSeconds`, `offsetInSeconds`,
`durationInSeconds`, `activityType`, `activitySubType`. Not editable by the user; wellness totals
(steps/distance) are already counted in Dailies/Epochs.

## Activity types _(Garmin spec — Activity API Appendix A)_

`activityType` (API name) is one of a large enumerated set; unmapped values should fall back to a
generic bucket. Representative values by family:

| Family | API names (selection) |
|---|---|
| Running | `RUNNING`, `INDOOR_RUNNING`, `TRAIL_RUNNING`, `TREADMILL_RUNNING`, `TRACK_RUNNING`, `STREET_RUNNING`, `ULTRA_RUN`, `VIRTUAL_RUN`, `OBSTACLE_RUN` |
| Cycling | `CYCLING`, `ROAD_BIKING`, `MOUNTAIN_BIKING`, `GRAVEL_CYCLING`, `INDOOR_CYCLING`, `VIRTUAL_RIDE`, `CYCLOCROSS`, `DOWNHILL_BIKING`, `BMX`, `TRACK_CYCLING`, `RECUMBENT_CYCLING`, `E_BIKE_FITNESS`, `E_BIKE_MOUNTAIN`, `ENDURO_MTB`, `E_ENDURO_MTB`, `HANDCYCLING`, `INDOOR_HANDCYCLING` |
| Swimming | `SWIMMING`, `LAP_SWIMMING`, `OPEN_WATER_SWIMMING` |
| Multisport / transition | `MULTI_SPORT`, `TRANSITION_V2`, `BIKE_TO_RUN_TRANSITION`, `RUN_TO_BIKE_TRANSITION`, `SWIM_TO_BIKE_TRANSITION` |
| Walking / hiking | `WALKING`, `CASUAL_WALKING`, `SPEED_WALKING`, `HIKING`, `RUCKING` |
| Gym & fitness | `FITNESS_EQUIPMENT`, `ELLIPTICAL`, `INDOOR_CARDIO`, `HIIT`, `INDOOR_ROWING`, `STAIR_CLIMBING`, `STRENGTH_TRAINING`, `PILATES`, `YOGA`, `MOBILITY`, `MEDITATION`, `BOULDERING`, `INDOOR_CLIMBING` |
| Winter | `WINTER_SPORTS`, `RESORT_SKIING`, `BACKCOUNTRY_SKIING`, `CROSS_COUNTRY_SKIING_WS`, `SKATE_SKIING_WS`, `SNOWBOARDING_WS`, `SNOW_SHOE_WS`, `SNOWMOBILING_WS`, `SKATING_WS` |
| Water | `WATER_SPORTS`, `KAYAKING`, `ROWING`, `PADDLING`, `SAILING`, `SURFING`, `WINDSURFING`, `KITEBOARDING`, `STAND_UP_PADDLEBOARDING`, `SNORKELING`, `WHITEWATER_RAFTING`, `WATERSKIING`, `WAKEBOARDING`, `BOATING`, `FISHING` |
| Team / racket | `TEAM_SPORTS`, `SOCCER`, `BASKETBALL`, `AMERICAN_FOOTBALL`, `BASEBALL`, `RUGBY`, `ICE_HOCKEY`, `FIELD_HOCKEY`, `LACROSSE`, `VOLLEYBALL`, `CRICKET`, `SOFTBALL`, `ULTIMATE_DISC`, `RACKET_SPORTS`, `TENNIS`, `PICKLEBALL`, `PADDELBALL` (Padel), `BADMINTON`, `SQUASH`, `RACQUETBALL`, `TABLE_TENNIS`, `PLATFORM_TENNIS` |
| Para | `PARA_SPORTS`, `WHEELCHAIR_PUSH_RUN`, `WHEELCHAIR_PUSH_WALK` |
| Other | `OTHER`, `GOLF`, `DISC_GOLF`, `BOXING`, `MIXED_MARTIAL_ARTS`, `ROCK_CLIMBING`, `FLOOR_CLIMBING`, `MOUNTAINEERING`, `INLINE_SKATING`, `JUMP_ROPE`, `DANCE`, `BREATHWORK`, `STOP_WATCH` |

See [`examples/push-activity-other-sport.json`](examples/push-activity-other-sport.json) for a
non-endurance type, and [`push-activity-zero-distance.json`](examples/push-activity-zero-distance.json)
for a valid `distanceInMeters: 0` (started-and-stopped) activity.
