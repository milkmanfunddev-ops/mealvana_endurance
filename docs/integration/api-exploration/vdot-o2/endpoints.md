# VDOT O2 — Endpoints

Six endpoints: two OAuth, two workout reads, two GPS uploads.

| # | Method | Path | Scope | Maturity |
|---|---|---|---|---|
| 1 | `GET` | `{authBase}/oauth/authorize` | — | Live |
| 2 | `POST` | `{authBase}/oauth/token` | — | Live (both grants) |
| 3 | `GET` | `{apiBase}/v1/vdot-workouts/{eventId}` | `read:workouts` | Defined but untested |
| 4 | `GET` | `{apiBase}/v1/vdot-workouts/{fromDate}/{toDate}` | `read:workouts` | Live |
| 5 | `POST` | `{apiBase}/v1/vdot-workouts/upload-gps` | `write:upload-gps` | Defined but untested |
| 6 | `POST` | `{apiBase}/v1/vdot-workouts/upload-gps/{eventId}` | `write:upload-gps` | Defined but untested |

Bases:

- `authBase` = `https://app.vdoto2.com` (always — the sandbox host does not resolve)
- `apiBase` = `https://api.vdoto2.com` (prod) or `https://api.sandbox.vdoto2.com` (sandbox)

All API calls send `Authorization: Bearer <ACCESS_TOKEN>` and
`Accept: application/json`.

---

## 1. `GET {authBase}/oauth/authorize`

Browser-facing authorization request. Full details in
[`authentication.md`](authentication.md).

| Param | Required | Value |
|---|---|---|
| `client_id` | ✅ | `<VDOT_CLIENT_ID>` |
| `redirect_uri` | ✅ | A pre-registered URI, e.g. `com.milkman.mealvanaendurance://callback` |
| `response_type` | ✅ | `code` |
| `scope` | ✅ | e.g. `read:workouts` |
| `state` | recommended | Opaque CSRF token; may not be echoed back |

**Request**

```
https://app.vdoto2.com/oauth/authorize?client_id=<VDOT_CLIENT_ID>&redirect_uri=com.milkman.mealvanaendurance%3A%2F%2Fcallback&response_type=code&scope=read%3Aworkouts&state=9f2c1a4b7e0d5638a1c2f9047b6e8d3350fa2c19be74d068a35f1c9e2b04d7a6
```

**Response** — a redirect to the registered URI carrying the code:

```
com.milkman.mealvanaendurance://callback?code=aB3%2BxY9%2FzQ%3D%3D
```

