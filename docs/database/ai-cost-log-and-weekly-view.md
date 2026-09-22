# The AI call log, the weekly cost view, and the 90-day sweep

What each object is, what it answers, and the two things that will mislead you if you read it without
knowing them. Built by ai-cost ticket 05 (mp-420 clause 6, mp-464 clause 7, approved as mp-470);
migration `supabase/migrations/20260922100000_ai_call_log_cost_view_and_retention.sql`.

## The point

October's real traffic is what sets the monthly budget (mp-430). Before this migration the log held
tokens and nothing else, so every cost figure in the 09-20 audit was an estimate from 3 to 8 dev
users. Now each call records what the gateway charged for it and what kind of turn it was, and one
saved view turns that into the five numbers Lee reads each week.

## The three log tables

| Table | One row is | Written by |
|---|---|---|
| `public.vana_calls` | one Vana model call | `_shared/vana/log.ts` (`logCall`) and `_shared/vana/rate-limit.ts` (`reserveCall` writes the row, `completeCall` settles it) |
| `public.ai_usage` | one model call from any AI function | `_shared/ai/usage.ts` (`logAiUsage`) |
| `public.plan_generation_log` | one fuelling-plan generation | the nutrition-plan functions |

`vana_calls` is also the rate limiter's bucket store: the row goes in before the model runs, which is
what makes a burst countable (mp-430 clause 9, ticket 04).

## The columns ticket 05 added to `vana_calls`

- `cache_write_tokens` — the prompt cache's other direction. A write bills more than an uncached
  read, so without it a churning prefix and a warm one look identical.
- `first_step_input_tokens`, `first_step_cache_read_tokens` — the turn's **first** model step. Only
  the first step can read the shared prefix from cache; later steps read what this same call just
  wrote. A whole-turn ratio therefore flatters the cache, which is why the hit rate mp-420 is
  measured against is the first step's.
- `steps` — model steps in the turn. A runaway tool loop is many billed calls even when each is short.
- `gateway_cost_usd` — the gateway's own charge, summed over the turn's steps. **Null means the
  gateway reported nothing, not that the call was free.**
- `debited` — whether the call drew the athlete's budget.
- `input_mode` — `'tap'` or `'typed'`, sent by the app (`input_mode` on the wire). Null for the
  scripted opener and every background job. It is a measurement: nothing treats a tap differently.
- `subscriber_period_type`, `subscriber_active_until` — the `user_entitlements` pair as it stood at
  the call.

## Why the plan is a label, not a column

`user_entitlements` is the two-field cache of RevenueCat (mp-285): `active_until` and `period_type`,
with the store product id deliberately dropped. So the log stores that raw pair and
`public.vana_plan_label(period_type, active_until, at)` names the plan from it:

- no row, or access already ended → `none`
- `TRIAL` / `INTRO` → `trial`
- `PROMOTIONAL` → `promotional`
- `NORMAL`, access more than 45 days out → `annual`
- `NORMAL`, otherwise → `monthly`

The 45-day cut is what separates the two paying plans without the product id, and it is exact for the
traffic it was built for: a monthly subscriber's access is never more than about 31 days out, and
October's annual subscribers bought in October. **It misreads an annual subscriber in the last 45
days of their year as monthly** — which is the reason the raw pair is stored and the label is only a
function. Re-cut the function when the products change; no backfill needed.

## Reading the figures

```sql
select * from public.vana_weekly_cost order by week_start desc;
```

One row per ISO week and plan:

| Figure | Column |
|---|---|
| cost per athlete by plan | `cost_per_athlete_usd` |
| first-step cache hit rate | `first_step_cache_hit_rate` |
| cost per confirmed plan | `cost_per_confirmed_plan_usd` |
| spend in conversations that never add a meal | `planning_cost_without_a_meal_usd`, `planning_spend_share_without_a_meal` |
| share of turns that were fixed-label taps | `tapped_turn_share` |

`public.vana_call_facts` is the per-call view underneath it, with the plan label and two conversation
facts joined: did that conversation ever put a meal in a plan (`meal_plans.conversation_id` →
`plan_meals`), and did its plan get confirmed. Tool names are deliberately not consulted — meals
reach a plan through `updateBatch`, `draftWeek`, `planDay`, `planWeek` and `sameAsLastTime`, and that
list changes with the persona.

**Read `costed_calls` next to `calls`.** Cost here is only what the gateway charged; rows from before
2026-09-22 carry none, and so does any call the gateway stayed quiet about. A week where
`costed_calls` is well under `calls` is understated, and says so instead of reading low. Pricing
tokens from a table belongs to the monthly budget (mp-436, ai-cost ticket 09) — two price tables
would be two answers.

**`athlete_turns` is the denominator of the tap share**, not `calls`: only a turn the athlete sent
has an `input_mode`, and that is the only population where tapping instead of typing was a choice.

## The daily check

`cron.job 'ai-cost-daily-alert'`, 06:23 UTC, runs `public.vana_daily_cost_alert()` for yesterday.
Any account whose logged charge crossed $1.50 is posted to the `ai-cost-alert` edge function via
pg_net, which raises one Sentry event per account, fingerprinted on the account and the day.

It only reads. There is no branch in it that can stop a call and no caller of it on any request
path — the refusing is the monthly budget's job (mp-430, ticket 09). Threshold and day are
parameters, so `select * from public.vana_daily_cost_offenders('2026-10-04'::date, 1.50);` answers
the same question by hand.

Per environment, outside migrations: the Vault secrets `ai_cost_alert_url` and `ai_cost_alert_token`,
and the function secret `AI_COST_ALERT_TOKEN` matching the latter. Both seeded on dev 2026-09-22.
With them absent the check still runs and raises a NOTICE instead of a Sentry event.

## The 90-day sweep

`cron.job 'ai-log-retention-sweep'`, 03:41 UTC (after the raw-retention sweep at 03:17), runs
`public.ai_log_retention_sweep(now())`:

1. `vana_roll_up_weeks(now(), now() - 90 days)` freezes every complete week of `vana_weekly_cost`
   into `public.vana_weekly_rollup`. A missing week is always inserted; a week already frozen is
   overwritten only while `week_start` is on or after the cutoff, so every raw row of it is still
   there. The week straddling the cutoff keeps the figure it was frozen with the night before the
   first of its rows was deleted, instead of shrinking night by night.
2. Rows **strictly** older than 90 days are deleted from all three log tables. A row exactly 90.0
   days old is retained — the same boundary convention as `raw_retention_sweep`.

Rollups are kept forever; raw rows are not. The rollup is written first on purpose: a sweep that
deleted first would lose the week it was deleting.

`p_now` is injected, the way `raw_retention_sweep` takes it, so the sweep can be run at any clock
from a test or by hand. The cron entry is the only place the wall clock enters.
