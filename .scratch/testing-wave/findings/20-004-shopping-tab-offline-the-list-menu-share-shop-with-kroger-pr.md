# 20-004 · Shopping tab offline: the list menu, Share, Shop with Kroger, Previous lists, Add item, and a row's count

- kind: followup-test
- status: triaged
- ticket: 20
- run: w10-20260924T1614Z
- screen: Food (Shopping sub-tab), offline copy
- decision: 

**Steps.**
1. Cut the app's network with the per-app method in runs/20/notes.md, cold restart, open Food > Shopping (the offline copy, headed "Shopping list").
2. Try each control this run did not: the list's ⋯ menu (rename, new list, delete, Previous lists), Share, Shop with Kroger, adding an item, a row with a meal count (Farro, 2), and a hidden "have it" row's Add back.
3. Read the console for each.

**Expected.**
Each either works offline or says it needs the network; none leaves a half-done state, and Share sends the plain-text list (mp-244).

**Actual.**


**Evidence.**
- runs/20/16-offline-shopping-13s.png — the offline copy these controls sit on.

**Decision quote.**
> 

**Triage.**

Picked for retest ticket 90 (Lee, 2026-09-25: every open follow-up test folded into the planned runs, cap of ten lifted for this pass).
Moved to retest ticket 110 when 90 was split (Lee, 2026-09-25).
