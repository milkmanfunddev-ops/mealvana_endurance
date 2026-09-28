# 148: Retest: Log a Meal edges, first reads offline, and meals in clock order

**Status:** ready-for-agent
**Blocked by:** 135, 137.
**Next:** `/implement-lee testing-wave`
**Model:** opus
**Split from:** the 2026-09-26 triage (follow-ups folded into the retest of their screen) and fix ticket 137 item 2 (112-011).

**What to build:** A retest run on the testing build (`app-build.json`). It runs the folded Log a Meal follow-ups and 112-011, all without AI calls. Nothing is fixed during the run. Follow `RUNBOOK.md`.

**Accounts and start state:** test@test.com. Checks 1-3 need a **fresh sign-in on a cleared app** with the network cut right after sign-in. Plan them as one sign-in: clear, sign in online, `netcut.sh on SCRATCH --relaunch UDID` as soon as the Timeline lands, then run checks 1-3 before going online. Every log is named `W<WAVE>-148 …` and Removed at the end.

**Shared account:** test@test.com is also used by 147 and 149 (their own `W<WAVE>-147/149` rows). Check only your own rows.

**COST:** none.

## Checks

1. **First sign-in with the network cut (115-003).** Right after the offline relaunch: + Add Food > Recent, then Food > Plan, then Food > Shopping, 30 s on each. *Pass:* each shows its offline or loading state and settles within 30 s. No bare spinner is left forever, and no screen claims "no meals" or "no plan" while the reads never answered. *Verify:* screenshots at 0 s and 30 s, console.
2. **Recent on a fresh install offline, and a photo source (112-016 steps 1 and 3).** Still offline, Recent: note what shows after its 15 s wait. Online later: re-log a Recent meal whose source has a photo. *Pass:* offline Recent says it is offline or shows cached rows, never an empty "no recent meals". The photo re-log keeps or drops the photo as the screen says. *Verify:* screen, SELECT (photo columns by name).
3. **Recipes offline on a fresh install; recipe calories (112-019).** Still offline, Recipes tab. Online: log "Banana & Rice Peanut Butter Chews" at 2 servings. *Pass:* offline Recipes says it is offline, not empty. Record whether the logged calories are 195 × 2. `recipes.calories` per serving is a question for the recipe owner: write the answer you find in the code as an idea Finding if unclear. *Verify:* screen, SELECT.
4. **A combo at more than one serving; search offline (112-018).** Online, Common > a quick-add combo: try to log a double portion. Offline, search "egg". *Pass:* a double portion is possible (a stepper, or record that it is missing as an idea Finding). Offline search says it needs a connection. *Verify:* screen, SELECT.
5. **Quick log sheet times (112-020).** (a) Time eaten 11:30 PM today (later than now) > Log it. (b) The picker's text mode: type 68 into the hour and OK. (c) Yesterday's Log a Meal > a sheet: its default time. *Pass:* (a) is either refused or logged where the Timeline shows it at 11:30 PM. (b) never stores a wrong hour silently. (c) is recorded as seen, and a default that makes no sense is an idea Finding. *Verify:* screen, SELECT `created_at` / eaten time.
6. **A sheet left open two minutes (112-024).** Open a recipe sheet, wait 2 min online, Log it. Three times, then once after 30 s. *Pass:* each logs within a few seconds, and the first insert does not time out. A timeout that is then retried and lands still passes (135 item 1), with the times written down. *Verify:* console timings, SELECT.
7. **Remove or edit a log that has not uploaded, then go online (112-021).** Offline: log `W<WAVE>-148 unsent`, Remove it from the Timeline ⋯, `off`, and wait. Second log: offline, Edit food on it, then `off`. *Pass:* the removed one never appears on dev (or arrives already deleted). The edited one reaches dev with the edit. *Verify:* SELECT after going online and after a relaunch.
8. **Log a Meal's default tab and the % chip (112-022).** From the Timeline's + Add Food on this fresh sign-in. *Pass or record:* which tab opens, and what the orange chip beside Describe means (AI budget left?). A chip that reads like an error ("253%") is an idea Finding. Do not tap Analyze. *Verify:* screenshot, the chip's widget from code (say "from code, unverified").
9. **Manual number pad (115-002).** Manual > Calories. Try to close the number pad (tap Time eaten's label, the title) and reach Carbs, Protein, Fat and Save. *Pass:* the pad can be closed, or the next fields and Save can be reached, without values landing in the wrong field. *Verify:* screen, the values saved.
10. **Meals sit in clock order (112-011, 116-016).** Log four quick meals as "Any time" at 6:24, 6:25, 6:26 and 6:30 PM (Time eaten), plus a Lunch 30 min and one 31 min after another Lunch. Also Manual-log one set before midnight while logged after it, and Edit food to move one meal into, then out of, another's 30-minute window. *Pass:* no card is out of clock order. The 6:30 PM soup never sits under 6:24 PM. The 30/31-minute pair splits as 137's chained window says. *Verify:* Timeline screenshots, SELECT times.

**Findings:** 112-011; follow-ups 115-003, 112-016 (steps 1, 3), 112-019, 112-018, 112-020, 112-024, 112-021, 112-022, 115-002, 116-016.

**Decisions:** the ones each Finding cites. Ticket 137 item 2 (the grouping rule).

**Touches:** test@test.com: `W<WAVE>-148` meal logs, all Removed at the end. No account created.

- [ ] Runs by the runbook, with a look-around on every screen, nothing fixed. No RevenueCat or database writes the ticket doesn't name, even on your own account.
- [ ] `RUNS/verdicts.md`: one row per check and Finding id, with evidence under `runs/148/`.
- [ ] Each Finding listed is closed with evidence or a new bug Finding. A follow-up that passes is marked pass, and one that finds a problem gets a new Finding.
- [ ] Every `W<WAVE>-148` log is Removed at the end, checked by SELECT.

Next: /implement-lee testing-wave
