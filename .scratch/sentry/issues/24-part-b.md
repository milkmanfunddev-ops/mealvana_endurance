# 24, part B: N+1 queries and Vana refusals

The N+1 and Vana half of `24-dev-only-cleanup.md` (agent 24b). The layout, key and lifecycle half
is agent 24a's.

**Status:** done

- [x] The N+1 queries batched (DEV-88, DEV-89, DEV-97), each with a query-count test that was red
      before the fix and green after
- [x] Vana unauthenticated (DEV-90, DEV-91), pro-required (DEV-9C) and Code redeem (DEV-9A)
      confirmed: they still arrived as Fault on `sentry`; they now arrive as Degraded
- [ ] Issues resolved in Sentry (lead, after merge, with the final sha)

## Root cause

**DEV-88** (N+1 Query, 16 events, `ui.load root /`, 1.27.1+4). The span tree repeats
`SELECT * FROM activities WHERE lower(user_id)=? AND brick_id=? AND status IN archived…` and
`SELECT * FROM activities WHERE lower(user_id)=? AND id IN (?, ?) AND activity_type<>'brick'`,
seven bricks, twice over (two readers of the same week). Source:
`ActivitiesService._hydrateBrickMetadataForActivities`
(`lib/features/activities/application/activities_service.dart`). For each brick with no
`brickMetadata.segments` it ran one archived-legs query by `brick_id`, then
`_findLegacyBrickSegmentRows` ran one more by the leg ids parsed from the title. The athlete's
bricks were legacy ones (`<uuid> / <uuid> BRICK`) whose legs no longer exist, so nothing was ever
recovered and every week load paid the queries again.

**DEV-89** (N+1 Query, 5 events, `settings-formula-library`, last seen 1.26.0 on 2026-09-16; the
code was unchanged on `sentry`, so the issue is live). One `personal_formulas` read, then
`SELECT * FROM template_foods WHERE is_active=? ORDER BY name` 41 times.
`PersonalFormulasController.build` called `hydrateComponentConflictMetadata(ref, f.components)`
once per formula, and each call read the whole catalog.

**DEV-97** (N+1 Query, 4 events, `ui.load main`, 1.27.1+4). The repeating pair is
`INSERT OR REPLACE INTO daily_macro_targets …` and
`POST /rest/v1/daily_macro_targets?on_conflict=user_id,target_date`, once per computed day.
`DailyMacroService._calculateWeekOnce` looped over the engine's week response calling
`saveToLocal` and `saveToRemote` per day. (The `GET /rest/v1/users` in the pattern is an
unrelated span that happened to interleave.)

**DEV-90, DEV-91** (`VanaUnauthenticatedException: unauthenticated`), **DEV-9C**
(`ProRequiredException: pro_required`). All three are tagged `component: riverpod_provider`
(providers `homeControllerProvider`, `mealDetailControllerProvider`). `VanaTransport.mapErrorResponse`
already sends a 401/403/429 as a Degraded (`LoggedFault('Vana HTTP 401')`), then throws the typed
exception. That exception fails the provider, and `SentryProviderObserver.providerDidFail` sent it
again through `report.fault`. The allow-list did not know the Vana types, so the second copy was a
Fault. This was still true on `sentry` at `d8a7c29d`: the test below fails there.

**DEV-9A** (`CodeRedeemFailure(unavailable)`, `codeEntryControllerProvider`). Same observer path:
`CodeEntryController.redeem` writes the failure into state through `AsyncValue.guard`. The
breadcrumb shows `POST /functions/v1/redeem-code` answering non-2xx; `_invoke` maps that to
`CodeRedeemFailure.unavailable()` and the entry shows "try again". The code entry lives on
`mealplanning` and is not on `sentry` yet (commits `ed9bf7e8`, `ee7183af`), so the fix is the
allow-list entry, which applies once the branches meet.

