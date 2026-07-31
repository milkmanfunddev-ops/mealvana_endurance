# TrainingPeaks — Example Payloads

Sample request and response payloads for the TrainingPeaks Partner API, ready to paste into a test
or a REST client. Each file carries a `_comment` key describing which endpoint it belongs to; keys
prefixed with `_` are annotations, not part of the TrainingPeaks wire format.

**No real credentials or tokens appear in any file.** Placeholders are `<ACCESS_TOKEN>`,
`<REFRESH_TOKEN>`, `<TP_CLIENT_ID>`, `<TP_CLIENT_SECRET>`.

| File | Endpoint |
|---|---|
| [`token-response.json`](token-response.json) | `POST /oauth/token` |
| [`athlete-profile.json`](athlete-profile.json) | `GET /v1/athlete/profile` |
| [`athlete-zones.json`](athlete-zones.json) | `GET /v1/athlete/profile/zones` |
| [`workout-planned-run-structured.json`](workout-planned-run-structured.json) | `GET /v2/workouts/id/{id}` (planned, structured) |
| [`workout-planned-run-simple.json`](workout-planned-run-simple.json) | `GET /v2/workouts/...` (planned, no structure) |
| [`workout-completed-bike.json`](workout-completed-bike.json) | `GET /v2/workouts/...` (completed) |
| [`workout-list-response.json`](workout-list-response.json) | `GET /v2/workouts/{start}/{end}` |
| [`workout-structure-decoded.json`](workout-structure-decoded.json) | The `Structure` string, decoded |
| [`workout-basic-athlete-nulled.json`](workout-basic-athlete-nulled.json) | `GET /v2/workouts/...` as a basic athlete |
| [`event-next-triathlon.json`](event-next-triathlon.json) | `GET /v2/events/next` |
| [`nutrition-entry-create.json`](nutrition-entry-create.json) | `POST /v1/athletes/{id}/nutrition` |
| [`writeback-request.json`](writeback-request.json) | `PUT /v2/workouts/plan/{id}` |
| [`writeback-feedback-request.json`](writeback-feedback-request.json) | `PUT /v2/workouts/plan/{id}` (second text block) |
| [`writeback-remove-request.json`](writeback-remove-request.json) | `PUT /v2/workouts/plan/{id}` (text block removed) |
| [`error-400-bad-request.json`](error-400-bad-request.json) | Any endpoint — `400` |
| [`error-401-token-expired.json`](error-401-token-expired.json) | Any authenticated endpoint — `401` |
| [`error-403-premium-required.json`](error-403-premium-required.json) | `PUT /v2/workouts/plan/{id}` — `403` |
| [`error-404-not-found.json`](error-404-not-found.json) | Several — `404` |

## Reminders

- `Distance` is **metres**, `TotalTime` is **decimal hours**, `Weight` is **kilograms**.
- `Structure` is a **string containing JSON**; decoded, its top level is an **array**.
- `IntensityTarget.Value` is a **fraction** — `0.60` means 60 %.
- `PUT /v2/workouts/plan/{id}` is a **full-object replace**; omitted fields become `null`.
- `404` on the events endpoints means "none", not an error.
