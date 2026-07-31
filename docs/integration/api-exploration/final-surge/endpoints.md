# Final Surge — Endpoints

Base URL: `https://log.finalsurge.com`

Every `/API/v1/*` request must send both headers:

```
client-id: <FINAL_SURGE_CLIENT_ID>
Authorization: Bearer <access_token>
```

There are no OAuth scopes — the access token grants whatever the Partner API allows for that
athlete.

| # | Method | Path | Purpose | Provenance |
|---|---|---|---|---|
| 1 | `POST` | `/oauth/token` | Exchange auth code / refresh token for an access token | _(confirmed in sample payloads)_ |
| 2 | `GET` | `/API/v1/UpcomingWorkouts` | Next N days / N workouts from today | _(confirmed in sample payloads)_ |
| 3 | `GET` | `/API/v1/Workouts` | Workouts in an explicit date range | _(confirmed in sample payloads)_ |
| 4 | `GET` | `/API/v1/Workout/{WorkoutKey}` | One workout by key | _(confirmed in sample payloads)_ |
| 5 | `GET` | `<StructuredWorkoutURLs.json_fs_v1>` | Structured interval breakdown | _(Final Surge spec)_ |
| 6 | `GET` / `POST` | `/API/v1/ProfileInfo` | Partner-scoped key/value storage | _(Final Surge spec)_ |
| 7 | `POST` | `/API/v1/uploads` | Upload a completed FIT / TCX activity | _(Final Surge spec)_ |
| 8 | `POST` | `/API/v1/LoginToken` | Mint a short-lived web auto-login token | _(Final Surge spec)_ |

---

## 1. `POST /oauth/token`

Covered in full in [authentication.md](./authentication.md). Summary:

| Grant | Body fields |
|---|---|
| Authorization code | `client-id`, `client-secret`, `code` |
| Refresh | `client-id`, `refresh_token`, `grant_type=refresh_token` |

Credentials go in the **body** as `application/x-www-form-urlencoded`, with hyphenated key
names. Returns HTTP 200 with an `access_token`; a non-empty `error` field means failure.

---

## 2. `GET /API/v1/UpcomingWorkouts`

Returns the next scheduled workouts starting from the athlete's current day, and includes
completed workouts within the window. Only workouts within the upcoming 14 days can be
returned.

### Parameters

| Param | Type | Range | Default | Notes |
|---|---|---|---|---|
| `NumDays` | int (query) | 1–7 | 5 | Number of days to return, **including the current day**. |
| `NumWorkouts` | int (query) | 1–21 | 5 | Maximum number of workouts to return. |

Both parameters are optional and are applied together. If neither is provided, the next five
workouts are returned.

### Request

```http
GET /API/v1/UpcomingWorkouts?NumDays=7&NumWorkouts=21 HTTP/1.1
Host: log.finalsurge.com
client-id: <FINAL_SURGE_CLIENT_ID>
Authorization: Bearer REDACTED-FINAL-SURGE-TOKEN
```

### Response — HTTP 200

```json
{
  "Success": true,
  "ErrorNumber": null,
  "ErrorMessage": null,
  "Workouts": [
    {
      "WorkoutURL": "https://log.finalsurge.com/WorkoutDetails?s=f73de4d9-878c-4b6e-af37-ab2cf3540a28&id=cc3b49d9-0b25-44ff-9799-cdb5446f2d3a",
      "WorkoutDate": "2019-01-24T00:00:00",
      "WorkoutTime": "17:00:00",
      "WorkoutCode": "TRLTP",
      "WorkoutTitle": "Tempo Run",
      "WorkoutDescription": "10-15 minute Warm-Up + Tempo Run: 10-15 minutes + 10-15 minute Cooldown\r\n\r\nWorkout Purpose: \r\nBuild stamina - lactate threshold pace.",
      "WorkoutTypeName": "Run",
      "WorkoutSubTypeName": "Tempo Run",
      "WorkoutCompleted": false,
      "WorkoutIcon": 1,
      "PlannedTime": 1800,
      "PlannedDistance": 25.5,
      "PlannedDistanceType": "mi",
      "PlannedPace": "5:40-5:55",
      "PlannedPaceType": "min/mi",
      "StructuredWorkoutURLs": {
        "fit": null,
        "json_garmin_v1": null,
        "json_fs_v1": null,
        "mrc": null,
        "zwo": null
      }
    }
  ]
}
```

