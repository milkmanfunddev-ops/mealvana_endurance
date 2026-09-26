# 100: Retest the fixes of 94 to 99

**Status:** in-progress (wave 39, 2026-09-26)
**Blocked by:** 101.
**Next:** `/implement-lee testing-wave`
**Model:** opus

**What to build:** A retest run on a build that carries tickets 94-99. The wave lead rebuilds the testing app first (RUNBOOK, wave lead step 2). Re-run each Finding's steps, and check each fix ticket's behaviour as its file describes it.

**Findings to retest:** 32-007, 02-005, 11-002, 19-002, 16-006, 18-007, 17-004, 17-007, 24-007, 28-004, 29-002. Also ticket 94's items 1, 2, 4 and 5 as checks (no Finding of their own: the Swap screen list length, the plan reveal nudge after declining training apps, Settings' tile text; item 4 by reading the console on a launch).

**Follow-up tests to run:** none.

**Setup:** New accounts for 32-007 (signup), 02-005 (delete, then read RevenueCat by API) and 11-002 (`seed-codes.mjs seed`, then `own` for two coach codes of one coach). test@test.com for the rest. 29-002 needs the dev account's FinalSurge feed to send a completed workout: read the day's payloads in the console. When none is completed, mark it not run.

**Decisions:** the ones each Finding and fix ticket cite.

**Touches:** nothing (read only), except the accounts the run creates and deletes.

- [ ] Runs by the runbook: a slot taken and released, the console saved, a look-around on every screen visited, every new problem written as a Finding and nothing fixed.
- [ ] `RUNS/verdicts.md` has one row per Finding and check above: pass | fail | not run, evidence, and for a fail the new Finding's id. The run does not edit old Finding files; the lead closes the passes.
- [ ] Every account the run made is deleted at the end.

Next: /implement-lee testing-wave
