# Final Surge — Partner API Reference

[Final Surge](https://www.finalsurge.com) is a training-log and coaching platform. Athletes
and their coaches build a training calendar there — runs, rides, swims, strength days, rest
days — and can attach structured interval workouts to any session.

The **Final Surge Partner API** is an OAuth 2.0 REST API that lets an authorized partner
application read that calendar on an athlete's behalf, download structured-workout files,
store a small amount of partner-scoped profile data, and upload completed-activity files.

- **Base URL:** `https://log.finalsurge.com`
- **Style:** REST over HTTPS, JSON responses
- **Auth:** OAuth 2.0-style authorization-code flow (no scopes, no PKCE)
- **Data direction:** primarily read (pull). One write path exists for FIT/TCX uploads.

---

## How the API works

Three mechanics are unusual enough to state up front — they trip up most first
integrations:

1. **Credentials go in the request body, with hyphenated keys.** The token endpoint reads
   `client-id` / `client-secret` as `application/x-www-form-urlencoded` **body** fields —
   not as an `Authorization: Basic` header, and not with the OAuth-standard underscored
   names (`client_id`). See [authentication.md](./authentication.md).

2. **Data calls require a `client-id` HTTP header** *in addition to* the bearer token.
   Every `/API/v1/*` request must send both `client-id: <id>` and
   `Authorization: Bearer <token>`. The bearer token alone is not enough.

3. **HTTP 200 can still be an error.** Both `/oauth/token` and the workout endpoints return
   status 200 on failure and signal the error inside the JSON body — via an `error` field
   (token endpoint) or a `Success: false` / `ErrorNumber` / error-text envelope (data
   endpoints). Always inspect the body, not just the status code.

---

## Data available

| Category | Endpoint(s) | Provenance |
|---|---|---|
| **Athlete identity** — id, first/last name | `POST /oauth/token` response | _(confirmed in sample payloads)_ |
| **Scheduled (planned) workouts** — date, time, sport, title, description, planned time / distance / pace | `GET /API/v1/UpcomingWorkouts`, `GET /API/v1/Workouts`, `GET /API/v1/Workout/{key}` | _(confirmed in sample payloads)_ |
| **Completed (actual) results** — `ActualTime`, `ActualDistanceMeters`, `ActualPace` | Same workout objects | Fields defined; not observed populated in samples |
| **Workout classification** — type, subtype, icon, race flag, completed flag | Workout object | _(confirmed in sample payloads)_ |
| **Structured workouts** — steps, ramps, repeats with power / HR / pace targets | `StructuredWorkoutURLs.json_fs_v1` (+ `fit`, `json_garmin_v1`, `mrc`, `zwo`) | _(Final Surge spec)_ |
| **App-scoped profile storage** — a partner-owned `uniqueid` + `profile` key/value pair | `GET` / `POST /API/v1/ProfileInfo` | _(Final Surge spec)_ |
| **Activity file upload** — FIT / TCX | `POST /API/v1/uploads` | _(Final Surge spec)_ |
| **Auto-login token** — a 10-second token to deep-link into the Final Surge web app | `POST /API/v1/LoginToken` | _(Final Surge spec)_ |

The Partner API does **not** expose per-second sensor streams (heart-rate, power, GPS
tracks), athlete threshold/zone settings (FTP, LTHR, max HR), body-composition data, or any
webhook / push mechanism. It is a pull-based calendar and file API.

---

## Endpoints at a glance

| Method | Path | Purpose |
|---|---|---|
| `GET` | `/oauth/authorize` | Begin the authorization-code flow (browser redirect) |
| `POST` | `/oauth/token` | Exchange an authorization code (or refresh token) for an access token |
| `GET` | `/API/v1/UpcomingWorkouts` | The next N days / N workouts from today |
| `GET` | `/API/v1/Workouts` | Workouts in an explicit `StartDate`–`EndDate` range |
| `GET` | `/API/v1/Workout/{WorkoutKey}` | A single workout by key |
| `GET` | `<StructuredWorkoutURLs.json_fs_v1>` | The structured interval breakdown for a workout |
| `GET` / `POST` | `/API/v1/ProfileInfo` | Read / write partner-scoped profile storage |
| `POST` | `/API/v1/uploads` | Upload a completed FIT / TCX activity |
| `POST` | `/API/v1/LoginToken` | Mint a short-lived web auto-login token |

Full details, parameters, and request/response examples are in
[endpoints.md](./endpoints.md).

---

## Documentation set

| Doc | Contents |
|---|---|
| [authentication.md](./authentication.md) | OAuth authorize + token exchange + refresh, the body-credential rule, token/error shapes |
| [endpoints.md](./endpoints.md) | Every endpoint: method, path, params, headers, request + response examples |
| [workout-data.md](./workout-data.md) | The workout object — planned vs completed field families, units, and the `json_fs_v1` structured shape |
| [field-reference.md](./field-reference.md) | One exhaustive table of every field: name, object, type, units, example, notes |
| [examples/](./examples/) | Raw sample `.json` payloads referenced from the docs |

---

## Source files

Read these to go deeper than this reference. Credentials are redacted throughout as
`<FINAL_SURGE_CLIENT_ID>` / `<FINAL_SURGE_CLIENT_SECRET>`.

| Source | What it documents |
|---|---|
| `docs/final_surge/Final-Surge-Partner-API-Uploads.pdf` | The authoritative Final Surge Partner API vendor document (auth, ProfileInfo, uploads, UpcomingWorkouts, LoginToken, and the structured-workout object) |
| `lib/features/integrations/data/final_surge_api_client.dart` | The live REST surface — exact URLs, headers, query params, and response shapes for the OAuth, UpcomingWorkouts, Workouts, Workout/{key}, and structured-workout calls |
| `lib/features/integrations/application/final_surge_transformer.dart` | Field-level semantics and units for the workout object (e.g. `PlannedTime` is in seconds; pace conventions) |
| `test/fixtures/final_surge_fixtures.dart` | Real captured request/response payload shapes |
| `tool/final_surge_api_test.dart` | A standalone CLI probe (`auth`, `workouts`, `workout`, `daterange`, `profile`, `compare`) that exercises each endpoint |
| `test/integration/final_surge_api_test.dart` | Live-API integration checks asserting response structure and units |
