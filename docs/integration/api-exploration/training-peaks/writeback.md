# TrainingPeaks — Write API

The Partner API accepts writes as well as reads. This document covers the two write surfaces most
relevant to updating existing training and nutrition data: updating a planned workout
(`PUT /v2/workouts/plan/{id}`) and writing nutrition entries
(`POST`/`PUT`/`DELETE /v1/athletes/{id}/nutrition`). Creating workouts, uploading files, creating
events, and creating metrics are covered in [`endpoints.md`](endpoints.md).

---

## 1. `PUT /v2/workouts/plan/{workoutId}` — full-object replace

Scope: `workouts:plan`. Updates an existing planned workout.

**The defining behavior: this is a full-object replace, not a partial patch.** Any field omitted
from the request body, or sent as `null`, is written as `null` on TrainingPeaks' side. There is no
field-level merge.

The safe update pattern is therefore **read → modify → write**:

1. `GET /v2/workouts/id/{workoutId}?includeDescription=true` to fetch the complete current object.
2. Modify only the field(s) to change (leaving every other field exactly as returned).
3. `PUT /v2/workouts/plan/{workoutId}` with the **entire** object.

### Request

```http
PUT /v2/workouts/plan/123456789 HTTP/1.1
Host: api.trainingpeaks.com
Authorization: Bearer <ACCESS_TOKEN>
User-Agent: <application-name>/<version>
Content-Type: application/json
```

Body (the full workout object, one field changed) —
[`examples/writeback-request.json`](examples/writeback-request.json):

```json
{
  "Id": 123456789,
  "AthleteId": 54321,
  "WorkoutDay": "2026-07-21T00:00:00",
  "StartTimePlanned": "2026-07-21T06:30:00",
  "WorkoutType": "Run",
  "Title": "Track Intervals",
  "Description": "4x1000m with recoveries\n\n(updated notes here)",
  "TotalTimePlanned": 0.75,
  "DistancePlanned": 8000.0,
  "TSSPlanned": 65.0,
  "IFPlanned": 0.95,
  "ElevationGainPlanned": 45.0,
  "CaloriesPlanned": 520.0,
  "Tags": ["quality", "track"],
  "StructureDisplayUnit": "kilometer",
  "Locked": false,
  "Hidden": false,
  "Structure": null
}
```

### Responses

| Code | Meaning |
|---|---|
| `200 OK` | Success; body is the updated workout object |
| `204 No Content` | Success; no body |
| `401 Unauthorized` | Access token expired — refresh and retry |
| `403 Forbidden` | Refused — commonly a **basic athlete** (cannot modify future planned workouts) |
| `404 Not Found` | Workout no longer exists on TrainingPeaks |
| `429` / `5xx` | Rate limited / server error — retry with backoff |

### Constraints (shared with `POST /v2/workouts/plan`)

- `WorkoutDay` within 7 days past … 1 year future; its time component is ignored.
- `TotalTimePlanned` ≤ 99:59:59 (decimal hours), `DistancePlanned` ≤ 99 999 999 m,
  `TSSPlanned` ≤ 9999, `IFPlanned` ≤ 5.
- A valid non-RPE `Structure` causes `TotalTimePlanned`/`TSSPlanned`/`IFPlanned` to be **recomputed
  and ignored** on input.
- Basic (non-premium) athletes cannot create or modify future planned workouts — such a `PUT`
  returns `403`.

### The `Description` field as free text

`Description` is an arbitrary text field. Because `PUT` replaces the whole object, appending to a
description means reading the existing value, concatenating, and writing the full object back — the
edit only sticks if every other field is preserved. The two worked examples below append a delimited
text block to `Description` and demonstrate the replace-and-strip cycle:

- [`examples/writeback-feedback-request.json`](examples/writeback-feedback-request.json) — appending
  a second delimited block alongside an existing one.
- [`examples/writeback-remove-request.json`](examples/writeback-remove-request.json) — removing an
  appended block while preserving the original text.

---

## 2. Nutrition writes

Nutrition entries ("nutrition cards") are one card per athlete per day. Scope `nutrition:write`.

### `POST /v1/athletes/{athleteId}/nutrition` — create

Required: `NutritionDate`. Optional: `Calories` (kcal), `Carbohydrates`, `Fat`, `Protein` (grams).
See [`examples/nutrition-entry-create.json`](examples/nutrition-entry-create.json).

```json
{
  "NutritionDate": "2026-07-21T00:00:00",
  "Calories": 2500.0,
  "Carbohydrates": 320.0,
  "Fat": 70.0,
  "Protein": 120.0
}
```

Returns `201 Created` with the created object (including a `NutritionId`):

```json
{
  "NutritionId": 111,
  "AthleteId": 123456,
  "NutritionDate": "2026-07-21T00:00:00",
  "Calories": 2500.0,
  "Carbohydrates": 320.0,
  "Fat": 70.0,
  "Protein": 120.0
}
```

### `PUT /v1/athletes/{athleteId}/nutrition/{nutritionId}` — update

Same body as `POST`. The `NutritionDate` must either match the existing entry's date or be a date
that has no other nutrition card (one card per day). Returns `200 OK` with the updated object.

### `DELETE /v1/athletes/{athleteId}/nutrition/{nutritionId}` — delete

Returns `202 Accepted`.

> Reading nutrition (`GET /v1/athletes/{id}/nutrition`, scope `nutrition:read`) is **premium
> athletes only**. The write operations above do not carry that restriction.

All macros are **grams**; `Calories` are **kcal**.

---

## 3. Other write endpoints

Documented in full in [`endpoints.md`](endpoints.md):

| Action | Endpoint | Scope |
|---|---|---|
| Create planned workout | `POST /v2/workouts/plan` | `workouts:plan` |
| Delete workout | `DELETE /v2/workouts/id/{id}` | `workouts:read` + `workouts:plan` |
| Upload workout file (async + poll) | `POST /v3/file`, `GET /v3/status/{id}` | `file:write` |
| Add workout comment | `POST /v2/workouts/{athleteId}/id/{id}/comment` | `workouts:details` |
| Create event | `POST /v2/events` | `events:write` |
| Create metric | `POST /v2/metrics` | `metrics:write` |
| Webhook subscriptions | `.../v1/webhook/subscriptions` | `webhook:write-subscriptions` |
