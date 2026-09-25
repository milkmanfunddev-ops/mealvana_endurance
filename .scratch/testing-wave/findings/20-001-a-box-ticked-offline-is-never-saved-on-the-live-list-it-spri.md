# 20-001 · A box ticked offline is never saved: on the live list it springs back unticked, in the offline copy it shows ticked but is gone after a restart or once the network returns

- kind: bug
- status: triaged
- ticket: 20
- run: w10-20260924T1614Z
- screen: Food (Shopping sub-tab)
- decision: 

**Steps.**
1. Signed in as test@test.com, list 03c4c52b (15 rows) on Food > Shopping. Online, tick Avocado, Carrot and Wholewheat pasta (16:18:44Z): the database has all three within a second.
2. Cut this app's network (per-app `connect()` cut, runs/20/notes.md "Offline method"), 16:22:07Z; wait 20 s.
3. Case A, live list still on screen: tick Beets and Bell pepper, untick Avocado (16:22:32-34Z).
4. Case B, cold restart offline (16:23:09Z), Food > Shopping shows the plan's offline copy; tick Beets and Bell pepper (16:23:5xZ); cold restart offline again (16:24:10Z) and open Shopping.
5. Case C, cold restart offline (16:25:46Z), tick Cauliflower in the offline copy, then bring the network back without a restart (16:26:38Z) and wait 30 s.
6. After B and after C: SQL on shopping_items and the meal_plans.shopping mirror; edge logs for update_shopping_item.

**Expected.**
Story 62 of the testing-wave spec and the ticket: the items the athlete checks off stay checked after a restart and after going offline, and when the network comes back the dev database agrees. CLAUDE.md's offline-first rule: "local write first with upload-state tracking".

**Actual.**
- A: each tap sent `update_shopping_item`, which failed with "Network is unreachable"; the three boxes were back as they were by the first screenshot and stayed that way. Nothing tells the athlete (20-002).
- B: the offline copy took the ticks on screen, but after the offline restart Beets and Bell pepper were unticked again. The code confirms it: in the offline copy a tick changes only the screen state ("the offline mirror has no ids to write to", `ShoppingListController._toggle`).
- C: 5 s after the network came back the tab swapped the offline copy for the server's list, and Cauliflower's tick was gone.
- Database after B and after C: 15 rows, 15 names, 3 checked (the three online ticks), none of the offline ones; the mirror agrees. The edge logs show exactly six `update_shopping_item` calls for the run: the three online ticks and the three unticks that restored the account. Nothing was queued or replayed on reconnect.
- The ticks made online survived every restart, online and offline (the offline copy carries them), and nothing was lost or doubled. The failure is only for changes made while offline, which is the in-store case the ticket is about.

**Evidence.**
- runs/20/db-after-online-ticks.txt — 3 checked at 16:18:51Z.
- runs/20/12-offline-ticks-0s.png — right after the three offline taps on the live list: unchanged.
- runs/20/13-offline-ticks-8s.png — 8 s later: unchanged, no message.
- runs/20/console-excerpts.log — section A: three vana-action network errors at 11:22:32-34 local (16:22Z).
- runs/20/17-offline-mirror-two-ticked.png — offline copy with Beets and Bell pepper ticked.
- runs/20/18-offline-second-cold-restart-shopping.png — after the offline restart both are unticked.
- runs/20/20-offline-mirror-cauliflower-ticked.png — Cauliflower ticked offline.
- runs/20/22-reconnect-live-30s.png — 30 s after the network returned: Cauliflower unticked.
- runs/20/db-after-back-online.txt — 3 checked, none of the offline ticks.
- runs/20/db-after-reconnect-live.txt — Cauliflower `checked = false`.
- runs/20/edge-function-logs.txt — six update_shopping_item calls, none after 16:18:45Z until the restore at 16:27:39Z.

**Decision quote.**
> 

**Triage.**
Fix ticket 36 (Lee, 2026-09-25). Closed by the retest after it merges.
