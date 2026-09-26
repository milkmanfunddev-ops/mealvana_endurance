# 110-007 · Share on an empty list does nothing and says nothing

- kind: bug
- status: triaged
- ticket: 110
- run: w30-20260925T2103Z
- screen: Food (Shopping sub-tab)
- decision: 

**Steps.**
Follow-up 19-010 step 5. Open an empty hand-made list and tap the header's Share icon (21:19:2xZ).

**Expected.**
Either the icon is hidden or disabled on an empty list, or a message says there is nothing to share.

**Actual.**
No sheet, no message; the tap is silently ignored (`shareText` returns '' for an empty list).

**Evidence.**
- runs/110/49-share-empty-list.png — after the tap.

**Decision quote.**
> 

**Triage.**

Fix ticket 133, Shopping lists and Kroger (Lee, 2026-09-26). Closed by the retest after it merges. Record: `triage-20260926.md`.
