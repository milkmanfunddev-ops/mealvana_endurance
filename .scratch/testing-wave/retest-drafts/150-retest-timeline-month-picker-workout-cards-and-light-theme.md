# 150: Retest: the Timeline, month picker, workout cards and Light theme

**Status:** ready-for-agent
**Blocked by:** 137.
**Next:** `/implement-lee testing-wave`
**Model:** opus
**Split from:** fix ticket 137 and the 2026-09-26 triage, about ten checks a run.

**What to build:** A retest run on the testing build (`app-build.json`). It re-runs each Finding's steps against ticket 137's fixes and runs the folded Timeline follow-ups. The Activity detail screen keeps its look and copy (standing rule), so only numbers and navigation are judged there. Nothing is fixed during the run. Follow `RUNBOOK.md`.

**Accounts and start state:** test@test.com, app data cleared. Its FinalSurge swim of Fri Sep 25 (18f023ed…, provider-completed) is the card for checks 5 and 6: SELECT `activities` (id, name, status, completion_type, scheduled_date_time) first and use whatever provider-completed workout exists if that one moved. Check 3 needs a second account C, new (`CRED new`), bought Annual. Location permission is reset before check 6 (`xcrun simctl privacy UDID reset location com.milkman.mealvanaendurance.dev`).

**Shared account:** test@test.com is read here, except the Appearance setting, which is local to the device. Other runs may log meals on it.

**COST:** none.

## Checks

1. **The month picker's Today closes the sheet, and the day arrows stay put (117-004).** Open the date dropdown, tap the month arrows, then Today. On a past day, read the Next day arrow's position from the element list on two days with different title widths. *Pass:* Today closes the sheet on today. The arrows sit at the same x on both days. (CS-6 in `calendar-sheet.md` says the sheet stays open. The ticket's ruling wins for this retest, and the clash is already open for Xuan.) *Verify:* screenshots, element-list x positions.
2. **Pull to refresh syncs connected apps (117-005).** On today pull the Timeline down. *Pass:* a refresh indicator shows. The console logs the integration sync (forceSyncIntegrations or similar) with no "data is fresh" skip, and `integrations.last_sync_at` for FinalSurge moves (UTC, see 153). *Verify:* console, SELECT (provider, last_sync_at, last_sync_status).
3. **A sign-in opens on today (117-010).** Walk back to a past day, sign out, Log In again: the Timeline opens on today. Walk back again, sign out, Log In as account C: today. *Pass:* today both times. *Verify:* screenshots of the date header.
4. **Light theme, and System (119-003, 119-011).** Settings > Appearance > Light, relaunch, look at the Timeline. Then System: `xcrun simctl ui UDID appearance light`, then `dark`, with the app open and after a relaunch in each. Put Dark back. *Pass:* in Light, meal names, kcal and times are readable and the header and workout cards follow the theme. System follows the simulator both ways. Accent contrast on cream is a known open token call (137 notes). Note it without failing. *Verify:* screenshots.
5. **A verified workout's name shows (100-002).** Previous day to the FinalSurge swim's day, Workout filter. *Pass:* the card reads "Swim" in full, and the badge shrinks or wraps. *Verify:* screenshot, element list.
6. **A provider-completed workout opens its detail, with no location prompt (100-003, 100-004).** Tap that card. *Pass:* the activity's plan view (`/plan`) opens, not Create New Activity Plan, and no location prompt shows. Then open an upcoming activity inside the forecast range. The location prompt may show there. Answer Don't Allow. *Verify:* screenshots, console route lines.
7. **A finished day's projection meets "so far" (116-010).** A past day with meals (Thu Sep 24 or any past day with logs) > Full Breakdown > Today's Energy. *Pass:* the burned-by-end projection equals the so-far figure on a finished day. Today's projection is unchanged. The card's words ("Today's…") are held for Xuan (116-009, 117-003) and are not judged. *Verify:* screenshot, the numbers written into notes.
8. **Add Activity from a past day's Workout filter (100-012).** Sep 25 (or another past day), Workout filter, + Add Activity. *Pass or record:* where the prefill ("12 mi Run", date) comes from. Tap Generate Plan only if no activity of that name exists that day. A prefilled form that would duplicate an existing run is a bug Finding. Back without saving. *Verify:* screen, SELECT activities for that day before and after (no new row).
9. **Today's Fuel and the Plan tab note, look-around (116-018).** Today's Fuel > "Where it came from" on a day with no meals, and right after a `W<WAVE>-150` meal is logged and then Removed. Two meals of one type plus one with no type. Today's Fuel on a past and a future day. The Plan tab's Vana card offline, and on a day with no plan meals. *Pass:* the rows and counts follow the logs. Wording ("INTAKE TODAY") is held for Xuan, so record it without failing. *Verify:* screenshots, SELECT.

**Findings:** 117-004, 117-005, 117-010, 119-003, 100-002, 100-003, 100-004, 116-010; follow-ups 119-011, 100-012, 116-018.

**Decisions:** Lee's rulings in `triage-20260926.md` (117-005, 100-003, 100-004, the Activity detail standing rule). Held for Xuan and not judged: 112-009, 116-009, 117-003.

**Touches:** test@test.com (read, one or two `W<WAVE>-150` logs Removed at the end, the device's Appearance setting put back to Dark). Account C (made, bought Annual, deleted at the end).

- [ ] Runs by the runbook, with a look-around on every screen, nothing fixed. No RevenueCat or database writes the ticket doesn't name, even on your own account.
- [ ] `RUNS/verdicts.md`: one row per check and Finding id, with evidence under `runs/150/`.
- [ ] Each Finding listed is closed with evidence or a new bug Finding.
- [ ] Account C is deleted through the app, and Appearance is back to Dark.

Next: /implement-lee testing-wave
