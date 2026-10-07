# 16: Events, the race checklist and carb loading

**Status:** ready (round develop-2026-10)
**Labels:** test, round:develop-2026-10, area:events, area:carb-loading
**Branch:** `develop-next`
**Source:** new; carb-loading surfaces from Xuan's G-series (`.scratch/carb-loading/spec.md` on
develop-next, ratified specs under `docs/ssot/spec/fueling/carb-loading*.md`)
**Blocked by:** none.
**Next:** `/testing-wave develop-2026-10 --only 16`
**Model:** opus

**What to test:** The athlete creates, edits and deletes an event; builds its race checklist; sets up a
carb-loading plan from the event and lives through loading day 1 on the Timeline: the LOAD face, the
slot cards, a slot's page, a one-tap log, the breakdown, an edited day target, a protocol change, and
deleting the plan. Screens, the database and the ratified copy agree.

**Runs by:** `docs/testing-wave/RUNBOOK.md` on develop-next (until it lands there:
`git show origin/mealplanning:.scratch/testing-wave/RUNBOOK.md`). This round's paths: RUNS =
`.scratch/testing-wave/rounds/develop-2026-10/runs/16/`, Findings in
`.scratch/testing-wave/rounds/develop-2026-10/findings/`. One slot, console to RUNS, a look-around on
every screen, every problem a Finding, nothing fixed.

**Accounts:** one new `lee+e2e-16-<UTC time>@rightpathprogramming.com`, onboarding with run and a real
weight (the carb targets are g/kg). **App data:** cleared by the wave lead. **Cost:** no AI call.

## Screens (from code, unverified)

| Screen | Entry | Code |
|---|---|---|
| Events tab; event card (Delete Event) | tab 1 | `lib/features/events/presentation/screens/events_list_screen.dart`, `widgets/event_list_card.dart` |
| New / Edit Event (name, date, start time, goal time, Goal Pace or Goal Speed (mph) for cycling, location, bib, registration URL) | `/events/create`; "Edit Event" | `event_form_screen.dart` |
| Event detail ("Create / View Nutrition Plan", "Set Up Carb Loading" / "Carb Loading Plan" / "Carb loading window has passed", "Race Day Checklist") | `/events/:eventId` | `event_detail_screen.dart`, `widgets/event_action_buttons_card.dart` |
| Race Day Checklist ("Add Custom Item") | `/events/:eventId/checklist` | `lib/features/race_checklist/presentation/screens/race_checklist_screen.dart` (stored in the local database only, from code) |
| Protocol chooser (3-Day Classic, 2-Day Quick, 1-Day; disabled with "Needs N days" when it does not fit) | "Set Up Carb Loading" | `lib/features/carb_loading/presentation/screens/carb_loading_protocol_selection_screen.dart` |
| Carb Loading Plan summary page (DAY rows, g and g/kg, EDITED chip, "Change protocol") and the repick dialogs ("Keep your edited targets?" Keep my targets / Reset to protocol; "Edited target won’t carry over") | "Carb Loading Plan" | `carb_plan_summary_screen.dart`, `widgets/carb_repick_dialogs.dart` |
| Timeline on a loading day: LOAD face on the energy card, `CarbLoadBar`, slot cards | `/main` | `macro_dashboard_screen.dart`, `lib/shared/widgets/kyle_design/` |
| Slot page (⊕ one-tap log, Log a meal) | tap a slot card | `carb_slot_screen.dart` |
| Carbs breakdown ("By meal", "Protocol", "Manage plan" footer) | the LOAD face's breakdown | `carb_breakdown_screen.dart` |

Ratified rules to hold the screens to (quote them word for word in an ssot-conflict Finding):
`docs/ssot/spec/fueling/carb-loading.md`, `carb-loading-entryway.md`,
`docs/ssot/spec/design/components/carb-slot-card.md`, `energy-card.md`. The spec's copy register is
verbatim ("N g behind pace", "N g ahead of pace", "On pace", "N g to go", "Target met" when loaded).
A backdrop tap on either repick dialog aborts: dialog closed, plan untouched, chooser still open
(CE-9). Past day rows on the summary are inert; today and future rows open the Edit Target dialog
(G17). Coach mode is out of scope here (ticket 19).