Only `WorkoutDate`, `WorkoutCompleted`, `WorkoutTypeName`, and `WorkoutIcon` are guaranteed
non-null; every other workout field is nullable. Full field semantics are in
[workout-data.md](./workout-data.md). Full sample:
[examples/workouts-list-response.json](./examples/workouts-list-response.json).

### Response envelope

| Field | Type | Notes |
|---|---|---|
| `Success` | bool | `true` on success. |
| `ErrorNumber` | int, nullable | e.g. `401`. |
| `ErrorMessage` | string, nullable | Error text (observed key on this endpoint). The vendor spec names this field `ErrorDescription` on some responses — read both. |
| `Workouts` | array, nullable | `null` on error. |

---

## 3. `GET /API/v1/Workouts`

Returns workouts within an explicit date range. Useful for windows that reach beyond what a
single `UpcomingWorkouts` call covers.

### Parameters

| Param | Type | Format | Notes |
|---|---|---|---|
| `StartDate` | string (query) | `YYYY-MM-DD` | Zero-padded local date. |
| `EndDate` | string (query) | `YYYY-MM-DD` | Inclusive. |

### Request

```http
GET /API/v1/Workouts?StartDate=2025-12-23&EndDate=2025-12-30 HTTP/1.1
Host: log.finalsurge.com
client-id: <FINAL_SURGE_CLIENT_ID>
Authorization: Bearer REDACTED-FINAL-SURGE-TOKEN
```

### Response

Identical envelope and workout shape to `UpcomingWorkouts` — a `Success` envelope wrapping a
`Workouts` array.

> **Availability note:** this endpoint returns `404` on some Final Surge accounts. Probe it
> before relying on it, and fall back to `UpcomingWorkouts` where it is not available.

---

## 4. `GET /API/v1/Workout/{WorkoutKey}`

Returns a single workout by its `WorkoutKey` (a GUID taken from a previous list response).

### Request

```http
GET /API/v1/Workout/79f28709-f623-4cb5-b99a-4c3161e6d20f HTTP/1.1
Host: log.finalsurge.com
client-id: <FINAL_SURGE_CLIENT_ID>
Authorization: Bearer REDACTED-FINAL-SURGE-TOKEN
```

### Response — HTTP 200

Unlike the list endpoints, this returns the **raw workout object directly**, not wrapped in
a `Success` / `Workouts` envelope. It may still carry an `ErrorMessage` field on an HTTP 200
response, so inspect the body for an error before using it.

Full sample: [examples/workout-single-response.json](./examples/workout-single-response.json).

---

## 5. `GET <StructuredWorkoutURLs.json_fs_v1>`

Not a fixed path. When a workout has structured steps, its object carries a
`StructuredWorkoutURLs` collection of format → download URL. Fetch a member URL with the same
two headers (`client-id` + `Authorization`) to download that format.

| Format | Contents |
|---|---|
| `fit` | Industry-standard FIT file with the structured workout steps loaded. |
| `json_garmin_v1` | A JSON object shaped to Garmin's Training API workout specification. |
| `json_fs_v1` | A JSON object with all of Final Surge's workout-builder features. See [workout-data.md § Structured workouts](./workout-data.md#structured-workouts). |
| `mrc` | Standard MRC file. Duration-and-power workouts only. |
| `zwo` | Zwift structured-workout format. Duration-and-power workouts only. |

A format is `null` when it is not available for that workout.

### Request

