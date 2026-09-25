# 88-006 · Browse's Recents re-orders a few seconds after it opens, so a tap lands on a different meal

- kind: bug
- status: triaged
- ticket: 88
- run: w29-20260925T1949Z
- screen: Browse meals
- decision: 

**Steps.**
1. Conversation `d8efbdb3` > plus > Browse meals (20:01:46Z). Read the Recents row at 20:01:50Z: Injera with shiro wot first, Käsespätzle second.
2. Tap "+" on the first Recents card (20:01:59Z).

**Expected.**
Recents is stable once shown, and the tap adds the meal that was under the finger.

**Actual.**
By the tap the Recents row had changed to "Rice, black beans & roasted plantain" and "Rice, black beans, guac & hot sauce", and the tap added Rice, black beans & roasted plantain. The edge log shows `recent_meals` taking 1.8–5.2 s, so the first paint is replaced when the call returns. Seen again in 0401b3d8 and 449da56d (Recents content differs per open).

**Evidence.**
- runs/88/31-18-009-browse-from-d8efbdb3.png: Recents with Injera first.
- runs/88/32-18-009-add-injera-1s.png: 9 s later, plantain first and added.
- runs/88/edge-02-18-008-double-tap.txt: recent_meals 5160 ms.

**Decision quote.**
> 

**Triage.**

Fix ticket 128 (Lee, 2026-09-25). Closed by the retest after it merges.
