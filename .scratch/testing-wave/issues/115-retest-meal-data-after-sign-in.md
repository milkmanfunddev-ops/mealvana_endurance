# 115: Retest: meal data after sign-in, and the paywall's delete analytics

**Status:** in-progress (wave 32, 2026-09-25)
**Blocked by:** 110.
**Pair with:** 116 (the fuelling plan and the timeline's numbers, same account). This run confirms an existing Draft on test@test.com last (16-003), which changes the confirmed plan, its list and its Plan-tab note; 116 reads that note (09-002, 14-010) and logs meals today. In one wave, 116 reads the note before 115 confirms: 115 writes the confirm time in `notes.md`.
**Next:** `/implement-lee testing-wave`
**Model:** opus
**Split from:** 91 (Lee, 2026-09-25: about ten checks per run).

**What to build:** A retest run. Re-run the steps of each Finding below on the testing build (the commit in `.scratch/testing-wave/app-build.json`), check the fix holds, and give each a verdict. Then run the follow-up tests listed. Nothing is fixed during the run.

**Findings to retest:** 26-001 19-004 20-003 10-001 04-001 16-003. Read each file in `.scratch/testing-wave/findings/` first: its Steps are the retest, and its Triage line names the fix ticket (read that ticket's file for what changed).

**Follow-up tests to run:** none.

**Setup:** test@test.com, except 04-001 (a new account on the paywall) and 10-001 (a Lapsed account with a meal logged before its lapse, signed in where it never was: read its Steps). All five checks but 04-001 are fix ticket 46's: data shows after sign-in without opening Food first, and loading never reads as empty.

**Order:** 26-001 and 19-004 first, on the cleared app's first sign-in (Recent and Food before anything else opens Food). 20-003 needs three rows ticked on the list: untick them after. 16-003 last: confirm an existing Draft from the Review sheet (no new plan, no COST spend), then open Shopping. It runs after ticket 110, which needs the current confirmed plan's list.

**Decisions:** the ones each Finding cites.

**Touches:** nothing (read only), except the accounts the run creates and deletes, and test@test.com's confirmed plan (16-003).

- [ ] Runs by the runbook: a slot taken and released, the console saved to the run folder, a look-around on every screen visited, every new problem written as a Finding and nothing fixed.
- [ ] `RUNS/verdicts.md` has one row per Finding above: id, pass | fail | not run, the evidence (paths under `runs/115/`), and for a fail the new bug Finding's id. A fail is filed as a new bug Finding that names the old id in its Steps. The run does not edit the old Finding files: the wave lead closes the passes from this table.
- [ ] Each follow-up test above is run and gets a row in `verdicts.md`. A problem it finds is a new Finding.
- [ ] Every account the run made is deleted at the end (runbook step 9) unless the setup says to keep it.

Next: /implement-lee testing-wave
