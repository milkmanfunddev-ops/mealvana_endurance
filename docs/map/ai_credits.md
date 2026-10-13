# AI credits (tokens)

domain: 9 Account and app · folder: `lib/features/ai_credits/` (12 files)

AI actions cost one credit each: describing a meal, analysing a meal photo, a formula coach insight. Every account
gets 50 free credits a month. The phone calls them "tokens" on the meal screen and "credits" on the dialog and
purchase page.

- **See the balance.** The fortune-cookie pill on "Log a Meal" (pink under three); the price sits inside the
  "Analyze" button.
- **Top up.** Tap the pill: "Refill tokens" ("You're out of tokens" at zero), "Each analysis costs 1 token. Top up
  to keep going.", packs "50 tokens · Starter" and "250 tokens · Best value" with store prices → "You're topped
  up!". Buying needs a signed-in account; an anonymous athlete is sent to create one. "Your purchase went through,
  but the tokens are still on their way…" / "That didn't go through. Nothing was charged."
- **At zero.** "Out of AI credits · You've used all your AI credits. Get more to keep using AI features." → "Not
  now" / "Get credits" → "AI Credits" (route `/buy-credits`: "Your Balance", "Credit Packs", "Restore", "How credits
  work"). In builds where credits are switched off that page reads "AI Credits — Coming Soon" while Describe and
  photo still work.
- **Tester pack.** A $0.99 one-credit pack appears only on devices marked internal (Settings, seven taps on the
  version).

Charging happens on the server (`ensure-credits` grants, the AI functions debit, nothing is charged on failure)
and only when the server has credits enforced. Tables, read-only from the phone: `token_wallets` (balance, free
period; realtime), `token_ledger`, `ai_usage`. Purchases go through RevenueCat (offering `credits`) and the
`revenuecat-webhook` credits the wallet; the app polls, listens, and refreshes on foreground. Reuse:
`credits_controller`, `purchase_controller` + `revenue_cat_service`, `token_pill`, `token_cost_chip` / `token_cost_tag`,
`token_top_up_sheet`, `insufficient_credits_paywall`, `domain/credit_packs.dart`. Dead: `credit_balance_chip.dart`.
qa: only `spec/design/vana/orientation-tools.md`, `voice.md` mention credits. ops: bug `cookie-balance-stale-on-auth-change`;
decisions `anonymous-user-at-the-paywall`, `paywall-offer-mode-vs-hard-gate`, `existing-user-grandfathering-before-any-paywall`.
Related: `meal_logging.md`, `formula_kit.md`.
