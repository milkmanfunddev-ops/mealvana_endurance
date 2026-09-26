# 31-010 · Notification permission prompt: first shown on the second launch; test Allow and what it writes

- kind: followup-test
- status: closed
- ticket: 31
- run: w11-20260924T1648Z
- screen: Timeline
- decision: 

**Steps.**
1. Clear the app's data, log in (first launch: no notification prompt seen this run).
2. Terminate and launch: the iOS prompt "Endurance Dev Would Like to Send You Notifications" shows.
3. Tap Allow on one run and Don't Allow on another; read public.users.notifications_enabled by SQL after each.

**Expected.**
The prompt comes at a moment the app chose, and the stored notification setting matches the answer.

**Actual.**
Not run fully. This run tapped Don't Allow; notifications_enabled stayed false (db-after-signout.txt).

**Evidence.**
- runs/31/10-relaunch.png: the prompt on the second launch
- runs/31/db-after-signout.txt: notifications_enabled false

**Decision quote.**
> 

**Triage.**

Picked for retest ticket 109 (Lee, 2026-09-25: every open follow-up test folded into the planned runs, cap of ten lifted for this pass).
Moved to retest ticket 125 when 109 was split (Lee, 2026-09-25).

Run by retest ticket 125 (run w37-20260926T0221Z, build 72d3723e): fail, carried by new bug Finding 125-004 (the prompt comes on the second launch, not at sign-in, and Allow writes nothing to `users.notifications_enabled`).
