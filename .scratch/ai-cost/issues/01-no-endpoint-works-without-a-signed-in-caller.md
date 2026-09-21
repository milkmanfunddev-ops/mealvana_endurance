# 01: No endpoint works without a signed-in caller

**Status:** done (wave 1, 2026-09-21)
**Blocked by:** None (can start immediately).
**Next:** `/implement-lee ai-cost`
**Model:** opus

**What to build:** Nobody outside the app can send a plan email or write an athlete's data. The plan-email function refuses a caller who is not signed in. The bulk upload keeps working for released app versions but writes only to the signed-in athlete's own account. The meal-plan parser on dev, which has no source in the repo, is gone. Dev only; production waits for Lee's go.

**Decisions:** mp-432; approved as mp-466.

**Touches:** supabase/functions/send-nutrition-plan-email, supabase/functions/upload-all-data, supabase/config.toml

- [x] An unsigned request to the plan-email function gets 401 and sends nothing (test through the handler); a signed-in request still sends.
- [x] The bulk upload takes the user id from the token and ignores any user id in the body (handler test with a body naming another user).
- [x] `parse-meal-plan` is undeployed from dev (deleted 2026-09-21); nothing in the repo refers to it (no source, no `config.toml` entry).
- [x] The ticket lists every function under `supabase/functions/` that calls a model, sends mail or writes with the service role, with its auth check.
- [x] Deployed to dev 2026-09-21 (both answer 401 to no token and to the anon key). Nothing is deployed to production.

## Function audit

Read on 2026-09-21 from the source at `7d08cbd2`, every function directory under
`supabase/functions/`. "Gateway only" means the function has no caller check of its own and
relies on Supabase's `verify_jwt`, **which the public anon key satisfies** — so a gateway-only
function is reachable by anyone holding a key that ships in the app. `verify_jwt = false` entries
are in `supabase/config.toml`.

