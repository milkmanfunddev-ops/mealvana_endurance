# 89-011 · Previous plans offline spins 35 to 40 s before its failed text, and Pull down to try again does nothing

- kind: bug
- status: open
- ticket: 89
- run: w29-20260925T1950Z
- screen: Previous plans (sheet)
- decision: 

**Steps.**
1. test@test.com. Cut the app's network (netcut, 20:22:03Z). Plan ⋮ > Previous plans (20:22:04Z).
2. Wait. Then restore the network (20:22:46Z) and pull down on the sheet, as its text says.

**Expected.**
Offline, the failed text shows within a few seconds, since every connect fails at once. "Pull down to try again" reloads the list.

**Actual.**
The spinner showed for 35-40 s while the console logged "Network error calling vana-action" every ~6 s (Riverpod retrying `previousPlansProvider`); "Couldn't load earlier plans. Pull down to try again." appeared by 20:22:45Z. Back online, two slow pull-downs did nothing: the sheet has no RefreshIndicator (previous_plans_sheet.dart), and a fast pull dismisses the sheet. Closing and reopening the sheet loaded the list at once.

**Evidence.**
- runs/89/81-17-006-prev-plans-offline.png: spinner at 1 s.
- runs/89/82-17-006-prev-plans-offline-12s.png: spinner at ~20 s.
- runs/89/83-17-006-prev-plans-offline-60s.png: the failed text at ~40 s.
- runs/89/86-17-006-pull-down-2.png: after pulling down online, unchanged.
- runs/89/87-17-006-reopened-online.png: reopened, loaded.
- runs/89/console-redacted.log: 15:22:05-15:22:37 local, repeated VANA_TRANSPORT network errors.

**Decision quote.**
> 

**Triage.**
