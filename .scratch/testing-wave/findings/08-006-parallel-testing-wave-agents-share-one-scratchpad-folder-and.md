# 08-006 · Parallel testing-wave agents share one scratchpad folder, and ticket 09's helper scripts overwrote ticket 08's mid-run, one pointing at the other agent's simulator

- kind: bug
- status: closed
- ticket: 08
- run: w7-20260924T1216Z
- screen: none
- decision: 

**Steps.**
1. Tickets 08 and 09 ran at once in wave 7, each an agent session with the same scratchpad folder (`/private/tmp/claude-501/…/scratchpad`).
2. Ticket 08 wrote `ui.py` (idb helper with its UDID), `rc.sh`, `sql.sh` and `pw` there at 12:21–12:25Z.
3. Ticket 09 wrote files with the same names there at 12:28–12:31Z.

**Expected.**
Each agent's scratch files are its own; nothing one agent runs can touch the other's simulator or account.

**Actual.**
Ticket 09's files replaced ticket 08's. From about 12:28Z, 08's `ui.py` targeted 09's simulator (UDID 4E0B6999-…); 08's `ui.py ls` at 12:35:41Z read 09's screen and its one `tap "Back"` found nothing, so no tap landed on 09's device. 08's `rc.sh` now asked RevenueCat for 09's user id concatenated with 08's (`resource_missing`), which looks like a vanished customer; this is likely also what ticket 06 saw as its "scratch curl helper answered resource_missing" note. 08's `pw` file was overwritten with 09's password; 08's password survived only because it was already in the credentials file. Debugging it printed a `bash -x` trace of 09's `rc.sh`, which put the RevenueCat secret key into this agent's transcript (not into any file in the repo); rotating that key is Lee's call. 08 moved its helpers to `scratchpad/t08/` at 12:36Z and checked everything after that against its own UDID. Fix idea: the runbook or the agent prompt names a per-ticket scratch folder (`$TMPDIR/testing-wave-NN/`), and helpers take the UDID as an argument, never a constant.

**Evidence.**
- runs/08/notes.md (12:35–12:36Z entries)
- runs/08/revenuecat-D-1235-failed-read-1.txt, runs/08/revenuecat-D-1235-failed-read-2.txt (the `resource_missing` answers)

**Decision quote.**
> 

**Triage.**

Closed (Lee, 2026-09-25): each ticket has its own scratch folder since wave 8 (IMPROVEMENTS #26), and waves 8-18 ran with no overlap.
