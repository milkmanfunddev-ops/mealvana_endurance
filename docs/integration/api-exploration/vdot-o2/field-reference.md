# VDOT O2 — Field Reference

Every field the VDOT O2 API returns, in one place. Example values are
illustrative; there are no captured vendor payloads for the workout or upload
endpoints.

---

## Token response — `POST {authBase}/oauth/token`

The live API sends camelCase; the wiki documents snake_case. A client should
accept either.

| Field | Object | Type | Units | Example | Notes |
|---|---|---|---|---|---|
| `accessToken` / `access_token` | token | string (JWT) | — | `<ACCESS_TOKEN>` | Required. The JWT carries only a numeric VDOT user id — no name or email |
| `refreshToken` / `refresh_token` | token | string | — | `<REFRESH_TOKEN>` | Optional; may be omitted on a refresh response |
| `expiresIn` / `expires_in` | token | int | **seconds** | `7776000` | Access-token lifetime. Observed ~90 days live; wiki example shows 3600 |
| `tokenType` / `token_type` | token | string | — | `"Bearer"` | Always Bearer |

### Token error response (observed)

| Field | Object | Type | Example | Notes |
|---|---|---|---|---|
| `status` | token error | string | `"NOK"` | Non-standard — not RFC 6749 |
| `error` | token error | string | `"invalid_payload"` / `"invalid_code"` | See [`authentication.md`](authentication.md#error-responses) |

---

## Workout object — `GET {apiBase}/v1/vdot-workouts/…`

| Field | Object | Type | Units | Example | Notes |
|---|---|---|---|---|---|
| `eventId` | workout | string (UUID) | — | `"78edbf80-30ef-40ba-ac93-d8661ebb2b49"` | Required. Stable, unique workout id |
| `eventName` | workout | string \| null | — | `"Quality Session"` | May be null or blank |
| `eventDate` | workout | string, ISO-8601 **tz-naive** | local date-time | `"2026-06-01T00:00:00"` | Treat as local, not UTC, even if a trailing `Z` is present |
| `eventType` | workout | enum string | — | `"easyPace"` | `easyPace`, `qualitySession`, `crossTraining` |
| `status` | workout | enum string | — | `"planned"` | `planned`, `modified`, `completed`, `skipped` |
| `plannedTime` | workout | number | **seconds** | `4620` | Planned duration |
| `plannedDistance` | workout | number | **meters** | `15449` | Planned distance |
| `crossTrainingType` | workout | enum string | — | `"bike"` | Only when `eventType == "crossTraining"`. `bike`, `swim`, `rowing`, `elliptical`, `stepping`, `strength`, `yoga`, `crossFit`, `other` |
| `crossTrainingEffort` | workout | enum string | — | `"moderate"` | Cross-training only. `easy`, `moderate`, `hard` |
| `steps` | workout | array | — | see below | Structured step tree; may be `[]` |

---

## Step object — `steps[]` leaf (`"type": "step"`)

| Field | Object | Type | Units | Example | Notes |
|---|---|---|---|---|---|
| `type` | step | string | — | `"step"` | Node discriminator |
| `intensity` | step | enum string | — | `"interval"` | `warmup`, `cooldown`, `recovery`, `interval`, `active`, `rest` |
| `duration` | step | object | — | `{ "type": "time", "value": 900 }` | Duration prescription |
| `duration.type` | step.duration | string | — | `"time"` \| `"distance"` | |
| `duration.value` | step.duration | number | **seconds** (`time`) / **meters** (`distance`) | `900` / `800` | |
| `target` | step | object | — | `{ "type": "speed", "valueLow": 4.55, "valueHigh": 4.79 }` | Pace / HR prescription — see below |
| `target.type` | step.target | string | — | `"speed"` | `speed`, `heartRate`, `swimStroke`, `exercise` |
| `target.value` | step.target | number | depends on `type` | `4.67` | Single-point target |
| `target.valueLow` | step.target | number | depends on `type` | `4.55` | Band lower bound |
| `target.valueHigh` | step.target | number | depends on `type` | `4.79` | Band upper bound |
| `exerciseName` | step | string | — | `"Back Squat"` | Strength steps |
| `order` | step | number | — | `1` | Position within the containing array |

> **`target` units.** `heartRate` is bpm. `speed` units are **not verified** —
> likely meters/second by analogy with the SI fields elsewhere in the payload,
> but unconfirmed; `swimStroke` and `exercise` encodings are also undocumented.
> Verify against a captured payload before relying on them.

## Step object — `steps[]` branch (`"type": "repeatStep"`)

| Field | Object | Type | Example | Notes |
|---|---|---|---|---|
| `type` | repeatStep | string | `"repeatStep"` | Node discriminator |
| `repeatValue` | repeatStep | int | `6` | Number of repetitions |
| `steps` | repeatStep | array | nested steps | Child nodes; recurses |
| `order` | repeatStep | number | `2` | Position within the containing array |

---

## GPS upload response — `POST …/upload-gps[/{eventId}]`

**PascalCase** — unlike every other VDOT O2 payload. Accept either casing.

| Field | Object | Type | Example | Notes |
|---|---|---|---|---|
| `Success` / `success` | upload result | bool | `true` | Whether the upload was accepted |
| `Message` / `message` | upload result | string | `"Workout uploaded."` | Human-readable result |

---

## Not exposed by the API

The following are **not** available through any known VDOT O2 endpoint:

| Data | Notes |
|---|---|
| Athlete name / email / weight / DOB / gender | No profile endpoint; the token JWT carries only a numeric user id |
| VDOT score | No endpoint exposes it |
| Training-pace zones as a table | Per-step `target`s are the only pace data |
| Race equivalencies | No endpoint exposes them |
| Completed-session actuals (real time / distance / HR / pace) | A `completed` workout returns only the planned fields |
| Free-text workout description / coach notes | Only the structured `steps[]` tree |
| A provider-side `updatedAt` / `lastModified` timestamp | Not present on the workout object |