The code may contain a literal `+` (percent-encoded here as `%2B`) and must be
parsed without the form-urlencoded `+`→space rule — see
[`authentication.md`](authentication.md#the--in-authorization-code-requirement).

---

## 2. `POST {authBase}/oauth/token`

Serves both the authorization-code exchange and the refresh grant. Fully
documented in [`authentication.md`](authentication.md); summarized here.

### 2a. Authorization-code exchange

```http
POST https://app.vdoto2.com/oauth/token
Authorization: Basic <base64(client_id:client_secret)>
Content-Type: application/x-www-form-urlencoded
Accept: application/json

grant_type=authorization_code&code=<AUTH_CODE>&redirect_uri=com.milkman.mealvanaendurance%3A%2F%2Fcallback&client_id=<VDOT_CLIENT_ID>&client_secret=<VDOT_CLIENT_SECRET>
```

**200** → [`examples/token-response.json`](examples/token-response.json)

```json
{
  "accessToken": "<ACCESS_TOKEN>",
  "refreshToken": "<REFRESH_TOKEN>",
  "expiresIn": 7776000,
  "tokenType": "Bearer"
}
```

**400** → [`examples/error-invalid-payload.json`](examples/error-invalid-payload.json)
(observed):

```json
{ "status": "NOK", "error": "invalid_payload" }
```

### 2b. Refresh

```http
POST https://app.vdoto2.com/oauth/token
Authorization: Basic <base64(client_id:client_secret)>
Content-Type: application/x-www-form-urlencoded
Accept: application/json

grant_type=refresh_token&refresh_token=<REFRESH_TOKEN>&client_id=<VDOT_CLIENT_ID>&client_secret=<VDOT_CLIENT_SECRET>&token=<EXPIRED_ACCESS_TOKEN>
```

`client_id` / `client_secret` must appear in the **body**; a Basic header alone
returns `invalid_payload`.

---

## 3. `GET {apiBase}/v1/vdot-workouts/{eventId}`

Fetch a single workout by its stable event id. **Defined but untested** — no
captured response is available; the shape below is reconstructed.

| Element | Value |
|---|---|
| Path param `eventId` | UUID string — VDOT O2's stable workout id |
| Headers | `Authorization: Bearer <ACCESS_TOKEN>`, `Accept: application/json` |
| Scope | `read:workouts` |
| Success shape | a **single JSON object** (not an array) |

**Request**

```http
GET https://api.vdoto2.com/v1/vdot-workouts/78edbf80-30ef-40ba-ac93-d8661ebb2b49
Authorization: Bearer <ACCESS_TOKEN>
Accept: application/json
```

**Response 200** _(reconstructed from the client parser — not a captured vendor payload)_:

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

Full field semantics in [`workout-data.md`](workout-data.md).

---

## 4. `GET {apiBase}/v1/vdot-workouts/{fromDate}/{toDate}`

Fetch all of an athlete's workouts within a date range. This is the primary read
endpoint.

| Element | Value |
|---|---|
| Path params | `fromDate`, `toDate` — `YYYY-MM-DD`, zero-padded |
| Headers | `Authorization: Bearer <ACCESS_TOKEN>`, `Accept: application/json` |
| Scope | `read:workouts` |
| **Max range** | **60 days** per request (VDOT O2's documented limit) |
| Success shape | a **JSON array** of workout objects |

For a window longer than 60 days, a client must **chunk** the request into
≤60-day segments and concatenate the results, de-duplicating by `eventId` across
chunk boundaries.

**Request**

```http
GET https://api.vdoto2.com/v1/vdot-workouts/2026-05-20/2026-07-04
Authorization: Bearer <ACCESS_TOKEN>
Accept: application/json
```

**Response 200** — an array (abridged; full version in
[`examples/workouts-date-range.json`](examples/workouts-date-range.json)).
_(reconstructed from the client parser — not a captured vendor payload.)_

```json
[
  {
    "eventId": "78edbf80-30ef-40ba-ac93-d8661ebb2b49",
    "eventName": "Easy Run",
    "eventDate": "2026-06-01T00:00:00",
    "eventType": "easyPace",
    "status": "planned",
    "plannedTime": 4620,
    "plannedDistance": 15449,
    "steps": []
  },
  {
    "eventId": "c1f4a2b9-77de-4c31-9b60-2ea5f3c88101",
    "eventName": "Quality Session",
    "eventDate": "2026-06-03T00:00:00",
    "eventType": "qualitySession",
    "status": "planned",
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
  },
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
]
```

The response is a bare array; a non-array body is unexpected. `eventDate` values
are timezone-naive — see [`workout-data.md`](workout-data.md#eventdate-is-timezone-naive).

---

## 5 & 6. `POST {apiBase}/v1/vdot-workouts/upload-gps[/{eventId}]`

Upload a GPS file (FIT / TCX / GPX). **Defined but untested.** Requires the
`write:upload-gps` scope.

- `POST /v1/vdot-workouts/upload-gps` — VDOT O2 matches the file to an event itself.
- `POST /v1/vdot-workouts/upload-gps/{eventId}` — attach the file to a specific event.

The request is `multipart/form-data`:

| Part / field | Type | Required | Notes |
|---|---|---|---|
| `file` | file (FIT / TCX / GPX) | ✅ | Multipart field name is literally `file` |
| `uploadId` | string | ✅ | Caller-supplied idempotency key |
| `sourceId` | string | optional | |
| `sourceName` | string | optional | |

Headers: `Authorization: Bearer <ACCESS_TOKEN>`, `Accept: application/json`.

**Request**

```http
POST https://api.vdoto2.com/v1/vdot-workouts/upload-gps/78edbf80-30ef-40ba-ac93-d8661ebb2b49
Authorization: Bearer <ACCESS_TOKEN>
Accept: application/json
Content-Type: multipart/form-data; boundary=----boundary

------boundary
Content-Disposition: form-data; name="uploadId"

3f9a1c22-88b1-4e0e-9c3a-b0d7f5e21a44
------boundary
Content-Disposition: form-data; name="sourceName"

ExampleSource
------boundary
Content-Disposition: form-data; name="file"; filename="run-2026-06-01.fit"
Content-Type: application/octet-stream

<binary FIT bytes>
------boundary--
```

**Response 200** — [`examples/gps-upload-response.json`](examples/gps-upload-response.json)
_(reconstructed from the client parser — not a captured vendor payload)_:

```json
{ "Success": true, "Message": "Workout uploaded." }
```

> **PascalCase.** This response uses `Success` / `Message`, unlike every other
> VDOT O2 payload, which is camelCase. A robust client should accept either
> casing.

The GPS upload is VDOT O2's only write surface — the API accepts no workout
descriptions, notes, or other structured data. There is no webhook or push
mechanism; reads are pull-only.
