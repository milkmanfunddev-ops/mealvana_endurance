# Garmin — Complete Field Reference

Every field across all GCDP APIs in one lookup table: field name, API, type, unit, example value,
notes. All timestamps are **UTC Unix epoch seconds**; a paired `startTimeOffsetInSeconds` gives
device-local time (not a standard timezone offset). Source: _(Garmin spec)_ unless a note says
_(payload)_ = confirmed in sample payloads.

## Envelope / common

| Field | API | Type | Unit | Example | Notes |
|---|---|---|---|---|---|
| `userId` | all (Garmin→partner) | string | — | `d3315b10…` | Stable API User ID; persists across UATs. |
| `userAccessToken` | all (push) | string | — | `<USER_ACCESS_TOKEN>` | UAT of the user who generated the data. |
| `summaryId` | all | string | — | `act-run-001` | Unique record identifier. |
| `callbackURL` | ping | string | — | `…/rest/activities?...` | GET to pull data (ping mode). |
| `uploadStartTimeInSeconds` / `uploadEndTimeInSeconds` | ping | int | epoch s | `1711584000` | Upload-time window of new data. |
| `startTimeInSeconds` | Activity, Health | int | epoch s (UTC) | `1711612800` | Record start. |
| `startTimeOffsetInSeconds` | Activity, Health | int | s | `-18000` | Add for device-local time. |
| `calendarDate` | Health (per-day) | string | yyyy-mm-dd | `2024-03-28` | Display date, no tz math. |
| `durationInSeconds` | Activity, Health | int | s | `2700` | Monitoring-period length. |

## Activity API

| Field | Type | Unit | Example | Notes |
|---|---|---|---|---|
| `activityId` | string/int | — | `5001968355` | Garmin Connect activity ID. |
| `activityName` | string | — | `Easy Morning Run` | |
| `activityType` | string | — | `RUNNING` | See activity-data.md list. |
| `distanceInMeters` | float | m | `5200` | `0` is valid (started/stopped). |
| `activeKilocalories` | int | kcal | `380` | Activity + BMR. |
| `averageHeartRateInBeatsPerMinute` | int | bpm | `142` | |
| `maxHeartRateInBeatsPerMinute` | float | bpm | `168` | |
| `averageSpeedInMetersPerSecond` / `maxSpeedInMetersPerSecond` | float | m/s | `1.93` | |
| `averagePaceInMinutesPerKilometer` / `maxPaceInMinutesPerKilometer` | float | min/km | `8.65` | |
| `averageRunCadenceInStepsPerMinute` / `maxRunCadenceInStepsPerMinute` | float | spm | `172` | |
| `averageBikeCadenceInRoundsPerMinute` / `maxBikeCadenceInRoundsPerMinute` | float | rpm | `85` | |
| `averageSwimCadenceInStrokesPerMinute` | float | strokes/min | `34` | |
| `averagePowerInWatts` / `maxPowerInWatts` / `normalizedPowerInWatts` | float | W | `210` | _(payload)_ |
| `elevationGainInMeters` / `elevationLossInMeters` | float | m | `35` | _(payload)_; spec: `totalElevationGainInMeters`/`totalElevationLossInMeters`. |
| `maxElevationInMeters` / `minElevationInMeters` | float | m | `312` | _(payload)_ |
| `numberOfActiveLengths` | int | — | `20` | Pool lengths. |
| `steps` | int | — | `5022` | |
| `startingLatitudeInDegree` / `startingLongitudeInDegree` | float | ° | `39.0997` | |
| `deviceName` | string | — | `Forerunner 965` | `"unknown"` when unidentified. |
| `manual` | boolean | — | `true` | Created on Connect, not device. |
| `isWebUpload` | boolean | — | `false` | Uploaded via web app. |
| `isParent` | boolean | — | `true` | Multisport parent. |
| `parentSummaryId` | string | — | `act-multi-001` | Child → parent link. |
| `pushes` / `averagePushCadenceInPushesPerMinute` / `maxPushCadenceInPushesPerMinute` | int/float | pushes / min | `120` | Wheelchair mode. |

### Activity detail — sample

| Field | Type | Unit | Notes |
|---|---|---|---|
| `latitudeInDegree` / `longitudeInDegree` | float | ° | Decimal degrees. |
| `elevationInMeters` | float | m | |
| `airTemperatureCelcius` | float | °C | |
| `heartRate` | int | bpm | |
| `speedMetersPerSecond` | float | m/s | Not pool swim. |
| `stepsPerMinute` / `runCadenceInStepsPerMinute` | float | spm | Latter _(payload)_. |
| `bikeCadenceInRPM` | float | rpm | |
| `swimCadenceInStrokesPerMinute` | float | strokes/min | |
| `powerInWatts` | float | W | |
| `directWheelchairCadence` | float | pushes/min | Wheelchair mode. |
| `totalDistanceInMeters` | float | m | Cumulative. |
| `timerDurationInSeconds` / `clockDurationInSeconds` / `movingDurationInSeconds` | int | s | moving ≤ timer ≤ clock. |

