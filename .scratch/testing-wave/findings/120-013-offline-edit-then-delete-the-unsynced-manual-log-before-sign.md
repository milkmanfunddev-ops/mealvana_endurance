# 120-013 · Offline, edit then delete the unsynced Manual log before signing out: does the next sign-in send the edit, or resurrect it?

- kind: followup-test
- status: open
- ticket: 120
- run: w39-20260926T1013Z
- screen: Timeline
- decision: 

**Steps.**
1. Offline, Manual log a meal, then edit it, then (second run) delete it.
2. Sign out offline, sign back in online.

**Expected.**
Dev ends with the edited meal, or with no meal after the delete; a deleted unsynced log never comes back.

**Actual.**


**Evidence.**
- runs/120/local-dirty-02-offline.txt (an unsynced Manual log)

**Decision quote.**
> 

**Triage.**

