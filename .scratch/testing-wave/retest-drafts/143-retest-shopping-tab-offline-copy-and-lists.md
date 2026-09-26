# 143: Retest: the Shopping tab's offline copy, list labels and names

**Status:** ready-for-agent
**Blocked by:** 133.
**Next:** `/implement-lee testing-wave`
**Model:** opus
**Split from:** fix ticket 133 and the 2026-09-26 triage (`triage-20260926.md`), about ten checks a run.

**What to build:** A retest run on the testing build named in `.scratch/testing-wave/app-build.json` (rebuilt after the last fix wave). It re-runs the steps of each Finding below and checks the fix as ticket 133 describes it. It then runs the folded follow-up. Nothing is fixed during the run. Follow `RUNBOOK.md` from step 1.

**Accounts and start state:** test@test.com (`CRED type test@test.com --udid UDID`), app data cleared. Before the first tap, SELECT the week's plans (`meal_plans`: id, status, confirmed_at, is_deleted) and lists (`shopping_lists`: id, plan_id, name, confirmed_at, is_deleted). Write the confirmed plan's id and its list id in `RUNS/notes.md`. Every check below starts from that list. Offline uses `netcut.sh launch`, then `on` / `off` (the socket close means the first offline tap really is offline). Hand-made lists this run creates are named `W<WAVE>-143 …` and deleted at the end.

**Shared account:** test@test.com and the same plan list are used by 144 (Kroger, Rebuild, Share) and 146 reads Previous plans on its own account. Do not run 143 and 144 in the same wave. If the lead must pair them, 144 waits for `SCRATCH-shared/143-done` (IMPROVEMENTS #72).

**COST:** none. No plan, logging or chat spend.

## Checks

1. **An offline-copy tick is kept and sent (110-001).** Relaunch offline (`netcut.sh launch`, `on`). Food > Shopping shows the offline copy. Tick one unticked row, wait 30 s, then `off` without a restart and wait 60 s. *Pass:* the console has no `shopping tick dropped: no row for`, the row stays ticked, and `shopping_items.checked` is true for that line once online. *Verify:* screen, console, DB SELECT on `shopping_items` (name, checked, updated_at) for the list.
2. **Offline ticks on the live list show on the offline copy after a restart (110-002).** Live list on screen, `on`, tick one row and untick another. Cold restart still offline, open Shopping. *Pass:* the offline copy shows both changes. Once `off`, both reach the DB. *Verify:* screenshots before and after the restart, the tick store file, DB SELECT.
3. **The offline copy has the last online tick (110-003).** Online, tick a row and wait for it to settle (DB shows it). `on`, then cold restart offline. *Pass:* the offline copy shows that tick. *Verify:* screen, and the local plan's `shopping` mirror read from the app's sqlite (`xcrun simctl get_app_container UDID com.milkman.mealvanaendurance.dev data`, SELECT only).
4. **Offline Previous lists says it needs a connection (110-004).** Offline cold start, Shopping > ⋯ > Previous lists. *Pass:* the sheet says the lists need a connection (133's new content key). It never says "No earlier lists yet." *Verify:* screen.
5. **A tap while the offline notice slides in (110-014, follow-up).** Live list online, `on`, tick a row, and within a second tap a second row's box. *Pass:* both taps register, on screen and in the tick store, and both reach the DB once `off`. A lost tap is a new bug Finding with a 10 fps recording (`simctl io recordVideo`). *Verify:* recording, tick store, DB.
6. **"An earlier list" only on an older list (110-005, 115-001).** (a) On the plan's list tick a row: the header keeps the confirmed label, not "· An earlier list". This holds even when a newer draft list exists on dev, so check the week's lists first. (b) ⋯ > New list: the new list opens and stays open, and it is never labelled earlier. (c) From Previous lists delete a `W<WAVE>-143` list while the plan's list is open: the open list is not relabelled earlier. *Pass:* all three. *Verify:* screenshots, `shopping_lists` SELECT.
7. **Plurals (110-006).** A list with one meal and a hand-made list with one item. *Pass:* "1 meal" and "1 item" in the header, the totals and the Previous lists rows. *Verify:* screen.
8. **New list asks for a name (110-010).** ⋯ > New list. *Pass:* a dialog pre-filled "List · <today in words>". Accept it, then New list again with the same name, and it becomes "… (2)". Cancel creates nothing. *Verify:* screen, `shopping_lists.name` SELECT.
9. **No list for a draft; deleted plans' lists hidden (110-012).** SELECT `shopping_lists` joined to `meal_plans` for this account: no list belongs to a never-confirmed draft (the migration removed 4 on dev). Previous lists shows no row for a draft or for a deleted plan. If a draft exists, its Plan tab ⋮ offers no working "Rebuild shopping list" (it is hidden or does nothing, and no row is written). *Pass:* all three. *Verify:* DB SELECT, screen. Known (133 notes): a draft's offline copy can still show mirror lines when the week has no confirmed plan. That is not a fail here.

**Findings:** 110-001, 110-002, 110-003, 110-004, 110-005, 115-001, 110-006, 110-010, 110-012; follow-up 110-014.

**Decisions:** Lee's rulings in `triage-20260926.md` (110-010, 110-012; clarifies mp-244).

**Touches:** test@test.com. Ticks and unticks on the confirmed plan's list (put back as found at the end, with the list's before-state in `RUNS/expected.md`). Two to four `W<WAVE>-143` hand-made lists, deleted at the end. No account created.

- [ ] Runs by the runbook: a slot taken and released, the console saved and redacted, a look-around on every screen visited, every new problem written as a Finding, nothing fixed. No RevenueCat or database writes the ticket doesn't name, even on your own account.
- [ ] `RUNS/verdicts.md` has one row per check and per Finding id: pass | fail | not run, evidence under `runs/143/`, and for a fail the new bug Finding's id.
- [ ] Each Finding listed is closed with evidence or a new bug Finding. The run does not edit old Finding files; the lead closes the passes.
- [ ] The list's ticks are back to their before-state and the run's hand-made lists are deleted.

Next: /implement-lee testing-wave
