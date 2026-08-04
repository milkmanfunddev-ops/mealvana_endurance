# Coverage Gaps & "Test Everything" Roadmap (2026-06-25)

Grounded in an actual inventory of `supabase/functions/`, `test/`, and
`lib/features/`. Companion to `test-recommendations-2026.md` (which has the P0
"next tests"); this doc is the **full map of what is NOT yet tested**, so we can
close coverage deliberately. Layers: **local** (Deno edge-fn unit) · **edge-fn
integration** (live) · **widget** · **Patrol** (device).

## Where coverage is already strong (don't re-do)
- **Nutrition engine** — `_shared/nutrition/*.test.ts` (12 files): rule/template/LP
  solvers, personal-formula pins, pin-backfill, sweat-hydration, overrides, audit.
- **Sync / repositories** — `test/new_sync` (24 files): offline-first dirty tracking,
  dedup, tombstones across providers.
- **Nutrition plan + Formula Kit** Flutter units; **widget smoke (159)** + seeded content.
- **Tested edge fns:** generate-macros-v4, generate-nutrition-plan-v3,
  calculate-daily-macros, garmin-ping, garmin-push, sync-final-surge.

---

## Layer 1 — Edge functions: ~24 of 33 have NO tests

### 1a. Food / catalog functions (P0 — core data path, pure-ish, easy to test)
| Function | What to test (local unit + 1 live integration) |
|---|---|
| `get-foods` | query/filter/pagination; empty result; diet/allergy filtering shape; malformed input → 400 |
| `search-catalog` | ranking/match; diacritics; empty query; injection-safe |
| `lookup-product` | barcode hit/miss; OpenFoodFacts mapping → our schema; missing nutriments fallback |
| `save-user-food` | validation; dedupe vs existing; unit normalization; RLS (user can't write another user's food) |
| `search-public-events` | text/date/location filter; dedupe; pagination |

### 1b. AI functions (P1 — mock the model, test the wiring/prompt/guardrails)
| Function | What to test |
|---|---|
| `analyze-meal-photo` | image→structured nutrition parsing; low-confidence flag; bad/empty image → graceful error; token/size limits |
| `describe-meal` | NL→structured; NDJSON streaming shape; refusal/empty handling |
| `ai-coach` | each mode; AI-Gateway call shape (mock); `COACH_INSIGHT_MODEL` honored; failure → fallback, not crash |
| `jade-chat` | streaming protocol; history persistence payload; system-prompt assembly; error path |

These call the model — unit-test by **mocking the AI Gateway client** and asserting
request assembly + response parsing + error handling. One live smoke each behind `--e2e`.

### 1c. Garmin / integration family (P1 — server-to-server, currently dark)
| Function | What to test |
|---|---|
| `garmin-oauth-callback` | code→token exchange; `+` in code (the ME-721 bug class); state validation |
| `garmin-deregistration` | mapping removal; idempotency |
| `garmin-backfill` | 90-day request assembly; auth |
| `garmin-user-mapping` | upsert on `garmin_user_id`; conflict handling |
| `sync-all-data` / `upload-all-data` | batch upsert; `onConflict: 'id'` (the 42P10 gotcha); partial-failure reporting |

### 1d. User lifecycle (P1)
`create-user`, `delete-user`, `upsert-user-profile` — creation side effects, cascade
delete (no orphans), profile merge, RLS. `send-nutrition-plan-email` — template render
+ Resend call (mock) + bad-address handling.

### 1e. Weather (P1)
`get-weather-forecast` — provider response → our shape; the **weather→hydration chain**
(feed temp/humidity into generate-macros, assert fluid scales) is the high-value one.

### 1f. Legacy versions — DECIDE, don't test
`generate-macros`, `generate-macros-v3`, `generate-nutrition-plan`,
`generate-nutrition-plan-v2` — confirm these are dead (app calls v4 / v3) and **delete**,
or document why they stay. Don't write tests for code that's being retired.

---

## Layer 2 — Flutter business logic (services/controllers) under-tested

