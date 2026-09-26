# 118: Retest: accessibility, layout, TrainingPeaks refusals and the dev button

**Status:** in-progress (wave 36, 2026-09-26)
**Blocked by:** none.
**Pair with:** 119 (Profile & Preferences, same account): 21-004 and 64-001 may leave test@test.com's TrainingPeaks connection marked as needing reconnection, which 119's 31-006 chips and 31-013 Connected Apps read. 122: this run's 11-005 redeems DEVCOACH30 on a new athlete, a pending pairing to test@test.com as coach; 122 accepts and declines pairings (11-009). Each checks only its own athletes' pairings.
**Next:** `/implement-lee testing-wave`
**Model:** opus
**Split from:** 93 (Lee, 2026-09-25: about ten checks per run).

**What to build:** A retest run. Re-run the steps of each Finding below on the testing build (the commit in `.scratch/testing-wave/app-build.json`), check the fix holds, and give each a verdict. Then run the follow-up tests listed. Nothing is fixed during the run.

**Findings to retest:** 03-007 08-002 11-005 12-002 18-005 21-004 23-001 28-006 64-001. Read each file in `.scratch/testing-wave/findings/` first: its Steps are the retest, and its Triage line names the fix ticket (read that ticket's file for what changed).

**Follow-up tests to run:** 04-006 (Onboarding back button mid-flow keeps the answers already given). Each Finding file holds the steps; read it first. Give each a verdict in `RUNS/verdicts.md` like the retests.

**Setup:** test@test.com, plus a new account for 04-006 (onboarding), 11-005 (the paywall) and 08-002. Read VoiceOver labels with `idb ui describe-all --udid UDID`. 21-004 and 64-001 need a TrainingPeaks token that the API refuses: check that the app marks the connection as needing reconnection. If you cannot cause the refusal without a write the runbook forbids, mark it not run and say why. 12-002 taps Ask Vana: `COST spend WAVE chat 118` before its opener.

**Decisions:** the ones each Finding cites.

**Touches:** nothing (read only), except the accounts the run creates and deletes.

- [ ] Runs by the runbook: a slot taken and released, the console saved to the run folder, a look-around on every screen visited, every new problem written as a Finding and nothing fixed.
- [ ] `RUNS/verdicts.md` has one row per Finding above: id, pass | fail | not run, the evidence (paths under `runs/118/`), and for a fail the new bug Finding's id. A fail is filed as a new bug Finding that names the old id in its Steps. The run does not edit the old Finding files: the wave lead closes the passes from this table.
- [ ] Each follow-up test above is run and gets a row in `verdicts.md`. A problem it finds is a new Finding.
- [ ] Every account the run made is deleted at the end (runbook step 9) unless the setup says to keep it.

Next: /implement-lee testing-wave
