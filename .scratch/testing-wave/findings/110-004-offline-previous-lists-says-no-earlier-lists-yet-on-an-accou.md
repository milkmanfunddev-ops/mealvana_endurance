# 110-004 · Offline, Previous lists says No earlier lists yet on an account with seven earlier lists

- kind: bug
- status: triaged
- ticket: 110
- run: w30-20260925T2103Z
- screen: Food (Shopping sub-tab) > Previous lists, offline
- decision: 

**Steps.**
Follow-up 20-004. Offline cold restart, Food > Shopping (offline copy), ⋯ > Previous lists (21:11:31Z).

**Expected.**
Previous lists says it needs the network (or shows what it last had), since the list read failed.

**Actual.**
The sheet reads "No earlier lists yet." The account has seven earlier lists. An athlete offline in the store is told their lists are gone.

**Evidence.**
- runs/110/26-offline-previous-lists.png — the sheet offline.
- runs/110/08-previous-lists.png — the same sheet online.

**Decision quote.**
> 

**Triage.**

Fix ticket 133, Shopping lists and Kroger (Lee, 2026-09-26). Closed by the retest after it merges. Record: `triage-20260926.md`.