### Activity detail — lap

`startTimeInSeconds` (int, epoch s). _(payload)_ also `durationInSeconds`, `distanceInMeters`,
`averageHeartRate`, `maxHeartRate`, `averageSpeedInMetersPerSecond`.

### Activity file (ping) / Move IQ

Files: `fileType` (`FIT`/`TCX`/`GPX`), `activityType`, `deviceName`, `activityId`, `activityName`,
`activityDescription`, `manual`, `callbackURL`. Move IQ: `calendarDate`, `offsetInSeconds`,
`activityType`, `activitySubType`.

## Health API

### Dailies

| Field | Type | Unit | Notes |
|---|---|---|---|
| `steps` | int | — | |
| `distanceInMeters` | float | m | |
| `activeTimeInSeconds` | int | s | |
| `activeKilocalories` | int | kcal | Excludes BMR. |
| `bmrKilocalories` | int | kcal | Basal rate. |
| `moderateIntensityDurationInSeconds` / `vigorousIntensityDurationInSeconds` | int | s | MET 3–6 / >6. |
| `floorsClimbed` / `floorsClimbedGoal` | int | — | |
| `minHeartRateInBeatsPerMinute` / `averageHeartRateInBeatsPerMinute` / `maxHeartRateInBeatsPerMinute` / `restingHeartRateInBeatsPerMinute` | int | bpm | Avg = 7-day. |
| `timeOffsetHeartRateSamples` | map | offset s → bpm | 15-s samples. |
| `averageStressLevel` / `maxStressLevel` | int | 1–100 | `-1` = no data. |
| `stressDurationInSeconds` / `restStressDurationInSeconds` / `activityStressDurationInSeconds` / `lowStressDurationInSeconds` / `mediumStressDurationInSeconds` / `highStressDurationInSeconds` | int | s | |
| `stressQualifier` | string | — | `calm`…`very_stressful_awake`. |
| `bodyBatteryChargedValue` / `bodyBatteryDrainedValue` | int | — | Day gain/drain. |
| `bodyBatteryHighestValue` / `bodyBatteryLowestValue` | int | 0–100 | _(payload)_ |
| `stepsGoal` / `intensityDurationGoalInSeconds` | int | — / s | |
| `pushes` / `pushDistanceInMeters` / `pushesGoal` | int/float | — | Wheelchair mode. |

### Epochs

`activeTimeInSeconds` (s), `steps` (int), `distanceInMeters` (m), `activeKilocalories` (kcal),
`met` (float MET), `intensity` (`SEDENTARY`/`ACTIVE`/`HIGHLY_ACTIVE`), `meanMotionIntensity` /
`maxMotionIntensity` (0–7), `activityType` (`WALKING`/`RUNNING`/`SEDENTARY`/`GENERIC`/`SLEEP`/`WHEELCHAIR_PUSH`).

### Sleeps

| Field | Type | Unit | Notes |
|---|---|---|---|
| `deepSleepDurationInSeconds` / `lightSleepDurationInSeconds` / `remSleepInSeconds` / `awakeDurationInSeconds` / `unmeasurableSleepInSeconds` | int | s | |
| `totalNapDurationInSeconds` | int | s | |
| `sleepLevelsMap` | map | — | level → [{start,end}]. |
| `validation` | string | — | `DEVICE`, `AUTO_FINAL`, `ENHANCED_FINAL`, … |
| `timeOffsetSleepRespiration` | map | offset s → breaths/min | |
| `timeOffsetSleepSpo2` | map | offset s → % | |
| `overallSleepScore` | map | — | `{value, qualifierKey}`. |
| `sleepScores` | map | — | Component qualifiers. |
| `sleepScoreQuality` / `sleepQualityScore` / `sleepDurationScore` / `restlessMomentsCount` | string/int | — | _(payload)_ |
| `naps` | list | — | `{napDurationInSeconds, napStartTimeInSeconds, napValidation, napOffsetInSeconds}`. |

### Body composition

`measurementTimeInSeconds` / `measurementTimeOffsetInSeconds` (epoch s / s), `weightInGrams` (g),
`bodyFatInPercent` / `bodyWaterInPercent` (% 0–100), `muscleMassInGrams` / `boneMassInGrams` (g),
`bodyMassIndex` (float). _(payload)_ variant keys: `percentFat`, `percentHydration`, `bmi`.

