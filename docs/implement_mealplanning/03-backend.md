# 03 — Backend (Phase 2): edge functions + RPCs

**Why edge functions:** `supabase/functions/jade-chat/index.ts` already runs `npm:ai@6` `streamText` +
`tool` + `zod` under Deno, streams the NDJSON envelope, does `ensureAndCheckCredits` / `debitForUsage`,
`logAiUsage`, Sentry. `server/vana/*.ts` ports nearly file-for-file. One deploy target, one secret set.

## 1. Layout
```
supabase/functions/
  _shared/vana/
    contracts.ts      ← copied from prototype (the frozen contract)
    persona.ts        ← CORE / PLANNING_PROMPT / GENERAL_PROMPT verbatim
    context.ts        ← buildAthleteContext + contextBlock (+ derive-week-character.ts)
    tools.ts          ← makeVanaTools(kind) — the 24 tools, same tool sets
    actions.ts        ← runAction + extraAction + homePayload
    plan.ts meals.ts memory.ts grocery.ts daynotes.ts macros.ts holidays.ts weather.ts embeddings.ts
    rate-limit.ts log.ts
    stream.ts         ← NDJSON writer shared with jade-chat (extract from jade-chat/index.ts)
    entitlement.ts    ← requirePro(userId) reads user_entitlements (Phase 3)
  vana-chat/index.ts     POST — auth → pro gate → rate limit → credits → context → streamText → persist
  vana-action/index.ts   POST — auth → pro gate → runAction (no model, no credits)
  vana-day-notes/index.ts POST — {plan_id} → generateDayNotes; called by vana-action after confirm/edit
                          via EdgeRuntime.waitUntil (never awaited by the client)
  vana-opener/  (folded into vana-chat with opener:true — no separate fn)
```
Port rules: `db()`/service-role + `userId` filters → **the caller's JWT client** (RLS does the filtering);
service-role only for `vana_calls`, `meal_library_pairs` refresh, and `daily_macro_targets` fills.
`env.ts` model selection → `_shared/ai/model.ts` constants (`VANA_CHAT_MODEL` default
`anthropic/claude-haiku-4-5`, `VANA_TOOL_MODEL`, `VANA_EMBED_MODEL openai/text-embedding-3-small`)
via the AI Gateway key already in edge secrets. Open-Meteo/holidays: unchanged (no keys).

## 2. Work items
1. **Extract** `stream.ts` from `jade-chat` (NDJSON writer, `text/ui/done/error` + new `status`). Add
   `status` emission on `tool-call` stream parts (map tool → copy string; client shows it).
2. **Port `_shared/vana/`** (≈2,500 lines TS). Replace TanStack server-fn imports; `createServerFn`
   bodies become plain functions. Keep `contracts.ts` byte-identical to the prototype's.
3. **`vana-chat`**: body per `02-contract §5`. `opener:true` + `kind=meal_planning` runs the scripted
   opener (`OPENERS`) and persists it. `shownMealIds` from prior `vana_messages.parts`. No credit debit (Pro only, §3);
   `logAiUsage` still records every call.
   `x-conversation-id` header before first byte.
4. **`vana-action`**: switch on `type`; add the app-only actions (`get_home`, `get_meal`, `recent_meals`,
   `set_saved_meal_notes`, `set_meal_feedback`). `confirm_plan` = transactional RPC `confirm_meal_plan(p_plan_id)`
   (status→confirmed, shopping built, archive other drafts for the week) so the client gets a remote
   ack in one call; then `waitUntil(vana-day-notes)`.
5. **Postgres**: new migration `2026090X_meal_planning_rpcs.sql` with `confirm_meal_plan`,
   `plan_set_servings`, `plan_remove_meal`, `plan_log_from_plan` (writes `meal_logs source='plan'`,
   decrements `servings_left`), `plan_toggle_shopping`, `plan_set_day_slot` — small SQL functions the
   Dart repos can also call directly when offline-first upload replays them. Grocery aggregation stays
   TS (`grocery.ts`) inside `confirm_meal_plan`'s caller; if we want it in SQL later, `shopping` is
   just a jsonb column.
6. **Jade → Vana**: `jade-chat` persona replaced by `GENERAL_PROMPT`; it becomes a thin alias of
   `vana-chat` with `kind=general` (keep the route for 1.23.x clients until `min_app_version` passes it).
   `ai_coach_chat_repository.dart` repoints to `vana-chat` (Phase 4). Tables: write `vana_*` directly.
7. **Rate limit buckets** move from `jade_calls` to `vana_calls` (same columns).
8. **Tests**: port `grocery.test.ts`, `context.test.ts`, `smoke-vana.test.ts` into
   `supabase/functions/tests/vana/`; add to `run-algorithm-tests.sh`. Contract test: a fixture
   conversation replayed against `vana-chat` asserts every emitted `ui` part parses against a JSON
   schema generated from `contracts.ts` — the same schema the Dart `fromJson` tests use.
9. Deploy both refs with `/deploy-edge` (`--no-verify-jwt`); update `EDGE_FUNCTION_AUDIT.md`.

## 3. Entitlement semantics (decided 2026-09-01: Pro only)
- `vana-chat`/`vana-action`/`vana-day-notes` return **403 `pro_required`** unless `user_entitlements` has an
  active `pro` row OR the caller is an internal tester OR the `PRO_GATE_ENABLED` secret is `false` (dev
  default). Client maps 403 → `/pro`.
- **No credit debit** for meal planning. Every model call is still logged to `vana_calls` (cost
  telemetry) and rate-limited. `ensureAndCheckCredits` is NOT called on the Vana paths; the general-kind
  chat that replaces Jade keeps its existing 1-credit debit for free-tier users and is free for Pro.

## 4. Acceptance
- Signed in as the dev test user, `curl vana-chat` with `opener:true` streams the opener + a
  `meal_picker` whose meals exclude the user's allergens; `vana-action pick_meals` returns a `batch`
  with the meal; `confirm_plan` returns `shopping_list` and `meal_plans.status='confirmed'`;
  `log_from_plan` writes a `meal_logs` row with `source='plan'`, `plan_meal_id` set, `servings_left−1`.
- `vana_calls` has one row per model call; 429 after 5 rapid chats; **no** credit debit for Pro users; 403 for a
  non-pro user when the gate is on.
- `run-algorithm-tests.sh` green incl. the new vana suite.
