# 08-024 · A meal logged on another device (ticket 02, 11:10Z) never showed on this device's Timeline during the same minutes

- kind: followup-test
- status: open
- ticket: 08
- run: w1-20261007T1105Z
- screen: Timeline (tab 0), test@test.com
- decision: 

**Steps.**
1. Ticket 02 logs a meal on test@test.com at 11:10:15Z on wave-pool-2 (meal_logs row 40600e48-…).
2. Ticket 08 is signed in as test@test.com on wave-pool-3 from 11:09:26Z, on the Timeline, Events and Learn tabs until 11:12Z, then an offline cold start from the local database.
3. Ticket 08's Timeline never showed the breakfast card (runs/08/notes.md, part B).

**Expected.**
The rule for cross-device visibility is not written down for meal logs. The retest decides it: with two simulators signed in as one account, log a meal on one, then on the other (a) pull-to-refresh or re-open the Timeline, (b) relaunch, (c) wait N minutes; record when, if ever, the card appears and which action brought it.

**Actual.**
Filed by the wave lead from runs/08/notes.md ("Ticket 02's meal log on test@test.com did not appear on my Timeline during the run (not a Finding; timing)"). 08's Timeline was open from 11:09:26Z, the meal landed on the server at 11:10:15Z, and 08's offline relaunch at 11:11:31Z read the local database, which did not have it. Whether a foreground Timeline is expected to pick up another device's write within two minutes is an open question for the retest, not a bug yet.

**Evidence.**
- runs/08/notes.md — part B, the line quoted above
- runs/02/notes.md — the 11:10:15Z log and the SQL row
- runs/02/db-after.txt — the meal_logs row

**Decision quote.**
> 

**Triage.**

