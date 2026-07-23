# Garmin — Endpoints

Every endpoint across the five GCDP APIs, grouped by API. All paths are absolute. All timestamps are
**UTC Unix epoch seconds** _(Garmin spec)_.

- Host (REST/backfill/user): `https://apis.garmin.com`
- OAuth authorize: `https://connect.garmin.com`, token: `https://diauth.garmin.com`

Full field models: [`activity-data.md`](activity-data.md), [`health-data.md`](health-data.md),
[`training-courses-womens.md`](training-courses-womens.md). OAuth detail:
[`authentication.md`](authentication.md).

---

## OAuth & user endpoints

| Method | Path | Purpose |
|---|---|---|
| GET | `https://connect.garmin.com/oauth2Confirm` | Authorization request (PKCE). |
| POST | `https://diauth.garmin.com/di-oauth2-service/oauth/token` | Exchange code for tokens / refresh. |
| GET | `/wellness-api/rest/user/id` | Fetch the stable API User ID. |
| GET | `/wellness-api/rest/user/permissions` | Fetch the user's granted permissions. |
| DELETE | `/wellness-api/rest/user/registration` | Delete the user's registration (`204`). |

```
GET https://apis.garmin.com/wellness-api/rest/user/id
Authorization: Bearer <ACCESS_TOKEN>
→ {"userId":"d3315b1072421d0dd7c8f6b8e1de4df8"}

GET https://apis.garmin.com/wellness-api/rest/user/permissions
→ ["ACTIVITY_EXPORT","WORKOUT_IMPORT","HEALTH_EXPORT","COURSE_IMPORT","MCT_EXPORT"]
```

---

## Activity API _(Garmin spec — Activity API 1.2.3)_

Inbound (Garmin → partner) webhooks deliver the data; the pull endpoints below are called **only in
response to a ping** (a successful ping/push integration otherwise never calls them). Pull endpoints
accept a **max 24-hour** `uploadStartTimeInSeconds`/`uploadEndTimeInSeconds` window (query by upload
time, i.e. when the user synced).

| Method | Path | Purpose |
|---|---|---|
| POST | (partner endpoint) | Receive `activities` / `activityDetails` / `manuallyUpdatedActivities` push or ping. |
| GET | `/wellness-api/rest/activities?uploadStartTimeInSeconds=&uploadEndTimeInSeconds=` | Pull activity summaries (ping callback). |
| GET | `/wellness-api/rest/activityDetails?uploadStartTimeInSeconds=&uploadEndTimeInSeconds=` | Pull activity details (samples + laps). Push only for historical; 24 h duration cap. |
| GET | `/wellness-api/rest/manuallyUpdatedActivities?uploadStartTimeInSeconds=&uploadEndTimeInSeconds=` | Pull user-edited activities. |
| GET | `/wellness-api/rest/activityFile?id=&token=` | Download a raw FIT/TCX/GPX file (ping only; URL valid 24 h, one download). |

```
GET https://apis.garmin.com/wellness-api/rest/activities
    ?uploadStartTimeInSeconds=1452470400&uploadEndTimeInSeconds=1452556800
→ [ { "summaryId":"5001968355", "activityType":"RUNNING", "startTimeInSeconds":1452470400,
      "startTimeOffsetInSeconds":0, "durationInSeconds":11580,
      "averageSpeedInMetersPerSecond":2.889, "distanceInMeters":519818.125,
      "activeKilocalories":448, "deviceName":"fenix 8" } ]
```

---

## Health API _(Garmin spec — Health API 1.2.2)_

Same webhook + ping-callback model, **max 24-hour** upload-time window. One pull endpoint per
wellness type:

| Method | Path (`/wellness-api/rest/…`) | Data type |
|---|---|---|
| GET | `dailies` | Daily summaries |
| GET | `epochs` | 15-minute epochs |
| GET | `sleeps` | Sleep summaries |
| GET | `bodyComps` | Body composition |
| GET | `stressDetails` | Stress + Body Battery |
| GET | `userMetrics` | VO2max / fitness age |
| GET | `pulseox` | Pulse ox (SpO2) |
| GET | `allDayRespiration` | Respiration |
| GET | `healthSnapshot` | Health Snapshot |
| GET | `hrv` | Heart-rate variability |
| GET | `bloodPressures` | Blood pressure |
| GET | `skinTemp` | Skin temperature |

Each takes `?uploadStartTimeInSeconds=&uploadEndTimeInSeconds=`.

---

## Women's Health API _(Garmin spec — Women's API 1.0.4)_

| Method | Path | Purpose |
|---|---|---|
| POST | (partner endpoint) | Receive `mct` push/ping. |
| GET | `/wellness-api/rest/mct?uploadStartTimeInSeconds=&uploadEndTimeInSeconds=` | Pull MCT summaries (0–1 per response). |

---

## Backfill (Activity, Health, Women's) _(Garmin spec)_

