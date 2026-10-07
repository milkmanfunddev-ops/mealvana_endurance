# 19: Coach mode: the portal at phone width, pairing, and writes that wait for the server

**Status:** ready (round develop-2026-10)
**Labels:** test, round:develop-2026-10, area:coach-mode, remote-ack
**Branch:** `develop-next`
**Source:** new; the portal layout fix is Sentry ticket 24a (DEV-5S)
**Blocked by:** none.
**Next:** `/testing-wave develop-2026-10 --only 19`
**Model:** opus

**What to test:** A coach opens the portal on a phone-sized screen without layout errors, pairs with a
new athlete by code, creates and edits the athlete's event, activity and carb-loading plan, and each
of those writes reports success only after the server has it. The athlete then sees the coach's work,
and both sides chat.

**Runs by:** `docs/testing-wave/RUNBOOK.md` on develop-next (until it lands there:
`git show origin/mealplanning:.scratch/testing-wave/RUNBOOK.md`). This round's paths: RUNS =
`.scratch/testing-wave/rounds/develop-2026-10/runs/19/`, Findings in
`.scratch/testing-wave/rounds/develop-2026-10/findings/`. One slot, console to RUNS, a look-around on
every screen, every problem a Finding, nothing fixed.

**Accounts:** the coach is the dev test account (`test@test.com`, role coach). The athlete is one new
`lee+e2e-19-<UTC time>@rightpathprogramming.com`. One simulator: switch accounts by signing out and in.
Other tickets use the dev test account in the same wave; touch only this athlete's data.

**App data:** cleared by the wave lead.

**Rule under test (CLAUDE.md, `docs/technical/write-consistency-policy.md`):** a coach writing an
athlete's data must get the server's acknowledgement before showing success or navigating. Offline, the
write fails with a retry path and nothing is saved locally as if it had worked. Athlete self-service
stays offline-first.

## Screens (from code, unverified)

| Screen | Entry | Code |
|---|---|---|
| Coach portal (sidebar: athletes, "Generate Athlete Code" / "Generate Pairing Code", Messages, Reports; athlete panel tabs Profile, Targets, Events, Carb Loading, Activities, Chat) | web route; on a phone only by deep link `xcrun simctl openurl UDID "com.milkman.mealvanaendurance:///coach-portal"` | `lib/features/coach_mode/presentation/screens/coach_portal_screen.dart`, `widgets/portal_sidebar.dart`, `widgets/portal_athlete_detail_panel.dart` |
| Coach creates an athlete event | panel "+" → `/events/create` with `forUserId` | `lib/features/events/presentation/screens/event_form_screen.dart`, `lib/features/events/application/events_service.dart` |
| Coach creates / opens an athlete activity | `/distancepacegut` with `forUserId`; `/plan` with `isCoachView` | `new_activity_screen.dart`, `activity_detail_screen.dart`, `lib/features/coach_mode/presentation/providers/coach_activity_detail_controller.dart` (writes marked `remoteAckRequired`) |
| Coach carb loading: create dialog, day detail, food picker, custom food | Carb Loading tab | `widgets/create_carb_loading_dialog.dart`, `lib/features/carb_loading/presentation/screens/{carb_loading_day_detail_page,carb_loading_food_selection_screen,create_custom_carb_loading_food_screen}.dart` (`/carb-loading-select-food`, `create-custom-carb-loading-food`) |
| Coach targets form | Targets tab | `widgets/portal_nutrition_targets_form.dart` |
| Athlete: Coach Connection ("Enter Coach Code", "Message Coach", "Disconnect from Coach") | Settings → Coach Connection → `/settings/coach-connection` | `lib/features/settings/presentation/screens/coach_connection_screen.dart` |
| Athlete: My Coaches → Coach Directory | Settings → My Coaches → `/my-coaches` → `/coach-directory` | `my_coaches_screen.dart`, `coach_directory_screen.dart` |
| Chat (both sides) | `/chat/:relationshipId` | `coach_chat_screen.dart` |