| Function | Why it matters | Auth check |
| --- | --- | --- |
| `ai-coach` | model (`generateText`, `index.ts:286`); service-role write (`index.ts:256`, AI usage log `:322`) | token → user in code, `index.ts:94-107` |
| `analyze-meal-photo` | model (`generateObject`, `index.ts:202`); service-role storage + write (`index.ts:146`) | token → user in code, `index.ts:60-72`; photo ownership re-checked `index.ts:134` |
| `calculate-daily-macros` | service-role client (`index.ts:38`), reads only. FROZEN v5 engine | gateway only |
| `calculate-daily-macros-v6` | service-role client (`index.ts:37`); fills `daily_macro_targets` | gateway only |
| `create-user` | service role (`createServiceClient`, `index.ts:10`); inserts `users` `:76` and `food_preferences` `:111` | gateway only |
| `delete-user` | service role (`index.ts:48`); deletes the account | token → user in code, `index.ts:32-58` |
| `describe-meal` | model (`generateObject`, `index.ts:151`); service-role write (`index.ts:138`, insert `:211`) | token → user in code, `index.ts:58-70` |
| `ensure-credits` | service role (`index.ts:51`); grants credits via `ensure_free_credits` `:58` / `ensure_allowance` `:71` | token → user in code, `index.ts:48-55` |
| `garmin-backfill` | service role (`index.ts:248`); writes activities | token → user in code, `index.ts:82-95` |
| `garmin-deregistration` | service role (`index.ts:77`); deletes `garmin_user_mappings` `:91` | **none** — `verify_jwt = false`, no signature check. Garmin webhook |
| `garmin-oauth-callback` | no database client, no writes | **none** — `verify_jwt = false`. OAuth redirect |
| `garmin-ping` | service role (`index.ts:98`); 6 writes | **none** — `verify_jwt = false`, no signature check. Garmin webhook |
| `garmin-push` | service role (`index.ts:323`); 12 writes, the busiest prod function | **none** — `verify_jwt = false`, no signature check. Garmin webhook |
| `garmin-user-mapping` | service role (`index.ts:29`); writes the mapping | token → user in code, `index.ts:23-34`, plus a Garmin token check `index.ts:44` |
| `generate-macros-v4` | service role (`createServiceClient`, `index.ts:44`), reads pins | gateway only |
| `generate-nutrition-plan-v3` | service role (`createServiceClient`, `index.ts:126`); 5 writes | gateway only |
| `get-foods` | anon client carrying the caller's `Authorization` (`index.ts:58-64`), RLS applies; no writes | caller's JWT forwarded to PostgREST |
| `get-weather-forecast` | no database, no model; calls a weather API | gateway only |
| `jade-chat` | model via `runChat` (`_shared/vana/chat.ts`); credits debited | `authenticate()`, `index.ts:49` |
| `kroger` | no service-role write; third-party cart API | `authenticate()` `index.ts:17` + `requirePro` `:62`. `verify_jwt = false` by design (checked in code) |
| `lookup-product` | service-role client (`index.ts:29`), cache reads | gateway only |
| `meal-photo` | service-role storage and writes via `auth.v.admin` (`index.ts:53`, `:58`) | `authenticate()`, `index.ts:41` |
| `revenuecat-webhook` | service role (`handler.ts:48`); 6 writes, grants entitlements | shared secret in the `Authorization` header, `handler.ts:286-288`. `verify_jwt = false` |
| `search-catalog` | anon client carrying the caller's `Authorization` (`index.ts:47-53`) | caller's JWT forwarded to PostgREST |
| `search-nutrition-products` | service role (`index.ts:85`); upserts the product cache `:149` | gateway only |
| `search-public-events` | service role (`index.ts:21`); RPC read `:40` | gateway only |
| `send-nutrition-plan-email` | **sends mail** (Resend, `handler.ts:138`) | `authenticate()`, `handler.ts:120` — added by this ticket |
| `sync-all-data` | anon client carrying the caller's `Authorization` (`index.ts:21-24`); reads only | caller's JWT forwarded to PostgREST, but `user_id` still comes from the body `index.ts:28` |
| `upload-all-data` | service-role upsert across 8 tables (`handler.ts:145`) | `authenticate()`, `handler.ts:100` — added by this ticket; owner stamped from the token |
| `upsert-user-profile` | service role (`index.ts:59`); 4 writes | gateway only, and `user_id` comes from the **body** (`index.ts:78`) |
| `vana-action` | model via `_shared/vana/actions.ts` (pantry vision, memory extraction) | `authenticate()` `index.ts:28` + `requirePro` `:36` |
| `vana-chat` | model via `runChat`; credits debited | `authenticate()` `index.ts:40` + `requirePro` `:49` |
| `vana-day-notes` | model via `generateDayNotes` | `authenticate()` `index.ts:27` + `requirePro` `:36` |

Not in the repo: `parse-meal-plan` runs on dev with no source here and no `config.toml` entry.
Nothing in the codebase references it (only two mentions in `docs/release/prod-readiness-outstanding.md`).

Findings outside this ticket's Touches, for a later ticket — not fixed here:

- `upsert-user-profile` writes a profile for whatever `user_id` the body names, with the service
  role and no caller check. Same shape as the `upload-all-data` hole this ticket closed.
- `create-user`, `generate-nutrition-plan-v3`, `calculate-daily-macros-v6` and
  `search-nutrition-products` write with the service role behind the gateway check only.
- The four Garmin webhooks accept any caller: `verify_jwt = false` and no signature or shared
  secret, unlike `revenuecat-webhook`. `garmin-push` and `garmin-ping` then write with the service
  role. Whether Garmin offers a signature to check is an open question.
- `sync-all-data` forwards the caller's JWT (so RLS applies) but still reads `user_id` from the
  body; the two can disagree.
- `upload-all-data`'s two child tables, `carb_loading_days` and `carb_loading_day_meals`, have no
  `user_id` column, so they cannot be stamped. A caller could still upsert rows onto another
  athlete's `carb_loading_plans` id. Closing that needs a parent-ownership lookup.

Next: /implement-lee ai-cost
