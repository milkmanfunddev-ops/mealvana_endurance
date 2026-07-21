# VDOT O2 — Workout Data

The workout object returned by the two `GET /v1/vdot-workouts/…` endpoints. It
represents a single planned or completed session, including a nested `steps[]`
tree that carries the structured prescription (intervals, repeats, and per-step
pace/HR targets).

> **Coverage note.** There are no captured vendor payloads for the workout
> endpoints. The field set and enum values below come from the client parser and
> the VDOT O2 wiki; the specific example values are illustrative and every JSON
> block is _(reconstructed from the client parser — not a captured vendor
> payload)_.

---

## Top-level workout object

| Field | Type | Units | Optional | Notes |
|---|---|---|---|---|
| `eventId` | string (UUID) | — | **required** | Stable, unique workout id — the natural key for de-duplication across chunked range requests |
| `eventName` | string \| null | — | optional, may be null or blank | Coach-assigned session name |
| `eventDate` | string, ISO-8601 **tz-naive** | local date-time | present in practice | The calendar date/time the session is scheduled — see the timezone note below |
| `eventType` | enum string | — | optional | `easyPace`, `qualitySession`, `crossTraining` |
| `status` | enum string | — | optional | `planned`, `modified`, `completed`, `skipped` |
| `plannedTime` | number | **seconds** | optional | Planned duration |
| `plannedDistance` | number | **meters** | optional | Planned distance |
| `crossTrainingType` | enum string | — | only when `eventType == "crossTraining"` | The cross-training modality |
| `crossTrainingEffort` | enum string | — | optional, cross-training only | `easy`, `moderate`, `hard` |
| `steps` | array of step objects | — | optional, may be `[]` | The structured step tree (below) |

---

## Enum values

### `eventType`

| Value | Meaning |
|---|---|
| `easyPace` | Easy run |
| `qualitySession` | Quality / interval running workout |
| `crossTraining` | Non-running session (see `crossTrainingType`) |

### `status`

| Value | Meaning |
|---|---|
| `planned` | Scheduled, not yet done |
| `modified` | Scheduled with edits applied |
| `completed` | Marked done |
| `skipped` | Skipped by the athlete |

> A `completed` workout still exposes only the **planned** fields — `plannedTime`
> and `plannedDistance` remain the plan. The API does **not** return
> completed-session actuals (real time, distance, heart rate, or pace).

### `crossTrainingType`

Observed values: `bike`, `swim`, `rowing`, `elliptical`, `stepping`, `strength`,
`yoga`, `crossFit`, `other`. Present only when `eventType == "crossTraining"`.

### `crossTrainingEffort`

`easy`, `moderate`, or `hard`. Optional; present only on cross-training sessions.

---

## `eventDate` is timezone-naive

```jsonc
"eventDate": "2026-06-01T00:00:00"    // no Z, no offset
```

`eventDate` is a **timezone-naive** local date-time — it represents the calendar
day the coach scheduled the session, not a UTC instant. VDOT O2 sometimes appends
a trailing `Z`, but the value should still be treated as **local**, not UTC:
interpreting `2026-06-01T00:00:00` as UTC would shift it to the previous day for
any athlete west of Greenwich. Strip any trailing `Z` and parse the remainder as
a local date-time.

---

## The `steps[]` tree

The `steps[]` array describes the structured workout. It has two node types, and
`repeatStep` nests recursively to represent repeat blocks (e.g. "6 × 800 m").

### `step` (leaf node)

| Field | Type | Units | Notes |
|---|---|---|---|
| `type` | `"step"` | — | Node discriminator |
| `intensity` | enum string | — | `warmup`, `cooldown`, `recovery`, `interval`, `active`, `rest` |
| `duration` | object | — | `{ type, value }` — see below |
| `duration.type` | `"time"` \| `"distance"` | — | |
| `duration.value` | number | **seconds** when `time`, **meters** when `distance` | |
| `target` | object | — | Pace / HR / stroke prescription — see below |
| `exerciseName` | string | — | Present on strength steps |
| `order` | number | — | Position within the containing array |

### `repeatStep` (branch node)

| Field | Type | Notes |
|---|---|---|
| `type` | `"repeatStep"` | Node discriminator |
| `repeatValue` | int | Number of repetitions |
| `steps` | array | Child step nodes, repeated `repeatValue` times |
| `order` | number | Position within the containing array |

