# 88: Retest: meal-plan chat

**Status:** ready-for-agent
**Blocked by:** none.
**Next:** `/implement-lee testing-wave`
**Model:** opus

**What to build:** A retest run. Re-run the steps of each Finding below on the testing build (the commit in `.scratch/testing-wave/app-build.json`), check the fix holds, and give each a verdict. Then run the follow-up tests listed. Nothing is fixed during the run.

**Findings to retest:** 14-001 14-002 15-001 15-002 15-003 16-001 16-002 16-004 16-005 18-001 18-003 29-001 61-001. Read each file in `.scratch/testing-wave/findings/` first: its Steps are the retest, and its Triage line names the fix ticket (read that ticket's file for what changed).

**Follow-up tests to run:** 16-011 (confirm a Draft while the week already has a confirmed plan), 09-006 (Review plan: remove a meal, Keep planning, Confirm offline and tapped twice), 18-008 (Browse untried paths).

**Setup:** test@test.com (vegetarian: a salmon search returns nothing). One `COST spend WAVE plan 88` for the new plan; reuse existing plans and conversations for everything else. Browse's + writes to the conversation's draft plan and builds a shopping list (IMPROVEMENTS #47), so name in `notes.md` which conversation and plan each write went to. Ticket 89 uses the same account in the same wave: it reads Previous plans and lists, and 19-009 edits the confirmed plan's list. Treat its rows as expected.

**Known leftover, not a failure:** the Swap screen can show a short list because it asks `search_meals` for 20 and then drops blank-number meals. That is ticket 94's; 61-001 checks that no blank-number meal is offered or placed.

**Decisions:** the ones each Finding cites.

**Touches:** nothing (read only), except the accounts the run creates and deletes.

- [ ] Runs by the runbook: a slot taken and released, the console saved to the run folder, a look-around on every screen visited, every new problem written as a Finding and nothing fixed.
- [ ] `RUNS/verdicts.md` has one row per Finding above: id, pass | fail | not run, the evidence (paths under `runs/NN/`), and for a fail the new bug Finding's id. A fail is filed as a new bug Finding that names the old id in its Steps. The run does not edit the old Finding files: the wave lead closes the passes from this table.
- [ ] Each follow-up test above is run and gets a row in `verdicts.md`. A problem it finds is a new Finding.
- [ ] Every account the run made is deleted at the end (runbook step 9) unless the setup says to keep it.

Next: /implement-lee testing-wave
