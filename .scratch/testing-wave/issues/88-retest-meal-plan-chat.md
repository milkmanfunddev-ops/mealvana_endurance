# 88: Retest: meal-plan chat

**Status:** in-progress (wave 29, 2026-09-25)
**Blocked by:** none.
**Next:** `/implement-lee testing-wave`
**Model:** opus

**What to build:** A retest run. Re-run the steps of each Finding below on the testing build (the commit in `.scratch/testing-wave/app-build.json`), check the fix holds, and give each a verdict. Then run the follow-up tests listed. Nothing is fixed during the run.

**Findings to retest:** 14-001 14-002 15-001 15-002 15-003 16-001 16-002 16-004 16-005 18-001 18-003 29-001 61-001. Read each file in `.scratch/testing-wave/findings/` first: its Steps are the retest, and its Triage line names the fix ticket (read that ticket's file for what changed).

**Follow-up tests to run:** 16-011 (confirm a Draft while the week already has a confirmed plan), 09-006 (Review plan: remove a meal, Keep planning, Confirm offline and tapped twice), 18-008 (Browse untried paths).

**More follow-up tests (Lee, 2026-09-25, cap of ten lifted for this pass):** 18-009 (Browse from a conversation whose plan is archived or confirmed: Add writes into that plan (code read), check what the athlete sees), 03-006 (meal_plan_build's last leg (Ate it to a meal_logs row) was not reached: the first plan tile had no servings left), 09-007 (Confirm plan routes to the Shopping sub-tab in the log but the Plan sub-tab shows; check which one the athlete should land on), 14-006 (Plan tab: New meal plan then Back with nothing picked, several times), 14-007 (Plan tab menu: Start a new plan and Delete plan while a new-plan draft is open), 14-008 (Getting back to a half-built new-plan draft from the Plan tab), 14-009 (New meal plan offline or with the opener failing), 09-008 (Vana new-plan chat: leave with Back while the plan is generating, then come back), 16-010 (Conversation of a Draft archived by another confirm: what its plan bar, cards and Review sheet say), 15-005 (Resumed older conversation: tap an old turn's chips, Edit an old user turn, and change servings on an archived Draft), 15-006 (Older conversation opened offline, after a kill, and with a long transcript: history, plan bar and scroll position), 16-008 (Resumed meal-plan conversation: empty Ask me anything state while a vana-action call hangs to a socket timeout), 15-007 (Conversations list: scroll to the oldest row, rows for deleted or other-week plans, and the Ask Vana tab's empty state), 18-011 (Screens passed through on the way to Browse: general chat with no plus, Review plan on an old conversation's draft, Plan tab note card, Shopping tab after a browse pick), 12-009 (Vana companion: expand, close mid-stream, send while the opener streams, and the pro_required answer on screen), 15-004 (Ask Vana after a fresh sign-in started a second general conversation for Sep 24 and paid for a new opener), 15-008 (The full-screen general chat shows a third suggestion chip the Ask Vana sheet did not). Each Finding file holds the steps; read it first. Give each a verdict in `RUNS/verdicts.md` like the retests.

**Setup:** test@test.com (vegetarian: a salmon search returns nothing). One `COST spend WAVE plan 88` for the new plan; reuse existing plans and conversations for everything else. Browse's + writes to the conversation's draft plan and builds a shopping list (IMPROVEMENTS #47), so name in `notes.md` which conversation and plan each write went to. Ticket 89 uses the same account in the same wave: it reads Previous plans and lists, and 19-009 edits the confirmed plan's list. Treat its rows as expected.

**Known leftover, not a failure:** the Swap screen can show a short list because it asks `search_meals` for 20 and then drops blank-number meals. That is ticket 94's; 61-001 checks that no blank-number meal is offered or placed.

**Decisions:** the ones each Finding cites.

**Touches:** nothing (read only), except the accounts the run creates and deletes.

- [ ] Runs by the runbook: a slot taken and released, the console saved to the run folder, a look-around on every screen visited, every new problem written as a Finding and nothing fixed.
- [ ] `RUNS/verdicts.md` has one row per Finding above: id, pass | fail | not run, the evidence (paths under `runs/NN/`), and for a fail the new bug Finding's id. A fail is filed as a new bug Finding that names the old id in its Steps. The run does not edit the old Finding files: the wave lead closes the passes from this table.
- [ ] Each follow-up test above is run and gets a row in `verdicts.md`. A problem it finds is a new Finding.
- [ ] Every account the run made is deleted at the end (runbook step 9) unless the setup says to keep it.

Next: /implement-lee testing-wave
