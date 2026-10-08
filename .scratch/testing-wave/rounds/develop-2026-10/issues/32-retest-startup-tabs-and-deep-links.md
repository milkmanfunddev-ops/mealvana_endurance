# 32: Retest: startup, tabs and deep links

**Status:** done 2026-10-08 (wave 3 run complete; see runs/32/notes.md)
**Labels:** retest, round:develop-2026-10, area:startup, read-only
**Branch:** `develop-next` (worktree per ticket, branched from the round's base after the fix wave lands)
**Source:** TRIAGE.md rulings of 2026-10-07: followups 08-016 to 08-023; fix retests for ticket 28
(08-007 with 01-011, 08-008), ticket 22 (08-009), ticket 26 (orphan routes archived: 08-003, 08-004,
08-005, 08-010, 08-011, 08-012, 08-014) and ticket 27 (Jade archived: 08-001, 08-002, 08-006)
**Blocked by:** the fix wave (tickets 21–29) and its rebuild; runs in wave 3
**Next:** `/testing-wave develop-2026-10 --only 32`
**Model:** opus

**What to test:** A fresh install launched signed out and signed in, online and offline; the launch-trail
dialog and the startup timers after ticket 28 and 22; every tab's untried paths from ticket 08; and the
routes tickets 26 and 27 archived, which must now answer by deep link with Page Not Found (or a sane
fallback) while nothing in the app misses them.

**13 checks, more than the ten SPEC.md allows.** Part 1 (5 fix retests: 28 ×2, 22, 26, 27) and part 2
(8 followups) need the same account and start state, so they are written as one run; the lead may cut
them into two tickets (`32a` part 1, `32b` part 2), each on a cleared simulator.

**Runs by:** `docs/testing-wave/RUNBOOK.md`. RUNS = `.scratch/testing-wave/rounds/develop-2026-10/runs/32/`,
Findings in `.scratch/testing-wave/rounds/develop-2026-10/findings/`. One slot, console to RUNS, a
look-around on every screen, every problem a Finding, nothing fixed.

**Accounts:** the dev test account (`CRED type test@test.com --udid UDID`), signed in after the signed-out
checks. Read-only: this run writes nothing on the account except what a check names, and none does (Events'
swipe is cancelled at its confirm; New Event is opened and backed out of, never saved). Tickets 31 and 33
log meals on the same account in the same wave: a meal card that appears or vanishes mid-run is theirs.

**App data:** cleared by the wave lead (signed out, empty database and prefs). `clear-app.sh` empties the
app's folders only; the notification permission state is whatever the copied dev simulator holds. Record
it from the first launch's `push heal: permission=` console line before judging step 5.

**Cost:** no AI call. Nothing is submitted on any screen.

**Read first.** CLAUDE.md's notification rule covers this ticket (startup chain, permission prompt, deep
links): `.claude/skills/notification-testing/` and `../ops/docs/messaging-relay-and-testing.md` do not
exist on develop-next (ticket 17 files that idea; do not file it again). Read tickets 22, 26, 27 and 28 in
`ROUND/issues/` for what each fix changed, and `launch_trail.dart`'s guard after 28.

**Retest rule.** A check that passes closes the Finding(s) named beside it: write `PASS <id>` in
`RUNS/notes.md` with the evidence; the lead marks them `closed`. A check that fails files a new Finding with
`findings.mjs new 32 … --round develop-2026-10` citing the old id (`Retest of 08-NNN`). 08-021 may also
close through ticket 29 (backports).

## Screens (from code, unverified)

| Screen | Route / entry | Code |
|---|---|---|
| Launch trail (dev) dialog | over any screen at launch/resume | `launch_trail.dart` (path in ticket 28) |
| Welcome | `/welcome` | `lib/features/onboarding/presentation/screens/welcome_screen.dart` |
| Timeline (tab 0) | `/main` | `lib/shared/widgets/tabs_screen.dart` → `MacroDashboardBody` |
| Events (tab 1), event detail, New Event | tab | `lib/features/events/presentation/screens/events_list_screen.dart`, `.../widgets/event_list_card.dart` (swipe has a `confirmDismiss`) |
| Learn (tab 2), lesson player | tab | `lib/features/education/presentation/screens/{education,video_player}_screen.dart` |
| Log a meal sheet, Recipes tab | Timeline "+ Add Food" | `lib/features/meal_logging/presentation/screens/{log_meal,recipe_picker}_screen.dart` |
| Settings, Sign Out dialog | gear | `lib/features/settings/presentation/screens/settings_screen.dart` (dialog text ~line 583) |
| Page Not Found, "Go Home" | any unknown path | `lib/shared/core/app_router.dart` `errorBuilder` |

