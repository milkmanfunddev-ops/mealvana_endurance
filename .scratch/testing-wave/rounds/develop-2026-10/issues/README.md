# Round develop-2026-10: the ticket set

Test tickets for the round-up of `develop-next` (spec: `.scratch/develop-roundup/spec.md` § 2). Every
ticket runs by `docs/testing-wave/RUNBOOK.md`, files Findings with
`findings.mjs new NN … --round develop-2026-10`, and ends with the same exit: Findings filed, created
accounts deleted, lock released, simulator left for the lead, `findings/` and `runs/NN` committed.

Every screen named in a ticket was checked against `lib/` on `develop-next` at `a0cc8145` (route in
`lib/shared/core/app_router.dart`, or the widget that pushes it). Code maps in the tickets say "from
code, unverified": the screen decides.

## Tickets

| # | Title | Source | Account | Notes |
|---|---|---|---|---|
| 01 | Delete account, plus-address signup and the account sweep | mealplanning 02 | new | paywall-menu, Gate and Patrol steps dropped; adds the UK-region consent pass |
| 02 | Logging a meal by describing it | mealplanning 23 | test@test.com | 1 AI call; via the Log a meal sheet |
| 03 | Logging a meal from a photo in the library | mealplanning 24 | test@test.com | 1 AI call; via the sheet's Gallery |
| 04 | Logging manually and building a meal | mealplanning 25 | test@test.com | |
| 05 | Logging from Recent, Common and Recipes | mealplanning 26 | test@test.com | |
| 06 | Editing and deleting a logged meal changes the day's totals | mealplanning 27 | test@test.com | made self-contained, no longer blocked by 05 |
| 07 | Barcode logging on a simulator | mealplanning 28 | test@test.com | likely ends in a followup-test for Lee's phone |
| 08 | Cold start: leftover data, every tab, and every route-only screen | mealplanning 29 | sim leftover, then test@test.com | app data NOT cleared; carries the HANDOFF's owed v21 cold start |
| 09 | The timeline and the fuelling plan show the week | mealplanning 30 | test@test.com | read only |
| 10 | Settings, profile and sign-out | mealplanning 31 | test@test.com | blocked by 09; widened to every Settings sub-screen |
| 11 | Signup with the emailed code, and forgot password | mealplanning 32 | new | lands on the Timeline, not a paywall |
| 12 | AI credits: the balance, the out-of-credits wall, and a spend | new | new | up to 3 AI calls; one named SQL write (drain own wallet) |
| 13 | Connected apps: connect, sync and disconnect all five providers | new | new | provider test logins from `CRED list` |
| 14 | A dead Garmin token, and the TrainingPeaks write-back edit window | new (Sentry 19 + 22 device checks) | new | blocked by 13 |
| 15 | Activities and bricks: create, plan, edit, log fuel, delete | new | new | |
| 16 | Events, the race checklist and carb loading | new (carb-loading G-series) | new | |
| 17 | Notification surfaces and the carb-loading race-window nudge | new (carb-loading G27) | new | notification-testing skill and ops fact sheet missing on develop-next |
| 18 | The Sentry probes reach the dev project from this round's build | new (Sentry 15) | test@test.com | probe issues handed to the lead to resolve |
| 19 | Coach mode: the portal at phone width, pairing, and writes that wait for the server | new (Sentry 24a) | test@test.com + new | web half only if the lead runs a web build |
| 20 | (reserved: the Sentry leftovers ticket, written separately) | spec § 4 | — | — |
| 21 | Signup and verify-email fixes | fix: 01-002, 01-003, 01-005, 01-009 | — | after 29 |
| 22 | Timestamps and startup telemetry | fix: 01-004, 01-006, 08-009 | — | after 29; not with 21 |
| 23 | AI credits work as intended on develop | fix: 02-001, 02-002 | — | after 29; dev-only wallet SQL by the lead (breaks mealplanning's Vana on dev until Phase B: Lee's call) |
| 24 | Meal review saves the note and keeps quantity separate | fix: 02-003, 02-005 | — | after 29 |
| 25 | Edge logs through the Supabase MCP; delete edge_logs.sh | fix: 02-004, 01-013 | — | no overlap |
| 26 | Archive the route-only orphan screens | fix: 08-003/004/005/010/011/012/014 | — | after 29; with or before 27 |
| 27 | Archive Jade | fix: 08-001, 08-002, 08-006 | — | after 29 and 26 |
| 28 | Guards: launch trail and events padding | fix: 08-007, 01-011, 08-008 | — | after 29 (08-008 may land in 29) |
| 29 | Backport the mealplanning round's shared fixes | fix: 08-025 + ~27 BUGS rows + 67 ticket items | — | **runs first and alone**; ~45 commits, sequential agents by area |
| 30 | Retest: auth and account | 01-007, 01-010, 01-014..018 + 21/22 retests | new | wave 3, 13 checks (30a/30b) |
| 31 | Retest: meal logging | 02-006..012 + 24 retests | test@test.com | wave 3, 3 spends |
| 32 | Retest: startup, tabs and deep links | 08-016..023 + 26/27/28/22 retests | test@test.com | wave 3, 13 checks |
| 33 | Retest: cross-device and leftovers | 08-024, 01-012 | test@test.com + new | wave 3, two simulators |

