# 11: Errors the app has no copy for read as "Kroger could not be reached"

**What to build:** When something fails on Mealvana's side, the shopper is not told Kroger is down.
Every error code the server can return either has its own copy, or falls into a generic message
that doesn't blame Kroger. Only a real failure to reach Kroger says Kroger could not be reached.

Found on the 2026-09-10 simulator pass (`../device-verification.md`, defect 4; screenshot
`../evidence/2026-09-10/03-zip-failed-stale-backend.png`).

**Blocked by:** None (can start immediately)

**Status:** built 2026-09-11. Not yet seen on a device.

## What happens

`KrogerRemote.call` (`lib/features/kroger/data/kroger_repository.dart`) turns the server's `error`
string into a `KrogerException`, and `_error` in the controller turns anything else into
`unavailable`. The screen looks the code up in `_messageKeys`
(`lib/features/kroger/domain/kroger_messages.dart`) and falls back to `kroger.unavailable`:
"Kroger could not be reached. Your draft is saved on this device."

Codes the server can return that have no entry, so they all show that sentence:

| Code | Where it comes from | What it actually means |
|---|---|---|
| `invalid_action` | `service.ts`, an action the deployed function doesn't know | App and function are out of step |
| `invalid_body`, `invalid_input`, `invalid_id`, `invalid_modality` | request validation | The app sent something malformed |
| `unauthenticated` | `_shared/vana/auth.ts` (401) | The Mealvana session is missing or expired |
| `invalid_token_response` | `client.ts`, Kroger's token reply was malformed | Kroger answered, but wrongly |
| `method_not_allowed` | `kroger/index.ts` | Not reachable from the app |

On 2026-09-10 the dev function lagged the app by three tickets. Setting a ZIP returned
`invalid_action`, and the shopper read that Kroger couldn't be reached, which sent the investigation
the wrong way first.

`kroger_unavailable` (a real upstream failure) already has its own key, but its default copy is
word-for-word the same as `unavailable`, so the two can't be told apart on screen either.

## Direction

- Give the fallback a message that doesn't name Kroger as the cause (something went wrong, the
  draft is saved, try again), and keep "Kroger could not be reached" for `kroger_unavailable` and
  for transport failures, where the request never got an answer.
- `unauthenticated` asks the shopper to sign in to Mealvana again.
- The validation codes and `invalid_action` share the generic message. They're bugs or version
  skew, and the shopper can't act on them differently.
- A test asserts that every code the server can emit maps to a key, so a new server code without
  copy fails in CI rather than on a device.
- New copy goes in as content keys (`content_keys.dart` plus `assets/config/content_defaults.json`).

## Acceptance

- [x] `invalid_action` and the validation codes do not show "Kroger could not be reached"
- [x] `unauthenticated` gets copy that tells the shopper what to do
- [x] `kroger_unavailable` and a network failure still say Kroger could not be reached
- [x] A test fails if the server gains an error code the app has no mapping for

## Notes from the build

- The controller's `_error` decides whose fault a failure is. `http.ClientException` (the socket
  failure package:http wraps) and `AuthRetryableFetchException` (the session refresh that runs
  first when the access token has expired, offline) are `unavailable`. Anything else, such as a
  `PostgrestException` or a bug, is the new `unexpected` code. A `FunctionException` with no
  `error` in its body (a crashed function or a gateway page) is `unexpected` as well.
- New copy: `kroger.unexpected` ("Something went wrong…") and `kroger.signed_out`.
  `kroger.kroger_unavailable` now adds "Try again in a few minutes", so the two "could not be
  reached" messages differ.
- `kroger_content_keys_test` reads error codes out of the kroger function's TypeScript source.
  It only sees string literals in `index.ts`, `_shared/kroger/*.ts`, `auth.ts` and
  `entitlement.ts`.
- `export_unknown` is mapped even though `service.ts` catches it and stores a receipt instead.
  The scan requires a mapping, and the mapping is harmless.
- A hand-off that no app would open still throws `unavailable` ("Kroger could not be reached").
- Server side, fixed after the review (Lee asked, "#12"): `KrogerClient` turns a request that never
  got an answer, or a reply that isn't JSON, into `kroger_unavailable`. Any other throw is a bug in
  the function, and `failure()` in `catalog.ts` answers it as `internal_error` (500), which the app
  shows as "Something went wrong". The function has to be deployed for this to reach dev.
