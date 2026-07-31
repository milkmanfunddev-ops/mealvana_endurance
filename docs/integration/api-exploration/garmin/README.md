# Garmin — Connect Developer Program API Reference

A developer reference for the **Garmin Connect Developer Program (GCDP)** APIs: what they expose,
how data is delivered, every endpoint, every field, and worked examples. This is a vendor-API
reference — it describes Garmin's platform, not any particular application built on top of it.

Provenance is marked inline throughout:
- _(Garmin spec)_ — taken from Garmin's official PDF specifications.
- _(confirmed in sample payloads)_ — verified against captured webhook payloads (see [`examples/`](examples/)).

## The API family

The GCDP is made up of five APIs _(Garmin spec — Start Guide §2.1)_. Two directions of data flow:

| API | Direction | Purpose |
|---|---|---|
| **Activity API** | Garmin → partner | Completed, device-recorded fitness activities (runs, rides, swims, multisport) with summaries, per-second samples, laps, and raw files. |
| **Health API** | Garmin → partner | All-day wellness: dailies, epochs, sleep, body composition, stress/Body Battery, user metrics (VO2max/fitness age), pulse ox, respiration, HRV, health snapshot, blood pressure, skin temperature. |
| **Women's Health API** | Garmin → partner | Menstrual Cycle Tracking (MCT) schedule data and pregnancy snapshot. |
| **Training API v2** | partner → Garmin | Push workouts and workout schedules into a user's Garmin Connect account (CRUD). |
| **Courses API** | partner → Garmin | Push navigable courses (geo-points + course points) into a user's Garmin Connect account (CRUD). |

## Delivery model

