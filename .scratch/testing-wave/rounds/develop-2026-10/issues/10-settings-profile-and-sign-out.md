# 10: Settings, profile and sign-out

**Status:** ready (round develop-2026-10)
**Labels:** test, round:develop-2026-10, area:settings
**Branch:** `develop-next`
**Source:** testing-wave 31 (`origin/mealplanning`), widened to every Settings sub-screen
**Blocked by:** 09 (changes a setting on the account 09 reads; run in a later wave).
**Next:** `/testing-wave develop-2026-10 --only 10`
**Model:** opus

**What to test:** The athlete opens every Settings screen, changes one profile setting and sees it kept
after a relaunch and on the server, puts it back, then signs out.

**Runs by:** `docs/testing-wave/RUNBOOK.md` on develop-next (until it lands there:
`git show origin/mealplanning:.scratch/testing-wave/RUNBOOK.md`). This round's paths: RUNS =
`.scratch/testing-wave/rounds/develop-2026-10/runs/10/`, Findings in
`.scratch/testing-wave/rounds/develop-2026-10/findings/`. One slot, console to RUNS, a look-around on
every screen, every problem a Finding, nothing fixed.

**Accounts:** the dev test account. **App data:** cleared by the wave lead.

## Screens (from code, unverified)

All reached from Settings (`/settings`, gear on the Timeline header), `settings_screen.dart`:

| Row | Route | Screen |
|---|---|---|
| Profile & Preferences | `/settings/preferences` → sweat profile `/settings/sweat-profile` | `PreferencesScreen`, `SweatProfileScreen` |
| Appearance | dialog/sheet on the row | in `settings_screen.dart` |
| Diet, Allergies & Formulas | `/settings/food-preferences-hub` → `/settings/dietary-preference`, `/settings/allergies`, `/settings/food-preferences` (→ `food-detail`), `/settings/food-preferences/formula-library` (→ `before|during|after/:id`, `personal/create`) | `FoodPreferencesHubScreen`, onboarding `DietaryPreferenceScreen`/`AllergiesScreen`, `FoodPreferencesScreen`, `FoodDetailScreen`, `FormulaLibraryScreen`, `FormulaDetailScreen`, `FormulaEditorScreen` |
| Sport Preferences | `/settings/sport-preferences-hub` → `/settings/running-details`, `/settings/cycling-details`, `/settings/swimming-details` | `SportPreferencesHubScreen` + onboarding detail screens |
| Body Composition | `/settings/nutrition-profile` | `NutritionProfileScreen` |
| Nutrition Targets | `/settings/nutrition-targets` | `NutritionTargetsScreen` |
| Privacy | `/settings/privacy` | `PrivacySettingsScreen` |
| Help & Feedback | `/help` | `HelpFeedbackScreen` |
| Account: sign out | in `settings_screen.dart` → `/welcome` | — |

Coach Connection and Connected Apps belong to tickets 19 and 13; open them once here only to check
they render.

## Expected records (`RUNS/expected.md`)

- Pick one Profile & Preferences field that writes to `users` (read the screen's save method first and
  name the column). Before, after the change, after putting it back: by SQL.
- Formula editor: if you create a personal formula, its row (read the repository first); delete it at
  the end and check it is gone.

## Steps

1. Sign in. Open each row above, one screen at a time; screenshot and read the console after each.
2. Change the chosen field. Save. Relaunch: kept on screen. SQL: kept on the server. If it is still
   local-only after a minute online, that is a bug (the earlier round's 119-001).
3. Put it back; SQL again.
4. Appearance: switch Light, read the Timeline (the earlier round found it unreadable, 119-003), switch
   back to the starting mode.
5. Formula library: open one Before, During and After formula; create a personal formula, then delete
   it. Record whether the coach-insight panel shows (behind `COACH_INSIGHTS_ENABLED`, off by default).
6. Sign out. Land on Welcome. Sign back in: the account's data returns.

## What counts as a Finding

- A setting that does not persist, persists only locally, or shows a different value after relaunch.
- A row that opens nothing, opens the wrong screen, or cannot be backed out of.
- Settings showing "Error loading settings" (Sentry ticket 15 fixed one cause on the way).
- Console errors; look-around paths as followup-test Findings.

**Earlier Findings for the source ticket:**
`git ls-tree --name-only origin/mealplanning .scratch/testing-wave/findings/ | grep '/31-'`. Read the
titles first. Most of that round's fixes never reached develop-next, so a recurrence cites the old id
under Evidence.

## Exit

- [ ] Findings filed with `node scripts/testing-wave/findings.mjs new 10 "<one line>" --round develop-2026-10 --kind bug|ssot-conflict|followup-test|idea --run RUN`, every field filled; `findings.mjs index --round develop-2026-10 --out "$TMPDIR/tw-10-index.md"` exits clean.
- [ ] Every account this run made is deleted in the app and marked `CRED update <address> --state deleted` (`delete-failed` if it failed). An address that never finished signup goes under "Leftover accounts" in `RUNS/notes.md` with its auth user id.
- [ ] Background processes stopped by PID, log stream stopped, app terminated, `LOCK release slot testing-wave-10`. The simulator is left for the wave lead to drop.
- [ ] Console redacted (runbook § 9.4); only `console-redacted.log` is kept.
- [ ] `findings/10-*.md` and `runs/10/` committed on the ticket branch, explicit paths only.
