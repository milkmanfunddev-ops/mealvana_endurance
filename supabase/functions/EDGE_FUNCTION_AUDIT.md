# Edge Function Audit

**Last audited:** 2026-07-16
**Method:** every `.functions.invoke('<name>')` in `lib/`, cross-referenced against the deployed
function list on dev + prod, 24h of prod invocation logs, `pg_cron` (not installed), and
server-to-server calls inside `supabase/functions/`.

> **The 2025-12-20 version of this file was seven months stale and actively wrong** — it listed
> `generate-macros` and `generate-nutrition-plan` as ACTIVE long after the client had moved to
> `generate-macros-v4` / `generate-nutrition-plan-v3`. Re-run the audit rather than trusting this
> file's age.

## Re-run the audit

```bash
# What the client actually invokes (the multi-line .invoke( form matters — most call sites use it):
grep -rhA1 "\.invoke($" lib/ | grep -oE "^\s*'[a-z0-9-]+'" | tr -d " '" | sort -u
grep -rhoE "\.invoke\('[a-z0-9-]+'" lib/ | grep -oE "'[a-z0-9-]+'" | tr -d "'" | sort -u

# Deployed list:   Supabase MCP list_edge_functions (or the dashboard)
# Recent traffic:  Supabase MCP get_logs service=edge-function  (24h window)
```

**A function is only dead if ALL of these hold:** not in the client invoke list, not called by another
edge function, no traffic in the log window, not an external webhook, and no `pg_cron` job.

Two traps worth naming, both hit during this audit:
- **"No local source" is not sufficient.** 20 functions were deployed with no source in the repo.
- **"Not called by the client" is not sufficient.** Webhooks are called by Garmin / RevenueCat.
- Beware loose greps: `grep "generate-macros"` also matches `generate-macros-v4`.

---

## Client-invoked (19)

`ai-coach` · `analyze-meal-photo` · `calculate-daily-macros` · `create-user` · `delete-user` ·
`describe-meal` · `garmin-backfill` · `garmin-user-mapping` · `generate-macros-v4` ·
`generate-nutrition-plan-v3` · `get-foods` · `get-weather-forecast` · `jade-chat` · `lookup-product` ·
`search-catalog` · `search-nutrition-products` · `search-public-events` · `send-nutrition-plan-email` ·
`sync-all-data` · `upsert-user-profile`

## External webhooks — never client-invoked, DO NOT DELETE on that basis (5)

`garmin-oauth-callback` · `garmin-ping` · `garmin-push` · `garmin-deregistration` ·
`revenuecat-webhook`

`garmin-push` is the busiest function in prod logs by a wide margin.

## Deployed, uncalled, kept

`upload-all-data` · `sync-final-surge` — both have local source; retained pending a decision.

---

## Removed 2026-07-16 — 20 functions, dev + prod

Each had **no local source** (they existed only in the now-deleted `supabase/functions_old/`), **no
client invocation**, **no traffic in 24h of prod logs**, no cron job, and was not a webhook.

`barcode-lookup` · `carb-loading` · `create-nutrition-plan` · `delete-user-food` ·
`generate-ai-nutrition-plan` · `generate-macros` · `generate-macros-v3` · `generate-nutrition-plan` ·
`generate-nutrition-plan-v2` · `get-carb-loading-foods` · `run-plan` · `save-activity-completion` ·
`save-calendar-activity` · `save-calendar-event` · `save-carb-loading-plan` · `save-food-preferences` ·
`save-user-food` · `search-active-events` · `send-push-notification` · `update-user-preferences`

Prod went 47 → 27 deployed functions. `search-catalog` and `garmin-ping` verified healthy afterwards,
and the dev app was exercised post-deletion.

### ⚠️ Residual risk, and how to undo

`app_config.min_app_version` is **1.14.1**, so clients older than the `-v3`/`-v4` cutover are still
*permitted* to run. Such a client would call `generate-macros` / `generate-nutrition-plan` and now
receive a 404. **Zero traffic across 24h of prod logs says no such client is active** — but a 24h
window is evidence, not proof.

**To restore any one of them** — the source is in git history, immediately before the `functions_old`
deletion:

```bash
git show badd4920^:supabase/functions_old/<name>/index.ts    # inspect
git checkout badd4920^ -- supabase/functions_old/<name>      # restore the dir
supabase functions deploy <name> --project-ref wvmvsodrvbkxfydabqed
```

**The durable fix** is to raise `min_app_version` past the `-v3`/`-v4` cutover so old clients are
force-upgraded rather than 404'd. That is a product call and was not done here.

---

## Added 2026-09-01 — meal planning (Vana), dev only

Phase 2 of `docs/implement_mealplanning/` (spec: `03-backend.md`). Deployed to **dev** (`vlmtsdzpnjnavdgytcmi`)
with `--no-verify-jwt`; **not on prod** until the Phase 5/6 runbook (prod has none of the meal-planning tables yet).
Shared code: `supabase/functions/_shared/vana/` (also imported by `jade-chat` — redeploy all four on any change there).

| Function | Caller | Notes |
|---|---|---|
| `vana-chat` | 1.24 client (`lib/features/meal_planning`, replaces `jade-chat` for `ai_coach`) | NDJSON chat, Pro-gated (403 `pro_required`; dev secret `PRO_GATE_ENABLED=false`), rate-limited via `vana_calls`, **no credit debit**. |
| `vana-action` | 1.24 client | Model-free plan edits/reads (`{type, payload}` → `{parts, ...}`); `confirm_plan` → `confirm_meal_plan()` RPC, then invokes `vana-day-notes`. |
| `vana-day-notes` | `vana-action` / `vana-chat` (server-to-server, under `EdgeRuntime.waitUntil`, with the athlete's JWT) | Never invoked directly by the client — do not delete on that basis. |
| `jade-chat` | ≤1.23.x client | Now a thin alias of the Vana **general** chat (same route, envelope and credit debit); writes `vana_*` tables directly. Retire once `min_app_version` passes 1.24. |

Secrets: `AI_GATEWAY_API_KEY` (existing), `PRO_GATE_ENABLED`, optional `VANA_CHAT_MODEL` / `VANA_TOOL_MODEL` /
`VANA_EMBED_MODEL`. Telemetry: one `vana_calls` row per model call + `ai_usage`.
