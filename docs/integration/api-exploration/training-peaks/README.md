# TrainingPeaks — API Reference

A developer reference for the **TrainingPeaks Partner API**: what it exposes, how to authenticate,
every endpoint, every field, and worked examples. TrainingPeaks is a training-plan platform for
endurance athletes and coaches; the Partner API lets an approved third-party application read and
write an athlete's training and nutrition data.

- **Protocol:** HTTPS-only REST, JSON request/response bodies.
- **Auth:** OAuth 2.0, three-legged `authorization_code` flow with Bearer access tokens.
- **Required header:** every request must send a `User-Agent` identifying the calling application.
- **Access:** organizational/business use only; partners apply at
  `https://api.trainingpeaks.com/request-access` and validate in sandbox before production.

> **Marking convention.** Endpoints and fields are tagged either
> _(confirmed in sample payloads)_ — a captured or fixture payload of that exact shape exists in
> [`examples/`](examples/) — or _(TP spec)_ — documented by TrainingPeaks but not represented by a
> captured payload here. Placeholders such as `<TP_CLIENT_ID>`, `<TP_CLIENT_SECRET>`,
> `<ACCESS_TOKEN>`, `<REFRESH_TOKEN>`, and `<AUTH_CODE>` stand in for secrets — no real credentials
> appear anywhere in these docs.

---

## Hosts and environments

TrainingPeaks runs two independent environments. The **OAuth host is separate from the API host**.

| Purpose | Sandbox | Production |
|---|---|---|
| OAuth (authorize / token / deauthorize) | `oauth.sandbox.trainingpeaks.com` | `oauth.trainingpeaks.com` |
| API (all data endpoints) | `api.sandbox.trainingpeaks.com` | `api.trainingpeaks.com` |
| Web app | `app.sandbox.trainingpeaks.com` | `app.trainingpeaks.com` |
| Account signup | `home.sandbox.trainingpeaks.com` | `home.trainingpeaks.com` |

All URLs are `https://`. Requests made over plain HTTP receive `302 Object moved`.

The **sandbox database is refreshed from production every Saturday 6:00 PM MST**; anything created in
sandbox during the week is overwritten. Metrics data is not synced into sandbox.

---

## The coach / athlete model

TrainingPeaks accounts are either **athletes** or **coaches**, and access is scoped to one role per
authorization:

- An **athlete** authorization (`athlete:profile`) grants access to that single athlete's own data.
- A **coach** authorization (`coach:athletes`) grants access to the list of athletes the coach
  manages, their assistants, and each athlete's data — addressed by `{athleteId}` path segments.
- `athlete:profile` and `coach:athletes` are **mutually exclusive** in a single grant.

Most endpoints have two forms: a self form (`/v2/workouts/id/{id}`) resolved against the
authenticated athlete, and an athlete-addressed form (`/v2/workouts/{athleteId}/id/{id}`) used by
coach integrations.

**Premium vs basic athletes.** Many endpoints and fields require a premium (paid) athlete
subscription. Basic accounts receive `403 Forbidden` on premium-only endpoints, and premium-only
fields come back `null` (and are silently ignored on write). Detect premium status via the
`IsPremium` field on the athlete profile (which excludes trial subscriptions).

---

## Read + write capability

The API is bidirectional:

- **Read:** athlete profile, training zones, planned and completed workouts, detailed workout
  channel data, events/races, body metrics, and nutrition entries.
- **Write:** create/update/delete planned workouts, upload workout files, create events, create
  body metrics, and create/update/delete nutrition entries. A near-real-time **webhook**
  subscription system (early access) can push workout create/update/delete notifications.

---

## Data available — at a glance

### Read

| Data type | Endpoint | Scope | Status |
|---|---|---|---|
| API version | `GET /v1/info/version` | none | _(TP spec)_ |
| Athlete profile | `GET /v1/athlete/profile` | `athlete:profile` | _(confirmed in sample payloads)_ |
| Training zones (HR, speed, power) | `GET /v1/athlete/profile/zones` | `athlete:profile` | _(confirmed in sample payloads)_ |
| Zones by type | `GET /v1/athlete/zones/{zoneType}` | `athlete:profile` | _(TP spec)_ |
| Coach profile & athlete list | `GET /v1/coach/profile`, `GET /v1/coach/athletes` | `coach:athletes` | _(TP spec)_ |
| Workouts by date range | `GET /v2/workouts/{start}/{end}` | `workouts:read` | _(confirmed in sample payloads)_ |
| Single workout | `GET /v2/workouts/id/{id}` | `workouts:read` | _(confirmed in sample payloads)_ |
| Changed-workouts feed | `GET /v2/workouts/changed` | `workouts:read` | _(TP spec)_ |
| Detailed workout channels | `GET /v2/workouts/id/{id}/details` | `workouts:details` | _(TP spec)_ |
| Mean-max / time-in-zones | `GET /v2/workouts/id/{id}/meanmaxes`, `.../timeinzones` | `workouts:details` | _(TP spec)_ |
| Workout of the Day | `GET /v2/workouts/wod/{date}` | `workouts:wod` | _(TP spec)_ |
| Next event / events by date | `GET /v2/events/next`, `GET /v2/events/{date}` | `events:read` | _(confirmed in sample payloads)_ |
| Body metrics | `GET /v2/metrics/...` | `metrics:read` | _(TP spec)_ |
| Nutrition entries | `GET /v1/athletes/{id}/nutrition` | `nutrition:read` | _(TP spec)_ |

