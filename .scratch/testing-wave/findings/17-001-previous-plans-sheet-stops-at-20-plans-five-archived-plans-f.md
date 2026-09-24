# 17-001 · Previous plans sheet stops at 20 plans: five archived plans from the week of Aug 23 never appear

- kind: bug
- status: open
- ticket: 17
- run: w12-20260924T1712Z
- screen: Previous plans (sheet from the Plan tab's ⋮)
- decision: 

**Steps.**
1. Sign in as test@test.com (26 plans with `is_deleted = false`).
2. Food → Plan → ⋮ beside "Sep 20 – Sep 26" → Previous plans.
3. Scroll to the bottom of the sheet.
4. Compare the rows with `meal_plans` for the account.

**Expected.**
Every archived and confirmed plan with meals, other than the one on the Plan tab: 21 plans, the oldest being the week of Aug 23 – Aug 29.

**Actual.**
17 rows; the last is "Aug 30 – Sep 5 · 3 meals". Five archived plans from the week of 2026-08-23 with meals never appear: c95e286f (3), d5b89888 (4), 40b20856 (3), d63f7220 (3), 83eb5608 (3). The server's `listPlans` (`supabase/functions/_shared/vana/plan.ts`) reads `.limit(20)` over every non-deleted plan, drafts and empty plans included, and the client then drops the current plan and plans with no meals, so the sheet shows 17 of the 20 and nothing past them. There is no "show more" and no paging. The athlete can never reach those plans. The two plans that store `days` (d5b89888, 83eb5608) are among the missing ones, so the view's handling of days could not be checked.

**Evidence.**
- runs/17/db-sheet-vs-sql.txt — the sheet's rows beside every plan by SQL.
- runs/17/09-previous-plans-sheet-bottom.png — the bottom of the sheet, ending at Aug 30.
- runs/17/db-plans-before.json — all 40 of the account's plans.
- runs/17/edge-function_logs.txt — `list_plans` calls.

**Decision quote.**
> 

**Triage.**
