# 86-002 · Local database holds this week's plan 173cebb2 as archived while dev holds it as draft

- kind: followup-test
- status: triaged
- ticket: 86
- run: w25-20260925T1324Z
- screen: Plan tab
- decision: 

**Steps.**
1. Log in as test@test.com on a phone that already held its rows (leftover data).
2. Once the first sync settles (about 80 s), read the local `meal_plans` rows for week 2026-09-20 and the
   same plans on dev.
3. Find out which side is right for plan 173cebb2 (created 2026-09-24 21:09Z, never confirmed), and whether
   the Plan tab, Previous plans or the Vana planning chat shows it as a draft to resume.

**Expected.**
The local status of each plan matches dev's once sync has run, or the difference is deliberate and
written down (for example, a local rule that archives a stale draft when the week has a confirmed plan).

**Actual.**
At 13:27:42Z the local copy held 173cebb2 as `archived` and be6abf2f as `confirmed`; dev holds 173cebb2 as
`draft` (confirmed_at null). Seen in this run's database reads only, not on a screen; not the subject of
ticket 86.

**Evidence.**
- runs/86/local-plans-week0920-1328.txt
- runs/86/db-test-week0920-plans.txt

**Decision quote.**
> 

**Triage.**
Picked for retest ticket 107 (Lee, 2026-09-25).
