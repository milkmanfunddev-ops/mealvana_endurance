# VDOT O2 — Example Payloads

Example JSON for each VDOT O2 API shape.

> **These examples are reconstructed from the client parser — they are not
> captured vendor payloads.** No recorded VDOT O2 workout or upload responses are
> available here, so the workout, token-success, and upload examples show the
> structure the parser expects with illustrative values. The two token-**error**
> bodies were observed against the live token endpoint and are marked as such.

Fields prefixed with `_` (e.g. `_comment`) are documentation annotations, **not
part of the VDOT O2 API**. Credentials are redacted as `<ACCESS_TOKEN>`,
`<REFRESH_TOKEN>`, `<VDOT_CLIENT_ID>`, `<VDOT_CLIENT_SECRET>`, `<AUTH_CODE>`;
UUIDs are fabricated.

| File | Source | Contents |
|---|---|---|
| `token-response.json` | reconstructed | Successful token exchange (camelCase — the live API shape) |
| `token-response-snake-case.json` | reconstructed | The snake_case variant documented in the wiki |
| `error-invalid-payload.json` | **observed** | HTTP 400 — empty `client_id`/`client_secret` in the body, or a JSON body |
| `error-invalid-code.json` | **observed** | HTTP 400 — payload accepted, the authorization code itself is bad |
| `workout-planned.json` | reconstructed | A planned easy run |
| `workout-completed.json` | reconstructed | A completed quality session with a nested repeat block and per-step targets |
| `workout-crosstraining.json` | reconstructed | A cross-training bike session with a null `eventName` |
| `workout-skipped-filtered.json` | reconstructed | A `skipped` status workout and a `strength` cross-training session |
| `workouts-date-range.json` | reconstructed | A full array response from the date-range endpoint |
| `training-paces-step-targets.json` | reconstructed | Every `steps[].target` shape (`speed`, `heartRate`, `swimStroke`, `exercise`) |
| `gps-upload-response.json` | reconstructed | The PascalCase GPS-upload response |
