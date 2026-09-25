# 15-004 · Ask Vana after a fresh sign-in started a second general conversation for Sep 24 and paid for a new opener

- kind: followup-test
- status: triaged
- ticket: 15
- run: w12-20260924T1712Z
- screen: Ask Vana sheet
- decision: 

**Steps.**
1. On an app with cleared data, sign in as an account that already has a general conversation today (test@test.com had `8507a520`, 14:50Z, from ticket 16's run on another simulator).
2. Tap Ask Vana on Food. Read vana_conversations and vana_calls.
3. Repeat on the same install after a second open, after midnight, and on an install that opened Ask Vana earlier the same day.

**Expected.**
One general conversation per person per day (the ambient conversation, VS-5 / mp-275 clause 1, as the code's `VanaAmbientConversation` describes it): the sheet continues today's conversation and does not spend a new opener.

**Actual.**
Seen once, not settled. At 17:17:17Z the sheet created `4d62c862` (general, context_day 2026-09-24) and streamed an opener (vana.opener.general, Haiku, $0.0216, debited). Conversations → Ask Vana then listed two "Quick question" rows for Sep 24 (12:17 PM and 9:50 AM). The earlier `8507a520` has context_day null, so the server may not count it as today's conversation (it may predate the day pointer, or the pointer lives only on the device that made it). Needs a clean repeat to say whether a sign-in on a new device should find today's conversation.

**Evidence.**
- runs/15/db-after.txt — `4d62c862` (context_day 2026-09-24) and `8507a520` (context_day null); the vana_calls row.
- runs/15/08-conversations-general.png — two Sep 24 rows.
- runs/15/06-vana-sheet.png — the opener.

**Decision quote.**
> 

**Triage.**

Picked for retest ticket 88 (Lee, 2026-09-25: every open follow-up test folded into the planned runs, cap of ten lifted for this pass).