### Write

| Action | Endpoint | Scope | Status |
|---|---|---|---|
| Create planned workout | `POST /v2/workouts/plan` | `workouts:plan` | _(TP spec)_ |
| Update planned workout (full replace) | `PUT /v2/workouts/plan/{id}` | `workouts:plan` | _(confirmed in sample payloads)_ |
| Delete workout | `DELETE /v2/workouts/id/{id}` | `workouts:read` + `workouts:plan` | _(TP spec)_ |
| Upload workout file | `POST /v3/file` → poll `GET /v3/status/{id}` | `file:write` | _(TP spec)_ |
| Add workout comment | `POST /v2/workouts/{athleteId}/id/{id}/comment` | `workouts:details` | _(TP spec)_ |
| Create event | `POST /v2/events` | `events:write` | _(TP spec)_ |
| Create metric | `POST /v2/metrics` | `metrics:write` | _(TP spec)_ |
| Create nutrition entry | `POST /v1/athletes/{id}/nutrition` | `nutrition:write` | _(confirmed in sample payloads)_ |
| Update / delete nutrition | `PUT` / `DELETE /v1/athletes/{id}/nutrition/{id}` | `nutrition:write` | _(TP spec)_ |
| Manage webhook subscriptions | `.../v1/webhook/subscriptions` | `webhook:write-subscriptions` | _(TP spec, early access)_ |

---

## Units — read these first

TrainingPeaks uses specific, non-obvious units. They are consistent across the whole API.

| Quantity | Unit | Note |
|---|---|---|
| Distance | **metres** | `Distance`, `DistancePlanned` — always metres, never km/miles |
| Duration | **decimal hours** | `TotalTime`, `TotalTimePlanned` — `1.25` = 1 h 15 min, **not** seconds |
| Weight | **kilograms** | `Weight`, `WeightInKilograms` — always kg, regardless of `PreferredUnits` |
| Speed zones | **metres per second** | `SpeedZones` thresholds and bounds |
| Power zones | **watts** | `PowerZones` |
| Heart-rate zones | **bpm** | `HeartRateZones` |
| Structure intensity | **fraction** | `IntensityTarget.Value` `0.60` = 60 % of the target metric |
| Nutrition macros | **grams** | `Carbohydrates`, `Fat`, `Protein`; `Calories` are kcal |

Pace is **not** returned by the API; it must be derived from distance and time.

---

## Document map

| File | Contents |
|---|---|
| [`authentication.md`](authentication.md) | OAuth flow (web + mobile), the full scope list, token exchange & refresh, sandbox vs production |
| [`endpoints.md`](endpoints.md) | Every endpoint: method, path, params, scope, request + response example |
| [`workout-data.md`](workout-data.md) | The workout object; planned vs completed fields; the `Structure` interval model |
| [`athlete-data.md`](athlete-data.md) | Athlete profile, training zones, metrics, events/calendar |
| [`writeback.md`](writeback.md) | The write API: `PUT` workout-plan (full-object replace) and nutrition writes |
| [`field-reference.md`](field-reference.md) | One exhaustive table of every field: object, type, unit, example |
| [`examples/`](examples/) | Raw JSON payloads for each endpoint |

---

## Source files

This reference is grounded in the sources below; read them for deeper detail.

- **TrainingPeaks' own API guide** (transcribed from the [Partner API wiki](https://github.com/TrainingPeaks/PartnersAPI/wiki)):
  `docs/training_peaks/TRAININGPEAKS_API_COMPREHENSIVE_GUIDE.md`
- OAuth environment/credential setup notes: `docs/training_peaks/README.md`,
  `docs/training_peaks/WEB_OAUTH_SETUP.md`, `docs/training_peaks/TRAININGPEAKS_API_IMPLEMENTATION.md`
- A working API client (endpoint shapes, headers, error mapping):
  `lib/features/integrations/data/training_peaks_api_client.dart`
- Field semantics and the decoded `Structure` model:
  `lib/features/integrations/application/training_peaks_transformer.dart`
- Captured/fixture payloads: `test/fixtures/training_peaks_fixtures.dart`
- Write path (`PUT` workout-plan): `lib/features/integrations/application/tp_writeback_service.dart`,
  `lib/features/integrations/application/tp_writeback_formatter.dart`

Official links: [Partner API wiki](https://github.com/TrainingPeaks/PartnersAPI/wiki) ·
[access request](https://api.trainingpeaks.com/request-access) ·
[support portal](https://sportsbrands.atlassian.net/servicedesk/customer/portal/2).
