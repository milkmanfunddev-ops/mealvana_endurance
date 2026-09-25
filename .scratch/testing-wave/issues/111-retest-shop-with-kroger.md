# 111: Retest: Shop with Kroger

**Status:** done (wave 30, 2026-09-25)
**Blocked by:** none.
**Pair with:** 110 (the Shopping tab, same account). This run connects and disconnects test@test.com's Kroger connection and removes its production row (22-005); 110 ticks rows and makes and deletes its own hand-made lists. Read the list for 22-003 once, with its time in `notes.md`, and treat 110's lists as expected.
**Next:** `/implement-lee testing-wave`
**Model:** opus
**Split from:** 90 and 109 (Lee, 2026-09-25: about ten checks per run).

**What to build:** A retest run. Re-run the steps of each Finding below on the testing build (the commit in `.scratch/testing-wave/app-build.json`), check the fix holds, and give each a verdict. Then run the follow-up tests listed. Nothing is fixed during the run.

**Findings to retest:** 20-008 21-002 21-003 21-010 22-003 22-005. Read each file in `.scratch/testing-wave/findings/` first: its Steps are the retest, and its Triage line names the fix ticket (read that ticket's file for what changed).

**Follow-up tests to run:** 21-005 (Kroger sheet: tap Cancel on the kroger.com system alert and close the sign-in sheet with X), 21-006 (Kroger sheet: wrong password, then the right one), 21-007 (Kroger screen: connect with the network cut, and double-tap Connect Kroger), 21-008 (Kroger screen: the connection shows connected on an access token expired a week, prove the refresh path), 21-009 (Kroger screen: allow location on Shop with Kroger and see whether the delivery area fills), 22-004 (Kroger screen: Set delivery ZIP and Match all while not connected, on certification). Each Finding file holds the steps; read it first. Give each a verdict in `RUNS/verdicts.md` like the retests.

**Setup:** test@test.com. The Kroger screen half of 22-003, and 22-004, need a Kroger certification shopper login (IMPROVEMENTS #52). Without one, check the Shopping tab half of 22-003 and mark the Kroger half and 22-004 not run. 20-008 is read from the edge log of the Shopping tab opens. Never Place Order.

**22-005 (moved here from ticket 109):** a leftover Kroger connection from the other environment shows and can be removed; test@test.com's production row, if it is still there. It needs the screen before any connect in this run, and its removal changes what the connect checks start from, so it runs in this ticket and never beside it.

**Order:** on the fresh app data, the first Shop with Kroger open reads the location prompt's reason (21-002), then Allow (21-009, then location off in iOS Settings). Then 22-005 before any connect, 22-004 while not connected, 20-008 and 22-003, then the connect paths (21-003, 21-005, 21-006, 21-007, 21-008), and 21-010 (Disconnect asks first) last.

**Decisions:** the ones each Finding cites.

**Touches:** nothing (read only), except the accounts the run creates and deletes, and test@test.com's Kroger connection (22-005 and the connect checks).

- [ ] Runs by the runbook: a slot taken and released, the console saved to the run folder, a look-around on every screen visited, every new problem written as a Finding and nothing fixed.
- [ ] `RUNS/verdicts.md` has one row per Finding above: id, pass | fail | not run, the evidence (paths under `runs/111/`), and for a fail the new bug Finding's id. A fail is filed as a new bug Finding that names the old id in its Steps. The run does not edit the old Finding files: the wave lead closes the passes from this table.
- [ ] Each follow-up test above is run and gets a row in `verdicts.md`. A problem it finds is a new Finding.
- [ ] Every account the run made is deleted at the end (runbook step 9) unless the setup says to keep it.

Next: /implement-lee testing-wave
