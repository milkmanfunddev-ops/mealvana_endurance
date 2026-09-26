# 161: Retest: Learn, Events, Describe's layout, and Vana dictation

**Status:** ready-for-agent
**Blocked by:** 141.
**Next:** `/implement-lee testing-wave`
**Model:** opus
**Split from:** fix ticket 141 and the 2026-09-26 triage, about ten checks a run.

**What to build:** A retest run on the testing build (`app-build.json`). It re-runs each Finding's steps against ticket 141's small fixes and runs the folded Learn, Events, Describe and dictation follow-ups. Nothing is fixed during the run. Follow `RUNBOOK.md`.

**Accounts and start state:** test@test.com, app data cleared (its events include IRONMAN Cozumel on 2026-11-23 and a past Baton Rouge Half Marathon; SELECT `events` first and use what is there). Speech Recognition and Microphone start refused for check 7: answer Don't Allow at the first Dictate prompt. Resetting microphone permission uses `xcrun simctl privacy UDID reset microphone com.milkman.mealvanaendurance.dev`. Speech Recognition is toggled in the simulator's Settings app for "Endurance Dev".

**Shared account:** test@test.com. This run writes a Notify Me interest and at most one `W<WAVE>-161` event (deleted at the end).

**COST:** none. Dictation opens an old conversation by deep link, and Describe is never analysed.

## Checks

1. **Notify Me answers once (117-006).** Learn > Notify Me under Premium Video Library, then again, then the Courses card's Notify Me. *Pass:* "We'll let you know" once. A second tap writes nothing (one analytics event). Both cards behave the same. *Verify:* screen, console `[ANALYTICS]`.
2. **Event countdown counts fairly (117-007).** Events > IRONMAN Cozumel (58 days out on 09-26; adjust for today's date). *Pass:* weeks under about 9 weeks ("8 weeks away"), months beyond. The badge, the upcoming card and the detail agree. *Verify:* screenshots.
3. **Learn offline (117-008).** Open Learn online once, then `netcut on --relaunch`, open Learn. *Pass:* the cached lessons, or an offline message with Retry. Never "No videos available yet". Retry after `off` loads them. *Verify:* screenshots.
4. **A past event's detail (117-014).** Open the past event. Try Create Carb Loading Plan and Race Day Checklist, More options (⋯) on a past and an upcoming event, the Home button, and Cozumel's Registration link. *Pass or record:* what each builds and for which dates. Anything written for a race already run is a bug Finding. Delete anything the run created. *Verify:* screen, SELECT `events` / carb-loading rows before and after.
5. **New Event at the list's end (118-013).** My Events with the current count, then with one extra `W<WAVE>-161` event: scroll to the end, scroll up until the tab bar re-expands, scroll down, tap New Event each time. *Pass:* New Event is reachable and never under the tab bar. Delete the extra event. *Verify:* screenshots.
6. **Describe's layout (118-012).** Log a Meal > Describe. Set text size to the 1.6 cap (dev pill > testing tools). Type 12 lines, and switch to Manual and back with the keyboard up. *Pass:* Analyze stays visible and tappable in each state. Do not press it. *Verify:* screenshots, Analyze's frame in `describe-all`.
7. **The dictation message (120-005).** Open an old conversation by deep link. Tap Dictate and answer Don't Allow. *Pass:* the message names the app as iOS Settings lists it ("Endurance Dev" on dev), and the composer stays tappable while it shows (tap the field during the message). *Verify:* screenshot, `describe-point` on the composer.
8. **Dictate after turning access on (120-014).** Settings app > Endurance Dev > turn Speech Recognition and Microphone on. Back to the app with no relaunch, tap Dictate. *Pass:* no settings message. Dictation starts listening, or says why not. That dictation works on real speech is device-only. *Verify:* screenshot, console.

**Not counted (device: not run on simulator):** 120-014's real speech input.

**Findings:** 117-006, 117-007, 117-008, 120-005; follow-ups 117-014, 118-013, 118-012, 120-014.

**Decisions:** Lee's rulings in `triage-20260926.md` (117-006 Notify Me records interest; 120-005 names the app as iOS lists it).

**Touches:** test@test.com: a Notify Me interest, at most one temporary event (deleted), and the app's microphone and speech permissions on this simulator. No account created.

- [ ] Runs by the runbook, with a look-around on every screen, nothing fixed. No RevenueCat or database writes the ticket doesn't name, even on your own account.
- [ ] `RUNS/verdicts.md`: one row per check and Finding id, with evidence under `runs/161/`.
- [ ] Each Finding listed is closed with evidence or a new bug Finding.
- [ ] Anything the run created on test@test.com (event, carb-loading plan, checklist) is deleted, checked by SELECT.

Next: /implement-lee testing-wave
