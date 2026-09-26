# 31-011 · Settings: Sign Out, then Cancel, and Delete Account, then Cancel

- kind: followup-test
- status: closed
- ticket: 31
- run: w11-20260924T1648Z
- screen: Settings
- decision: 

**Steps.**
1. Tap Sign Out, then Cancel: stay signed in, nothing changes.
2. Tap Delete Account, then Cancel: the account is untouched (check by SQL). Use a throwaway account for any step past Cancel.

**Expected.**
Cancel leaves the session and the account as they were.

**Actual.**
Not run.

**Evidence.**
- runs/31/05-settings.png: Sign Out and Delete Account

**Decision quote.**
> 

**Triage.**

Picked for retest ticket 93 (Lee, 2026-09-25: every open follow-up test folded into the planned runs, cap of ten lifted for this pass).
Moved to retest ticket 119 when 93 was split (Lee, 2026-09-25).

Run by retest ticket 119 (run w36-20260926T0031Z, build 72d3723e): pass; both Cancels leave the session and rows as they were.
