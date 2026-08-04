# AI Credits — purchase & metering design

Status: **backend foundation built + deployed (dev + prod), enforcement OFF by default.**
Last updated: 2026-06-29.

Users hold a balance of app-defined **AI credits**. Each AI action costs a fixed
number of credits. Users get a free monthly allotment and can buy more via
consumable in-app purchases (RevenueCat → App Store / Google Play). We price in
round credits, NOT raw LLM tokens (raw token cost is tracked separately in
`ai_usage` for our own cost monitoring).

The feature has two halves:
- **Use → debit** (in the AI edge functions) — built.
- **Purchase → grant** (RevenueCat webhook) — built.

---

## What's built and live

### Database (dev + prod)
- `token_wallets` — materialized per-user balance (never negative), plus
  `free_period` (YYYY-MM of last free grant).
- `token_ledger` — append-only audit of every grant/debit (reason, ref,
  balance_after). Unique index on `ref` for `grant_purchase` → idempotent
  purchase grants.
- RPCs (SECURITY DEFINER, **service-role only**):
  - `grant_credits(user, amount, reason, ref)` → new balance.
  - `debit_credits(user, amount, reason, ref)` → `{success, balance}` (atomic,
    balance-guarded).
  - `ensure_free_credits(user, amount)` → grants the monthly free amount once per
    calendar month (lazy; no cron needed).
- RLS: users read their own wallet + ledger; only the RPCs/service role write.
- SQL of record: `supabase/migrations/_archived/20260629140000_ai_credit_wallet.sql`.

### Edge functions (dev + prod)
- `_shared/ai/credits.ts` — enforcement helpers, gated by `AI_CREDITS_ENFORCED`.
  - `ensureAndCheckCredits` (provision wallet + free grant, check affordability,
    no debit; **fail-open** on error).
  - `debitForUsage` (debits after a successful call; fire-and-forget).
  - `insufficientCreditsBody` (structured 402 body for the app).
- Wired into all 4 AI functions: `ai-coach`, `describe-meal`,
  `analyze-meal-photo`, `jade-chat`. Each: check **after** input validation,
  **before** the model call → returns **HTTP 402** `{error:'insufficient_credits',
  balance, cost}` when broke; debits only on success. Opener-mode ai_coach greetings
  are not charged.
- `revenuecat-webhook` (deployed with `--no-verify-jwt`) — on a purchase event,
  maps product id → credits → `grant_credits` (idempotent per RC event id).

### RevenueCat (project `proj77b3c48f`, Test Store app `appa283bb35a2`)
- Consumable products: `mealvana_credits_100` / `_500` / `_1200` (100/500/1200
  credits).
- Offering **"AI Credit Packs"** (`credits`) with 3 packages, products attached.

---

## Defaults (all tunable via Supabase secrets — no redeploy of logic needed)

| Thing | Default | Override secret |
|---|---|---|
| Enforcement | **off** | `AI_CREDITS_ENFORCED=true` |
| Free credits / month | 50 | `AI_FREE_MONTHLY_CREDITS` |
| ai-coach cost | 1 | `AI_COST_AI_COACH` |
| describe-meal cost | 1 | `AI_COST_DESCRIBE_MEAL` |
| analyze-meal-photo cost | 2 | `AI_COST_ANALYZE_MEAL_PHOTO` |
| jade-chat cost | 1 | `AI_COST_JADE_CHAT` |
| product → credits map | code defaults | `RC_PRODUCT_CREDITS` (JSON) |
| webhook shared secret | — (required) | `REVENUECAT_WEBHOOK_SECRET` |

Set secrets per env, e.g.:
`supabase secrets set AI_FREE_MONTHLY_CREDITS=50 --project-ref <ref>`

---

## To turn it ON (when the paywall is ready)
1. Set `REVENUECAT_WEBHOOK_SECRET` on both projects; configure the RC webhook
   (Integrations → Webhooks) → URL `https://<ref>.supabase.co/functions/v1/revenuecat-webhook`,
   Authorization header = that secret.
2. (Optional) Set `RC_PRODUCT_CREDITS`, `AI_FREE_MONTHLY_CREDITS`, cost overrides.
3. Flip `AI_CREDITS_ENFORCED=true`. From then on, AI calls check + debit credits.

Do **dev first**, exercise the full loop, then prod.

---

## Remaining prerequisites (app store + Flutter — not buildable server-side)
1. **Store products**: create the 3 consumables in App Store Connect + Google
   Play (RC today only has Test Store entries). Link real store apps to the RC
   project (today only a Test Store app exists).
2. **Flutter SDK + UI**: add `purchases_flutter`, configure with RC public API
   keys, call `Purchases.logIn(<supabase user id>)` so RC `app_user_id` == our
   user id (the webhook depends on this), build a credit-balance widget + a
   "buy credits" paywall, and handle the **402** from AI calls by opening it.
3. **RC public API keys** (Apple/Google) into the app config (gitignored).
4. Decide final pack sizes + prices + the free monthly amount.

See `SETUP_GUIDE.md` / `YOUR_NEXT_STEPS.md` for the store-account progress.

---

## Admin / monitoring queries
```sql
-- Current balances (top holders)
SELECT user_id, balance, free_period, updated_at
FROM public.token_wallets ORDER BY balance DESC LIMIT 50;

-- Credit activity last 30 days
SELECT reason, count(*), sum(delta) FROM public.token_ledger
WHERE created_at > now() - interval '30 days' GROUP BY reason;

-- Real LLM token cost per user (separate from credits) — see ai_usage
SELECT user_id, sum(input_tokens+output_tokens) total_tokens, count(*) calls
FROM public.ai_usage WHERE created_at > now() - interval '30 days'
GROUP BY user_id ORDER BY total_tokens DESC;
```
