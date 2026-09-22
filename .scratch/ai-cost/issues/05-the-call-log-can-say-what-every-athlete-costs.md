# 05: The call log can say what every athlete costs

**Status:** in-progress (wave 3, 2026-09-22)
**Blocked by:** 02 (touches supabase/functions/_shared/vana/chat.ts), 04 (touches supabase/functions/_shared/vana/chat.ts).
**Next:** `/implement-lee ai-cost`
**Model:** opus

**What to build:** Lee can open one saved view and read, per week: cost per athlete by plan, the first-step cache hit rate, cost per confirmed plan, spend in conversations that never add a meal, and the share of turns that were fixed-label taps. An account that costs more than $1.50 in a day is reported to Sentry the same day. The app says whether each message was tapped or typed.

**Decisions:** mp-420, mp-464; approved as mp-470.

**Touches:** supabase/migrations, supabase/functions/_shared/vana/log.ts, supabase/functions/_shared/vana/chat.ts, lib/features/meal_planning/data/vana_chat_repository.dart, lib/features/meal_planning/application/vana_chat_controller.dart, docs/database

- [x] The call log gains cache-write tokens, step count, the gateway's charge, whether the turn drew the budget, tap or typed, and the subscriber's plan and trial state. Idempotent migration, applied to dev.
- [x] The app sends tap or typed with every message (test through the real chat controller).
- [x] One saved weekly view gives the five figures above.
- [x] A daily check reports any account over $1.50 in a day to Sentry and refuses nothing.
- [x] Raw rows in the three AI log tables are swept after 90 days; weekly rollups are kept.
- [x] A log test asserts every new column is written.

Next: /implement-lee ai-cost

## Dev check (2026-09-22)

Migration `20260922100000_ai_call_log_cost_view_and_retention.sql` applied to DEV
(`vlmtsdzpnjnavdgytcmi`) via the Management API, then applied a second time to prove it is
idempotent. Deployed to dev: `ai-cost-alert` (new), `vana-chat`, `jade-chat`, `describe-meal`,
`analyze-meal-photo`.

**Two live turns, the same conversation, one typed and one tapped** (`3af2ca69`, test@test.com —
the one entitled dev account). Every new column landed, and the pair happens to show the cache
working:

| | turn 1 (`typed`) | turn 2 (`tap`) |
|---|---|---|
| `input_tokens` | 10,439 | 10,511 |
| `cache_read_tokens` | 0 | 10,436 |
| `cache_write_tokens` | 10,436 | 72 |
| `first_step_input_tokens` / `..._cache_read_tokens` | 10,439 / 0 | 10,511 / 10,436 |
| `steps` | 1 | 1 |
| `gateway_cost_usd` | $0.013358 | $0.0012916 |
| `debited` | true | true |
| `subscriber_period_type` / `..._active_until` | NORMAL / 2026-10-15 | same |
| `vana_plan_label(...)` | `monthly` | `monthly` |

A warm second turn cost a tenth of the cold first one, and the log can now say so. Rows written
before the deploy carry null in every new column, which is the honest answer.

**The weekly view, on dev, with that traffic** (`select * from public.vana_weekly_cost`):
week 2026-09-21, plan `monthly` — 1 athlete, 2 calls, 2 costed, $0.01465, cost per athlete
$0.01465, first-step cache hit rate 0.4981 (the cold/warm pair), tap share 0.5000 over 2 athlete
turns. Everything logged before the deploy groups under plan `none` with `costed_calls` 0, so an
understated week says so instead of reading low.

**The five figures, hand-checked** against a synthetic week inside a rolled-back transaction on dev
(two athletes, two planning conversations — one with a meal added and its plan confirmed, one that
never added anything):

- annual: cost/athlete $0.012; first-step hit rate (26,000+30,000)/(31,000+33,000) = 0.8750; cost
  per confirmed plan $0.012; spend without a meal $0.000, share 0.0000; tap share 1/2.
- monthly: cost/athlete $0.030; hit rate 4,000/20,000 = 0.2000; no confirmed plan (null); spend
  without a meal $0.030, share 1.0000; tap share 0.0000.

**The sweep**, in a rolled-back transaction at an injected clock: rolled the week up first, then
purged the rows strictly older than 90 days; the rollup kept the figures (hit rate 0.8, tap share
0.5) after its raw rows were gone, and the row exactly 90.0 days old was retained. Run for real
afterwards: `{"rollup_rows_written":15,"rollup_rows_kept":15,"purged":{"vana_calls":30,"ai_usage":0,
"plan_generation_log":0}}` — 30 dev call rows older than 2026-06-24 are gone, which is what the
nightly job would have done anyway.

**The daily check, end to end.** `AI_COST_ALERT_TOKEN` set as a dev function secret and the Vault
secrets `ai_cost_alert_url` / `ai_cost_alert_token` seeded to match. `select
public.vana_daily_cost_alert('2026-09-21', -1)` found its one account, posted through pg_net and
got `{"success":true,"reported":1}` back (`net._http_response` id 3, status 200). The function
answers 401 on a wrong token. It reads only: no branch in the SQL or the function can refuse a
call, and nothing on a request path calls either.

Cron on dev: `ai-log-retention-sweep` 03:41 UTC, `ai-cost-daily-alert` 06:23 UTC.

Docs: `docs/database/ai-cost-log-and-weekly-view.md`, linked from `docs/database/README.md`.

**Prod:** nothing applied. The migration is additive and idempotent; it needs Lee's go, and the
Vault + function secrets have to be seeded per environment.
