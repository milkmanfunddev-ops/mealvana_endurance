# 17: Notification surfaces and the carb-loading race-window nudge

**Status:** ready (round develop-2026-10)
**Labels:** test, round:develop-2026-10, area:notifications, area:carb-loading
**Branch:** `develop-next`
**Source:** new; the nudge is carb-loading G27 (CE-11), `.scratch/carb-loading/spec.md` § "G27 GREEN"
**Blocked by:** none.
**Next:** `/testing-wave develop-2026-10 --only 17`
**Model:** opus

**What to test:** What an athlete sees from the app's notifications on a simulator: the permission
prompt, the push stack starting (or saying why it did not), the carb-loading nudge's on-open catch-up
and its tap into the event, and the nudge disarming when a plan exists and re-arming when it is
removed.

**Runs by:** `docs/testing-wave/RUNBOOK.md` on develop-next (until it lands there:
`git show origin/mealplanning:.scratch/testing-wave/RUNBOOK.md`). This round's paths: RUNS =
`.scratch/testing-wave/rounds/develop-2026-10/runs/17/`, Findings in
`.scratch/testing-wave/rounds/develop-2026-10/findings/`. One slot, console to RUNS, a look-around on
every screen, every problem a Finding, nothing fixed.

**Read first, and what is missing.** CLAUDE.md says anyone touching notifications, scheduling or deep
links, testing included, reads the `notification-testing` skill and the push-stack fact sheet first.
On develop-next, `.claude/skills/notification-testing/` does not exist (the branch has only
`device-sweep`, `drive-device`, `shorebird-patch`), and `../ops/docs/messaging-relay-and-testing.md`
does not exist either (there is no `ops` checkout beside the repo). File one `idea` Finding that says
both are missing, so the lead adds it to IMPROVEMENTS, and work from the code below. Do not invent a
push setup: anything that needs OneSignal or APNs from outside stays a followup-test for Lee's phone
(the round's spec allows push taps there).

**Accounts:** one new `lee+e2e-17-<UTC time>@rightpathprogramming.com` (onboarding with run).
**App data:** cleared by the wave lead. **Cost:** no AI call.

## What the code does (from code, unverified)

- `NotificationService` (`lib/shared/services/notification_service.dart`): local notifications on the
  reminders channel, OneSignal for remote push, and payload routing (`<type>:<id>`, e.g.
  `activity:<id>`, `carb_event:<eventId>`).
- The nudge (`lib/features/carb_loading/application/carb_load_nudge_service.dart`, copy in
  `CarbNudgeEngine`): for an event with no carb plan, local notifications at 06:00 local on race day −3,
  −2 and −1 (never race day). On app open or resume inside that window with no plan and nothing shown
  today, it shows one at once (catch-up). At most one a day across both paths. Creating a plan disarms;
  deleting one re-arms. Tapping opens `/events/:eventId` (`EventDetailScreen`, with "Set Up Carb
  Loading").
- D9 (CLAUDE.md): a silent path in the push stack must record that it ran. The 1.29.0 case was an empty
  OneSignal app id that returned silently and disabled push for every fresh install.

## Steps

1. Sign up. Record when iOS asks for notification permission (first sign-in, first launch after, or
   never). Allow.
2. Console: find what the push stack said at startup: OneSignal initialised, or a recorded reason it
   was skipped. Never write the app id into notes. Silence on that path is a bug (D9).
3. Create a marathon event 2 days from today (inside the −3…−1 window) with no carb plan. Send the
   app to the background (Home, with the mobile MCP's `mobile_press_button`) and bring it back: a nudge
   shows now (catch-up). Screenshot the banner or Notification Center. Its words match `CarbNudgeEngine`
   and the CE-11 register in `docs/ssot/spec/fueling/carb-loading.md` (quote it in any ssot-conflict).
4. Background and foreground twice more: no second nudge today. Relaunch the app: still none.
5. Tap the nudge in Notification Center: the app opens on that event's detail with "Set Up Carb
   Loading".
6. Set up a plan (any protocol that fits). Background, foreground: no nudge. Remove the plan
   ("Remove carb loading plan"): the sweep re-arms; today's nudge was already shown, so expect none
   today; write that the 06:00 fires are "not seen live".
7. Create an event 10 days out: no nudge. Create one dated today: no nudge (never race day).
8. Delete the events and the account.

## What counts as a Finding

- A nudge outside the window, on race day, twice in a day, or after a plan exists.
- A tap that lands anywhere but the event's detail.
- A permission prompt that never comes, or comes at a moment that makes no sense (record which).
- A push-stack startup path that records nothing (D9).
- The missing skill and fact sheet (one `idea` Finding).
- Console errors; look-around paths (time zone change, notifications denied, scheduled fires,
  remote push taps) as followup-test Findings.

## Exit

- [ ] Findings filed with `node scripts/testing-wave/findings.mjs new 17 "<one line>" --round develop-2026-10 --kind bug|ssot-conflict|followup-test|idea --run RUN`, every field filled; `findings.mjs index --round develop-2026-10 --out "$TMPDIR/tw-17-index.md"` exits clean.
- [ ] Every account this run made is deleted in the app and marked `CRED update <address> --state deleted` (`delete-failed` if it failed). An address that never finished signup goes under "Leftover accounts" in `RUNS/notes.md` with its auth user id.
- [ ] Background processes stopped by PID, log stream stopped, app terminated, `LOCK release slot testing-wave-17`. The simulator is left for the wave lead to drop.
- [ ] Console redacted (runbook § 9.4); only `console-redacted.log` is kept.
- [ ] `findings/17-*.md` and `runs/17/` committed on the ticket branch, explicit paths only.