### Stress details

`timeOffsetStressLevelValues` (map offset s → 1–100; negatives −1…−5), `timeOffsetBodyBatteryValues`
(map offset s → 0–100), `bodyBatteryDynamicFeedbackEvent` (`{eventStartTimeInSeconds,
bodyBatteryLevel}`), `bodyBatteryActivityEvents` (list of `{eventType, eventStartTimeInSeconds,
eventStartTimeOffsetInSeconds, duration, bodyBatteryImpact}`).

### User metrics

`vo2Max` (ml/kg/min), `vo2MaxCycling` (ml/kg/min), `fitnessAge` (years), `enhanced` (boolean).

### Pulse ox / Respiration / HRV / Snapshot / BP / Skin temp

| Field | Type | Unit | API |
|---|---|---|---|
| `timeOffsetSpo2Values` | map | offset s → % | Pulse ox |
| `onDemand` | boolean | — | Pulse ox |
| `timeOffsetEpochToBreaths` | map | offset s → breaths/min | Respiration |
| `lastNightAvg` / `lastNight5MinHigh` | int | ms | HRV |
| `hrvValues` | map | offset s → rmssd (ms) | HRV |
| `summaries` | list | — | Snapshot (`{summaryType,minValue,maxValue,avgValue,epochSummaries}`) |
| `systolic` / `diastolic` | int | mmHg | Blood pressure |
| `pulse` | int | bpm | Blood pressure |
| `sourceType` | string | `MANUAL`/`DEVICE` | Blood pressure |
| `measurementTimeInSeconds` / `measurementTimeOffsetInSeconds` | int | epoch s / s | BP, body comp |
| `avgDeviationCelsius` | float | °C | Skin temp |

## Training API v2

Workout: `workoutId`, `ownerId` (long), `workoutName`, `description`, `sport`,
`estimatedDurationInSecs` (s), `estimatedDistanceInMeters` (m), `poolLength` (double) /
`poolLengthUnit` (`YARD`/`METER`), `workoutProvider`, `workoutSourceId`,
`isSessionTransitionEnabled` (bool), `segments`, `createdDate`/`updatedDate`.
Segment: `segmentOrder`, `sport`, `estimated*`, `poolLength*`, `steps`.
Step: `type`, `stepId`, `stepOrder`, `intensity`, `description`, `durationType`, `durationValue`,
`durationValueType`, `targetType`, `targetValue`/`Low`/`High`/`Type`, `secondaryTarget*`,
`repeatType`, `repeatValue`, `skipLastRestStep`, `strokeType`, `drillType`, `equipmentType`,
`exerciseCategory`, `exerciseName`, `weightValue` (kg), `weightDisplayUnit` (`KILOGRAM`/`POUND`).
Schedule: `scheduleId`, `workoutId`, `date` (`YYYY-MM-DD`).

## Courses API

Course: `courseId` (long), `elapsedSeconds` (double), `courseName`, `description`, `distance` (m),
`elevationGain`/`elevationLoss` (m), `activityType`, `speedMetersPerSecond` (m/s),
`coordinateSystem` (`WGS84`/`GCJ02`/`BD09`), `geoPoints`.
GeoPoint: `latitude`, `longitude`, `elevation` (m), `distance` (m), `information`.
CoursePoint: `coursePointType`, `name`, `segmentUuid`.

## Women's Health API (MCT)

`periodStartDate` (date), `dayInCycle` (int), `periodLength` (int), `currentPhase` (int),
`currentPhaseType` (string), `lengthOfCurrentPhase` (int), `daysUntilNextPhase` (int),
`fertileWindowStart` / `lengthOfFertileWindow` (int), `predictedCycleLength` (int),
`isPredictedCycle` (bool), `cycleLength` (int), `lastUpdatedTimeInSeconds` (epoch s),
`hasSpecifiedCycleLength` / `hasSpecifiedPeriodLength` (bool), `pregnancySnapshot` (object:
`title`, `originalDueDate`, `dueDate`, `pregnancyCycleStartDate`, `numOfBabies`,
`weightGoalUserInput{heightInCentimeters, weightInGrams}`, `bloodGlucoseList[{valueInMilligramsPerDeciliter,
logType, reportTimestampInSeconds}]`).

## Lifecycle

`deregistrations` (list of `{userId, userAccessToken}`), `userPermissionsChange` (list of
`{userId, summaryId, permissions, changeTimeInSeconds}`; permission strings `ACTIVITY_EXPORT`,
`HEALTH_EXPORT`, `WORKOUT_IMPORT`, `COURSE_IMPORT`, `MCT_EXPORT`).
