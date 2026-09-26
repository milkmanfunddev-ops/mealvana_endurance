# 113-008 · Manual and Edit Meal accept 99,999 kcal, 1000 g carbs and a time eaten later today with no check or warning

- kind: idea
- status: wontfix
- ticket: 113
- run: w40-20260926T1051Z
- screen: Log a Meal → Manual tab; Edit Meal
- decision: 

**Steps.**
Product question (how should the app behave?), from follow-ups 25-002 and 27-005.

1. Manual tab: "W40-113 Huge values", 99999 kcal, 1000 g carbs, .5 g protein, 12.345 g fat, Snack, time 3:15 AM → Save (10:57:36Z). Saved exactly as typed (row 8c8b2645); the day's intake jumps by 99,999 kcal with no question asked.
2. Edit Meal: Time eaten changed to 11:45 PM while it was 6:12 AM (11:12:20Z). Saved as eaten_at 2026-09-27 04:45Z with log_date 2026-09-26: a meal "eaten" 17 hours in the future is accepted.

Question for Lee: should the logging forms confirm or cap values far outside a meal (say over 5,000 kcal or 500 g of one macro), and refuse or confirm a time eaten later than now? Leading dot ".5" and three-decimal grams saved fine and need nothing.

**Expected.**
A decision on sanity limits for manual meal values and future eaten times.

**Actual.**
No limit or warning on either.

**Evidence.**
- runs/113/19-huge-filled.png
- runs/113/28-timeline-after-manual.png (99,999 kcal row)
- runs/113/db-after-manual.txt (row 8c8b2645 as typed)
- runs/113/69-edit-time-1145pm.png
- runs/113/db-after-edit-nomacros.txt (eaten_at 2026-09-27 04:45Z)

**Decision quote.**
> 

**Triage.**

Won't fix (Lee, 2026-09-26): no limits on values or eaten times.
