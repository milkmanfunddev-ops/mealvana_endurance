# VDOT O2 — API Overview

**VDOT O2 (V.O2, `vdoto2.com`)** is a running-training platform built around
Jack Daniels' **VDOT** metric — the running-performance index from *Daniels'
Running Formula* that maps a runner's fitness to training paces (Easy, Marathon,
Threshold, Interval, Repetition) and race-time equivalencies. Coaches and
athletes plan structured workouts on the platform; the API exposes those planned
and completed workouts to third-party applications.

VDOT O2 offers an **OAuth 2.0 REST API** (currently labelled **BETA**). A client
authenticates a VDOT O2 athlete via the authorization-code flow, then reads that
athlete's workouts by event id or over a date range, and can upload GPS files
(FIT/TCX/GPX) back to the platform for it to match against planned events.

- Wiki: https://github.com/VDOT-O2/V.O2-API/wiki
- Partner contact: `info@vdoto2.com`

> **Documentation coverage caveat.** VDOT O2 has the **thinnest documentation of
> the four integration APIs described in this project**. The API is BETA, the
> public wiki is sparse and in places contradicts the live service (see below),
> and there are **no captured vendor payloads** available here — every example
> JSON in these docs is _(reconstructed from the client parser — not a captured
> vendor payload)_, and is labelled as such. The exceptions are two token-error
> bodies that were observed against the live token endpoint. Where a field's
> units or semantics are unverified, that is stated explicitly rather than
> guessed.

---

## How the API works

1. **Authorize** — send the athlete to `GET {authBase}/oauth/authorize` with your
   `client_id`, a registered `redirect_uri`, `response_type=code`, and the scopes
   you need. The athlete logs into VDOT O2 and approves; VDOT O2 redirects back to
   the `redirect_uri` with a `?code=…`.
2. **Exchange** — `POST {authBase}/oauth/token` with `grant_type=authorization_code`
   to trade the code for an access token + refresh token.
3. **Read** — call the workout endpoints on the API host with
   `Authorization: Bearer <access_token>`.
4. **Refresh** — when the access token expires, `POST {authBase}/oauth/token`
   with `grant_type=refresh_token`.
5. **Upload** *(optional)* — `POST` a GPS file to the upload endpoints (requires
   the `write:upload-gps` scope).

VDOT O2's token endpoint is a **custom .NET service**, not a stock OAuth server,
and it diverges from RFC 6749 in ways a client must handle explicitly — its error
shapes, credentials-in-body requirement, and `+`-in-code behavior. See
[`authentication.md`](authentication.md).

### Hosts

| Purpose | Production | Sandbox |
|---|---|---|
| OAuth (`authBase`) — `authorize` + `token` | `https://app.vdoto2.com` | *(none — see note)* |
| REST API (`apiBase`) — workouts + upload | `https://api.vdoto2.com` | `https://api.sandbox.vdoto2.com` |

> The wiki documents `https://app.sandbox.vdoto2.com` as a sandbox OAuth host,
> but **that hostname does not resolve** — only `app.vdoto2.com` exists. OAuth
> always runs against production; only the **API** host has a working sandbox.

### Scopes

| Scope | Grants |
|---|---|
| `read:workouts` | Read the workout endpoints (`GET /v1/vdot-workouts/…`) |
| `write:upload-gps` | Upload GPS files (`POST /v1/vdot-workouts/upload-gps[/{eventId}]`) |

---

## Data available

| Category | Where | Notes |
|---|---|---|
| **OAuth tokens** | `POST /oauth/token` | `accessToken`, `refreshToken`, `expiresIn`, `tokenType`. Live API returns **camelCase**; the wiki documents snake_case. `expiresIn` has been observed at 7 776 000 s (~90 days). |
| **Planned workouts** | `GET /v1/vdot-workouts/{eventId}` and `/{from}/{to}` | `eventId`, `eventName`, `eventDate`, `eventType`, `status`, `plannedTime`, `plannedDistance`, and the `steps[]` tree. |
| **Completed workouts** | same endpoints, `status: "completed"` | The object carries the **plan**, not actuals — no recorded time, distance, HR, or pace is exposed for a completed session. |
| **Cross-training** | same endpoints, `eventType: "crossTraining"` | Adds `crossTrainingType` (bike, swim, strength, …) and `crossTrainingEffort` (easy/moderate/hard). |
| **Structured step tree** | `steps[]` on a workout | Nested `step` / `repeatStep` nodes with `intensity`, `duration {type,value}`, and a **pace `target {type,value,valueLow,valueHigh}`** — this is where per-step pace/HR prescriptions (the E/M/T/I/R paces) live. See [`workout-data.md`](workout-data.md). |
| **GPS upload result** | `POST /v1/vdot-workouts/upload-gps[/{eventId}]` | `{ "Success": bool, "Message": string }` (**PascalCase** — unique to this endpoint). |

**Not exposed by any known endpoint:** the athlete's numeric VDOT score,
standalone training-pace zones as a table, race-equivalency tables, and any human
athlete profile or name. The access token is a JWT carrying only a numeric VDOT
user id; there is no profile endpoint.

### Endpoint maturity

Because there are no captured vendor payloads, endpoints differ in how well their
responses are known:

| Endpoint | Status |
|---|---|
| `POST /oauth/token` (both grants) | Exercised against the live token endpoint |
| `GET /v1/vdot-workouts/{from}/{to}` | Exercised against the live API |
| `GET /v1/vdot-workouts/{eventId}` | **Defined but untested** — response shape reconstructed only |
| `POST /v1/vdot-workouts/upload-gps` | **Defined but untested** |
| `POST /v1/vdot-workouts/upload-gps/{eventId}` | **Defined but untested** |

---

## Documents in this reference

- [`authentication.md`](authentication.md) — OAuth 2.0 flow, the custom-scheme
  redirect, the credentials-in-body requirement, and the `+`-in-code handling.
- [`endpoints.md`](endpoints.md) — every endpoint: method, path, params, headers,
  request + response examples.
- [`workout-data.md`](workout-data.md) — the workout object and the nested
  `steps[]` structured tree, including the pace `target` structure.
- [`field-reference.md`](field-reference.md) — one exhaustive table of every field.
- [`examples/`](examples/) — reconstructed JSON payloads for each shape.

## Source files

The client code and project notes these docs are derived from:

- `lib/features/integrations/data/vdot_api_client.dart` — every endpoint, base
  URLs, the token model, and error handling.
- `lib/features/integrations/application/vdot_transformer.dart` — the workout
  object fields and the `steps[]` tree, including the `target` structure.
- `lib/features/integrations/application/vdot_oauth_service.dart` — the OAuth
  flow, custom-scheme redirect, and `+`-in-code raw parsing.
- `docs/vdot/README.md`, `docs/vdot/NEXT_STEPS.md` — project notes, live-endpoint
  probe results, and a summary of the VDOT O2 wiki.
