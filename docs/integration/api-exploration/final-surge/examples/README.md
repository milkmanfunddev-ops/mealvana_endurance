# Final Surge — Example Payloads

Raw sample payloads referenced from the docs in the parent directory. Credentials are
redacted as `<FINAL_SURGE_CLIENT_ID>` / `<FINAL_SURGE_CLIENT_SECRET>`. Access tokens and
athlete GUIDs are non-sensitive placeholder values.

| File | What it is | Source |
|---|---|---|
| `auth-token-request.txt` | `POST /oauth/token` — code and refresh variants | API spec |
| `auth-token-response.json` | Successful token exchange, athlete fields at root | Confirmed in sample payloads |
| `auth-token-error.json` | Failure with HTTP 200 + `error` field | Constructed shape |
| `error-401.json` | List-endpoint error envelope | Confirmed in sample payloads |
| `workouts-list-response.json` | Full `UpcomingWorkouts` response, mixed workouts | Confirmed in sample payloads |
| `workout-planned-run.json` | Run with a single target pace in the description | Confirmed in sample payloads |
| `workout-planned-run-pace-range.json` | Run with a pace **range** `@ 9:12 - 10:01` | Confirmed in sample payloads |
| `workout-planned-bike-km.json` | Ride in kilometres | Confirmed in sample payloads |
| `workout-planned-swim-yards.json` | Swim in yards | Confirmed in sample payloads |
| `workout-planned-missing-data.json` | Everything null — nullable-field example | Confirmed in sample payloads |
| `workout-rest-day.json` | A Rest Day workout object | Confirmed in sample payloads |
| `workout-completed-bike.json` | Completed ride with `Actual*` fields | Constructed — no completed payload captured |
| `workout-structured-parent.json` | Workout carrying `StructuredWorkoutURLs` | Confirmed in sample payloads |
| `structured-workout-json-fs-v1.json` | Simplified interval sample (steps + repeat block) | Illustrative sample |
| `structured-workout-with-ramp.json` | Simplified ramp sample | Illustrative sample |
| `workout-single-response.json` | `GET /API/v1/Workout/{key}` — unwrapped object | Shape from client behavior |
| `profile-info-response.json` | `GET /API/v1/ProfileInfo` — partner-scoped storage | API spec |

Files marked *Constructed* or *Illustrative* carry an inline `_comment` describing what they
represent. The authoritative field-level `json_fs_v1` structured-workout schema is in
[../workout-data.md § Structured workouts](../workout-data.md#structured-workouts).
