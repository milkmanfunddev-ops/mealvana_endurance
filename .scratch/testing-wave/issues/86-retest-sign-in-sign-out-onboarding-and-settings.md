# 86: Retest: sign-in, sign-out, onboarding and settings

**Status:** in-progress (wave 25, 2026-09-25)
**Blocked by:** none.
**Next:** `/implement-lee testing-wave`
**Model:** opus

**What to build:** A retest run. Re-run the steps of each Finding below on the testing build (the commit in `.scratch/testing-wave/app-build.json`), check the fix holds, and give each a verdict. Then run the follow-up tests listed. Nothing is fixed during the run.

**Findings to retest:** 02-001 02-002 02-003 02-006 03-002 03-004 03-009 06-003 09-004 09-013 12-003 14-003 14-004 31-001 31-014 32-001 32-002 04-008. Read each file in `.scratch/testing-wave/findings/` first: its Steps are the retest, and its Triage line names the fix ticket (read that ticket's file for what changed).

**Follow-up tests to run:** none.

**Setup:** New accounts made by the run (`CRED new`), plus the dev test account test@test.com for the switch checks. Two accounts on one device for ticket 33's leak checks (02-001, 14-003, 14-004, 03-002, 32-002). **14-004 runs on the dev simulator's leftover data**: the lead does NOT run clear-app on this ticket's simulator, so the app opens with whatever the dev simulator held; run 14-004 first, then sign out and continue.

**Known leftovers, not failures of these retests:** the iOS Speech Recognition/Microphone purpose wording (09-004), the plan reveal's Connect now nudge (04-008 is only the daily plan preview), the failed-first-configure case in RevenueCat login (09-013) and the Settings tile string (31-014) are ticket 94's. Check what the Finding describes; do not fail it for the leftover.

**Decisions:** the ones each Finding cites.

**Touches:** nothing (read only), except the accounts the run creates and deletes.

- [ ] Runs by the runbook: a slot taken and released, the console saved to the run folder, a look-around on every screen visited, every new problem written as a Finding and nothing fixed.
- [ ] `RUNS/verdicts.md` has one row per Finding above: id, pass | fail | not run, the evidence (paths under `runs/NN/`), and for a fail the new bug Finding's id. A fail is filed as a new bug Finding that names the old id in its Steps. The run does not edit the old Finding files: the wave lead closes the passes from this table.
- [ ] Each follow-up test above is run and gets a row in `verdicts.md`. A problem it finds is a new Finding.
- [ ] Every account the run made is deleted at the end (runbook step 9) unless the setup says to keep it.

Next: /implement-lee testing-wave
