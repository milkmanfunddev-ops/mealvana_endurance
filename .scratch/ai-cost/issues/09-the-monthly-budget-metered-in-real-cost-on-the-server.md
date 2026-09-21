# 09: The monthly budget, metered in real cost on the server

**Status:** ready-for-agent
**Blocked by:** 02 (touches supabase/functions/describe-meal/index.ts), 04 (touches supabase/functions/vana-chat/index.ts), 05 (touches supabase/migrations), 08 (touches supabase/functions/describe-meal/index.ts).
**Next:** `/implement-lee ai-cost`
**Model:** fable

**What to build:** Every account has $4.00 of AI a month, the trial week $1.00, and the packs add $1.00 and $5.00 at today's prices. Every call draws it down, openers included. A conversation that crosses the line finishes; the next call is refused with the top-up response. Credits already in a wallet become budget at 2 cents each. The old free grant of 20 credits ends when the paywall opens.

**Decisions:** mp-430, mp-436, mp-282; approved as mp-474.

**Touches:** supabase/migrations, supabase/functions/_shared/ai/credits.ts, supabase/functions/_shared/ai/allowance.ts, supabase/functions/_shared/ai/usage.ts, supabase/functions/_shared/ai/wallet_rules.test.ts, supabase/functions/vana-chat/index.ts, supabase/functions/_shared/vana/actions.ts, supabase/functions/describe-meal/index.ts, supabase/functions/analyze-meal-photo/index.ts, supabase/functions/revenuecat-webhook

- [ ] The wallet holds whole micro-dollars. A call reserves an estimate for its kind in one atomic statement that also checks the balance; on finish the reservation becomes the real cost; a failed call gets it back.
- [ ] Real cost is the gateway's own charge, or logged tokens priced from one table when the gateway reports none. No test asserts a price.
- [ ] Wallet seam, real SQL on dev in a rolled-back transaction: settle to real cost; two parallel reservations where one fits; a failed call refunded; a call that finishes over the budget and the next refused; monthly budget spent before bought budget; 50 old credits become $1.00.
- [ ] A database error refuses the call (shared credits test).
- [ ] Openers draw the budget. Every debiting call is covered: chat, openers, the pantry photo, the described meal, the meal photo.
- [ ] The monthly grant is $4.00, the trial week $1.00, the packs $1.00 and $5.00; a transferred subscription leaves the allowance where it was granted; the free grant of 20 credits ends at the paywall date.
- [ ] The client is sent a share, a refill date and bought extra, never a dollar figure.
- [ ] Open question carried from the spec, to answer in this ticket or raise on the page: a sandbox purchase reaching production must not grant a real budget.

Next: /implement-lee ai-cost