## Expected records

Read only. `RUNS/expected.md` lists, from tickets 26 and 27, the routes that must now be unknown (below),
and the console lines that must not appear (`error_reported … SlowOperation` for `deferred.notifications`
spanning the prompt; a launch-trail dialog without a notification).

## Steps

Deep links use the three-slash form, `xcrun simctl openurl UDID "com.milkman.mealvanaendurance:///<path>"`,
unless a step says two slashes. iOS asks "Open in Endurance Dev?" the first time; that prompt is a resume.

### Signed out

1. **08-007 and 01-011 (ticket 28).** First cold launch (runbook step 3, console on). No launch-trail
   dialog. Background and resume three times (home button, then relaunch from the icon; an openurl
   prompt): no dialog, never a stack of them. Then, if `xcrun simctl push UDID
   com.milkman.mealvanaendurance.dev <payload>.apns` can deliver a payload the app's guard counts (read the
   guard; write the payload to SCRATCH), terminate the app, push, tap the banner: exactly one dialog. If the
   guard cannot be fed from a simulator push, write "real-payload half not run" and file a followup-test
   for Lee's phone. Pass needs the negative half at least.
2. **08-020.** `netcut.sh launch UDID SCRATCH`, `netcut.sh on SCRATCH --relaunch UDID`: signed-out cold start
   offline: Welcome renders, no crash. "I already have an account", sign in offline with the test account:
   the message shown, no crash, nothing stuck spinning. `netcut.sh off SCRATCH`.
3. **08-022.** Signed out, open `/athlete/feedback`, `/buy-credits` and `/settings/food-preferences`: each
   lands on Welcome (the redirect guard), never a signed-in screen. Open
   `com.milkman.mealvanaendurance://athlete/feedback` (two slashes): Page Not Found; tap Go Home and record
   where it settles after 5 s.

### Sign in and startup timers

4. Sign in with the test account. **08-020 (kill during sync):** within 2 s of the Timeline appearing,
   terminate the app; relaunch: the Timeline comes back with the account's data, no reset, no crash.
5. **08-017 and 08-009 (ticket 22).** Record on which launch the iOS notification prompt first appears
   (fresh install, after sign-in, after the kill). When it shows, leave it up about 10 s and tap Don't
   Allow. Pass for 08-009: the console's `deferred.notifications` duration (if logged) excludes the time
   the prompt was up, and no `SlowOperation` `error_reported` covers it. Record the other three timers
   (`deferred.revenuecat`, `dashboard.activities.background_sync`, `dashboard.integration_sync`) for ticket
   17; with three wave simulators up they are environment, not verdicts. Note any `notif_scheduled` lines
   after Don't Allow (scheduling with permission off is intended; say so if seen).

### Tabs

6. **08-023.** Timeline: record the order of same-time activities and the net balance, then again after a
   tab round trip and after a relaunch, with clock times. Order changing between reads is a bug Finding;
   a balance that moves with time of day is noted with the reason the code gives (read the balance's
   calculation, cite it).
7. **08-008 (ticket 28) and 08-018.** Events: drag the list to its end (slow idb drag): New Event sits fully
   above the floating tab bar. Tap it: the new-event screen opens; Back out without saving. Open the
   upcoming event and a past event, Back from each to the list. Pull to refresh. Swipe one card: the confirm
   appears; Cancel; the card stays and nothing is deleted (SQL `events` count for the account unchanged).
8. **08-019.** Learn: play lessons 1.2 and 1.3 (1.3 is off-screen in the carousel), use fullscreen, mute
   and ±15 s; tap Notify Me on Pro Videos and on Courses (record what it says and whether it writes
   anything: read its handler first, and skip the tap if it writes to the server); open a lesson with
   `netcut.sh on SCRATCH` (clear message, no crash), then `netcut.sh off SCRATCH`.