Access to GCDP APIs is **server-to-server only**; access from end-user devices is not permitted, and
ad-hoc polling for data is not allowed _(Garmin spec — Health API §4, Start Guide §2.1)_. The
inbound (Garmin → partner) APIs are **webhook-based**. Each data type is configured, in the
[Endpoint Configuration tool](https://apis.garmin.com/tools/endpoints), to deliver via one of two
modes _(Garmin spec)_:

| Mode | What Garmin sends | Partner action |
|---|---|---|
| **Push** | An HTTPS `POST` whose JSON body **contains the summary data directly**. | Respond `200` within 30 s; process asynchronously. |
| **Ping** | An HTTPS `POST` containing a **pointer** (`callbackURL`) per user/data type — no data. | Respond `200` within 30 s, then `GET` the `callbackURL` to pull the data. |

Push and ping return the **same data model**; the choice is purely integration preference _(Garmin
spec — Activity API §5)_. Both share the same retry logic, the same "failed notification"
definition (endpoint unreachable, non-`200` response, or connection error), and an **On Hold**
setting that queues notifications for up to seven days during planned maintenance _(Garmin spec)_.

**Response contract:** the ping/push service has a 30-second timeout. The partner must return HTTP
`200` **before** performing any callback work; holding the connection open while fetching callback
data is the most common cause of integration instability _(Garmin spec — Activity API §4.1)_.
Notifications are guaranteed available for **7 days** after receipt (Activity Files: **24 hours**)
_(Garmin spec — Start Guide §2.1)_.

## Base URLs

| Purpose | Base URL |
|---|---|
| OAuth2 authorization | `https://connect.garmin.com/oauth2Confirm` _(Garmin spec — OAuth2 PKCE)_ |
| OAuth2 token / refresh | `https://diauth.garmin.com/di-oauth2-service/oauth/token` _(Garmin spec)_ |
| Health / Activity / Women's REST (+ backfill, user endpoints) | `https://apis.garmin.com/wellness-api/rest` _(Garmin spec)_ |
| Training API — workouts | `https://apis.garmin.com/workoutportal/workout/v2` (create), `https://apis.garmin.com/training-api/workout/v2` (get/update/delete) _(Garmin spec)_ |
| Training API — schedules | `https://apis.garmin.com/training-api/schedule` _(Garmin spec)_ |
| Courses API | `https://apis.garmin.com/training-api/courses/v1/course` _(Garmin spec)_ |
| Config / web tools | `https://apis.garmin.com/tools/endpoints`, `https://apis.garmin.com/tools/login` _(Garmin spec)_ |

## Data available at a glance

| API | Data types (envelope key) |
|---|---|
| **Activity** | Activity summaries (`activities`), activity details with samples + laps (`activityDetails`), manually-updated activities (`manuallyUpdatedActivities`), activity files FIT/TCX/GPX (`activityFiles`), Move IQ auto-detected events (`moveIQActivities`) |
| **Health** | Dailies (`dailies`), epochs (`epochs`), sleeps (`sleeps`), body composition (`bodyComps`), stress details (`stressDetails`), user metrics (`userMetrics`), pulse ox (`pulseox`), respiration (`allDayRespiration`), health snapshot (`healthSnapshot`), HRV (`hrv`), blood pressure (`bloodPressures`), skin temperature (`skinTemp`) |
| **Women's Health** | Menstrual Cycle Tracking + pregnancy snapshot (`mct`) |
| **Training** | Workouts, workout schedules |
| **Courses** | Courses (route geo-points + course points) |
| **User / lifecycle** | Deregistrations (`deregistrations`), user-permission changes (`userPermissionsChange`), user ID, user permissions |

## Key concepts

- **User Access Token (UAT / access token).** OAuth2 bearer token identifying the consenting user.
  See [`authentication.md`](authentication.md).
- **User ID.** A stable per-user identifier that persists across re-registration and across a
  partner's multiple programs. Push/ping notifications carry it so partners can match data to a
  user _(Garmin spec — OAuth2 PKCE, "User ID")_. `GET /wellness-api/rest/user/id`.
- **Timestamps.** All timestamps are **UTC Unix epoch seconds**. Records may also carry a
  `startTimeOffsetInSeconds` — the difference between UTC and the time shown on the user's device.
  This is **not** a standard timezone offset; users may set device time to anything within 24 h of
  UTC. Once-per-day summaries also carry a `calendarDate` (`yyyy-mm-dd`) needing no timezone math
  _(Garmin spec — Health API §6.2)_. See [`field-reference.md`](field-reference.md).
- **Updated records.** A later summary with the same start time + type and equal-or-greater
  duration **replaces** the earlier one; the latest always takes precedence _(Garmin spec — Health
  API §6.1)_.
- **Backfill.** Request historic data (data recorded before registration or purged by retention).
  Returns `202` immediately; the data is later delivered through the normal push/ping path. Max
  window per request: **90 days** (Health/Women's) or **30 days** (Activity). See
  [`endpoints.md`](endpoints.md#backfill).
- **Deregistration & permission changes.** When a user disconnects or toggles data-sharing
  permissions, Garmin sends a `deregistrations` or `userPermissionsChange` notification. See
  [`authentication.md`](authentication.md#lifecycle-notifications).

## Rate limits _(Garmin spec)_

| API | Evaluation key | Production key |
|---|---|---|
| Health / Activity / Women's backfill | 100 days of data / minute | 10,000 days of data / minute per key |
| Training API | 100 calls/partner/min; 200 calls/user/day | 3,000 calls/partner/min; 1,000 calls/user/day |
| Courses API | 100 calls/partner/min; 200 calls/user/day | 6,000 calls/partner/min; 6,000 calls/user/day |

Per-user backfill is limited to 1 month of requests since first connection. Exceeding a Training/
Courses limit returns HTTP `429`. Duplicate backfill requests return HTTP `409`.

## Document set

| Doc | Contents |
|---|---|
| [`authentication.md`](authentication.md) | OAuth2 + PKCE flow, scopes/permissions, token lifecycle & refresh, user ID, deregistration, permission-change notifications, webhook validation. |
| [`endpoints.md`](endpoints.md) | Every endpoint across all five APIs: method, path, params, request/response examples. |
| [`activity-data.md`](activity-data.md) | Activity API data model — summaries, activity details (samples, laps), manually-updated, files, Move IQ; units + full JSON. |
| [`health-data.md`](health-data.md) | Health API data model — all 12 wellness types with field tables, units, and JSON. |
| [`training-courses-womens.md`](training-courses-womens.md) | Training API v2 (workouts + schedules), Courses API, Women's Health API (MCT). |
| [`field-reference.md`](field-reference.md) | One exhaustive lookup table of every field across all APIs: name, API, type, units, example, notes. |
| [`examples/`](examples/) | Raw sample JSON payloads for push, ping, health, deregistration, and spec-derived training/courses/women's bodies. |

## Source files

**Vendor specifications** (`docs/integration/`):
- `Activity_API-1.2.3.pdf` — Activity API
- `Health_API_1.2.2.pdf` — Health API
- `Training_API_V2_1/Training_API_V2.pdf` (+ `Appendix A and B.xlsx` for exercise names) — Training API v2
- `Courses API_2/Courses_API.pdf` — Courses API
- `Women's_API_1.0.4.pdf` — Women's Health API
- `OAuth2PKCE_1.pdf` — OAuth2 + PKCE flow
- `Garmin Developer Program_Start_Guide_1.1_0.pdf` — program overview, ping/push, lifecycle

**Reference code** (real payload shapes and field values verified here):
- `supabase/functions/_shared/garmin/types.ts`, `mappers.ts`, `auth.ts`, `activity_completion.ts` (+ `.test.ts`)
- `supabase/functions/garmin-push/index.ts`, `garmin-ping/index.ts`, `garmin-backfill/index.ts`, `garmin-deregistration/index.ts`
