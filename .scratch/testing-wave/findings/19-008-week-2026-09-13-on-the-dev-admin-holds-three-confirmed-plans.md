# 19-008 · Week 2026-09-13 on the dev admin holds three confirmed plans and a draft

- kind: followup-test
- status: wontfix
- ticket: 19
- run: w11-20260924T1647Z
- screen: none
- decision: 

**Steps.**
1. SELECT id, status, week_start FROM meal_plans WHERE user_id = test@test.com's id AND week_start = '2026-09-13'.
2. Find out whether these rows predate the rule that confirming archives every other plan for the week, or whether some path (Vana, a retry, the old Confirm) still confirms without archiving.
3. Open the Plan and Shopping tabs for that week (and Previous lists) and see which plan and list the app shows.

**Expected.**
One confirmed plan per week; the others archived.

**Actual.**
Seen while reading the account's state for this run, not caused by it: plans f2c0bc78, 4e29032c and 6e167344 are all `confirmed` for week 2026-09-13 (confirmed 09-16 and 09-17), and fc9687ff is a `draft` for that week. Not ruled on here, since the rows may be older than the rule.

**Evidence.**
- runs/19/db-00-before.txt: the meal_plans section.

**Decision quote.**
> 

**Triage.**

Closed (Lee, 2026-09-25, follow-up sort): the rows predate the one-confirmed-plan-per-week rule (mp-241); nothing to test.
