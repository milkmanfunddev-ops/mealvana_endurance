# 24-001 · One photo analysis writes two rows to the AI call log, so the weekly cost view counts each logging call and its tokens twice

- kind: bug
- status: triaged
- ticket: 24
- run: w14-20260924T2015Z
- screen: Log a Meal (Describe, photo)
- decision: 

**Steps.**
1. Signed in as test@test.com, open + Add Food, Describe tab, Gallery, pick a food photo.
2. Tap Analyze once (one analyze-meal-photo request, 20:18:44Z).
3. Read `vana_calls` (the table behind the `jade_calls` view) for the account in the call window.

**Expected.**
One row per AI call in the Vana call log, carrying the tokens, the gateway cost, `debited` and the plan
state, so `vana_call_facts` / `vana_weekly_cost` count one call and its tokens once.

**Actual.**
Two rows for the one call: `vana.meal_photo` (20:18:35Z, the rate-limit reservation, completed with 2368 in /
162 out, gateway_cost_usd 0.013695, debited true, subscriber NORMAL) and `analyze-meal-photo`
(20:18:44Z, the same 2368 / 162 tokens, gateway_cost_usd, debited, steps and subscriber state all null).
`vana_weekly_cost` takes `count(*)` as calls and sums input/output tokens over every row, so each photo
log counts as two calls and doubles its tokens; the cost sum is right only because the second row's cost
is null. Ticket 23's describe-meal call at 19:07Z shows the same pair (`vana.describe_meal` +
`describe-meal`), so every AI logging call is doubled. Source: `supabase/functions/analyze-meal-photo/index.ts`
inserts into `jade_calls` after `completeCall` already filled the reservation row whose own comment says
"The reservation IS this call's row in the Vana call log"; `describe-meal/index.ts` does the same.
ai_usage (one row) and token_ledger (reserve -13000, settle -695 = 13,695 micro-dollars = cost_usd) are right.

**Evidence.**
- runs/24/db-vana-calls.txt: the four rows (two per call, ticket 23's and this run's).
- runs/24/db-ai-usage-ledger-after.txt: one ai_usage row, the ledger pair, two jade_calls rows.
- runs/24/edge-requests.txt: a single POST to analyze-meal-photo at 15:18:44 local.

**Decision quote.**
> 

**Triage.**
Fix ticket 43 (Lee, 2026-09-25). Closed by the retest after it merges.
Moved to retest ticket 114 when 91 was split (Lee, 2026-09-25).