**DEV-A4, DEV-AF, DEV-AG, DEV-AH, DEV-AK, DEV-AJ.** Deliberate probes. A4 is ticket 12's
`ensure-credits` probe throw; AF, AG, AH, AK are ticket 15's debug-screen probes (Fault, Degraded,
Note then Fault, unhandled crash); AJ is ticket 15's edge probe posting `'not json'` to
`get-foods` (event `5e04bf51…`, recorded in `15-device-check-and-the-doc.md`).

## Fix

- **DEV-88.** `_hydrateBrickMetadataForActivities` collects the bricks that need hydration, then
  runs ONE archived-legs query (`brick_id IN (…)`, grouped by brick) and ONE legacy-legs query
  (`id IN (…)` over every id parsed from every legacy title) before the loop. The per-brick
  ordering and recovery logic is unchanged (`_orderLegacyBrickSegmentRows`). The title-match
  fallback (titles that name sports, `BIKE / RUN`) still queries per brick; it runs only after
  both batched lookups found nothing. A list with no brick to hydrate runs no extra query.
- **DEV-89.** `component_conflict_hydration.dart` gains `hydrateComponentConflictMetadataAll`,
  which reads the catalog once for a list of component lists. `PersonalFormulasController.build`
  uses it. The single-formula function (editor) is unchanged in behaviour.
- **DEV-97.** `DailyMacroTargetsRepository` gains `saveAllToLocal` (one Drift `batch`: one
  transaction, one executor call, one Sentry span) and `saveAllToRemote` (one PostgREST upsert of
  the row array, same `onConflict: 'user_id,target_date'` as the single-day path, which has
  always worked against that table). `_calculateWeekOnce` saves the computed days with them. The
  remote failure handling is shared with `saveToRemote` and now carries `days` in its data.
- **Vana and Code refusals.** `expected_failures.dart` gains two reasons and four entries:
  `VanaUnauthenticatedException` → `expired_session`; `ProRequiredException` → `not_entitled`
  (new); `VanaRateLimitedException` and `CodeRedeemFailure(` → `handled_refusal` (new). `Report`
  downgrades them on its own, so the observer's copy now arrives as a warning with the reason
  tag. A Vana 5xx (`VanaServerException`) stays a Fault. The 429 was not in the ticket; it takes
  the same path and the transport comment already calls it expected.

Files:
- `lib/features/activities/application/activities_service.dart`
- `lib/features/formula_kit/application/component_conflict_hydration.dart`
- `lib/features/formula_kit/application/personal_formulas_controller.dart`
- `lib/features/daily_macros/data/daily_macro_targets_repository.dart`
- `lib/features/daily_macros/application/daily_macro_service.dart`
- `lib/shared/services/report/expected_failures.dart`

Tests (each red before its fix, green after; red counts in brackets):
- `test/helpers/query_counter.dart`: a Drift `QueryInterceptor` that counts statements; reusable
  for the next N+1.
- `test/features/activities/application/brick_hydration_query_count_test.dart`: real
  `ActivitiesService` over a counting in-memory DB, seven orphan legacy bricks plus a linked and a
  recoverable legacy brick. Asserts 3 `activities` selects for the week (was 18) and that the
  recovered metadata and relinking are unchanged.
- `test/features/formula_kit/personal_formulas_catalog_query_count_test.dart`: real
  `PersonalFormulasController` and `TemplateFoodsRepository`; 41 formulas read the catalog once
  (was 41) and every component still gets its allergens and diets.
- `test/features/daily_macros/week_save_round_trips_test.dart`: real `DailyMacroService`, real
  `SupabaseClient` over an in-memory HTTP client answering with the engine's week shape. Asserts
  one local batch of 7 and no per-day INSERT (was 7), and one POST carrying 7 rows.
- `test/features/meal_planning/data/vana_refusals_degraded_test.dart`: real `VanaTransport` →
  provider failure → real `SentryProviderObserver` → real `SentryReport` with an in-memory SDK
  transport. 401, 403 `pro_required`, 429 and both `CodeRedeemFailure` kinds arrive as warnings
  with their reason tag (5 red before); a 500 stays an error (control).

