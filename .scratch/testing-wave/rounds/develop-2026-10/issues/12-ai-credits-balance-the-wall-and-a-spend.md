# 12: AI credits: the balance, the out-of-credits wall, and a spend

**Status:** ready (round develop-2026-10)
**Labels:** test, round:develop-2026-10, area:ai-credits, ai-call, revenuecat
**Branch:** `develop-next`
**Source:** new (replaces the subscription tickets 04–13, which test code develop-next does not have)
**Blocked by:** none.
**Next:** `/testing-wave develop-2026-10 --only 12`
**Model:** opus

**What to test:** The credits system that predates the paywall work. A new account gets its free
allotment and sees it in the token pill. A Jade turn and a described meal each spend what the server
says they cost. At zero, an AI call meets the "Out of AI credits" dialog, "Get credits" opens the
buy screen, a Test Store pack lands as credits, and the next call goes through.

**Runs by:** `docs/testing-wave/RUNBOOK.md` on develop-next (until it lands there:
`git show origin/mealplanning:.scratch/testing-wave/RUNBOOK.md`). This round's paths: RUNS =
`.scratch/testing-wave/rounds/develop-2026-10/runs/12/`, Findings in
`.scratch/testing-wave/rounds/develop-2026-10/findings/`. One slot, console to RUNS, a look-around on
every screen, every problem a Finding, nothing fixed.

**Accounts:** one new `lee+e2e-12-<UTC time>@rightpathprogramming.com` (`CRED new` before signup).
Never drain or top up a shared account.

**App data:** cleared by the wave lead.

**Cost:** up to three spends: `COST spend WAVE chat 12` before the Jade send, `COST spend WAVE
logging 12` before each describe send (two). The send refused at zero balance makes no model call
(the server checks the balance first); write that in notes so the lead can count it back.

## Screens (from code, unverified)

| Screen | Entry | Code |
|---|---|---|
| Welcome, onboarding, signup, Verify your email | `/welcome` → `/onboarding` → `/auth/post-onboarding` → `/auth/email-signup` | see ticket 01 |
| Log a meal sheet, Describe tab, with the token pill | Timeline "+ Add Food" | `lib/features/meal_logging/presentation/screens/log_meal_screen.dart`, `lib/features/ai_credits/presentation/widgets/token_pill.dart` |
| Token top-up sheet | tap the pill | `lib/features/ai_credits/presentation/sheets/token_top_up_sheet.dart` |
| Review | `/meal-log/review` | `lib/features/meal_logging/presentation/screens/meal_review_screen.dart` |
| Jade chat | deep link `/jade` | `lib/features/ai_coach/presentation/screens/ai_coach_chat_screen.dart` |
| "Out of AI credits" dialog ("Not now" / "Get credits") | a 402 from an AI call | `lib/features/ai_credits/presentation/insufficient_credits_paywall.dart` |
| AI Credits (Your Balance, Credit Packs, Restore, How credits work) | `/buy-credits` | `lib/features/ai_credits/presentation/screens/buy_credits_screen.dart` |
| RevenueCat Test Store purchase sheet | a pack's buy button | system / RevenueCat |
| Settings → Developer / Tester section | seven taps on the version text | `lib/features/settings/presentation/screens/settings_screen.dart` |

## How the system works (from code, unverified; confirm on screen and by SQL)

- Wallet: `token_wallets` (balance, `free_period`) and `token_ledger` (delta, reason, ref,
  balance_after). Read-only from the app; edge functions write. `ensure-credits` grants the monthly
  free allotment once per calendar month.
- Costs and enforcement live in `supabase/functions/_shared/ai/credits.ts`: per-action cost
  (`describe-meal`, `analyze-meal-photo`, `jade-chat`), the free allotment, and `AI_CREDITS_ENFORCED`.
  With enforcement off, nothing is debited and nothing is refused. Do not read or change the secret;
  learn it from behaviour (step 3).
- App: `TokenPill` on the Log a meal sheet's Describe tab opens the top-up sheet
  (`lib/features/ai_credits/presentation/sheets/token_top_up_sheet.dart`). A 402 from an AI function
  becomes `InsufficientCreditsException` and the "Out of AI credits" dialog ("Not now" / "Get credits")
  in `insufficient_credits_paywall.dart`, which pushes `/buy-credits` (`BuyCreditsScreen`). Packs come
  from the RevenueCat `credits` offering; the dev debug build uses the Test Store key when one is set.
