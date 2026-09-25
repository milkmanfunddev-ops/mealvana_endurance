# 31-003 · First tap on the Settings gear right after dismissing the What's New sheet did nothing

- kind: followup-test
- status: wontfix
- ticket: 31
- run: w11-20260924T1648Z
- screen: Timeline
- decision: 

**Steps.**
1. Log in; the "New in Mealvana: Shake to tell us what's wrong" sheet shows over Timeline.
2. Tap Got it, then about 2 s later tap the Settings gear.
3. Repeat with shorter and longer gaps, and with a swipe-down dismiss.

**Expected.**
The first gear tap opens Settings.

**Actual.**
Seen once at 16:51 UTC: the first gear tap did nothing and Timeline stayed; a second tap opened Settings. Not repeated, so the cause (tap swallowed during the sheet's dismiss, or an idb tap timing issue) is unknown.

**Evidence.**
- runs/31/04-after-login.png: the sheet over Timeline before Got it

**Decision quote.**
> 

**Triage.**

Closed (Lee, 2026-09-25, follow-up sort): seen once and not repeated; every run watches for it and it reopens if seen again.