Verification: `dart analyze` clean on every changed file; the five files above, plus
`test/shared/source_guard`, `report_test.dart`, `sentry_provider_observer_test.dart`,
`fork_conflict_metadata_test.dart` and `daily_macro_targets_roundtrip_test.dart`: 76 tests pass.
No full suite (wave rule).

## Owed

- **No device run.** The query counts are proven in tests only. Confirming in Sentry means a dev
  build: open the week with an orphan legacy brick (DEV-88), the formula library (DEV-89), and a
  week with uncached days (DEV-97), then check no new N+1 event arrives on the new release.
- **The Code test uses a stand-in class.** `CodeRedeemFailure` is on `mealplanning` only; the test
  declares a class with the same name and `toString()` (the allow-list classifies on exactly that
  text). When `mealplanning` merges into `sentry` (or the reverse), point the test at the real
  type. On the same merge, `CodeEntryController._invoke` still calls the deleted legacy logger; its
  5xx branch should become `report.degraded` with the status, so the cause of an `unavailable`
  is still recorded on the client.
- **Two warnings per Vana refusal.** The transport's Degraded (`Vana HTTP 401`) and the observer's
  downgraded copy both arrive. Neither alerts. If the count bothers Lee, the transport's own report
  could become a Note.
- **Title-match brick fallback** still queries once per orphan brick whose title names sports
  (`BIKE / RUN`). The DEV-88 athlete's bricks never reached it; batch it if a new N+1 event shows
  `activity_type IN (…) AND scheduled_date_time BETWEEN`.

## Sentry resolution

| Issue | Action | Comment for Sentry |
|---|---|---|
| MEALVANA-ENDURANCE-DEV-88 | resolve | Brick hydration batched: one archived-legs and one legacy-legs query per list, not two per brick (ticket 24b, `<sha>`). |
| MEALVANA-ENDURANCE-DEV-89 | resolve | Your Formulas reads the template_foods catalog once per load, not once per formula (ticket 24b, `<sha>`). |
| MEALVANA-ENDURANCE-DEV-97 | resolve | Week macros saved in one Drift batch and one PostgREST upsert instead of one of each per day (ticket 24b, `<sha>`). |
| MEALVANA-ENDURANCE-DEV-90 | resolve-as-degraded | Vana 401 is an expected refusal; now Degraded with expected_failure:expired_session (ticket 24b, `<sha>`). |
| MEALVANA-ENDURANCE-DEV-91 | resolve-as-degraded | Vana 401 is an expected refusal; now Degraded with expected_failure:expired_session (ticket 24b, `<sha>`). |
| MEALVANA-ENDURANCE-DEV-9C | resolve-as-degraded | Vana 403 pro_required routes to the paywall; now Degraded with expected_failure:not_entitled (ticket 24b, `<sha>`). |
| MEALVANA-ENDURANCE-DEV-9A | resolve-as-degraded | CodeRedeemFailure is shown to the athlete; now Degraded with expected_failure:handled_refusal once the Code entry reaches this branch (ticket 24b, `<sha>`). |
| MEALVANA-ENDURANCE-DEV-A4 | resolve | Deliberate probe (ticket 12): ensure-credits probe throw. |
| MEALVANA-ENDURANCE-DEV-AF | resolve | Deliberate probe (ticket 15): debug screen Fault. |
| MEALVANA-ENDURANCE-DEV-AG | resolve | Deliberate probe (ticket 15): debug screen Degraded. |
| MEALVANA-ENDURANCE-DEV-AH | resolve | Deliberate probe (ticket 15): debug screen Note then Fault. |
| MEALVANA-ENDURANCE-DEV-AK | resolve | Deliberate probe (ticket 15): debug screen unhandled crash. |
| MEALVANA-ENDURANCE-DEV-AJ | resolve | Deliberate probe (ticket 15): edge probe posted 'not json' to get-foods. |