| Feature | Current | Gaps to cover (unit tests, mock repos/services) |
|---|---|---|
| **coach_mode** | none | coach↔athlete pairing/accept/revoke; remote-ack write policy; chat send/retry; reports aggregation; portal state; **coach-on-athlete writes require remote ack** (CLAUDE.md rule) — test it |
| **calendar** | none | month/day build; date selection; activity/event placement; tz-naive `scheduled_date_time` handling (the Garmin-match bug class) |
| **carb_loading** | smoke only | protocol selection → day-by-day schedule math; custom-food add; persistence |
| **meal_logging** | 1 file | each of 5 log methods → ConsumedTotals; edit/delete; recent/recipe pickers; photo/describe wiring (mock edge fn) |
| **integrations** | partial | TP/FS/VDOT/Garmin sync → local insert → `uploadDirtyRecords()`; pre-logout sync; provider re-delete churn (the fixed bug — keep a regression test) |
| **auth** | 1 file | signup/login/reset-code/new-password flows; session restore; email-verification gap (Lee's TODO) |
| **app_startup** | partial | startup ordering; recoverable vs non-recoverable init; force-upgrade gate; Drift init path |
| **weather** | none | forecast fetch/caching; humidity→plan input |
| **ai_coach** | 1 file | chat controller streaming, history persistence, error states |
| **user_foods / recipes / notes / sharing / education / feedback** | little/none | CRUD + render; share-intent; content loading |

## Layer 3 — Widget tests: deepen beyond render

- **Content tests** for the under-covered features above (coach portal/athlete/chat,
  calendar month, carb-loading schedule, meal-logging review/pickers, weather detail,
  ai_coach chat) — seed state, assert values (pattern: `daily_macros_content_test.dart`).
- **Form-validation matrix** — finish the rest (user-profile bounds, sweat-profile,
  nutrition-targets, formula editor empty/no-foods).
- **Plan-state matrix** — loading/empty/populated/error for plan-detail + adjust-macros.
- **Navigation/interaction** — tab switching, back-stack unwind, deep-link entry,
  returnSelection (swap-food) round-trips.
- **Multi-size responsive gate** — run smoke at `kSmokeSizes` with overflow enforced.
- **Golden + a11y** — high-traffic cards; tap-target/contrast/text-scaling.

## Layer 4 — Patrol: only 3 flows exist (activities-CRUD, events-CRUD, formula-pin)

Missing user journeys (one representative each):
- **Full onboarding** signup → profile → sports → dietary → allergies → first plan
  (needs the Android birth-year picker fix + dev signup account).
- **Personal-formula create→pin→generate→assert-plan-uses-it** (the full product loop).
- **Meal logging** — log via manual + one AI method → Daily/Fuel-timeline reflects it.
- **Carb-loading** protocol from an event → schedule renders/persists.
- **Settings change persists** across app restart (offline-first).
- **Templates** save → reuse (function-only).
- **Integrations connect** (Garmin/FS/TP) — **Android only** (iOS sandboxes OAuth).
- **Coach mode** — pair with an athlete, send a message, see it cross-user (remote-ack).

---

## Suggested sequence to "test everything"
1. **Edge-fn local units for 1a (food/catalog)** + **1e weather→hydration** — highest
   value, cheap, currently dark.  → then **1b AI** (mock gateway) and **1c/1d**.
2. **Flutter service units** for coach_mode, calendar, meal_logging, integrations-sync
   (these encode real business rules and have near-zero coverage).
3. **Widget content tests** for those same under-covered features.
4. **Patrol** the missing journeys (after Phase-0 unblockers).
5. **Delete the legacy edge fns (1f)** so we're not chasing coverage on dead code.
6. **CI gating** so all of it guards every PR.

Each layer has a clear owner pattern already proven this session (Deno harness for
edge fns, `new_sync` mock-repo pattern for services, `pumpSeeded` for widgets, Patrol
flow files for journeys) — so this is fan-out-able.
