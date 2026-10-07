# 13: Connected apps: connect, sync and disconnect all five providers

**Status:** ready (round develop-2026-10)
**Labels:** test, round:develop-2026-10, area:integrations
**Branch:** `develop-next`
**Source:** new
**Blocked by:** none. Ticket 14 uses the same provider logins and must run in a later wave.
**Next:** `/testing-wave develop-2026-10 --only 13`
**Model:** opus

**What to test:** On a fresh account, each of Garmin Connect, TrainingPeaks, Final Surge, V.O2 and
Runna connects, imports, syncs on demand and disconnects. The database and the providers end where
the code says they should.

**Runs by:** `docs/testing-wave/RUNBOOK.md` on develop-next (until it lands there:
`git show origin/mealplanning:.scratch/testing-wave/RUNBOOK.md`). This round's paths: RUNS =
`.scratch/testing-wave/rounds/develop-2026-10/runs/13/`, Findings in
`.scratch/testing-wave/rounds/develop-2026-10/findings/`. One slot, console to RUNS, a look-around on
every screen, every problem a Finding, nothing fixed.

**Accounts:** one new `lee+e2e-13-<UTC time>@rightpathprogramming.com` (`CRED new`). Provider logins
come only from `CRED list`: look for a section per provider (Garmin, TrainingPeaks, Final Surge, V.O2,
Runna calendar URL). Use a provider login only if the credentials file marks it as a test athlete or as
authorised for testing (Lee, 2026-10-07: the TrainingPeaks login `lee.tri` is); never any other of Lee's own accounts. A provider with no login: one followup-test Finding ("needs a
<provider> test login in the credentials file") and move on. Provider API credentials for server-side
checks are in `secrets/integration_test.env` (main clone): never open, cat or print it; if a check needs
a value, load it into a variable without echoing, the way the runbook loads the Management token.

**App data:** cleared by the wave lead.

## Screens (from code, unverified)

| Screen | Entry | Code |
|---|---|---|
| Connected Apps (provider cards: Final Surge, TrainingPeaks, Garmin Connect, V.O2, Runna; Connect, Sync Now, Disconnect) | Settings → Connected Apps → `/settings/connected-apps` | `lib/features/settings/presentation/screens/connected_apps_screen.dart`, `lib/features/integrations/presentation/widgets/integration_provider_card.dart` |
| Provider sign-in sheets (out of process) | Connect | runbook § 5: coordinate taps from screenshots, one screenshot per tap |
| Import progress dialog | after a connect | `lib/features/integrations/presentation/widgets/import_progress_dialog.dart` |
| Disconnect dialog ("Disconnect <name>?") | Disconnect | `connected_apps_screen.dart` |
| TrainingPeaks write-back switch and its consent sheet | TrainingPeaks card | `lib/features/settings/presentation/widgets/tp_writeback_toggle_row.dart` |
| Timeline | imported workouts | ticket 09's table |

## Expected records (`RUNS/expected.md`)

Before writing it, read the columns of `integrations` and `garmin_user_mappings` from
`information_schema` and leave out every token column: `integrations` holds live access and refresh
tokens, and a star or a token column prints them (#85).

| After | `integrations` (provider, active flag, sync status, last sync, reauth flag) | Other |
|---|---|---|
| Each connect | one active row for the provider | Garmin: one `garmin_user_mappings` row (user id, Garmin user id, created_at) |
| Each sync | last sync stamped in UTC (the earlier round's 117-001 found local wall clock) | `activities` rows from that provider, counted by provider for the import window |
| Each disconnect | row inactive or gone (read the disconnect code first and write which) | provider's future activities: kept or removed, per the code |

Garmin disconnect on develop-next asks `garmin-user-mapping` to drop only our row; nothing calls
Garmin's deregistration endpoint (from code: no `user/registration` call in
`supabase/functions/garmin-user-mapping`, `delete-user` or `_shared/garmin`). So Garmin may keep pushing
for that Garmin user. Check `garmin-push` edge logs for that Garmin user id for 10 minutes after the
disconnect. Pushes logged as errors (`no_user_mapping`) are a bug Finding; the earlier round filed the
same thing as 112-010 / 121-010, and the fix lives only on mealplanning.

## Steps

1. Sign up. Settings → Connected Apps: five cards, none connected.
2. For each provider with a test login, in this order: Final Surge, TrainingPeaks, V.O2, Garmin, Runna.
   a. Connect. Drive the sheet by coordinates; `CRED type` the password once the field has focus.
   b. "<name> connected! Importing workouts..." then the import dialog. SQL the row; count imported
      activities; open the Timeline and find two of them on their days.
   c. Sync Now. Record the snackbar. SQL: last sync moved, in UTC.
   d. TrainingPeaks only: turn the write-back switch on, read the consent sheet, turn it off again.
      (Ticket 14 tests writes.)
3. Garmin only: before connecting, record which dev user (if any) already holds this Garmin user's
   mapping (user id, created_at; no tokens). Connecting may take it over; write who held it after.
4. Disconnect each provider. "<name> disconnected". SQL the end state. Garmin: watch the push log.
5. Delete the account in the app. SQL: no `integrations` or `garmin_user_mappings` row left for it.

## What counts as a Finding

- A connect that ends without a row, a row without a connect, a sheet that cannot be completed.
- An import that lands nothing for a provider whose test athlete has workouts in the window, or lands
  them on the wrong day.
- "Last synced" stamped on a failed sync, or in local time.
- Disconnect or account delete that leaves a provider pushing or a mapping behind.
- Console errors; look-around paths (re-connect after disconnect, connect offline, cancel mid-sheet)
  as followup-test Findings.

## Exit

- [ ] Findings filed with `node scripts/testing-wave/findings.mjs new 13 "<one line>" --round develop-2026-10 --kind bug|ssot-conflict|followup-test|idea --run RUN`, every field filled; `findings.mjs index --round develop-2026-10 --out "$TMPDIR/tw-13-index.md"` exits clean.
- [ ] Every account this run made is deleted in the app and marked `CRED update <address> --state deleted` (`delete-failed` if it failed). An address that never finished signup goes under "Leftover accounts" in `RUNS/notes.md` with its auth user id.
- [ ] Background processes stopped by PID, log stream stopped, app terminated, `LOCK release slot testing-wave-13`. The simulator is left for the wave lead to drop.
- [ ] Console redacted (runbook § 9.4); only `console-redacted.log` is kept.
- [ ] `findings/13-*.md` and `runs/13/` committed on the ticket branch, explicit paths only.