## Expected records (`RUNS/expected.md`)

Read the columns of `events`, `carb_loading_plans`, `carb_loading_days`, `meal_logs` and `activities`
from `information_schema` first.
- Event: one `events` row; after edit, the new date and name (date edits persist: release fix
  `acbc2960`). With a nutrition plan created from the event, the linked `activities` row moves with the
  event's date (pick `418b9c80`).
- Carb plan (3-Day Classic, race in 3 days, so today is Day 1): one `carb_loading_plans` row and three
  `carb_loading_days` rows whose targets are each day's rate × the account's weight in kg, whole grams.
  Read the rates from the chooser's cards and from the spec; a mismatch between them is an
  ssot-conflict.
- After a day-target edit: that day's grams and its stored g/kg change; EDITED shows.
- After the one-tap log: one `meal_logs` row with the slot set and the resolved food (the code logs
  with method `carb_slot_recommendation`, from code).
- After delete plan: no plan or day rows for the event. After delete event: no event row.

## Steps

1. Sign up. Events tab → new event: a marathon 3 days from today, a goal time. Create.
   Then a cycling event: the form asks for Goal Speed (mph), not pace. Save it, then delete it from its
   card.
2. Marathon detail → Create Nutrition Plan (record the linked activity). Edit Event: move the date one
   day later and back. SQL: event and linked activity move together.
3. Race Day Checklist: let it generate, tick three items, add a custom item. Relaunch: still ticked.
4. Set Up Carb Loading → chooser. Record which protocols are enabled and the reason on any disabled
   one. Pick 3-Day Classic. Back on event detail: "Carb Loading Plan". SQL the plan and days.
5. Summary page: today's row → Edit Target → change by 20 g → save. EDITED shows; SQL. A past row (none
   yet on Day 1) is not tested here; write it as a followup-test.
6. Change protocol → 2-Day Quick: the "Keep your edited targets?" dialog. Tap the backdrop: aborts
   (CE-9). Change again → Reset to protocol. SQL. Change back to 3-Day Classic.
7. Timeline today: the LOAD face with the pace verdict, the loading bar and the slot cards. Record
   every string against the register. Open one slot: ⊕ one-tap log a recommended food. SQL. Back on the
   Timeline the verdict and the bar move by that food's carbs.
8. Open the breakdown: By meal, Protocol, then "Manage plan" opens the summary.
9. Summary → "Remove carb loading plan" → "Remove". SQL. The Timeline loses the LOAD face.
10. A second event 1 day out: the chooser shows the window state the spec rules for it; record it.
    Delete both events and the account.

## What counts as a Finding

- Any carb number that differs from rate × kg, from the stored row, or between the summary, the
  Timeline and the breakdown.
- A string not in the ratified register (ssot-conflict, quote the spec), a glow or colour off the
  component spec.
- A repick that changes the plan on a backdrop tap; an edit that does not persist.
- An event date edit that does not persist or leaves its activity behind.
- A checklist that forgets ticks after a relaunch.
- Console errors; look-around paths (offline edit, a race day in the past, two events in one week) as
  followup-test Findings.

## Exit

- [ ] Findings filed with `node scripts/testing-wave/findings.mjs new 16 "<one line>" --round develop-2026-10 --kind bug|ssot-conflict|followup-test|idea --run RUN`, every field filled; `findings.mjs index --round develop-2026-10 --out "$TMPDIR/tw-16-index.md"` exits clean.
- [ ] Every account this run made is deleted in the app and marked `CRED update <address> --state deleted` (`delete-failed` if it failed). An address that never finished signup goes under "Leftover accounts" in `RUNS/notes.md` with its auth user id.
- [ ] Background processes stopped by PID, log stream stopped, app terminated, `LOCK release slot testing-wave-16`. The simulator is left for the wave lead to drop.
- [ ] Console redacted (runbook § 9.4); only `console-redacted.log` is kept.
- [ ] `findings/16-*.md` and `runs/16/` committed on the ticket branch, explicit paths only.