- Purchase: RevenueCat's webhook (`supabase/functions/revenuecat-webhook`) writes a `grant_purchase`
  ledger row whose `ref` is the RevenueCat event id.
- Jade: `/jade` (`AiCoachChatScreen`). Its banner is mounted nowhere on develop-next, so open it by
  deep link: `xcrun simctl openurl UDID "com.milkman.mealvanaendurance:///jade"`.

## Expected records (`RUNS/expected.md`)

| When | `token_wallets.balance` | newest `token_ledger` row | RevenueCat |
|---|---|---|---|
| After signup | the free allotment | `grant_free` | customer exists or not: record |
| After the Jade turn | − jade cost (if enforced) | `debit_usage`, ref `jade-chat` | — |
| After the first describe | − describe cost (if enforced) | `debit_usage`, ref `describe-meal` | — |
| After the drain (step 5) | 0 | `debit_usage`, ref `testing-wave-12` | — |
| After the purchase | the pack's credits | `grant_purchase`, ref = RC event id | one non-subscription purchase of the pack's product |
| After the second describe | pack − cost | `debit_usage` | — |

## Steps

1. Sign up (onboarding with plausible answers). Timeline → "+ Add Food" → Describe. The pill shows the
   balance; SQL agrees.
2. Tap the pill: the top-up sheet lists packs with store prices (never hardcoded dollar values). Close
   it without buying.
3. Jade by deep link. Spend, send one short question. SQL: was a `debit_usage` row written? Yes means
   dev enforces credits; no means it does not. If it does not, run step 4 for the numbers, skip steps
   5–8, and write one followup-test Finding: "dev does not enforce AI credits; the wall cannot be
   tested". Never change the secret.
4. Describe one meal (spend first) and log it. SQL ledger and balance.
5. The one write this ticket names: drain the run's own wallet to zero through the server's own RPC,
   on your account only, with the Management API SQL:
   `select public.debit_credits('<your user id>', <current balance>, 'debit_usage', 'testing-wave-12');`
   No other write, ever, on any other account.
6. Describe again (spend first). Expect the "Out of AI credits" dialog. "Not now": nothing logged,
   balance still 0. Repeat the send (no spend needed: the server refuses before the model) and choose
   "Get credits": `/buy-credits` opens with "Your Balance" 0 and the packs.
7. Buy the smallest pack through the Test Store. Expect "Credits added to your balance." (or the
   "credits are on their way" message if the webhook is slower). Within a minute: the ledger row, the
   balance, the RevenueCat purchase by API. "Restore" once: no second grant.
8. Describe again (spend first): it goes through and debits.
9. Developer / Tester section (seven taps on the Settings version text): the "$0.99 test pack" shows in
   the packs. Do not buy it.

## What counts as a Finding

- Pill, buy screen and `token_wallets` disagreeing at any step.
- A refused call with no dialog, a dialog with the wrong balance, a debit on a failed or refused call.
- A purchase with no grant, two grants for one purchase (the ledger has a unique index on the
  purchase ref), or a grant with no purchase.
- Copy that names subscriptions, Pro or a paywall.
- Console errors; look-around paths as followup-test Findings.

## Exit

- [ ] Findings filed with `node scripts/testing-wave/findings.mjs new 12 "<one line>" --round develop-2026-10 --kind bug|ssot-conflict|followup-test|idea --run RUN`, every field filled; `findings.mjs index --round develop-2026-10 --out "$TMPDIR/tw-12-index.md"` exits clean.
- [ ] Every account this run made is deleted in the app and marked `CRED update <address> --state deleted` (`delete-failed` if it failed). An address that never finished signup goes under "Leftover accounts" in `RUNS/notes.md` with its auth user id.
- [ ] Background processes stopped by PID, log stream stopped, app terminated, `LOCK release slot testing-wave-12`. The simulator is left for the wave lead to drop.
- [ ] Console redacted (runbook § 9.4); only `console-redacted.log` is kept.
- [ ] `findings/12-*.md` and `runs/12/` committed on the ticket branch, explicit paths only.
