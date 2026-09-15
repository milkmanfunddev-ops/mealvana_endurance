# 20: The monthly Allowance and the top-up sheet

**Status:** ready-for-agent
**Blocked by:** 18 (touches supabase/functions/revenuecat-webhook/index.ts).
**Next:** `/implement-lee mealplanning`

**What to build:** A subscriber's wallet is topped up on every renewal and a trial gets the full grant on day one; when it runs out, the button that would debit shows the top-up sheet with the allowance, the renewal date and the two packs, and the app never locks. The webhook grants the monthly Allowance into the existing wallet on initial purchase and renewal (monthly on the anniversary for annual plans); Allowance is spent before pack credits and does not roll over; one shared 402 handler raises the sheet from every debiting call, including the Vana composer with a line above it.

**Decisions:** mp-281, mp-282; approved as mp-298.

**Touches:** supabase/functions/revenuecat-webhook/index.ts, supabase/functions/_shared/ai/credits.ts, supabase/functions/_shared/ai/usage.ts, lib/features/ai_credits/data/credits_repository.dart, lib/features/ai_credits/domain/credit_wallet.dart, lib/features/ai_credits/presentation/sheets/token_top_up_sheet.dart, lib/features/ai_credits/presentation/insufficient_credits_paywall.dart, lib/features/meal_planning/presentation/screens/vana_chat_screen.dart, lib/features/meal_logging/presentation/screens, lib/features/ai_coach/presentation/providers/ai_coach_chat_controller.dart, test/features/ai_credits

- [ ] A renewal event grants the Allowance; the trial's initial purchase grants it in full; a cancelled trial forfeits the remainder and pack credits are untouched (webhook seam).
- [ ] Debits take Allowance first, then packs; unused Allowance does not roll over (wallet tests).
- [ ] One handler for 402 in the shared layer raises the top-up sheet showing allowance, renewal date and packs; every current call site uses it.
- [ ] The Vana composer's send raises the sheet and shows one line above the composer; Vana never says "out of credits" in a message.
- [ ] The Allowance number is set in this ticket and recorded on mp-281's Details.

Next: /implement-lee mealplanning
