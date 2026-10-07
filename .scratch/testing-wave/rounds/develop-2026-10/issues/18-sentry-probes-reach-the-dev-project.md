# 18: The Sentry probes reach the dev project from this round's build

**Status:** ready (round develop-2026-10)
**Labels:** test, round:develop-2026-10, area:sentry
**Branch:** `develop-next`
**Source:** new; the device run of Sentry ticket 15 (`.scratch/sentry/issues/15-device-check-and-the-doc.md`),
repeated on the rebased branch's build
**Blocked by:** none.
**Next:** `/testing-wave develop-2026-10 --only 18`
**Model:** opus

**What to test:** On this round's build, the Debug console's Sentry probes each produce exactly the
event the reporting ladder promises, tagged with this build's release, in the dev project.

**Runs by:** `docs/testing-wave/RUNBOOK.md` on develop-next (until it lands there:
`git show origin/mealplanning:.scratch/testing-wave/RUNBOOK.md`). This round's paths: RUNS =
`.scratch/testing-wave/rounds/develop-2026-10/runs/18/`, Findings in
`.scratch/testing-wave/rounds/develop-2026-10/findings/`. One slot, console to RUNS, a look-around on
every screen, every problem a Finding, nothing fixed.

**Accounts:** the dev test account (a coach: its events carry `role:coach`). **App data:** cleared by
the wave lead.

## Where the buttons are (from code, unverified; confirm on screen)

Settings (gear on the Timeline header) → scroll to "Version X (N)" at the bottom → tap the version text
seven times → the "Developer / Tester" section appears (it shows by itself on a device already marked
internal) → "Debug console" (dev flavor only) → `DebugScreen` → expand "Sentry pipeline" → five buttons.
Code: `lib/features/settings/presentation/screens/settings_screen.dart` (`_handleVersionTap`,
`_buildTesterSection`), `debug_screen.dart`, `lib/features/settings/application/report_pipeline_probe.dart`.

| Button | Expected in the dev project (`docs/technical/sentry-integration.md` § Proving the pipeline on a device) |
|---|---|
| Throw a Fault | one `error` event, tags `severity:fault`, `area:debug`, `probe:fault` |
| Raise a Degraded | one `warning` event, `severity:degraded`, `probe:degraded` |
| Note, then throw | one `error` event, `probe:note_then_fault`, whose breadcrumbs carry the `note.debug` crumb "Debug screen: note before the Fault"; no event for the Note itself |
| Edge: bad payload | one event in environment `edge-dev`, tags `component:edge_function`, `edge_function:get-foods`; the app side records only a Note for the 400 |
| Crash (unhandled) | one `fatal`/`error` event, `handled: false`, mechanism `FlutterError` |

Every app event: `release` = `mealvana_endurance@<version>+<build>` for this build (read the version
and build from the Settings version label and write the expected string in `RUNS/expected.md`
before pressing anything), `environment` development, the Supabase user id, tags `role`, `device_id`,
`shorebird_patch:none`, a PostgREST `http` breadcrumb, no replay. Each Fault and Degraded also prints
one `📊 [ANALYTICS] error_reported {...}` line in the console (dev uses the echo tracker).

## Screens (from code, unverified)

| Screen | Entry | Code |
|---|---|---|
| Welcome → log in | `/welcome` → `/auth/post-onboarding?mode=login` → `/auth/email-login` | `lib/features/auth/presentation/screens/` |
| Timeline (header gear) | `/main` | `lib/shared/widgets/tabs_screen.dart` |
| Settings: version label, Developer / Tester section, "Debug console" row | `/settings` | `lib/features/settings/presentation/screens/settings_screen.dart` |
| Debug console, "Sentry pipeline" expansion with five buttons and a result line | `MaterialPageRoute` from the row | `lib/features/settings/presentation/screens/debug_screen.dart` |

## Expected records (`RUNS/expected.md`)

- Sentry, project `mealvana-endurance-dev`: exactly the five events in the button table above, each
  with this build's release (except the edge event, which carries environment `edge-dev`), the dev
  test account's user id, the listed tags and breadcrumbs, and no replay. Dev replay count unchanged.
- Console: one `📊 [ANALYTICS] error_reported` line per Fault and Degraded (three), none for the crash.
- Dev DB: none. The probes write no rows; the edge probe is refused by `get-foods` before any write.
- RevenueCat: none. No purchase or customer change in this ticket.

## Steps

1. Sign in. Reach the Debug console. Note the UTC time.
2. Press the five buttons in order, 10 seconds apart; screenshot the result line after each.
3. Query the dev project by API (org `milkman-24`, project `mealvana-endurance-dev`; token from
   `~/.sentryclirc`, read into a variable, never printed): events with tag `probe` in your window, and
   the `edge-dev` environment for `get-foods`. Save each event's JSON to RUNS after the runbook's token
   scan (§ 9.4 pattern). Record a table like ticket 15's: button, event id, issue id,
   level, release, tags, breadcrumb count.
4. Check the dev replay count did not move.
5. Do not resolve anything in Sentry. List the probe issue ids in `RUNS/notes.md` under "Probe issues":
   the lead resolves them as expected so the round's exit check ("no unresolved issue with an event
   from the round's build") is about real failures.

## What counts as a Finding

- A button that produces no event within two minutes, two events, the wrong level, a missing tag,
  the wrong release, or a replay.
- A Note that becomes its own event, or a Note-then-Fault event without the crumb.
- The edge probe landing in the app's environment, or not at all.
- Any other event that reaches the dev project during the run (startup Degradeds, the dev test
  account's TrainingPeaks/V.O2 token Degradeds): list them; file each one that is not already a known
  Sentry leftover (ticket 20 owns the leftovers list).
- Console errors; look-around paths as followup-test Findings.

## Exit

- [ ] Findings filed with `node scripts/testing-wave/findings.mjs new 18 "<one line>" --round develop-2026-10 --kind bug|ssot-conflict|followup-test|idea --run RUN`, every field filled; `findings.mjs index --round develop-2026-10 --out "$TMPDIR/tw-18-index.md"` exits clean.
- [ ] Every account this run made is deleted in the app and marked `CRED update <address> --state deleted` (`delete-failed` if it failed). An address that never finished signup goes under "Leftover accounts" in `RUNS/notes.md` with its auth user id.
- [ ] Background processes stopped by PID, log stream stopped, app terminated, `LOCK release slot testing-wave-18`. The simulator is left for the wave lead to drop.
- [ ] Console redacted (runbook § 9.4); only `console-redacted.log` is kept.
- [ ] `findings/18-*.md` and `runs/18/` committed on the ticket branch, explicit paths only.