Below `CoachPortalScreen.minLayoutWidth` (the medium breakpoint) the portal keeps its desktop layout
inside a horizontal scroll (Sentry ticket 24a). The coach portal reads athlete carb progress from
`logged_carbs_grams`, which the carb spec lists as known-broken and out of scope: note a 0 g reading,
do not file it as new.

## Expected records (`RUNS/expected.md`)

Columns from `information_schema` first. `coach_athlete_relationships` (coach, athlete, status,
timestamps); the code tables (`coach_pairing_codes` or `athlete_pairing_codes`, whichever the flow
writes); `events`, `activities`, `carb_loading_plans`, `carb_loading_days` rows owned by the athlete's
user id; `coach_messages` rows for each chat line.

## Steps

1. Sign up the athlete (onboarding with run, real weight). Sign out.
2. Sign in as the coach. Open the portal by deep link. Console: no `RenderFlex overflowed` line. Scroll
   the portal sideways and down; open every sidebar item and every panel tab on an existing athlete
   (read only). Screenshot each.
3. Generate a pairing code; write it in notes. Sign out. Sign in as the athlete → Coach Connection →
   type a wrong code (record the message), then the right one: "Connected to coach!". SQL the
   relationship. My Coaches → Coach Directory renders. "Message Coach": send one line.
4. Sign out; sign in as the coach; portal → the new athlete appears; Chat shows the athlete's line;
   reply.
5. Remote-ack checks, each first offline then online. Offline: `netcut.sh launch UDID SCRATCH` once at
   the start of this step, then `netcut.sh on SCRATCH` before each write and `off` after.
   a. Event: panel "+" → create an event for the athlete. Offline: an error with a way to retry, no
      "Event created", no navigation; SQL no row. Online: "Event created" only once the row exists;
      SQL at once.
   b. Activity: Activities → create one for tomorrow; open it (coach view), change a food quantity and
      save. Same offline/online checks; online "Changes saved successfully!" and back to the portal.
   c. Carb Loading: create a plan for the athlete's event (dialog). Same checks ("Carb loading plan
      created"). Open a day (`CarbLoadingDayDetailPage`) → add a food from the picker → create a custom
      food. Then delete the plan ("Carb loading plan deleted").
   d. Targets: change one target and save ("Nutrition targets saved"); reset to defaults.
6. EventDetailScreen at phone width (the second half of DEV-5S): open the athlete's event from the
   panel; console has no overflow.
7. Sign out; sign in as the athlete. The coach's event and activity show on Events and the Timeline.
   Chat shows the coach's reply. Disconnect from Coach: SQL status. Delete the athlete account; SQL:
   the relationship and the athlete's rows are gone.
8. Web half: only if the wave lead's prompt names a running web build (`:8080`). Then open the portal in
   Chrome at 390 px wide and repeat step 2. Without one, write a followup-test Finding ("coach portal at
   phone width on web").

## What counts as a Finding

- A coach write that shows success or navigates before the row exists, or that "succeeds" offline.
- An offline coach write with no retry path, or one that silently queues and uploads later.
- Any overflow or layout error in the portal or EventDetailScreen at phone width.
- A pairing code that fails for the right code or passes for a wrong one; a relationship row that
  disagrees with the screens.
- Console errors; look-around paths (coach removes athlete, two coaches, athlete offline edits after a
  coach edit) as followup-test Findings.

## Exit

- [ ] Findings filed with `node scripts/testing-wave/findings.mjs new 19 "<one line>" --round develop-2026-10 --kind bug|ssot-conflict|followup-test|idea --run RUN`, every field filled; `findings.mjs index --round develop-2026-10 --out "$TMPDIR/tw-19-index.md"` exits clean.
- [ ] Every account this run made is deleted in the app and marked `CRED update <address> --state deleted` (`delete-failed` if it failed). An address that never finished signup goes under "Leftover accounts" in `RUNS/notes.md` with its auth user id.
- [ ] Background processes stopped by PID, log stream stopped, app terminated, `LOCK release slot testing-wave-19`. The simulator is left for the wave lead to drop.
- [ ] Console redacted (runbook § 9.4); only `console-redacted.log` is kept.
- [ ] `findings/19-*.md` and `runs/19/` committed on the ticket branch, explicit paths only.