### The `steps[].target` structure (pace / HR prescription)

The `target` object on a leaf `step` is VDOT O2's **pace-target structure** — it
carries the prescribed intensity for that step. For a running interval this is
where the E/M/T/I/R-style pace band lives.

```jsonc
"target": {
  "type": "speed" | "heartRate" | "swimStroke" | "exercise",
  "value":     number,   // single-point target
  "valueLow":  number,   // band lower bound
  "valueHigh": number    // band upper bound
}
```

A target is expressed either as a **single point** (`value`) or as a **band**
(`valueLow`/`valueHigh`), depending on the prescription.

| `target.type` | Meaning | Units |
|---|---|---|
| `speed` | Pace / speed target | **Uncertain — not verified.** VDOT O2 uses SI elsewhere in the payload (`plannedDistance` in meters, `plannedTime` in seconds), so **meters/second is the likely convention**, but there is no captured payload to confirm it. Do not build on this without verifying against a live response. |
| `heartRate` | Heart-rate target | beats per minute (bpm) |
| `swimStroke` | Swim-stroke target | Encoding not documented / unverified |
| `exercise` | Strength-exercise target | Encoding not documented / unverified |

See [`examples/training-paces-step-targets.json`](examples/training-paces-step-targets.json)
for one example of every `target` shape.

> The wiki does not otherwise expose the athlete's VDOT score, a standalone
> training-pace table, or race equivalencies through any endpoint. The per-step
> `target` inside a workout is the only pace-prescription data the API surfaces.

---

## Full payload examples

### A. Planned easy run — [`examples/workout-planned.json`](examples/workout-planned.json)

_(reconstructed from the client parser — not a captured vendor payload)_

```json
{
  "eventId": "78edbf80-30ef-40ba-ac93-d8661ebb2b49",
  "eventName": "Easy Run",
  "eventDate": "2026-06-01T00:00:00",
  "eventType": "easyPace",
  "status": "planned",
  "plannedTime": 4620,
  "plannedDistance": 15449,
  "steps": []
}
```

### B. Completed quality session — [`examples/workout-completed.json`](examples/workout-completed.json)

_(reconstructed from the client parser — not a captured vendor payload)_ A
structured session with a nested repeat block and per-step targets. Note that
`status: "completed"` still exposes only the planned fields.

```json
{
  "eventId": "c1f4a2b9-77de-4c31-9b60-2ea5f3c88101",
  "eventName": "Quality Session",
  "eventDate": "2026-06-03T00:00:00",
  "eventType": "qualitySession",
  "status": "completed",
  "plannedTime": 3600,
  "plannedDistance": 12000,
  "steps": [
    { "type": "step", "intensity": "warmup", "duration": { "type": "time", "value": 900 }, "order": 1 },
    {
      "type": "repeatStep",
      "repeatValue": 6,
      "order": 2,
      "steps": [
        { "type": "step", "intensity": "interval", "duration": { "type": "distance", "value": 800 },
          "target": { "type": "speed", "valueLow": 4.55, "valueHigh": 4.79 }, "order": 1 },
        { "type": "step", "intensity": "recovery", "duration": { "type": "time", "value": 120 }, "order": 2 }
      ]
    },
    { "type": "step", "intensity": "cooldown", "duration": { "type": "time", "value": 600 }, "order": 3 }
  ]
}
```

### C. Cross-training bike — [`examples/workout-crosstraining.json`](examples/workout-crosstraining.json)

_(reconstructed from the client parser — not a captured vendor payload)_ A
cross-training session with a null `eventName`.

```json
{
  "eventId": "9b2c7de1-4a55-4f80-b0d3-6c1e9a2f7742",
  "eventName": null,
  "eventDate": "2026-06-04T00:00:00",
  "eventType": "crossTraining",
  "status": "planned",
  "crossTrainingType": "bike",
  "crossTrainingEffort": "moderate",
  "plannedTime": 3600,
  "steps": []
}
```

When `plannedDistance` is absent (as here), no distance is prescribed for the
session.

### D. Skipped session — [`examples/workout-skipped-filtered.json`](examples/workout-skipped-filtered.json)

Shows a `status: "skipped"` workout and a `crossTrainingType: "strength"`
session, illustrating status and cross-training-type variance in the payload.
