# 112-016 · Log a Meal Recent: a fresh install offline, and two logs with one name but different items

- kind: followup-test
- status: open
- ticket: 112
- run: w34-20260925T2320Z
- screen: Log a Meal (Recent)
- decision: 

**Steps.**
1. Clear the app, sign in, cut the network before Recent loads, open Log a Meal → Recent (the provider waits up to 15 s for sync).
2. Log two different meals under the same name (Manual), open Recent: which one does the row re-log?
3. Re-log a Recent meal whose source has a photo.

**Expected.**
Spinner then a clear empty/offline state, not an endless spinner; the row states which log it copies; the photo is or is not copied, by a stated rule.

**Actual.**


**Evidence.**
- runs/112/08-recent-tab.png

**Decision quote.**
> 

**Triage.**