Ordering: 10 after 09; 14 after 13. Fix wave (2026-10-07 triage): 29 alone first, then 21–28 by their Overlaps lines; wave 3 = 30–33 plus the untouched test tickets 03–07, 09–19. Tickets 02–07, 09, 10 and 18 share test@test.com; their prompts
must say which rows each one writes (runbook, "The wave lead's routine", step 5).

## Dropped from the source set

mealplanning 01 (harness: replaced by `docs/testing-wave/`), 03 (Patrol: no Patrol in runs), 04–13
(subscription paywall, Test Store subscriptions, redeem codes, Pro gate: not on develop-next), 14–22
(Plans, Vana, Shopping, Kroger: not on develop-next). No kept ticket was dropped for a missing screen.
Inside kept tickets: 02's paywall ⋯-menu delete and "the Gate treats the new user as never paid", and
32's "lands on the paywall", are gone because develop-next has no paywall.

## Screens no ticket covers (feeds COVERAGE.md)

Method: every `class …Screen`/`…Page` under `lib/features/*/presentation` and `lib/shared`, checked for
a route in the router and for any widget that constructs or navigates to it; then each route checked
for a caller. From code at `a0cc8145`; `_archived/` ignored.

**No way in at all (built nowhere, routed nowhere).** Candidates to wire up or delete, not to test:
- `AthleteDetailScreen` (`coach_mode`), superseded by the portal's athlete panel.
- `CoachDashboardScreen` (`coach_mode`), superseded by `CoachPortalScreen`.
- `CyclingInputScreen`, `SwimmingInputScreen` (`nutrition_plan`), superseded by `NewActivityScreen`.
- `RecipesScreen` (`recipes`); the Log a meal sheet's Recipes tab replaced it.
- `SettingsMenuScreen` (`settings`); its links go to `/settings/profile` and `/settings/help`, which are
  not routes, and to `/settings/sport-settings`, whose only other way in is a deep link.
- `ShareNutritionPlanScreen` (`sharing`).
- `MacroDashboardScreen` (the class; the Timeline mounts `MacroDashboardBody` from the same file, which
  09 covers).

**Reachable, but no ticket walks them:**
- `ForceUpgradeScreen` (`/force-upgrade`): needs dev `app_config` to demand a version above the build,
  a config write no ticket may make without Lee's ruling.
- `CoachRegistrationScreen` (`/coach/apply`, web only) and the web layout generally (the Coach tab,
  the navigation rail): the round has no web build; 19's web half runs only if the lead starts one.
- `LogScannedFoodScreen`: opens only after a real barcode scan; 07 expects to hand it to Lee's phone.
- Remote push taps (`activity:<id>` payloads, the Garmin completion push) and the local "activity
  uploaded" notification: need APNs/OneSignal or a real Garmin upload; 17 leaves them as followup-tests.
- Formula editor's coach-insight panel: behind `COACH_INSIGHTS_ENABLED`, off by default; 10 records
  whether it shows, nothing more.

**Route-only screens (no button leads there; 08 opens each by deep link, render only):** `/pro`
(`ProVersionScreen`), `/settings/sport-settings`, `/settings/food-preferences-consolidated`,
`/settings/food-preferences/add-food` (`AddFoodScreen`), `/athlete/feedback`, `/meal-log/manual`,
`/meal-log/photo`, `/meal-log/describe`, `/meal-log/recent-saved`, `/meal-log/recipe`, and `/jade`
(`AiCoachBanner` is mounted nowhere; 12 uses Jade by deep link). Their submit paths stay untested
except where 02–05 and 12 reach the same code through the sheet.