Requests historic data (recorded before registration or purged by retention). Returns **`202
Accepted`** with no body; the data is delivered later through the normal push/ping path. Params:
`summaryStartTimeInSeconds`, `summaryEndTimeInSeconds` (both required, by **record** time).
Max window per request: **90 days** (Health/Women's) or **30 days** (Activity). Duplicate requests →
`409`.

| Method | Path (`/wellness-api/rest/backfill/…`) | Backfills |
|---|---|---|
| GET | `activities` | Activity summaries + files |
| GET | `activityDetails` | Activity details (push only) |
| GET | `moveiq` | Move IQ events |
| GET | `dailies` | Dailies |
| GET | `epochs` | Epochs |
| GET | `sleeps` | Sleeps |
| GET | `bodyComps` | Body composition |
| GET | `stressDetails` | Stress details |
| GET | `userMetrics` | User metrics |
| GET | `pulseOx` | Pulse ox |
| GET | `respiration` | Respiration |
| GET | `healthSnapshot` | Health snapshot |
| GET | `hrv` | HRV |
| GET | `bloodPressures` | Blood pressure |
| GET | `skinTemp` | Skin temperature |
| GET | `mct` | Menstrual cycle tracking |

```
GET https://apis.garmin.com/wellness-api/rest/backfill/dailies
    ?summaryStartTimeInSeconds=1452384000&summaryEndTimeInSeconds=1453248000
→ 202 Accepted   (data arrives later via push/ping)
```

---

## Training API v2 (partner → Garmin) _(Garmin spec — Training API V2)_

Writes require the `WORKOUT_IMPORT` permission. Rate-limit breaches → `429`.

### Workouts

| Method | Path | Purpose |
|---|---|---|
| POST | `https://apis.garmin.com/workoutportal/workout/v2` | Create a workout (no `workoutId` in body). Returns the created workout. |
| GET | `https://apis.garmin.com/training-api/workout/v2/{workoutId}` | Retrieve a workout. |
| PUT | `https://apis.garmin.com/training-api/workout/v2/{workoutId}` | Update a workout (full body). |
| DELETE | `https://apis.garmin.com/training-api/workout/v2/{workoutId}` | Delete a workout. |

### Workout schedules

| Method | Path | Purpose |
|---|---|---|
| POST | `https://apis.garmin.com/training-api/schedule/` | Schedule a workout for a date. |
| GET | `https://apis.garmin.com/training-api/schedule/{workoutScheduleId}` | Retrieve a schedule. |
| PUT | `https://apis.garmin.com/training-api/schedule/{workoutScheduleId}` | Update a schedule. |
| DELETE | `https://apis.garmin.com/training-api/schedule/{workoutScheduleId}` | Delete a schedule. |
| GET | `https://apis.garmin.com/training-api/schedule?startDate=YYYY-MM-DD&endDate=YYYY-MM-DD` | Retrieve schedules by date range. |

Permissions probe: `GET https://apis.garmin.com/userPermissions/` → `["WORKOUT_IMPORT"]`.

Response codes: `200/204` success · `400` bad request · `401` UAT missing · `403` not allowed ·
`412` user-permission error · `429` rate-limited.

---

## Courses API (partner → Garmin) _(Garmin spec — Courses API)_

Writes require `COURSE_IMPORT`. Up to 50 courses may sync to a device at once.

| Method | Path | Purpose |
|---|---|---|
| POST | `https://apis.garmin.com/training-api/courses/v1/course` | Create a course (no `courseId` in body). Returns the created course. |
| GET | `https://apis.garmin.com/training-api/courses/v1/course/{courseId}` | Retrieve a course. |
| PUT | `https://apis.garmin.com/training-api/courses/v1/course/{courseId}` | Update a course. |
| DELETE | `https://apis.garmin.com/training-api/courses/v1/course/{courseId}` | Delete a course (`204`). |

Permissions probe: `GET https://apis.garmin.com/userPermissions/` → `["COURSE_IMPORT"]`.

Response codes: `200` success · `204` updated/deleted · `401` UAT missing · `404` not found ·
`412` user-permission error · `429` rate-limited.

---

## Error responses (REST APIs) _(Garmin spec)_

Errors return a JSON body `{ "errorMessage": "…" }` with one of:

| Status | Meaning |
|---|---|
| `400` | Bad request — an input parameter is invalid (e.g. timestamp in ms not s). |
| `401` | Authorization failed. |
| `403` | UAT unknown — malformed or user revoked consent. |
| `409` | Backfill duplicate — this window was already requested. |
| `412` | Precondition failed — UAT valid but user hasn't granted this summary type. |
| `429` | Too many requests (Training/Courses rate limit). |
| `500` | Internal server error. |

Activity Files download quirks: the callback URL is valid for **24 hours** and **one** download;
duplicate downloads return `410 Gone` _(Garmin spec — Activity API §7.4)_.