9. **08-016.** "+ Add Food" → Recipes tab. The account's Food Preferences say Vegetarian (check in
   Settings first). Record any meat or fish recipe offered. Read the picker's query and `docs/ssot/` for a
   rule on filtering by diet: unfiltered with no rule is noted; a ratified rule broken is an
   `ssot-conflict` with the quote. Close the sheet without logging.

### Archived routes, signed in

10. **Ticket 26 (08-003, 08-004, 08-005, 08-010, 08-011, 08-012, 08-014).** Open each of the nine
    archived paths: `/pro`, `/settings/sport-settings`, `/settings/food-preferences-consolidated`,
    `/settings/food-preferences/add-food`, `/meal-log/manual`, `/meal-log/photo`, `/meal-log/describe`,
    `/meal-log/recent-saved`, `/meal-log/recipe`. Pass: each shows Page Not Found (or a fallback ticket 26
    names), Go Home settles on the Timeline, and no console exception. Then the in-app half: Settings →
    Food Preferences opens and Back works; the Log a meal sheet's every tab opens (Describe, Manual,
    Recent, Common, Recipes, whichever exist); `/athlete/feedback` still renders (not archived; ticket 19 owns it), and
    `/buy-credits` renders or redirects as ticket 23 left it (26 did not touch it). Anything that crashed or lost a way in is a bug citing ticket 26.
11. **Ticket 27 (08-001, 08-002, 08-006).** Open `/jade`: Page Not Found, Go Home to the Timeline, no black
    screen. No Mealvana AI or Jade entry anywhere in the four surfaces. The thinking status during a
    describe or photo call needs an AI spend, which this ticket does not make: ticket 31 checks it in its
    spends 1 and 2. The lead closes 27 when both halves pass.
12. **08-021.** Settings → Sign Out: record the dialog text, tap Cancel (still signed in), then Sign Out.
    Where it lands, and whether anything of the account stays visible or is offered "as a guest" as the
    dialog says. A dialog that promises something the app does not do is a bug Finding.

## What counts as a Finding

- A fix retest that fails: new bug Finding citing the old id.
- Any console error or exception line (or "known noise: <why>"; on this account TrainingPeaks and V.O2
  token Degradeds are known, Sentry ticket 22).
- A crash, a black screen, a screen with no way back, a signed-in screen reached signed out.
- Any write to the account. Look-around paths as followup-test Findings.

## Exit

- [ ] Findings filed with `node scripts/testing-wave/findings.mjs new 32 "<one line>" --round develop-2026-10 --kind bug|ssot-conflict|followup-test|idea --run RUN`, every field filled; `findings.mjs index --round develop-2026-10 --out "$TMPDIR/tw-32-index.md"` exits clean.
- [ ] `RUNS/notes.md` lists each check with `PASS <id>` or the new Finding's id, so the lead can close or keep each old Finding.
- [ ] No account was created (nothing to delete). Nothing written on the test account (Events count unchanged).
- [ ] `netcut.sh off SCRATCH`; background processes stopped by PID, log stream stopped, app terminated, `LOCK release slot testing-wave-32`. The simulator is left for the wave lead to drop.
- [ ] Console redacted (runbook § 9.4); only `console-redacted.log` is kept.
- [ ] `findings/32-*.md` and `runs/32/` committed on the ticket branch, explicit paths only.

## Added 2026-10-07 (Lee): the test account's dead integrations

`test@test.com` carries dead TrainingPeaks and V.O2 refresh tokens, so every run logs their failures
as known noise. Lee ruled that connecting and disconnecting integrations is part of testing. On this
account, after the other checks: Settings → Connected Apps: disconnect V.O2 (no test login exists);
disconnect TrainingPeaks, then connect it again with the TrainingPeaks test login from `CRED list`
(`cred.mjs type lee.tri --udid UDID` into the web sign-in sheet, runbook step 5's OAuth note), run
Sync Now, and confirm the `integrations` row is live (`status`, `requires_reauth`, `last_sync_at`;
SELECT with named columns, never the token columns) and that a relaunch logs no refresh failure.
Both writes are named here and allowed. Evidence: screenshots and `db-integrations-*.txt`.