```http
GET /API/v1/StructuredWorkout/<workout>?format=json_fs_v1 HTTP/1.1
Host: log.finalsurge.com
client-id: <FINAL_SURGE_CLIENT_ID>
Authorization: Bearer REDACTED-FINAL-SURGE-TOKEN
```

### Response — HTTP 200

A structured-workout object (`workoutId`, `sport`, `steps[]`). The step schema and a full
example are in [workout-data.md § Structured workouts](./workout-data.md#structured-workouts).
Sample: [examples/structured-workout-json-fs-v1.json](./examples/structured-workout-json-fs-v1.json).

---

## 6. `GET` / `POST /API/v1/ProfileInfo`

Partner-scoped storage that Final Surge holds on the partner application's behalf for a given
athlete. It is **not** the athlete's Final Surge profile — both fields are `null` until the
partner writes to it. Requires the user-authorized headers.

### `GET /API/v1/ProfileInfo`

Read the stored values.

```json
{
  "uniqueid": null,
  "profile": null,
  "Success": true,
  "ErrorNumber": null,
  "ErrorDescription": null
}
```

### `POST /API/v1/ProfileInfo`

Store values against the athlete's account.

| Body field | Type | Max length | Notes |
|---|---|---|---|
| `uniqueid` | string | 200 | The partner's unique identifier for this athlete. |
| `profile` | string | 3000 | Additional partner-scoped profile information. |

```json
{ "Success": true, "ErrorNumber": null, "ErrorDescription": null }
```

Sample: [examples/profile-info-response.json](./examples/profile-info-response.json).

---

## 7. `POST /API/v1/uploads` _(Final Surge spec)_

Upload a completed activity file. FIT and TCX files are supported. Requires the
user-authorized headers and a `multipart/form-data` body.

| Body field | Type | Max length | Notes |
|---|---|---|---|
| `file` | file | — | **Required.** Encoded file data (FIT or TCX). |
| `workout-id` | string | 50 | The partner's unique identifier for this workout. |
| `workout-title` | string | 200 | Workout title. Ignored when merging into an existing titled workout. |
| `workout-description` | string | 3000 | Workout description. Ignored when merging into an existing described workout. |
| `workout-notes` | string | 3000 | Athlete notes. Stored as "Post Workout Notes" in Final Surge. |

**Response:** HTTP `201` if the file is successfully queued for processing.

---

## 8. `POST /API/v1/LoginToken` _(Final Surge spec)_

Generates a short-lived token for auto-logging the athlete into the Final Surge web app.
Takes no parameters; requires the user-authorized headers. Redirect the athlete's browser to
`https://beta.finalsurge.com/LoginWithToken?t=<token>`. **The token expires within 10
seconds of generation.**

```json
{ "Success": true, "ErrorNumber": null, "ErrorDescription": null, "Token": "<token>" }
```

---

## Error responses

### Envelope errors

Data endpoints return a `Success: false` envelope:

```json
{
  "Success": false,
  "ErrorNumber": 401,
  "ErrorMessage": "Invalid or expired access token",
  "Workouts": null
}
```

The error-text field is `ErrorMessage` on the workout list endpoints in observed responses,
and `ErrorDescription` in the vendor spec and on `ProfileInfo` / `LoginToken`. Read whichever
is present. Sample: [examples/error-401.json](./examples/error-401.json).

### Token-endpoint errors

`/oauth/token` returns HTTP 200 with a populated `error` field on failure:

```json
{ "access_token": null, "error": "invalid_grant" }
```

### Status codes

| Status | Meaning |
|---|---|
| `200` | Request reached the API. **Still check the body** for `error` / `Success: false`. |
| `201` | File accepted for processing (`/API/v1/uploads`). |
| `401` | Invalid or expired access token — re-authorize. |
| `404` | Not found. Observed for `/API/v1/Workouts` on some accounts. |
| `429` | Rate limited. |
| `5xx` | Server error. |
